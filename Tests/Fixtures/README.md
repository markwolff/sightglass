# Fixture Harness

This directory is the canonical Milestone 1 corpus for parser, validation, layout, geometry snapshot, and benchmark verification.

## Layout

- `Specs/`: canonical YAML specs, including valid v2 examples and intentionally invalid failure cases.
- `Repos/`: synthetic codebases used for file-path validation and future analysis evaluation.
- `fixture-manifest.json`: the single inventory for expected layer, node, edge, entry point, and flow counts.
- `Geometry/`: committed geometry goldens generated from the deterministic layout harness.
- `Benchmarks/`: committed machine-readable benchmark baselines.

## Local Verification

Run the full local gate from the repo root:

```sh
scripts/verify-local.sh
```

This builds the app target and runs the standalone verification harness, which:

- runs the Swift test suites, including the offscreen macOS smoke render
- parses and validates every canonical spec
- checks manifest counts against the parsed spec shape
- enforces layout invariants
- compares geometry snapshots
- writes a fresh benchmark report to `.context/benchmarks.json`

## Updating Goldens

When layout or geometry changes intentionally, regenerate the committed goldens and baseline:

```sh
swift run SightglassHarness verify --update-snapshots --benchmark-output Tests/Fixtures/Benchmarks/baseline.json
```

Review the diffs in `Geometry/` and `Benchmarks/` before committing.

## Adding New Fixtures

1. Add the spec under `Specs/` and, if file-path validation matters, add a matching repo under `Repos/`.
2. Register the new fixture in `fixture-manifest.json`.
3. If the fixture should participate in geometry coverage, give it a `snapshot` path and regenerate the goldens.
4. Keep fixtures reusable. Avoid inline test data when the case belongs in the shared corpus.
