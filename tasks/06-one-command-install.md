# Milestone 6: One-Command Install

## Goal

Ship Sightglass so a macOS developer can go from clean machine to first launch with one pasted command and no manual artifact hunting.

This milestone intentionally replaces the old "release, metrics, ecosystem" and "post-launch expansion" phases. Do not expand it into pricing, analytics, CI ecosystem hooks, web surfaces, or other future-track work.

## Depends On

- `01-spec-foundation-and-harness.md`
- `02-viewer-mvp.md`
- `03-analysis-and-generation.md`
- `04-continuous-sync-and-diff.md`
- `05-diagram-to-code.md`

## Parallelizable Tracks

- `[A]` Build a stable macOS release artifact from CI.
- `[B]` Ship one-command install surfaces.
- `[C]` Verify install, launch, upgrade, and uninstall flows.

## Tasks

- [ ] `[A]` Build release automation that produces a reproducible macOS artifact from GitHub Actions with a stable filename and release URL shape.
- [ ] `[A]` Decide the canonical artifact shape once and keep it boring: either a signed `.app.zip` for direct install or a source-build install path driven by a repo-hosted script.
- [ ] `[A]` Keep universal binaries, notarization, and hardened runtime in scope only if they are required for the chosen install path; do not block this milestone on DMGs or Sparkle.
- [ ] `[A]` Publish release notes that include the exact install command, minimum macOS version, and a short rollback path.
- [ ] `[B]` Add a repo-hosted `install.sh` that a user can run with `curl -fsSL https://raw.githubusercontent.com/markwolff/sightglass/main/install.sh | sh`.
- [ ] `[B]` Make the install script idempotent, explicit about where Sightglass is placed, and safe to re-run for upgrades.
- [ ] `[B]` Add a Homebrew path only if it stays one command end to end, for example a tap or cask that installs from the same release asset naming scheme.
- [ ] `[B]` Ensure the command requires no Xcode-specific knowledge from the user beyond whatever the install path truly needs.
- [ ] `[C]` Add release smoke tests that verify a clean-machine install, first launch, fixture load, graph render, and basic export path.
- [ ] `[C]` Add an uninstall path and document how to remove Sightglass cleanly.
- [ ] `[C]` Validate upgrade behavior by re-running the install command and confirming the existing app is replaced without manual cleanup.
- [ ] `[C]` Add concise install docs in the repo root so the landing page matches the release artifact behavior exactly.

## Verification

- A clean macOS machine can install Sightglass with one pasted command from the GitHub repo.
- The installed app launches without opening the source tree or asking the user to assemble artifacts manually.
- Re-running the install command upgrades or reinstalls cleanly.
- Release notes and repo docs show the same command and the same post-install expectations.

## Milestone

Human sign-off is required to approve the exact install command, artifact shape, and support burden. The roadmap stops here until new priorities are chosen explicitly.
