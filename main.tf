# ---------------------------------------------------------------------------
# Application Load Balancer
#
# Fintech-safe defaults baked in:
#   - deletion_protection on
#   - drop_invalid_header_fields on (request-smuggling mitigation)
#   - desync_mitigation_mode = defensive (HTTP desync mitigation)
#   - HTTP/2 on
#   - preserve_host_header on
#   - xff_header_processing_mode = append
# ---------------------------------------------------------------------------

resource "aws_lb" "this" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids
  ip_address_type    = var.ip_address_type

  enable_deletion_protection = var.enable_deletion_protection
  drop_invalid_header_fields = var.drop_invalid_header_fields
  desync_mitigation_mode     = var.desync_mitigation_mode
  enable_http2               = var.enable_http2
  idle_timeout               = var.idle_timeout
  preserve_host_header       = var.preserve_host_header
  xff_header_processing_mode = var.xff_header_processing_mode

  dynamic "access_logs" {
    for_each = local.access_logs_active ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.access_logs_prefix
      enabled = true
    }
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Target groups
# ---------------------------------------------------------------------------

resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  name                          = "${var.name}-${each.key}"
  port                          = each.value.port
  protocol                      = each.value.protocol
  protocol_version              = each.value.protocol_version
  vpc_id                        = var.vpc_id
  target_type                   = each.value.target_type
  deregistration_delay          = each.value.deregistration_delay
  slow_start                    = each.value.slow_start
  load_balancing_algorithm_type = each.value.load_balancing_algorithm_type

  health_check {
    enabled             = each.value.health_check.enabled
    path                = each.value.health_check.path
    port                = each.value.health_check.port
    protocol            = each.value.health_check.protocol
    matcher             = each.value.health_check.matcher
    healthy_threshold   = each.value.health_check.healthy_threshold
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
    interval            = each.value.health_check.interval
    timeout             = each.value.health_check.timeout
  }

  dynamic "stickiness" {
    for_each = each.value.stickiness.enabled ? [1] : []
    content {
      enabled         = true
      type            = each.value.stickiness.type
      cookie_duration = each.value.stickiness.cookie_duration
      cookie_name     = each.value.stickiness.cookie_name
    }
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Listeners
# ---------------------------------------------------------------------------

resource "aws_lb_listener" "this" {
  for_each = var.listeners

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port
  protocol          = each.value.protocol
  ssl_policy        = each.value.protocol == "HTTPS" ? each.value.ssl_policy : null
  certificate_arn   = each.value.protocol == "HTTPS" ? each.value.certificate_arn : null

  default_action {
    type             = each.value.default_action_type
    target_group_arn = each.value.default_action_type == "forward" ? aws_lb_target_group.this[each.value.target_group_key].arn : null

    dynamic "redirect" {
      for_each = each.value.default_action_type == "redirect" ? [each.value.redirect] : []
      content {
        host        = redirect.value.host
        path        = redirect.value.path
        port        = redirect.value.port
        protocol    = redirect.value.protocol
        query       = redirect.value.query
        status_code = redirect.value.status_code
      }
    }

    dynamic "fixed_response" {
      for_each = each.value.default_action_type == "fixed-response" ? [each.value.fixed_response] : []
      content {
        content_type = fixed_response.value.content_type
        message_body = fixed_response.value.message_body
        status_code  = fixed_response.value.status_code
      }
    }
  }

  tags = local.common_tags
}
