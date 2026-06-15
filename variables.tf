# ---------------------------------------------------------------------------
# Core identity
# ---------------------------------------------------------------------------

variable "name" {
  description = "Name for the load balancer. Becomes the resource name and prefix for derived target groups. 1–32 chars, alphanumeric + hyphens, no leading/trailing hyphen — AWS rejects longer or hyphen-edged names."
  type        = string
  validation {
    condition     = length(var.name) >= 1 && length(var.name) <= 32 && can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$", var.name))
    error_message = "name must be 1–32 chars, alphanumeric + hyphens, no leading/trailing hyphen."
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_id" {
  description = "VPC where the ALB and its target groups live."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs the ALB attaches to. Must span at least two AZs (AWS requirement). For internal=false, these should be public subnets; for internal=true, private subnets."
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "ALB requires at least 2 subnets in different AZs."
  }
}

variable "security_group_ids" {
  description = "Security group IDs attached to the ALB. Caller is responsible for the SG ingress (typically: HTTPS 443 from 0.0.0.0/0 for public ALBs, or from app SGs for internal)."
  type        = list(string)
  validation {
    condition     = length(var.security_group_ids) >= 1
    error_message = "ALB requires at least 1 security group."
  }
}

variable "internal" {
  description = "Internal ALB (private IPs only) vs internet-facing. Default false — most callers want internet-facing. Set true for service-to-service inside a VPC; pair with private subnets and an internal-only DNS record."
  type        = bool
  default     = false
}

variable "ip_address_type" {
  description = "IP address type. \"ipv4\" (default) for IPv4-only listeners; \"dualstack\" for IPv4+IPv6. Aurora-grade IPv6 readiness in fintech — verify your VPC has IPv6 enabled before setting dualstack."
  type        = string
  default     = "ipv4"
  validation {
    condition     = contains(["ipv4", "dualstack", "dualstack-without-public-ipv4"], var.ip_address_type)
    error_message = "ip_address_type must be ipv4, dualstack, or dualstack-without-public-ipv4."
  }
}

# ---------------------------------------------------------------------------
# Attributes — fintech-safe defaults
# ---------------------------------------------------------------------------

variable "enable_deletion_protection" {
  description = "Block accidental deletion via terraform destroy or AWS console. Default true — flip to false explicitly before a planned teardown."
  type        = bool
  default     = true
}

variable "drop_invalid_header_fields" {
  description = "Drop HTTP headers with names not conforming to RFC 7230. Mitigates request-smuggling. Default true (security best practice)."
  type        = bool
  default     = true
}

variable "desync_mitigation_mode" {
  description = "How the ALB handles requests that could confuse upstream proxies (the \"HTTP desync\" attack class). \"defensive\" is the AWS-recommended balance; \"strictest\" rejects more; \"monitor\" logs only."
  type        = string
  default     = "defensive"
  validation {
    condition     = contains(["monitor", "defensive", "strictest"], var.desync_mitigation_mode)
    error_message = "desync_mitigation_mode must be monitor, defensive, or strictest."
  }
}

variable "enable_http2" {
  description = "Enable HTTP/2 on the ALB. Default true — almost every modern client supports it and it improves latency."
  type        = bool
  default     = true
}

variable "idle_timeout" {
  description = "Idle timeout in seconds. AWS default 60. Increase for long-running streaming workloads (WebSockets, server-sent events) but watch out for cost on long-lived connections."
  type        = number
  default     = 60
  validation {
    condition     = var.idle_timeout >= 1 && var.idle_timeout <= 4000
    error_message = "idle_timeout must be 1-4000 seconds."
  }
}

variable "preserve_host_header" {
  description = "Forward the original Host header to targets without rewriting. Default true — apps that depend on the original Host (multi-tenant routing, signed URLs) need this."
  type        = bool
  default     = true
}

variable "xff_header_processing_mode" {
  description = "How the ALB handles incoming X-Forwarded-For. \"preserve\" keeps client values, \"append\" appends the client IP, \"remove\" strips it. Default \"append\"."
  type        = string
  default     = "append"
  validation {
    condition     = contains(["append", "preserve", "remove"], var.xff_header_processing_mode)
    error_message = "xff_header_processing_mode must be append, preserve, or remove."
  }
}

# ---------------------------------------------------------------------------
# Access logs — opt-in. Pair with terraform-aws-s3 for the bucket.
# ---------------------------------------------------------------------------

variable "access_logs_bucket" {
  description = "S3 bucket name to receive ALB access logs. Empty string disables logging. The bucket policy must allow the ELB service account in your region to PutObject (see AWS docs); when consuming devotica-labs/terraform-aws-s3, see the README \"ALB access logs\" section."
  type        = string
  default     = ""
}

variable "access_logs_prefix" {
  description = "Prefix for access log objects in the bucket. Trailing slash optional."
  type        = string
  default     = ""
}

variable "access_logs_enabled" {
  description = "Force-off switch for access logs even when access_logs_bucket is non-empty. Default true (logs on whenever bucket is set)."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Target groups
#
# Map keyed by a stable name (e.g. "api", "static") — the key is part of
# the Terraform address, so keep it stable across renames.
# ---------------------------------------------------------------------------

variable "target_groups" {
  description = "Map of target group key → config. See README for the full schema and listener-default-action references."
  type = map(object({
    port                          = number
    protocol                      = optional(string, "HTTP")
    protocol_version              = optional(string, "HTTP1")
    target_type                   = optional(string, "instance")
    deregistration_delay          = optional(number, 30)
    slow_start                    = optional(number, 0)
    load_balancing_algorithm_type = optional(string, "round_robin")

    health_check = optional(object({
      enabled             = optional(bool, true)
      path                = optional(string, "/")
      port                = optional(string, "traffic-port")
      protocol            = optional(string, "HTTP")
      matcher             = optional(string, "200-299")
      healthy_threshold   = optional(number, 2)
      unhealthy_threshold = optional(number, 3)
      interval            = optional(number, 30)
      timeout             = optional(number, 5)
    }), {})

    stickiness = optional(object({
      enabled         = optional(bool, false)
      type            = optional(string, "lb_cookie")
      cookie_duration = optional(number, 86400)
      cookie_name     = optional(string)
    }), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, tg in var.target_groups : contains(["HTTP", "HTTPS"], tg.protocol)
    ])
    error_message = "Every target_group.protocol must be HTTP or HTTPS."
  }

  validation {
    condition = alltrue([
      for k, tg in var.target_groups : contains(["instance", "ip", "lambda", "alb"], tg.target_type)
    ])
    error_message = "Every target_group.target_type must be one of: instance, ip, lambda, alb."
  }
}

# ---------------------------------------------------------------------------
# Listeners
#
# Map keyed by a stable name (e.g. "https", "http-redirect"). Each entry
# defines a port, protocol, and a default action — forward to a target
# group, redirect, or fixed response.
# ---------------------------------------------------------------------------

variable "listeners" {
  description = "Map of listener key → config. See README for the full schema."
  type = map(object({
    port            = number
    protocol        = string
    ssl_policy      = optional(string, "ELBSecurityPolicy-TLS13-1-2-2021-06")
    certificate_arn = optional(string)

    # default_action — exactly one of forward/redirect/fixed_response
    default_action_type = string
    target_group_key    = optional(string)

    redirect = optional(object({
      host        = optional(string, "#{host}")
      path        = optional(string, "/#{path}")
      port        = optional(string, "443")
      protocol    = optional(string, "HTTPS")
      query       = optional(string, "#{query}")
      status_code = optional(string, "HTTP_301")
    }), {})

    fixed_response = optional(object({
      content_type = optional(string, "text/plain")
      message_body = optional(string, "")
      status_code  = optional(string, "200")
    }), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, l in var.listeners : contains(["HTTP", "HTTPS"], l.protocol)
    ])
    error_message = "Every listener.protocol must be HTTP or HTTPS."
  }

  validation {
    condition = alltrue([
      for k, l in var.listeners : contains(["forward", "redirect", "fixed-response"], l.default_action_type)
    ])
    error_message = "Every listener.default_action_type must be one of: forward, redirect, fixed-response."
  }

  validation {
    condition = alltrue([
      for k, l in var.listeners :
      l.protocol != "HTTPS" || (l.certificate_arn != null && l.certificate_arn != "")
    ])
    error_message = "HTTPS listeners must supply certificate_arn."
  }

  validation {
    condition = alltrue([
      for k, l in var.listeners :
      l.default_action_type != "forward" || (l.target_group_key != null && l.target_group_key != "")
    ])
    error_message = "Listeners with default_action_type = forward must reference target_group_key."
  }
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags merged onto every taggable resource."
  type        = map(string)
  default     = {}
}
