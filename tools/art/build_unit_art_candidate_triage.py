from __future__ import annotations

import argparse
import csv
import json
from datetime import date
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PROOF_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_proof_matrix.json"
DEFAULT_METRICS = ROOT / "outputs" / "art_pipeline" / "style_validation" / "style_drift_audit_2026_06_30" / "foreground_detail_metrics.csv"
DEFAULT_OUT = ROOT / "outputs" / "art_pipeline" / "style_validation" / f"candidate_style_triage_{date.today().strftime('%Y_%m_%d')}"


def rel(path_text: str | Path) -> str:
    path = Path(path_text)
    if not path.is_absolute():
        path = ROOT / path
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_metrics(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def metric(row: dict[str, str], field: str) -> float:
    return float(row[field])


def proof_lookup(proof_data: dict[str, Any]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for proof in proof_data.get("proofs", []):
        if isinstance(proof, dict):
            result[str(proof.get("id", ""))] = proof
    return result


def build_rows(metrics_rows: list[dict[str, str]], proof_data: dict[str, Any]) -> list[dict[str, str]]:
    by_kind = proof_lookup(proof_data)
    by_label = {row["label"]: row for row in metrics_rows}
    vellum = by_label["REF Vellum raw"]
    paisley = by_label["REF Paisley"]
    vellum_edge = metric(vellum, "edge_mean")
    paisley_edge = metric(paisley, "edge_mean")
    vellum_contrast = metric(vellum, "gray_std")
    paisley_contrast = metric(paisley, "gray_std")
    rows: list[dict[str, str]] = []
    for row in metrics_rows:
        kind = row["kind"]
        role = row["role"]
        proof = by_kind.get(kind, {})
        status = str(proof.get("status", "reference" if row["label"].startswith("REF ") else "unknown"))
        edge_delta_vellum = metric(row, "edge_mean") - vellum_edge
        edge_delta_paisley = metric(row, "edge_mean") - paisley_edge
        contrast_delta_vellum = metric(row, "gray_std") - vellum_contrast
        contrast_delta_paisley = metric(row, "gray_std") - paisley_contrast
        flags: list[str] = []
        if role == "primary_anchor":
            stance = "ultimate_reference"
        elif role in {"secondary_contrast_anchor", "small_asset_material_reference"}:
            stance = "reference_context_not_primary"
        else:
            if edge_delta_paisley < -4.0:
                flags.append("edge_detail_far_below_paisley")
            elif edge_delta_vellum < -2.0:
                flags.append("edge_detail_below_vellum")
            if contrast_delta_paisley < -4.0:
                flags.append("contrast_far_below_paisley")
            elif contrast_delta_vellum < -2.0:
                flags.append("contrast_below_vellum")
            if metric(row, "colorfulness") < 8.0:
                flags.append("very_muted_color_proxy")
            if role == "review_candidate_not_anchor":
                flags.append("human_review_gate")
            if status == "current_candidate":
                flags.append("candidate_not_accepted")
            if not flags and edge_delta_vellum >= 0.0 and contrast_delta_vellum >= 0.0:
                flags.append("metric_detail_near_or_above_vellum")
            if "edge_detail_far_below_paisley" in flags or "contrast_far_below_paisley" in flags:
                stance = "high_risk_re_review_before_acceptance"
            elif "edge_detail_below_vellum" in flags or "contrast_below_vellum" in flags:
                stance = "needs_vellum_pairwise_visual_review"
            elif role == "review_candidate_not_anchor":
                stance = "next_gate_human_review_required"
            else:
                stance = "metrics_do_not_replace_visual_review"
        rows.append(
            {
                "label": row["label"],
                "proof_id": kind,
                "status": status,
                "reference_role": role,
                "edge_mean": row["edge_mean"],
                "edge_delta_vellum": f"{edge_delta_vellum:.2f}",
                "edge_delta_paisley": f"{edge_delta_paisley:.2f}",
                "gray_std": row["gray_std"],
                "contrast_delta_vellum": f"{contrast_delta_vellum:.2f}",
                "contrast_delta_paisley": f"{contrast_delta_paisley:.2f}",
                "flags": ", ".join(flags) if flags else "none",
                "review_stance": stance,
            }
        )
    return rows


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def write_markdown(path: Path, rows: list[dict[str, str]], metrics_path: Path, report_date: str) -> None:
    non_reference = [row for row in rows if not row["label"].startswith("REF ")]
    high_risk = [row for row in non_reference if row["review_stance"] == "high_risk_re_review_before_acceptance"]
    review_gate = [row for row in non_reference if row["reference_role"] == "review_candidate_not_anchor"]
    lines: list[str] = [
        "# Unit Art Candidate Style Triage",
        "",
        f"- Generated: {report_date}",
        f"- Metrics source: `{rel(metrics_path)}`",
        "- Primary rule: Vellum is the ultimate character reference. Metrics are proxies only; visual side-by-side review decides.",
        "- Passing-pool rule: accepted/current proofs remain narrow evidence by `reference_role` unless the user explicitly promotes one.",
        "",
        "## Summary",
        "",
        f"- Non-reference rows reviewed: {len(non_reference)}",
        f"- High-risk re-review rows: {len(high_risk)}",
        f"- Review-gate rows: {len(review_gate)}",
        "",
        "High-risk here means the candidate is materially below Paisley or Vellum on edge/contrast proxies and should not be allowed to pull the target style, even if the image has a clean cutout or matches the palette.",
        "",
        "## Highest Risk Rows",
        "",
    ]
    if high_risk:
        for row in high_risk:
            lines.append(
                f"- `{row['label']}` / `{row['proof_id']}`: {row['flags']} "
                f"(edge vs Vellum {row['edge_delta_vellum']}, contrast vs Vellum {row['contrast_delta_vellum']})."
            )
    else:
        lines.append("- None by the current proxy thresholds.")
    lines.extend([
        "",
        "## Full Triage Table",
        "",
        "| Label | Proof | Status | Role | Edge vs Vellum | Contrast vs Vellum | Flags | Stance |",
        "| --- | --- | --- | --- | ---: | ---: | --- | --- |",
    ])
    for row in rows:
        lines.append(
            f"| {row['label']} | `{row['proof_id']}` | `{row['status']}` | `{row['reference_role']}` | "
            f"{row['edge_delta_vellum']} | {row['contrast_delta_vellum']} | {row['flags']} | {row['review_stance']} |"
        )
    lines.extend([
        "",
        "## Use",
        "",
        "- Start visual review from the Vellum pairwise sheet, not this table.",
        "- If a row is high-risk, compare it beside Vellum before accepting or using it as prompt context.",
        "- If a high-risk row is already accepted, keep it narrow and do not let it influence the global target without explicit user review.",
        "- If a row is a current candidate, leave it out of live assets until the user approves it.",
        "",
    ])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--metrics-csv", type=Path, default=DEFAULT_METRICS)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--docs-output", type=Path)
    parser.add_argument("--report-date", default=date.today().isoformat())
    args = parser.parse_args()

    metrics_path = args.metrics_csv if args.metrics_csv.is_absolute() else ROOT / args.metrics_csv
    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    proof_data = load_json(PROOF_MATRIX_PATH)
    rows = build_rows(load_metrics(metrics_path), proof_data)
    csv_path = output_dir / "unit_art_candidate_style_triage.csv"
    md_path = output_dir / "unit_art_candidate_style_triage.md"
    write_csv(csv_path, rows)
    write_markdown(md_path, rows, metrics_path, args.report_date)
    if args.docs_output:
        docs_path = args.docs_output if args.docs_output.is_absolute() else ROOT / args.docs_output
        write_markdown(docs_path, rows, metrics_path, args.report_date)
        print(rel(docs_path))
    print(rel(md_path))
    print(rel(csv_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
