# Milestone 5: Diagram To Code

## Goal

Turn Sightglass into a controlled two-way system where diagram edits can drive agent-executed code changes and then verify that the code matches the intended architecture.

## Depends On

- `01-spec-foundation-and-harness.md`
- `02-viewer-mvp.md`
- `03-analysis-and-generation.md`
- `04-continuous-sync-and-diff.md`

## Parallelizable Tracks

- `[A]` Editable diagram state and persistence.
- `[B]` Change-set generation and prompt translation.
- `[C]` Agent execution, safety rails, and rollback.
- `[D]` End-to-end simulators and verification loops.

## Tasks

- [ ] `[A]` Introduce an editable graph model separate from the immutable analyzed spec so user edits can be staged before they are committed.
- [ ] `[A]` Decide whether manual overrides live inline in `.sightglass.yaml` or in a separate overlay file, and document the merge strategy explicitly.
- [ ] `[A]` Implement editing flows for add, remove, rename, reconnect, and re-layer operations on nodes, edges, layers, and flows.
- [ ] `[A]` Implement visual affordances for staged edits, unsaved changes, and conflicts with a freshly re-analyzed spec.
- [ ] `[A]` Preserve a clear audit trail of who changed the diagram intent and when, even if the initial release is single-user only.
- [ ] `[B]` Define a structured change-set format that captures architectural intent in machine-readable terms before it is translated into natural-language prompts.
- [ ] `[B]` Build prompt generation that turns change sets into actionable agent instructions with explicit constraints, acceptance criteria, and verification expectations.
- [ ] `[B]` Support a non-executing export mode first so users can inspect or run the prompt manually in their preferred coding agent.
- [ ] `[B]` Add support for re-analysis after code changes and compare intended versus observed architecture as the primary success signal.
- [ ] `[C]` Add an execution adapter layer for supported coding agents or local command integrations.
- [ ] `[C]` Run each code-changing action on an isolated branch or worktree so failures do not corrupt the user's primary checkout.
- [ ] `[C]` Require a preview step that shows the intended architectural change, the generated prompt, and the verification plan before execution starts.
- [ ] `[C]` Add safety checks for forbidden paths, unexpectedly large diffs, failed tests, and divergence between intended and resulting architecture.
- [ ] `[C]` Add rollback and resume behavior for partially completed agent runs.
- [ ] `[C]` Store execution logs, prompts, and verification outcomes for later debugging.
- [ ] `[D]` Create fake-agent simulators that apply known patches so end-to-end behavior can be tested without relying on live model variance.
- [ ] `[D]` Add end-to-end tests that cover: diagram edit, prompt generation, agent execution, repo mutation, re-analysis, spec comparison, and pass or fail decision.
- [ ] `[D]` Add failure-mode tests for rejected previews, failed verification, conflicting manual repo edits, and provider or agent timeouts.
- [ ] `[D]` Add acceptance tests around architectural intent, for example "insert caching layer between service and repository" and "split one module into two services," using synthetic repos.
- [ ] `[D]` Ensure all verification tests assert user-visible outcomes rather than the internal ordering of prompt builder or diff engine helpers.

## Verification

- A staged diagram change can produce a machine-readable change set, a human-reviewable prompt, a code modification in an isolated checkout, and a post-change verification result.
- Safety failures are recoverable, logged, and leave the user's primary checkout intact.
- End-to-end simulator runs exist for both success and rollback paths.
- The final verification loop compares resulting architecture to intended architecture automatically.

## Milestone

Human sign-off is required to approve the safety model, supported execution surface, and rollback expectations. Do not start the install milestone until automated code changes are safe enough for real user repos.
