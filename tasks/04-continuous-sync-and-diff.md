# Milestone 4: Continuous Sync And Diff

## Goal

Move from one-shot analysis to a living diagram that detects drift, supports incremental updates, and helps reviewers understand architectural change over time.

## Depends On

- `01-spec-foundation-and-harness.md`
- `02-viewer-mvp.md`
- `03-analysis-and-generation.md`

## Parallelizable Tracks

- `[A]` Freshness, file watching, and git state capture.
- `[B]` Incremental analysis and spec diffing.
- `[C]` Flow walkthroughs, keyboard support, and accessibility.
- `[D]` Mutation simulators, regression tests, and performance checks.

## Tasks

- [ ] `[A]` Track the loaded repo root, current spec path, last analyzed commit SHA, and freshness state in app state and persisted workspace metadata.
- [ ] `[A]` Add file watching so repo mutations can mark the current spec as stale without immediately forcing expensive analysis work.
- [ ] `[A]` Distinguish clearly between "changed files detected", "analysis pending", "analysis running", and "diagram fresh" states in the UI.
- [ ] `[A]` Add user controls for manual refresh, deferred refresh, and optional auto-refresh for supported repo sizes.
- [ ] `[B]` Implement git-diff-based impact analysis that maps changed files to affected nodes and impacted dependency neighborhoods.
- [ ] `[B]` Implement incremental prompt construction that sends only the impacted context plus the prior spec when a repo change is small enough.
- [ ] `[B]` Build a structured spec diff engine that identifies added, removed, renamed, and modified layers, nodes, edges, flows, and types.
- [ ] `[B]` Surface spec diffs in the UI with architecture-centric language rather than raw YAML line diffs.
- [ ] `[B]` Add support for comparing two arbitrary specs, including before and after a branch or pull request.
- [ ] `[B]` Add drift warnings for cases where the repo changed but the spec on disk still matches an older commit.
- [ ] `[C]` Implement the named flow walkthrough experience: dim unrelated graph elements, highlight the selected flow, pulse steps in sequence order, and animate same-sequence steps in parallel.
- [ ] `[C]` Add keyboard navigation across nodes, layers, flows, and entry points.
- [ ] `[C]` Add VoiceOver labels and accessibility summaries for the selected node, active flow, and freshness state.
- [ ] `[C]` Add focus-handling so keyboard navigation and mouse selection stay in sync.
- [ ] `[D]` Create repo mutation simulators that change routes, rename files, add dependencies, and remove components so incremental analysis can be tested repeatably.
- [ ] `[D]` Add golden spec diff fixtures and assert the user-visible change summary, not the internal diff algorithm steps.
- [ ] `[D]` Add flow animation tests using deterministic clocks or timeline controls rather than sleep-based timing.
- [ ] `[D]` Add performance tests that compare full analysis versus incremental analysis on the medium and noisy repo fixtures.
- [ ] `[D]` Add regression tests for stale-spec detection when files change outside of git, such as local uncommitted work.

## Verification

- The app can detect repo drift, explain why the diagram is stale, and refresh either incrementally or fully.
- Diff tests prove that real architectural changes are surfaced in human-meaningful summaries.
- Flow animation is covered by deterministic automated tests plus visual goldens.
- Accessibility and keyboard navigation have automated smoke coverage.

## Milestone

Human sign-off is required to approve default sync behavior, pricing or gating for continuous features, and the review UX for architectural diffs. Do not start Milestone 5 until these background behaviors are trustworthy and not overly noisy.
