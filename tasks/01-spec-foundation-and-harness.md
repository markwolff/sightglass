# Milestone 1: Spec Foundation And Verification Harness

## Goal

Bring the project onto the CodeFlow v2 foundation from `VISION.md` and build the automated harness that all later milestones rely on.

## Depends On

- No prior milestone.

## Parallelizable Tracks

- `[A]` Spec schema, parsing, validation, migration.
- `[B]` Fixture specs and synthetic repo simulators.
- `[C]` Test, benchmark, and screenshot harness.
- `[D]` Local developer workflow and documentation.

## Tasks

- [x] `[A]` Extend `Sources/Models` to represent the full v2 schema: `metadata`, `commit_sha`, `layer.rank`, `node.technology`, `node.owner`, `node.lifecycle`, `edge.type`, `edge.protocol`, `flows`, and `types`.
- [x] `[A]` Decide whether to keep v1 backward compatibility or add an explicit migration layer that upgrades v1 YAML into v2 in memory before validation.
- [x] `[A]` Replace the current string-array validator with a typed validation result that separates fatal errors, warnings, and remediation hints for the UI.
- [x] `[A]` Add structural validation for duplicate IDs, missing references, invalid colors, invalid `layer.rank`, missing `sequence` continuity in flows, empty layer or node names, and invalid protocol or relationship values.
- [x] `[A]` Add file-system cross-check validation so nodes with `file` paths that do not exist under the analyzed repo are flagged explicitly.
- [x] `[A]` Add commit and repo metadata plumbing so future milestones can attach freshness and diff state without reshaping the core models again.
- [x] `[A]` Add parser tests that prove behavior on full v2 examples, invalid references, duplicate IDs, missing files, invalid flow sequences, and mixed optional fields.
- [x] `[A]` Update existing tests to assert stable behavior contracts instead of assumptions tied to the current v1-only model shape.
- [x] `[B]` Create canonical fixture specs under `Tests/Fixtures/Specs` for at least: minimal valid spec, layered REST service, event-driven service, large graph, duplicate ID failure, bad reference failure, nonexistent file warning, and invalid flow ordering failure.
- [x] `[B]` Create synthetic codebase fixtures under `Tests/Fixtures/Repos` for at least: Express-style API, event-driven worker service, and a medium-size monolith with shared utilities.
- [x] `[B]` Add a fixture manifest that records expected node count, edge count, layer count, entry point count, and flow count for each canonical spec and repo.
- [x] `[B]` Store one intentionally noisy or ambiguous repo fixture to drive later evaluation work on accuracy and diff stability.
- [x] `[C]` Add a deterministic render harness for golden screenshots or geometry snapshots of sample specs so UI work can be verified without manual eyeballing.
- [x] `[C]` Add benchmark coverage for YAML parse time, validation time, layout time, and render time for representative fixture sizes.
- [x] `[C]` Add behavior tests for layout invariants that matter to users: all nodes receive positions, layers are vertically ordered by rank, nodes do not overlap within tolerances, and disconnected noise does not collapse the graph.
- [x] `[C]` Avoid implementation-detail tests such as asserting exact force values, helper call counts, or internal sweep order inside layout code.
- [x] `[C]` Add a smoke test that launches the app with a fixture spec and verifies the empty state disappears and the main canvas renders.
- [x] `[D]` Create one local gate command such as `scripts/verify-local.sh` or `make verify` that runs build, unit tests, UI tests, snapshots, and benchmarks that are practical in CI.
- [x] `[D]` Document where fixtures live, how to update goldens, and how future agents should add new fixtures instead of inventing inline test data.
- [x] `[D]` Add a short architecture note describing the v2 schema boundary so later work does not leak parsing rules into the rendering or analysis layers.

## Verification

- `swift test` or the chosen package-level test entry point passes on all parser, layout, and fixture suites.
- The screenshot or geometry harness produces deterministic results on at least one small, one medium, and one large graph fixture.
- The benchmark harness reports current parse and render baselines and stores them in a machine-readable format for regression checks.
- The local gate command is documented and runnable by an agent from a clean checkout.

## Milestone

Human sign-off is required after reviewing the v2 schema shape, validation philosophy, and the verification harness footprint. Do not start Milestone 2 until the schema and fixture set are accepted as the long-term contract.
