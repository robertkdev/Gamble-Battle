# Roles, Goals, Approaches (RGA) — Subject Semantics

This project evaluates RGA identity per unit. Tests assert whether units fall within the configured ranges for their assigned identity.

Key principles
- Subject = per-unit. Candidates are units whose assigned `primary_role` matches the metric’s role.
- K-of-N applies across conditions for the same unit. Sides are combined with OR: pass if any matching unit on A or B passes.
- Prefer unit-level KPIs from aggregates/kernels. If a metric must fall back to side-level, annotate spans with `reason="side_level_fallback"`.
- Spans for unit decisions include `subject_side` and `unit_id`; include `subject_role` when available.

Standard span extras
- `subject_side`: "a" | "b"
- `unit_id`: string
- `subject_role`: string (optional)
- `reason`: string (optional; e.g., `focus_fallback_time_alive`, `kernel_unsupported`)

Related telemetry fields
- `aggregates.units.[a|b][i].unit_id`, `incoming`, `pre_mit_incoming`
- `aggregates.kernels.focus_survival.focus_survival_per_unit.{a|b}.{unit_id}`
- `aggregates.kernels.throughput.peers_by_index.{a|b}`
- `aggregates.kernels.per_unit_kpis.{a|b}.{unit_id}`
- `aggregates.kernels.positioning.{a|b}` and `frontline_window.{a|b}`
