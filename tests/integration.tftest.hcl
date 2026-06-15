# Integration tests — apply + assert + destroy.
# Requires real AWS credentials AND pre-existing networking (VPC + subnets + SG + ACM cert).
# Triggered via workflow_dispatch on integration.yml.

provider "aws" {
  region = "ap-south-1"
}

variables {
  name = "integ-test-alb"

  vpc_id             = ""
  subnet_ids         = []
  security_group_ids = []

  target_groups = {
    api = {
      port        = 8080
      target_type = "ip"
    }
  }

  listeners = {
    http = {
      port                = 80
      protocol            = "HTTP"
      default_action_type = "fixed-response"
      fixed_response = {
        content_type = "text/plain"
        message_body = "integ-test OK"
        status_code  = "200"
      }
    }
  }

  enable_deletion_protection = false # so the integration teardown actually destroys

  tags = { Environment = "integration-test", Ephemeral = "true" }
}

run "apply_and_assert" {
  command = apply

  assert {
    condition     = aws_lb.this.arn != ""
    error_message = "ALB ARN must be set after apply."
  }
  assert {
    condition     = aws_lb.this.drop_invalid_header_fields == true
    error_message = "drop_invalid_header_fields must be true after apply."
  }
  assert {
    condition     = length(aws_lb_target_group.this) == 1
    error_message = "Expected exactly 1 target group."
  }
  assert {
    condition     = length(aws_lb_listener.this) == 1
    error_message = "Expected exactly 1 listener."
  }
}
