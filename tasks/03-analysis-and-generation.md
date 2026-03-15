# Milestone 3: Analysis And Generation

## Goal

Deliver the full code-to-spec pipeline: pre-scan, prompt construction, manual prompt export, and direct LLM-backed analysis with deterministic verification around it.

## Depends On

- `01-spec-foundation-and-harness.md`
- `02-viewer-mvp.md`

## Parallelizable Tracks

- `[A]` Repository scan, symbol extraction, and dependency graphing.
- `[B]` Prompt construction, token budgeting, and prompt assets.
- `[C]` Provider abstraction, analyze UX, and persistence.
- `[D]` Evaluation harness, mocked providers, and failure-mode tests.

## Tasks

- [ ] `[A]` Add repo scanning that respects `.gitignore`, recognizes supported language extensions, and produces a reproducible file tree summary.
- [ ] `[A]` Add framework and language detection heuristics for the initial targets called out in the vision, or explicitly define the narrower first-release matrix if that is more realistic.
- [ ] `[A]` Introduce tree-sitter or equivalent parsing to build a symbol index and module dependency graph from supported repo fixtures.
- [ ] `[A]` Implement heuristics for key-file selection: entry points, config files, route definitions, and most-imported files.
- [ ] `[A]` Add token estimation for scanned inputs before any provider call is attempted.
- [ ] `[A]` Capture enough repo context to validate generated node file paths against the real project tree after the provider returns a spec.
- [ ] `[B]` Replace the prompt stub in `Sources/Analysis/SpecGenerator.swift` with a structured prompt builder that composes role instructions, schema definition, examples, quality rules, file tree, symbol index, key file contents, and dependency summary.
- [ ] `[B]` Update `Resources/prompts/analyze-codebase.md` to the v2 schema and keep it synchronized with the in-code model definitions.
- [ ] `[B]` Add a manual "copy prompt" or "export prompt bundle" workflow so the free tier can run analysis without direct API integration.
- [ ] `[B]` Add prompt generation tests that assert the presence of required sections and the correct inclusion of repo-derived context, not brittle exact full-string matches.
- [ ] `[B]` Implement chunking strategy support for repos that exceed a single-context threshold, even if the first shipping version gates it behind an explicit large-repo warning.
- [ ] `[B]` Add the optional two-pass self-review flow behind a feature flag so quality improvements can be measured against cost and latency.
- [ ] `[C]` Add provider abstractions for direct API calls with deterministic fakes for tests.
- [ ] `[C]` Store provider configuration and API keys securely, ideally in Keychain rather than plain preferences.
- [ ] `[C]` Implement the Analyze button, progress UI, cancellation, retry, and failure messaging in the app shell.
- [ ] `[C]` Parse returned YAML, run validation, present actionable diagnostics, and allow saving the resulting `.sightglass.yaml` into the repo root.
- [ ] `[C]` Attach `analyzed_at`, `commit_sha`, and repo metadata to generated specs automatically.
- [ ] `[C]` Make it possible to re-open the generated spec immediately in the viewer without a second manual import step.
- [ ] `[D]` Create provider replay fixtures for success, malformed YAML, timeout, partial schema, and hallucinated nonexistent file cases.
- [ ] `[D]` Add evaluation tests that run the full prompt-generation pipeline on the synthetic repo fixtures and assert measurable quality signals such as file-path validity, minimum expected node recall, and absence of orphaned references.
- [ ] `[D]` Add tests that prove analysis respects `.gitignore` and does not accidentally leak ignored secrets or build outputs into prompts.
- [ ] `[D]` Add benchmark coverage for prompt build time, token estimation, and end-to-end analysis latency under mocked providers.
- [ ] `[D]` Add comparison harnesses so future prompt changes can be scored against the canonical repo fixtures rather than judged by intuition.

## Verification

- A user can point Sightglass at a supported repo, generate a prompt, run analysis either manually or through a provider, and land in the viewer with a saved v2 spec.
- Tests prove parser and UI behavior for malformed provider output, nonexistent file references, and repo scan filtering.
- Mocked end-to-end runs exist for at least one small and one medium repo fixture.
- Prompt and evaluation fixtures can be re-run automatically to detect regressions in quality or cost.

## Milestone

Human sign-off is required to approve provider support, privacy posture, and acceptable quality thresholds on fixture repos. Do not start Milestone 4 until analysis accuracy is good enough to trust as a daily workflow.
