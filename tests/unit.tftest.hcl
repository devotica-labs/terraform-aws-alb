# Plan-only unit tests — no AWS credentials required.

mock_provider "aws" {}

variables {
  name               = "unit-test-alb"
  vpc_id             = "vpc-00000000000000000"
  subnet_ids         = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]
  security_group_ids = ["sg-00000000000000000"]

  target_groups = {
    api = {
      port = 8080
    }
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

  tags = { Environment = "unit-test" }
}

run "lb_planned" {
  command = plan
  assert {
    condition     = aws_lb.this.name == "unit-test-alb"
    error_message = "ALB name must equal var.name."
  }
  assert {
    condition     = aws_lb.this.load_balancer_type == "application"
    error_message = "ALB load_balancer_type must always be \"application\" — this module is ALB-only."
  }
}

run "deletion_protection_default_on" {
  command = plan
  assert {
    condition     = aws_lb.this.enable_deletion_protection == true
    error_message = "enable_deletion_protection must default to true."
  }
}

run "drop_invalid_header_fields_default_on" {
  command = plan
  assert {
    condition     = aws_lb.this.drop_invalid_header_fields == true
    error_message = "drop_invalid_header_fields must default to true (request-smuggling mitigation)."
  }
}

run "desync_mitigation_defensive_default" {
  command = plan
  assert {
    condition     = aws_lb.this.desync_mitigation_mode == "defensive"
    error_message = "desync_mitigation_mode must default to defensive."
  }
}

run "http2_default_on" {
  command = plan
  assert {
    condition     = aws_lb.this.enable_http2 == true
    error_message = "enable_http2 must default to true."
  }
}

run "internal_default_false" {
  command = plan
  assert {
    condition     = aws_lb.this.internal == false
    error_message = "internal must default to false (internet-facing — the common case)."
  }
}

run "ipv4_default" {
  command = plan
  assert {
    condition     = aws_lb.this.ip_address_type == "ipv4"
    error_message = "ip_address_type must default to ipv4."
  }
}

run "target_group_count" {
  command = plan
  assert {
    condition     = length(aws_lb_target_group.this) == 1
    error_message = "Expected 1 target group when var.target_groups has 1 entry."
  }
}

run "target_group_name_is_prefixed" {
  command = plan
  assert {
    condition     = aws_lb_target_group.this["api"].name == "unit-test-alb-api"
    error_message = "Target group name must be <alb-name>-<tg-key>."
  }
}

run "listener_count" {
  command = plan
  assert {
    condition     = length(aws_lb_listener.this) == 1
    error_message = "Expected 1 listener when var.listeners has 1 entry."
  }
}

run "https_listener_has_certificate" {
  command = plan
  assert {
    condition     = aws_lb_listener.this["https"].certificate_arn != ""
    error_message = "HTTPS listener must have certificate_arn wired through."
  }
}

run "https_listener_has_tls13_default_policy" {
  command = plan
  assert {
    condition     = aws_lb_listener.this["https"].ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2021-06"
    error_message = "Default SSL policy must be the TLS 1.2/1.3 modern policy."
  }
}

run "access_logs_off_by_default" {
  command = plan
  assert {
    condition     = length(aws_lb.this.access_logs) == 0 || aws_lb.this.access_logs[0].enabled == false
    error_message = "Access logs must be off by default (no bucket supplied)."
  }
}

run "access_logs_on_when_bucket_set" {
  command = plan
  variables {
    access_logs_bucket = "my-bucket"
  }
  assert {
    condition     = aws_lb.this.access_logs[0].enabled == true
    error_message = "Access logs must be on when access_logs_bucket is set."
  }
}

run "tags_merged_with_defaults" {
  command = plan
  assert {
    condition     = aws_lb.this.tags["ManagedBy"] == "terraform"
    error_message = "Module-default tag ManagedBy must be merged."
  }
  assert {
    condition     = aws_lb.this.tags["Module"] == "terraform-aws-alb"
    error_message = "Module-default tag Module must be terraform-aws-alb."
  }
}

run "multiple_target_groups_and_listeners" {
  command = plan
  variables {
    target_groups = {
      api    = { port = 8080 }
      static = { port = 80 }
    }
    listeners = {
      https = {
        port                = 443
        protocol            = "HTTPS"
        certificate_arn     = "arn:aws:acm:ap-south-1:111122223333:certificate/00000000-0000-0000-0000-000000000000"
        default_action_type = "forward"
        target_group_key    = "api"
      }
      http-redirect = {
        port                = 80
        protocol            = "HTTP"
        default_action_type = "redirect"
      }
    }
  }
  assert {
    condition     = length(aws_lb_target_group.this) == 2
    error_message = "Expected 2 target groups."
  }
  assert {
    condition     = length(aws_lb_listener.this) == 2
    error_message = "Expected 2 listeners."
  }
}
