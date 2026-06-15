# ---------------------------------------------------------------------------
# Provider block — CI-friendly skip flags + non-AWS-shaped placeholder creds.
# ---------------------------------------------------------------------------
provider "aws" {
  region                      = "ap-south-1"
  access_key                  = "not-a-real-aws-key"
  secret_key                  = "not-a-real-aws-secret"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# Uses local path during development.
# Change to Registry source after first release:
#   source  = "devotica-labs/alb/aws"
#   version = "~> 0.1"

module "alb" {
  source = "../.."

  name = "devotica-prod-edge"

  vpc_id             = "vpc-00000000000000000"
  subnet_ids         = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb", "subnet-ccccccccccccccccc"]
  security_group_ids = ["sg-00000000000000000"]

  internal        = false
  ip_address_type = "dualstack"

  # All security defaults are already on; restating for the example.
  enable_deletion_protection = true
  drop_invalid_header_fields = true
  desync_mitigation_mode     = "defensive"
  enable_http2               = true
  idle_timeout               = 60
  preserve_host_header       = true
  xff_header_processing_mode = "append"

  # Access logs to the data bucket from terraform-aws-s3.
  access_logs_bucket = "devotica-prod-911526871324-data"
  access_logs_prefix = "alb-access-logs/devotica-prod-edge"

  target_groups = {
    api = {
      port             = 8080
      protocol         = "HTTP"
      protocol_version = "HTTP1"
      target_type      = "ip" # for ECS / EKS
      health_check = {
        path                = "/healthz"
        interval            = 15
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
    }
    static = {
      port        = 80
      protocol    = "HTTP"
      target_type = "ip"
      health_check = {
        path    = "/_health"
        matcher = "200"
      }
    }
  }

  listeners = {
    https = {
      port                = 443
      protocol            = "HTTPS"
      ssl_policy          = "ELBSecurityPolicy-TLS13-1-2-2021-06"
      certificate_arn     = "arn:aws:acm:ap-south-1:111122223333:certificate/00000000-0000-0000-0000-000000000000"
      default_action_type = "forward"
      target_group_key    = "api"
    }
    http-redirect = {
      port                = 80
      protocol            = "HTTP"
      default_action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    health = {
      port                = 8081
      protocol            = "HTTP"
      default_action_type = "fixed-response"
      fixed_response = {
        content_type = "text/plain"
        message_body = "ALB OK"
        status_code  = "200"
      }
    }
  }

  tags = {
    Environment = "production"
    Project     = "edge"
    Owner       = "platform@devotica.com"
    CostCenter  = "PLATFORM"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/devotica-labs/terraform-aws-alb"
  }
}
