# Contract tests — output surface stays stable across minor + patch versions.

mock_provider "aws" {}

variables {
  name               = "contract-alb"
  vpc_id             = "vpc-00000000000000000"
  subnet_ids         = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]
  security_group_ids = ["sg-00000000000000000"]

  target_groups = {
    api = { port = 8080 }
  }

  listeners = {
    https = {
      port                = 443
      protocol            = "HTTPS"
      certificate_arn     = "arn:aws:acm:ap-south-1:111122223333:certificate/00000000-0000-0000-0000-000000000000"
      default_action_type = "forward"
      target_group_key    = "api"
    }
  }
}

run "single_alb_planned" {
  command = plan
  assert {
    condition     = length([aws_lb.this]) == 1
    error_message = "Exactly one aws_lb.this resource must be planned."
  }
}

run "vpc_id_passthrough" {
  command = plan
  assert {
    condition     = aws_lb_target_group.this["api"].vpc_id == "vpc-00000000000000000"
    error_message = "Target group vpc_id must equal var.vpc_id."
  }
}

run "subnet_count_at_least_two" {
  command = plan
  assert {
    condition     = length(aws_lb.this.subnets) >= 2
    error_message = "ALB must attach to at least 2 subnets."
  }
}

run "load_balancer_type_always_application" {
  command = plan
  assert {
    condition     = aws_lb.this.load_balancer_type == "application"
    error_message = "load_balancer_type must always be \"application\" — NLB callers should use a sister module."
  }
}

run "target_group_key_stable" {
  command = plan
  assert {
    condition     = aws_lb_target_group.this["api"].port == 8080
    error_message = "Target group key \"api\" must produce a TG with the configured port."
  }
}
