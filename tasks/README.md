# Sightglass Task Map

This folder turns `VISION.md` into milestone-scoped execution tracks for agent-driven delivery. Read the files in order. Do not start a later milestone until the human gate at the end of the current file is cleared.

## Assumptions Resolved Here

- The product stays a native macOS app built from the current Swift Package structure.
- The CodeFlow spec should move to the v2 shape described in `VISION.md` before major viewer or analysis work continues, because later milestones depend on `flows`, richer metadata, and `commit_sha`.
- "Agent-driven development" means every milestone must be self-verifiable through automated tests, simulators, benchmarks, fixture repos, mocked providers, or UI automation.
- The requested `AskQuestionTool` is not available in this workspace, so ambiguities are handled by explicit assumptions plus human gates at milestone boundaries.
- The current repository is an early scaffold, not a near-complete implementation. Tasks below assume substantial feature work remains in `Sources/Analysis`, `Sources/Diagram`, `Sources/Models`, `Sources/Parser`, and `Sources/Views`.
- The current roadmap intentionally stops at one-command installation. Metrics programs, ecosystem hooks, and post-launch expansion stay parked until the human rewrites the roadmap again.

## Global Execution Rules

- Prefer small, independently shippable agent tasks that can land without manual stitching.
- Every user-facing behavior must have an automated verification path before a milestone is called complete.
- Unit tests must target behaviors and invariants. Do not write tests for private helper structure, force calculations, or render internals unless those details are part of the contract.
- Prefer fixture-driven tests over handwritten one-off inputs. Add canonical YAML specs and synthetic codebases under `Tests/Fixtures`.
- Add one deterministic local verification entry point by the end of Milestone 1. Later milestones may extend it, but they should not invent competing ad hoc scripts.
- When UI behavior matters, use macOS UI automation and deterministic screenshot or snapshot coverage rather than asserting incidental view hierarchy details.
- When LLM behavior matters, hide network variance behind provider fakes, canned transcripts, replay servers, or evaluation fixtures.

## Milestone Order

1. `01-spec-foundation-and-harness.md`
2. `02-viewer-mvp.md`
3. `03-analysis-and-generation.md`
4. `04-continuous-sync-and-diff.md`
5. `05-diagram-to-code.md`
6. `06-one-command-install.md`

## Definition Of Done For Any Milestone

- The code builds from a clean checkout.
- The milestone's automated checks run in one documented command.
- New fixtures and test utilities are documented where future agents will find them quickly.
- The milestone ends with a short decision memo or checklist that makes the required human sign-off explicit.
