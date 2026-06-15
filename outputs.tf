output "lb_arn" {
  description = "ARN of the ALB."
  value       = aws_lb.this.arn
}

output "lb_arn_suffix" {
  description = "ARN suffix (the part used in CloudWatch metric dimensions)."
  value       = aws_lb.this.arn_suffix
}

output "lb_id" {
  description = "ID of the ALB. Equal to the ARN."
  value       = aws_lb.this.id
}

output "lb_name" {
  description = "Name of the ALB (equals var.name)."
  value       = aws_lb.this.name
}

output "lb_dns_name" {
  description = "DNS name AWS assigned to the ALB. Use this as the target of a Route 53 alias record."
  value       = aws_lb.this.dns_name
}

output "lb_zone_id" {
  description = "Hosted zone ID of the ALB. Required when creating a Route 53 alias record."
  value       = aws_lb.this.zone_id
}

output "target_group_arns" {
  description = "Map of target group key → ARN. Consume from app modules (ECS services, EC2 ASGs) when registering targets."
  value       = { for k, tg in aws_lb_target_group.this : k => tg.arn }
}

output "target_group_arn_suffixes" {
  description = "Map of target group key → ARN suffix (CloudWatch dimension)."
  value       = { for k, tg in aws_lb_target_group.this : k => tg.arn_suffix }
}

output "target_group_names" {
  description = "Map of target group key → name."
  value       = { for k, tg in aws_lb_target_group.this : k => tg.name }
}

output "listener_arns" {
  description = "Map of listener key → ARN. Use when attaching listener rules (host- or path-based routing) from a separate module."
  value       = { for k, l in aws_lb_listener.this : k => l.arn }
}

output "access_logs_active" {
  description = "Whether ALB access logs are currently being written to S3."
  value       = local.access_logs_active
}
