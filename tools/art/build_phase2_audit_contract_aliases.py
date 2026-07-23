from __future__ import annotations

import argparse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CANONICAL_TEMPLATE = ROOT / "docs" / "art" / "unit_art_board_review_template.json"
CANONICAL_VALIDATOR = ROOT / "tools" / "art" / "validate_unit_art_board_review.py"
ALIAS_DIRECTORY = ROOT / "docs" / "art" / "phase2_calibration" / "audit_contract"
ALIAS_TEMPLATE = ALIAS_DIRECTORY / "unit_template.json"
ALIAS_VALIDATOR = ALIAS_DIRECTORY / "unit_validator.py"

CANONICAL_ROOT_LINE = "ROOT = Path(__file__).resolve().parents[2]"
ALIAS_ROOT_LINE = "ROOT = Path(__file__).resolve().parents[4]"


def _line_count(text: str, line: str) -> int:
    return sum(1 for candidate in text.splitlines() if candidate == line)


def rewrite_validator(canonical_text: str) -> str:
    canonical_count = _line_count(canonical_text, CANONICAL_ROOT_LINE)
    alias_count = _line_count(canonical_text, ALIAS_ROOT_LINE)
    if canonical_count != 1 or alias_count != 0:
        raise ValueError(
            "canonical validator root marker is absent or ambiguous: "
            f"canonical={canonical_count}, alias={alias_count}"
        )
    rewritten = canonical_text.replace(CANONICAL_ROOT_LINE, ALIAS_ROOT_LINE, 1)
    verify_validator_alias(canonical_text, rewritten)
    return rewritten


def verify_validator_alias(canonical_text: str, alias_text: str) -> None:
    canonical_count = _line_count(alias_text, CANONICAL_ROOT_LINE)
    alias_count = _line_count(alias_text, ALIAS_ROOT_LINE)
    if canonical_count != 0 or alias_count != 1:
        raise ValueError(
            "alias validator root rewrite is absent or ambiguous: "
            f"canonical={canonical_count}, alias={alias_count}"
        )
    restored = alias_text.replace(ALIAS_ROOT_LINE, CANONICAL_ROOT_LINE, 1)
    if restored != canonical_text:
        raise ValueError("alias validator differs from canonical code beyond the one root-line rewrite")


def build_aliases() -> None:
    template_bytes = CANONICAL_TEMPLATE.read_bytes()
    canonical_bytes = CANONICAL_VALIDATOR.read_bytes()
    canonical_text = canonical_bytes.decode("utf-8")
    alias_text = rewrite_validator(canonical_text)

    ALIAS_DIRECTORY.mkdir(parents=True, exist_ok=True)
    ALIAS_TEMPLATE.write_bytes(template_bytes)
    ALIAS_VALIDATOR.write_bytes(alias_text.encode("utf-8"))
    verify_aliases()


def verify_aliases() -> None:
    canonical_template = CANONICAL_TEMPLATE.read_bytes()
    alias_template = ALIAS_TEMPLATE.read_bytes()
    if alias_template != canonical_template:
        raise ValueError("alias template is not byte-identical to the canonical template")

    canonical_text = CANONICAL_VALIDATOR.read_bytes().decode("utf-8")
    alias_text = ALIAS_VALIDATOR.read_bytes().decode("utf-8")
    verify_validator_alias(canonical_text, alias_text)


def run_negative_controls() -> None:
    canonical_text = CANONICAL_VALIDATOR.read_bytes().decode("utf-8")

    missing_source = canonical_text.replace(
        CANONICAL_ROOT_LINE,
        "ROOT = Path(__file__).resolve().parents[3]",
        1,
    )
    try:
        rewrite_validator(missing_source)
    except ValueError:
        pass
    else:
        raise AssertionError("negative control unexpectedly accepted an absent canonical root marker")

    ambiguous_source = canonical_text + f"\n{CANONICAL_ROOT_LINE}\n"
    try:
        rewrite_validator(ambiguous_source)
    except ValueError:
        pass
    else:
        raise AssertionError("negative control unexpectedly accepted ambiguous canonical root markers")

    missing_rewrite = canonical_text
    try:
        verify_validator_alias(canonical_text, missing_rewrite)
    except ValueError:
        pass
    else:
        raise AssertionError("negative control unexpectedly accepted an absent alias root rewrite")

    valid_alias = rewrite_validator(canonical_text)
    ambiguous_rewrite = valid_alias + f"\n{ALIAS_ROOT_LINE}\n"
    try:
        verify_validator_alias(canonical_text, ambiguous_rewrite)
    except ValueError:
        pass
    else:
        raise AssertionError("negative control unexpectedly accepted ambiguous alias root rewrites")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build neutral Phase 2 audit-contract aliases from their canonical files."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Verify existing aliases without writing them.",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Run negative controls for absent and ambiguous root rewrites.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.check:
            verify_aliases()
        else:
            build_aliases()
        if args.self_test:
            run_negative_controls()
    except (OSError, UnicodeDecodeError, ValueError, AssertionError) as exc:
        print(f"FAIL: {exc}")
        return 1

    mode = "verified" if args.check else "built"
    print(f"PASS: Phase 2 audit-contract aliases {mode}")
    print(
        "PASS: validator differs only by "
        f"{CANONICAL_ROOT_LINE!r} -> {ALIAS_ROOT_LINE!r}"
    )
    if args.self_test:
        print("PASS: absent and ambiguous root-rewrite negative controls")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
