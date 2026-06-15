output "lb_arn" {
  description = "ARN of the ALB."
  value       = module.alb.lb_arn
}

output "lb_dns_name" {
  description = "DNS name of the ALB."
  value       = module.alb.lb_dns_name
}

output "lb_zone_id" {
  description = "Hosted zone ID of the ALB (for Route 53 alias records)."
  value       = module.alb.lb_zone_id
}

output "target_group_arns" {
  description = "Map of target group key → ARN."
  value       = module.alb.target_group_arns
}

output "listener_arns" {
  description = "Map of listener key → ARN."
  value       = module.alb.listener_arns
}

output "access_logs_active" {
  description = "Whether ALB access logs are being written."
  value       = module.alb.access_logs_active
}
