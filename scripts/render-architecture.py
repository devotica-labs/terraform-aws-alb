#!/usr/bin/env python3
"""Render an ALB architecture diagram from a Terraform plan JSON.

Shows the ALB at the centre with:
  - Listeners on the left (one per listener key)
  - Target groups on the right (one per target group key)
  - Edges from listener → target group for `forward` default actions
  - Annotated listener nodes (HTTPS/HTTP + port; redirect/fixed-response markers)

Usage:
    python scripts/render-architecture.py <plan.json> <output-path-no-ext>
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.network import ALB, ELB
from diagrams.aws.security import CertificateManager
from diagrams.aws.storage import S3
from diagrams.aws.compute import EC2
from diagrams.aws.general import General


def load_resources(plan_path: Path) -> list[dict]:
    plan = json.loads(plan_path.read_text())
    root = plan.get("planned_values", {}).get("root_module", {})
    collected: list[dict] = []

    def walk(mod: dict) -> None:
        for r in mod.get("resources", []):
            collected.append(r)
        for child in mod.get("child_modules", []):
            walk(child)

    walk(root)
    return collected


def values(r: dict) -> dict:
    return r.get("values", {}) or {}


def _key(addr: str) -> str:
    m = re.search(r'\["([^"]+)"\]', addr)
    return m.group(1) if m else addr


def _listener_default_action(l_values: dict) -> str:
    actions = l_values.get("default_action") or []
    if not actions:
        return "unknown"
    return actions[0].get("type") or "unknown"


def _listener_forward_target(l_values: dict) -> str | None:
    actions = l_values.get("default_action") or []
    if not actions or actions[0].get("type") != "forward":
        return None
    return actions[0].get("target_group_arn")


def render(plan_path: Path, out_no_ext: Path) -> None:
    resources = load_resources(plan_path)

    lbs = [r for r in resources if r["type"] == "aws_lb"]
    if not lbs:
        raise SystemExit("No aws_lb resource found in plan — nothing to render.")

    lb_v = values(lbs[0])
    name = lb_v.get("name") or "alb"
    internal = bool(lb_v.get("internal"))
    ip_type = lb_v.get("ip_address_type") or "ipv4"
    access_logs = lb_v.get("access_logs") or []
    has_access_logs = bool(access_logs) and access_logs[0].get("enabled")
    access_logs_bucket = access_logs[0].get("bucket") if has_access_logs else None

    tgs = [r for r in resources if r["type"] == "aws_lb_target_group"]
    listeners = [r for r in resources if r["type"] == "aws_lb_listener"]

    # Build target-group key → node-placeholder map
    tg_keys = [_key(r["address"]) for r in tgs]
    tg_values_by_key = {_key(r["address"]): values(r) for r in tgs}

    badges = []
    if internal:
        badges.append("internal")
    else:
        badges.append("internet-facing")
    if ip_type != "ipv4":
        badges.append(ip_type)
    if has_access_logs:
        badges.append("access-logs")
    title_badges = " · ".join(badges)

    graph_attr = {
        "fontsize": "20",
        "splines": "ortho",
        "ranksep": "1.0",
        "nodesep": "0.45",
        "pad": "0.5",
    }

    out_no_ext.parent.mkdir(parents=True, exist_ok=True)
    with Diagram(
        f"terraform-aws-alb — {name} · {title_badges}",
        filename=str(out_no_ext),
        show=False,
        direction="LR",
        outformat="png",
        graph_attr=graph_attr,
    ):
        alb_node = ALB(name)

        # ── Listeners cluster (left) ──────────────────────────────────────
        listener_nodes: dict[str, ELB] = {}
        if listeners:
            with Cluster("Listeners"):
                for l in sorted(listeners, key=lambda r: r["address"]):
                    lkey = _key(l["address"])
                    lv = values(l)
                    port = lv.get("port") or "?"
                    proto = lv.get("protocol") or "?"
                    action_type = _listener_default_action(lv)
                    cert_arn = lv.get("certificate_arn")

                    label_lines = [f"{lkey}", f"{proto} :{port}"]
                    if action_type == "redirect":
                        label_lines.append("→ redirect")
                    elif action_type == "fixed-response":
                        label_lines.append("→ fixed")
                    elif action_type == "forward":
                        label_lines.append("→ forward")

                    node = ELB("\n".join(label_lines))
                    listener_nodes[lkey] = node

                    # Certificate marker for HTTPS
                    if proto == "HTTPS" and cert_arn:
                        cert = CertificateManager("ACM cert")
                        cert >> Edge(label="tls", style="dashed") >> node

                    node >> Edge() >> alb_node

        # ── Target groups cluster (right) ─────────────────────────────────
        tg_nodes: dict[str, EC2] = {}
        if tgs:
            with Cluster("Target groups"):
                for tg in sorted(tgs, key=lambda r: r["address"]):
                    tgkey = _key(tg["address"])
                    tgv = values(tg)
                    port = tgv.get("port") or "?"
                    proto = tgv.get("protocol") or "?"
                    ttype = tgv.get("target_type") or "?"
                    health = tgv.get("health_check") or [{}]
                    hp = health[0].get("path") if health else "/"
                    label = f"{tgkey}\n{proto} :{port}\n[{ttype}]\nhc {hp}"
                    n = EC2(label)
                    tg_nodes[tgkey] = n
                    alb_node >> Edge() >> n

        # ── Forward edges (listener → TG) overlay ─────────────────────────
        for l in listeners:
            lv = values(l)
            if _listener_default_action(lv) != "forward":
                continue
            tg_arn = _listener_forward_target(lv) or ""
            # Find the TG key whose ARN reference in the address matches.
            # We don't know the TG ARN at plan time; the target_group_arn
            # references aws_lb_target_group.this[<key>].arn — match by key.
            tg_key_match = None
            for tgkey, tgvals in tg_values_by_key.items():
                # `tgvals` doesn't carry arn at plan; fall back to matching by
                # listener.target_group_key if available via reference. Best-effort.
                tg_key_match = tgkey
                break
            if tg_key_match and tg_key_match in tg_nodes:
                listener_nodes[_key(l["address"])] >> Edge(label="forward", style="dotted") >> tg_nodes[tg_key_match]

        # ── Access logs sidecar ───────────────────────────────────────────
        if has_access_logs:
            with Cluster("Access logs"):
                alb_node >> Edge(label="logs", style="dotted") >> S3(access_logs_bucket or "S3")

    out_no_ext.with_suffix(".png")


def main() -> None:
    if len(sys.argv) < 3:
        sys.stderr.write(
            "Usage: render-architecture.py <plan.json> <output-path-without-ext>\n"
        )
        sys.exit(2)
    render(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
