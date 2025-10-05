#!/usr/bin/env python3
"""Interactive viewer for Gamble Battle balance_matrix.csv.

Launches a Dash dashboard that visualises unit balance metrics with pies and bar
charts. Automatically reloads whenever the source CSV is overwritten by
BalanceRunner.
"""

from __future__ import annotations

import argparse
import math
import os
import sys
from dataclasses import dataclass
from datetime import datetime
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

try:
    import pandas as pd
except ImportError as exc:  # pragma: no cover - dependency guard
    sys.stderr.write(
        "Missing dependency: pandas required for balance_matrix_viewer.\n"
        "Install with: pip install pandas dash plotly\n"
    )
    raise

try:
    import dash
    from dash import Dash, Input, Output, State, dcc, html, no_update
    from dash import dash_table
except ImportError:  # pragma: no cover - dependency guard
    sys.stderr.write(
        "Missing dependency: dash required for balance_matrix_viewer.\n"
        "Install with: pip install dash plotly\n"
    )
    raise

try:
    import plotly.graph_objects as go
except ImportError:  # pragma: no cover - dependency guard
    sys.stderr.write(
        "Missing dependency: plotly required for balance_matrix_viewer.\n"
        "Install with: pip install plotly\n"
    )
    raise


REQUIRED_COLUMNS = {
    "attacker_id",
    "defender_id",
    "attacker_primary_role",
    "defender_primary_role",
    "attacker_primary_goal",
    "defender_primary_goal",
    "attacker_approaches",
    "defender_approaches",
    "attacker_cost",
    "defender_cost",
    "attacker_level",
    "defender_level",
    "attacker_win_pct",
    "defender_win_pct",
    "draw_pct",
    "attacker_avg_time_to_win_s",
    "defender_avg_time_to_win_s",
    "attacker_avg_remaining_hp",
    "defender_avg_remaining_hp",
    "matches_total",
    "hit_events_total",
    "attacker_hit_events",
    "defender_hit_events",
    "attacker_avg_damage_dealt_per_match",
    "defender_avg_damage_dealt_per_match",
}


def _default_csv_path() -> str:
    candidates = [
        os.path.join(os.getcwd(), "balance_matrix.csv"),
        os.path.join(os.path.expanduser("~"), "AppData", "Roaming", "Godot", "app_userdata", "Gamble Battle", "balance_matrix.csv"),
    ]
    for candidate in candidates:
        if os.path.isfile(candidate):
            return os.path.abspath(candidate)
    return os.path.abspath(candidates[0])

OPTIONAL_COLUMNS = {
    "attacker_avg_casts_per_match",
    "defender_avg_casts_per_match",
    "attacker_first_cast_time_s",
    "defender_first_cast_time_s",
    "schema_version",
}



@dataclass
class FileSignature:
    path: str
    mtime: float
    size: int

    @classmethod
    def capture(cls, path: str) -> Optional["FileSignature"]:
        try:
            stat = os.stat(path)
        except FileNotFoundError:
            return None
        return cls(path=path, mtime=stat.st_mtime, size=stat.st_size)

    def to_dict(self) -> Dict[str, float]:
        return {"mtime": self.mtime, "size": self.size}

    def is_different(self, other: Optional["FileSignature"]) -> bool:
        if other is None:
            return True
        return not (math.isclose(self.mtime, other.mtime) and self.size == other.size)


@dataclass
class NodeRecord:
    unit_id: str
    primary_role: str
    primary_goal: str
    approaches: str
    cost: int
    level: int


@dataclass
class EdgeRecord:
    pair: str
    attacker: str
    defender: str
    attacker_role: str
    defender_role: str
    attacker_goal: str
    defender_goal: str
    matches: int
    hit_events: int
    attacker_win_pct: float
    defender_win_pct: float
    draw_pct: float
    attacker_avg_time: float
    defender_avg_time: float
    attacker_avg_hp: float
    defender_avg_hp: float
    attacker_avg_damage: float
    defender_avg_damage: float
    advantage_pct: float
    tempo_gap: float
    ability_delta: Optional[float]

    def to_table_row(self) -> Dict[str, object]:
        row = {
            "Pair": self.pair,
            "Attacker": self.attacker,
            "Defender": self.defender,
            "A Role": self.attacker_role,
            "B Role": self.defender_role,
            "A Goal": self.attacker_goal,
            "B Goal": self.defender_goal,
            "Matches": self.matches,
            "Hit Events": self.hit_events,
            "A Win %": round(self.attacker_win_pct, 2),
            "B Win %": round(self.defender_win_pct, 2),
            "Draw %": round(self.draw_pct, 2),
            "Advantage %": round(self.advantage_pct, 2),
            "Tempo Gap s": round(self.tempo_gap, 2),
            "A Avg Time s": round(self.attacker_avg_time, 2),
            "B Avg Time s": round(self.defender_avg_time, 2),
            "A Avg HP": round(self.attacker_avg_hp, 2),
            "B Avg HP": round(self.defender_avg_hp, 2),
            "A Avg Dmg": round(self.attacker_avg_damage, 2),
            "B Avg Dmg": round(self.defender_avg_damage, 2),
        }
        if self.ability_delta is not None:
            row["Cast Delta"] = round(self.ability_delta, 2)
        return row


class BalanceMatrixModel:
    def __init__(self, frame: pd.DataFrame):
        self.frame = frame
        self.nodes: Dict[str, NodeRecord] = {}
        self.edges: List[EdgeRecord] = []
        self._role_set: set[str] = set()
        self._goal_set: set[str] = set()
        self._build()

    @property
    def roles(self) -> List[str]:
        return sorted(self._role_set)

    @property
    def goals(self) -> List[str]:
        return sorted(self._goal_set)

    def _build(self) -> None:
        for _, row in self.frame.iterrows():
            self._ingest_row(row)

    def _ingest_row(self, row: pd.Series) -> None:
        attacker_id = str(row["attacker_id"])
        defender_id = str(row["defender_id"])
        attacker_role = str(row["attacker_primary_role"])
        defender_role = str(row["defender_primary_role"])
        attacker_goal = str(row["attacker_primary_goal"])
        defender_goal = str(row["defender_primary_goal"])
        self._ensure_node(
            attacker_id,
            attacker_role,
            attacker_goal,
            str(row["attacker_approaches"]),
            int(row["attacker_cost"]),
            int(row["attacker_level"]),
        )
        self._ensure_node(
            defender_id,
            defender_role,
            defender_goal,
            str(row["defender_approaches"]),
            int(row["defender_cost"]),
            int(row["defender_level"]),
        )
        ability_delta = None
        if "attacker_avg_casts_per_match" in row.index and "defender_avg_casts_per_match" in row.index:
            try:
                ability_delta = float(row["attacker_avg_casts_per_match"]) - float(
                    row["defender_avg_casts_per_match"]
                )
            except (TypeError, ValueError):
                ability_delta = None
        edge = EdgeRecord(
            pair=f"{attacker_id} vs {defender_id}",
            attacker=attacker_id,
            defender=defender_id,
            attacker_role=attacker_role,
            defender_role=defender_role,
            attacker_goal=attacker_goal,
            defender_goal=defender_goal,
            matches=int(row["matches_total"]),
            hit_events=int(row["hit_events_total"]),
            attacker_win_pct=_to_percent(row["attacker_win_pct"]),
            defender_win_pct=_to_percent(row["defender_win_pct"]),
            draw_pct=_to_percent(row["draw_pct"]),
            attacker_avg_time=float(row["attacker_avg_time_to_win_s"]),
            defender_avg_time=float(row["defender_avg_time_to_win_s"]),
            attacker_avg_hp=float(row["attacker_avg_remaining_hp"]),
            defender_avg_hp=float(row["defender_avg_remaining_hp"]),
            attacker_avg_damage=float(row["attacker_avg_damage_dealt_per_match"]),
            defender_avg_damage=float(row["defender_avg_damage_dealt_per_match"]),
            advantage_pct=(
                _to_percent(row["attacker_win_pct"]) - _to_percent(row["defender_win_pct"])
            ),
            tempo_gap=float(row["attacker_avg_time_to_win_s"]) - float(
                row["defender_avg_time_to_win_s"]
            ),
            ability_delta=ability_delta,
        )
        self.edges.append(edge)

    def _ensure_node(
        self,
        unit_id: str,
        primary_role: str,
        primary_goal: str,
        approaches: str,
        cost: int,
        level: int,
    ) -> None:
        if unit_id not in self.nodes:
            self.nodes[unit_id] = NodeRecord(
                unit_id=unit_id,
                primary_role=primary_role,
                primary_goal=primary_goal,
                approaches=approaches,
                cost=cost,
                level=level,
            )
        self._role_set.add(primary_role)
        self._goal_set.add(primary_goal)

    def summary(self) -> Dict[str, object]:
        match_counts = [edge.matches for edge in self.edges]
        advantage_abs = [abs(edge.advantage_pct) for edge in self.edges]
        return {
            "total_units": len(self.nodes),
            "total_pairs": len(self.edges),
            "max_matches": max(match_counts) if match_counts else 0,
            "max_advantage": max(advantage_abs) if advantage_abs else 0.0,
        }


EDGE_TABLE_COLUMNS = [
    {"name": "Pair", "id": "Pair"},
    {"name": "Attacker", "id": "Attacker"},
    {"name": "Defender", "id": "Defender"},
    {"name": "A Role", "id": "A Role"},
    {"name": "B Role", "id": "B Role"},
    {"name": "A Goal", "id": "A Goal"},
    {"name": "B Goal", "id": "B Goal"},
    {"name": "Matches", "id": "Matches", "type": "numeric"},
    {"name": "Hit Events", "id": "Hit Events", "type": "numeric"},
    {"name": "A Win %", "id": "A Win %", "type": "numeric"},
    {"name": "B Win %", "id": "B Win %", "type": "numeric"},
    {"name": "Draw %", "id": "Draw %", "type": "numeric"},
    {"name": "Advantage %", "id": "Advantage %", "type": "numeric"},
    {"name": "Tempo Gap s", "id": "Tempo Gap s", "type": "numeric"},
    {"name": "A Avg Time s", "id": "A Avg Time s", "type": "numeric"},
    {"name": "B Avg Time s", "id": "B Avg Time s", "type": "numeric"},
    {"name": "A Avg HP", "id": "A Avg HP", "type": "numeric"},
    {"name": "B Avg HP", "id": "B Avg HP", "type": "numeric"},
    {"name": "A Avg Dmg", "id": "A Avg Dmg", "type": "numeric"},
    {"name": "B Avg Dmg", "id": "B Avg Dmg", "type": "numeric"},
    {"name": "Cast Delta", "id": "Cast Delta", "type": "numeric"},
]


def _to_percent(value: float) -> float:
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        return 0.0
    if numeric > 1.0:
        return numeric
    return numeric * 100.0


def load_matrix(path: str) -> Dict[str, object]:
    signature = FileSignature.capture(path)
    if signature is None:
        return {
            "error": f"Matrix file not found at {path}",
            "signature": None,
            "timestamp": datetime.utcnow().isoformat(),
        }
    frame = pd.read_csv(path)
    missing = REQUIRED_COLUMNS - set(frame.columns)
    if missing:
        return {
            "error": f"Missing required columns: {sorted(missing)}",
            "signature": signature.to_dict(),
            "timestamp": datetime.utcnow().isoformat(),
        }
    frame = frame.fillna(0)
    model = BalanceMatrixModel(frame)
    meta = model.summary()
    data = {
        "signature": signature.to_dict(),
        "timestamp": datetime.utcnow().isoformat(),
        "path": path,
        "summary": meta,
        "roles": model.roles,
        "goals": model.goals,
        "edges": [edge.to_table_row() for edge in model.edges],
        "raw_edges": [edge.__dict__ for edge in model.edges],
        "nodes": [node.__dict__ for node in model.nodes.values()],
        "error": None,
    }
    return data


def compute_filtered_view(
    data: Dict[str, object],
    selected_roles: Optional[Sequence[str]],
    selected_goals: Optional[Sequence[str]],
    min_matches: int,
    min_advantage: float,
) -> Tuple[List[EdgeRecord], Dict[str, NodeRecord]]:
    role_set = set(selected_roles or [])
    goal_set = set(selected_goals or [])
    edge_records = [EdgeRecord(**edge) for edge in data.get("raw_edges", [])]
    node_records = {node["unit_id"]: NodeRecord(**node) for node in data.get("nodes", [])}

    def node_visible(node: NodeRecord) -> bool:
        if role_set and node.primary_role not in role_set:
            return False
        if goal_set and node.primary_goal not in goal_set:
            return False
        return True

    visible_nodes = {nid for nid, node in node_records.items() if node_visible(node)}
    filtered_edges: List[EdgeRecord] = []
    for edge in edge_records:
        if edge.attacker not in visible_nodes or edge.defender not in visible_nodes:
            continue
        if edge.matches < min_matches:
            continue
        if abs(edge.advantage_pct) < min_advantage:
            continue
        filtered_edges.append(edge)
    filtered_node_records = {
        nid: node_records[nid]
        for nid in visible_nodes
        if any(edge.attacker == nid or edge.defender == nid for edge in filtered_edges)
    }
    if not filtered_node_records and role_set:
        filtered_node_records = {
            nid: node
            for nid, node in node_records.items()
            if node.primary_role in role_set and node.primary_goal in (goal_set or {node.primary_goal})
        }
    return filtered_edges, filtered_node_records


def build_role_pie(nodes: Dict[str, NodeRecord]) -> go.Figure:
    if not nodes:
        return _empty_figure("No units match the current filters")
    counts: Dict[str, int] = {}
    for node in nodes.values():
        counts[node.primary_role] = counts.get(node.primary_role, 0) + 1
    labels = sorted(counts.keys())
    values = [counts[label] for label in labels]
    fig = go.Figure(
        data=[
            go.Pie(
                labels=[label.title() for label in labels],
                values=values,
                hole=0.4,
                textinfo="label+percent",
            )
        ]
    )
    fig.update_layout(
        title="Unit distribution by role",
        legend=dict(orientation="h"),
        paper_bgcolor="#0e1012",
        plot_bgcolor="#0e1012",
        font=dict(color="#d8d8d8"),
    )
    return fig


def build_advantage_bar(edges: Sequence[EdgeRecord], top_n: int = 10) -> go.Figure:
    if not edges:
        return _empty_figure("No matchups meet the current filters")
    ranked = sorted(edges, key=lambda e: abs(e.advantage_pct), reverse=True)[:top_n]
    labels = [edge.pair for edge in ranked]
    values = [edge.advantage_pct for edge in ranked]
    colors = ["#2ca02c" if val >= 0 else "#d62728" for val in values]
    fig = go.Figure(
        data=[
            go.Bar(
                x=labels,
                y=values,
                marker_color=colors,
                text=[f"{val:.2f}%" for val in values],
                textposition="outside",
            )
        ]
    )
    fig.update_layout(
        title="Matchup advantage (top absolute deltas)",
        xaxis_title="Pair",
        yaxis_title="Advantage % (positive favors attacker)",
        paper_bgcolor="#0e1012",
        plot_bgcolor="#0e1012",
        font=dict(color="#d8d8d8"),
        margin=dict(l=40, r=20, t=60, b=120),
    )
    return fig


def _empty_figure(message: str) -> go.Figure:
    fig = go.Figure()
    fig.update_layout(
        title=message,
        xaxis=dict(visible=False),
        yaxis=dict(visible=False),
        paper_bgcolor="#0e1012",
        plot_bgcolor="#0e1012",
        font=dict(color="#d8d8d8"),
    )
    return fig


def build_dash_app(data: Dict[str, object], args: argparse.Namespace) -> Dash:
    app = Dash(__name__)
    app.title = "Balance Matrix Viewer"
    watch_disabled = not args.watch

    app.layout = html.Div(
        className="app-container",
        children=[
            dcc.Store(id="matrix-data", data=data),
            dcc.Interval(
                id="matrix-poll",
                interval=max(args.watch_interval, 1) * 1000,
                disabled=watch_disabled,
            ),
            html.H1("Balance Matrix Viewer"),
            html.Div(
                className="status-row",
                children=[
                    html.Div(id="status-banner", children=_status_text(data)),
                    html.Button("Refresh now", id="refresh-button", n_clicks=0),
                ],
            ),
            html.Div(
                className="controls",
                children=[
                    html.Div(
                        className="control",
                        children=[
                            html.Label("Filter by role"),
                            dcc.Dropdown(
                                id="role-filter",
                                options=[{"label": role.title(), "value": role} for role in data.get("roles", [])],
                                value=[],
                                multi=True,
                                placeholder="All roles",
                            ),
                        ],
                    ),
                    html.Div(
                        className="control",
                        children=[
                            html.Label("Filter by goal"),
                            dcc.Dropdown(
                                id="goal-filter",
                                options=[{"label": goal, "value": goal} for goal in data.get("goals", [])],
                                value=[],
                                multi=True,
                                placeholder="All goals",
                            ),
                        ],
                    ),
                    html.Div(
                        className="control",
                        children=[
                            html.Label("Min matches"),
                            dcc.Slider(
                                id="min-matches-slider",
                                min=0,
                                max=max(5, data.get("summary", {}).get("max_matches", 10)),
                                step=1,
                                value=1,
                                tooltip={"placement": "bottom"},
                            ),
                        ],
                    ),
                    html.Div(
                        className="control",
                        children=[
                            html.Label("Min advantage (%)"),
                            dcc.Slider(
                                id="min-advantage-slider",
                                min=0,
                                max=max(5, int(data.get("summary", {}).get("max_advantage", 10))),
                                step=1,
                                value=0,
                                tooltip={"placement": "bottom"},
                            ),
                        ],
                    ),
                ],
            ),
            html.Div(
                className="charts",
                children=[
                    dcc.Graph(id="role-pie"),
                    dcc.Graph(id="advantage-bar"),
                ],
            ),
            html.Div(id="summary-block", className="summary", children=_summary_children(data, [], {})),
            dash_table.DataTable(
                id="edge-table",
                columns=[col for col in EDGE_TABLE_COLUMNS if col["id"] != "Cast Delta" or any(
                    "Cast Delta" in edge for edge in data.get("edges", [])
                )],
                data=data.get("edges", []),
                filter_action="native",
                sort_action="native",
                sort_mode="multi",
                page_current=0,
                page_size=15,
                style_table={"height": "420px", "overflowY": "auto"},
                style_header={"backgroundColor": "#222", "color": "#eee"},
                style_cell={
                    "backgroundColor": "#111",
                    "color": "#e1e1e1",
                    "padding": "6px",
                    "fontFamily": "monospace",
                },
            ),
        ],
    )

    app.server.config.update(
        matrix_path=args.csv,
        watch_enabled=not watch_disabled,
    )

    register_callbacks(app)
    return app


def register_callbacks(app: Dash) -> None:
    @app.callback(
        Output("matrix-data", "data"),
        Output("status-banner", "children"),
        Input("matrix-poll", "n_intervals"),
        Input("refresh-button", "n_clicks"),
        State("matrix-data", "data"),
        prevent_initial_call=False,
    )
    def update_matrix(_: int, __: int, current: Dict[str, object]):
        triggered = dash.callback_context.triggered
        if not triggered:
            triggered_id = None
        else:
            triggered_id = triggered[0]["prop_id"].split(".")[0]
        matrix_path = app.server.config.get("matrix_path")
        signature = FileSignature.capture(matrix_path)
        if signature is None:
            error_data = {
                "error": f"Matrix file not found at {matrix_path}",
                "timestamp": datetime.utcnow().isoformat(),
                "signature": None,
            }
            return error_data, _status_text(error_data)
        current_signature = None
        if current and current.get("signature"):
            current_signature = FileSignature(
                path=matrix_path,
                mtime=float(current["signature"]["mtime"]),
                size=int(current["signature"]["size"]),
            )
        if triggered_id == "refresh-button" or signature.is_different(current_signature):
            data = load_matrix(matrix_path)
            return data, _status_text(data)
        return no_update, no_update

    @app.callback(
        Output("role-filter", "options"),
        Output("goal-filter", "options"),
        Output("min-matches-slider", "max"),
        Output("min-advantage-slider", "max"),
        Input("matrix-data", "data"),
    )
    def refresh_filter_options(data: Dict[str, object]):
        roles = data.get("roles", []) if data else []
        goals = data.get("goals", []) if data else []
        summary = data.get("summary", {}) if data else {}
        return (
            [{"label": role.title(), "value": role} for role in roles],
            [{"label": goal, "value": goal} for goal in goals],
            max(5, summary.get("max_matches", 10)),
            max(5, int(summary.get("max_advantage", 10))),
        )

    @app.callback(
        Output("role-pie", "figure"),
        Output("advantage-bar", "figure"),
        Output("edge-table", "data"),
        Output("summary-block", "children"),
        Input("matrix-data", "data"),
        Input("role-filter", "value"),
        Input("goal-filter", "value"),
        Input("min-matches-slider", "value"),
        Input("min-advantage-slider", "value"),
    )
    def refresh_views(
        data: Dict[str, object],
        roles: Sequence[str],
        goals: Sequence[str],
        min_matches: int,
        min_advantage: int,
    ):
        if not data:
            empty = _empty_figure("No data loaded yet")
            return empty, empty, [], _summary_children({}, [], {})
        if data.get("error"):
            empty = _empty_figure(data.get("error", "Unable to load data"))
            return empty, empty, [], _summary_children(data, [], {})
        edges, nodes = compute_filtered_view(
            data,
            roles,
            goals,
            int(min_matches or 0),
            float(min_advantage or 0),
        )
        pie_fig = build_role_pie(nodes)
        bar_fig = build_advantage_bar(edges)
        table_rows = [edge.to_table_row() for edge in edges]
        summary_children = _summary_children(data, edges, nodes)
        return pie_fig, bar_fig, table_rows, summary_children


def _status_text(data: Dict[str, object]) -> str:
    if not data:
        return "No data loaded"
    if data.get("error"):
        return f"WARNING: {data['error']} (last attempted {data.get('timestamp')})"
    timestamp = data.get("timestamp")
    path = data.get("path", "balance_matrix.csv")
    return f"Loaded {os.path.basename(path)} @ {timestamp}"


def _summary_children(
    data: Dict[str, object], edges: Sequence[EdgeRecord], nodes: Dict[str, NodeRecord]
) -> List[html.Div]:
    if data.get("error"):
        return [html.Div(data.get("error"), className="summary-error")]
    total_edges = len(edges)
    total_units = len(nodes)
    avg_advantage = (
        sum(abs(edge.advantage_pct) for edge in edges) / total_edges if total_edges else 0.0
    )
    avg_tempo = sum(edge.tempo_gap for edge in edges) / total_edges if total_edges else 0.0
    return [
        html.Div(f"Visible units: {total_units}"),
        html.Div(f"Visible matchups: {total_edges}"),
        html.Div(f"Average advantage delta: {avg_advantage:.2f}%"),
        html.Div(f"Average tempo gap: {avg_tempo:.2f}s"),
    ]


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Launch the balance matrix viewer dashboard")
    parser.add_argument(
        "--csv",
        default=_default_csv_path(),
        help="Path to the balance_matrix.csv file (auto-detected if omitted)",
    )
    parser.add_argument("--host", default="127.0.0.1", help="Host interface for the Dash server")
    parser.add_argument("--port", type=int, default=8050, help="Port for the Dash server")
    parser.add_argument(
        "--watch", action="store_true", default=True, help="Auto reload when CSV changes"
    )
    parser.add_argument(
        "--no-watch", dest="watch", action="store_false", help="Disable auto reload"
    )
    parser.add_argument(
        "--watch-interval",
        type=int,
        default=5,
        help="Seconds between file-change polls when watching",
    )
    parser.add_argument(
        "--debug", action="store_true", help="Enable Dash debug mode (reloader off)"
    )
    args = parser.parse_args(argv)
    args.csv = os.path.abspath(args.csv)
    return args


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    data = load_matrix(args.csv)
    app = build_dash_app(data, args)
    app.run(host=args.host, port=args.port, debug=args.debug, use_reloader=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
