# Phase 2 Round 8 Board stop report

Status: **STOPPED - NO BOARD VERDICT**

Date: 2026-07-22

Cut: `phase2-art-cut-9d03d7c`

Packet: `audit_packet.json`

Round 8 repaired both known Round 7 packet defects before convening exactly three fresh, clean-context seats:

- Seat A: `CONTRACT_AND_EVIDENCE_PROSECUTOR`
- Seat B: `PROFESSIONAL_STANDARDS_DIRECTOR`
- Seat C: `FAILURE_AND_ADOPTION_RED_TEAM`

Each seat received the same frozen blind packet: 59 evidence records, 55 artifacts, 184 source-identical material criteria, 10 professional dimensions, five surfaces, and five frozen benchmarks. Prior Board rounds, prior findings, stop reports, triage, repair claims, producer verdicts, and peer output were excluded.

## Repairs verified before review

Round 8 replaced the lossy 18-criterion summary with a deterministic authority-coverage manifest derived line by line from `docs/art/unit_art_board_reference_criteria.md`. Every material source line is mapped to one source-identical criterion with a real line locator; headings and metadata are separately classified. The coverage validator reports 184 material criteria and 31 structural or metadata lines with no missing or extra mappings.

Round 8 also added an artifact-first primary-record assembler. A reviewer can author small seat-owned shards while the assembler expands static authority and evidence receipts from the frozen packet and rejects missing, reordered, duplicated, or foreign records. Its self-test passed and its negative control rejects a missing evidence attestation.

These repairs make the packet materially stronger than Round 7. They do not constitute a Board verdict.

## Stop condition

Seat A's initial clean-room turn disconnected from the backend response stream before writing a primary record or checkpoint. The same seat then received the one permitted recovery, materially shortened to blind inspection of only four units and the five fixed benchmarks, with a tiny reviewer-owned checkpoint as its sole output. That bounded recovery ended with the identical backend response-stream disconnect before writing anything.

Seat C's initial full turn had already ended with the same disconnect. Its shortened recovery and Seat B's still-running turn were interrupted as soon as Seat A repeated the failure. The seat directories remained empty.

The user explicitly required the run to break on an endless loop. The root therefore stopped the Board. No replacement reviewers were spawned and no further retries were attempted.

No sealed primary records exist. No secondary round occurred. No cross-examination occurred. No semantic release review occurred. The Board state is `INSUFFICIENT EVIDENCE`, not `READY`, and all Phase 2 concepts remain candidates.

## Board protocol gap caught

Output sharding alone is insufficient for a large image-first audit because the upgraded Board contract still assumes that one reviewer turn can inspect the whole frozen visual corpus before any durable reviewer-authored checkpoint exists. This run failed before the assembler could help.

A future Board revision needs an explicit same-seat staged-review protocol that:

1. partitions blind visual inspection into bounded, durable checkpoints;
2. preserves reviewer identity and clean-context independence across continuation turns;
3. separates observation checkpoints from criterion dispositions and verdicts;
4. seals a completeness manifest before aggregation; and
5. defines one recovery boundary without allowing reviewer replacement or endless retries.

Do not reconvene this 12-unit audit until that protocol exists and passes a short-turn fault-injection test. Do not treat the valid packet, empty seat directories, interrupted seats, or historical Board records as approval evidence.

## Preserved evidence

- `audit_packet.json` and `authority_context.json` pass the upgraded Board schema validator.
- `authority_coverage.json` passes `tools/art/validate_phase2_board_authority_coverage.py`.
- `tools/art/assemble_phase2_board_primary.py` passes its self-test and missing-evidence negative control.
- The Phase 2 concept/evidence and calibration validators pass for the frozen 12-unit cut.
- The visual-debug evidence remains frozen under `outputs/visual_debug/vdh_runs/phase2-board-cut-9d03d7c/`.

These facts establish a valid review input and a reproducible infrastructure blocker, not Board approval.
