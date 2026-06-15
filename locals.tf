locals {
  common_tags = merge(
    { ManagedBy = "terraform", Module = "terraform-aws-alb" },
    var.tags
  )

  # Access logs are written only when (bucket non-empty) AND access_logs_enabled.
  access_logs_active = var.access_logs_bucket != "" && var.access_logs_enabled
}
