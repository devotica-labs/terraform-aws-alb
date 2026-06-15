output "lb_dns_name" {
  description = "DNS name of the ALB."
  value       = module.alb.lb_dns_name
}

output "target_group_arns" {
  description = "Map of target group key → ARN."
  value       = module.alb.target_group_arns
}
