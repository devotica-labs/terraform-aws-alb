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

  name = "my-app-alb"

  vpc_id             = "vpc-00000000000000000"
  subnet_ids         = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]
  security_group_ids = ["sg-00000000000000000"]

  target_groups = {
    api = {
      port = 8080
      # Defaults: HTTP, HTTP1, instance, 30s deregistration, sane health checks.
    }
  }

  listeners = {
    https = {
      port                = 443
      protocol            = "HTTPS"
      certificate_arn     = "arn:aws:acm:ap-south-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
      default_action_type = "forward"
      target_group_key    = "api"
    }
    http-redirect = {
      port                = 80
      protocol            = "HTTP"
      default_action_type = "redirect"
      # Redirect to HTTPS — block defaults already to 443/HTTPS/301.
    }
  }

  tags = {
    Environment = "example"
    Project     = "terraform-aws-alb"
    Owner       = "platform@devotica.com"
    CostCenter  = "PLATFORM-OSS"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/devotica-labs/terraform-aws-alb"
  }
}
