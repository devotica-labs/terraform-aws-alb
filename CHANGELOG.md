# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Releases are cut automatically by `release-please` on merge to `main`,
driven by Conventional Commit prefixes (`feat:` → minor, `fix:`/`docs:`/`chore:` → patch,
`feat!:` or `BREAKING CHANGE:` footer → major).

## [Unreleased]

### Added
- Initial module scaffold.
- Single `aws_lb` (load_balancer_type = application). NLB belongs in a
  sister module (terraform-aws-nlb) — the two share enough surface to be
  confusing if combined.
- `var.target_groups` map → one `aws_lb_target_group` per entry, with
  configurable health checks and stickiness.
- `var.listeners` map → one `aws_lb_listener` per entry, supporting
  `forward` / `redirect` / `fixed-response` default actions.
- Fintech-safe defaults: `enable_deletion_protection`,
  `drop_invalid_header_fields`, `desync_mitigation_mode = defensive`,
  `enable_http2`, `preserve_host_header`, TLS 1.2/1.3 modern SSL policy
  (`ELBSecurityPolicy-TLS13-1-2-2021-06`).
- Validation refuses HTTPS listeners without `certificate_arn` and
  `forward` listeners without `target_group_key`.
- Optional access logs to an S3 bucket (pair with `devotica-labs/terraform-aws-s3`).
- `examples/basic` (HTTPS + HTTP-redirect, single target group) and
  `examples/complete` (3 listeners, 2 target groups, access logs to S3,
  IPv6 dualstack).
- `tests/unit.tftest.hcl` (16 assertions, mock_provider, plan-only),
  `tests/contract.tftest.hcl` (5 output-surface contracts), and
  `tests/integration.tftest.hcl` (apply + assert + destroy on workflow_dispatch).

### Deferred to v0.2+
- Listener rules (host-based, path-based, header-based routing).
- Listener authentication (Cognito, OIDC).
- WAF web ACL association.
- Mutual TLS (mTLS) for HTTPS listeners.
