# Milestone 2: Viewer MVP

## Goal

Ship the complete V1 "analyze and visualize" viewer experience described in `VISION.md`, grounded in the current SwiftUI app structure.

## Depends On

- `01-spec-foundation-and-harness.md`

## Parallelizable Tracks

- `[A]` App state, file handling, and workspace UX.
- `[B]` Diagram rendering and interaction.
- `[C]` Sidebar, detail panel, toolbar, and export flows.
- `[D]` UI automation, snapshots, and performance verification.

## Tasks

- [x] `[A]` Expand `Sources/SightglassApp/AppState.swift` to track selected node ID, hovered node ID, visible layers, search query, selected flow ID, active entry point, layout algorithm, freshness state, and current repo root.
- [x] `[A]` Support loading `.sightglass.yaml` via file picker, drag-and-drop, and command-line launch argument.
- [x] `[A]` Add "Open Folder" flow even before direct analysis exists, so users can inspect a repo context and later generate or save specs into that workspace.
- [x] `[A]` Persist recent files and recent folders so onboarding does not reset every launch.
- [ ] `[A]` Add save and save-as support for `.sightglass.yaml`, including preserving comments only if the chosen persistence layer supports it.
- [x] `[A]` Surface validation results in the UI with clear blocking errors versus non-blocking warnings.
- [ ] `[B]` Replace the current straight-line renderer in `Sources/Diagram/DiagramRenderer.swift` with the specified layer-aware pipeline: camera transform, visible rect calculation, layer backgrounds, edge render, node render.
- [ ] `[B]` Implement viewport culling so off-screen nodes, edges, and labels are not drawn.
- [ ] `[B]` Implement Bezier edge routing, arrowheads, midpoint labels, and style variants for `calls`, `async`, `publishes`, `subscribes`, `reads`, and `writes`.
- [ ] `[B]` Implement layer background cards with dashed outlines and top-left labels.
- [ ] `[B]` Implement level-of-detail rendering tied to zoom thresholds instead of always drawing the same node card.
- [ ] `[B]` Implement cursor-anchored zoom, bounded zoom range, panning, fit-to-screen, and stable hit testing under pan and zoom transforms.
- [ ] `[B]` Add hover affordances with highlight state and pointer cursor semantics.
- [ ] `[B]` Upgrade layout support to include the default hybrid layered layout and the alternative force-directed layout named in the vision.
- [ ] `[C]` Upgrade `Sources/Views/SidebarView.swift` to include layer visibility toggles, search, flow picker, and entry point navigation.
- [ ] `[C]` Upgrade `Sources/Views/DetailPanel.swift` to show incoming and outgoing edges, layer membership, file path open action, technology label, owner, lifecycle, methods, types, and entry points for the selected node.
- [ ] `[C]` Upgrade `Sources/Views/ToolbarView.swift` to include layout mode toggle, zoom controls, fit-to-screen, export, and freshness indicator.
- [ ] `[C]` Implement export to PNG and SVG with deterministic framing so exports are testable.
- [x] `[C]` Add a proper empty state for "no repo selected" versus "repo selected but no spec generated yet" versus "spec failed validation."
- [ ] `[C]` Add keyboard shortcuts for open, save, fit, zoom, and export even if richer keyboard navigation waits until Milestone 4.
- [ ] `[D]` Add UI automation that verifies: open spec, select node, hide layer, search node, jump from entry point to node, fit-to-screen, export artifact creation.
- [ ] `[D]` Add golden screenshots for the small, medium, and large fixture specs at key zoom levels so level-of-detail changes are caught automatically.
- [ ] `[D]` Add a performance test for a 100-node spec and enforce the render target from `VISION.md`.
- [ ] `[D]` Add regression coverage for hover and selection behavior at transformed zoom and pan states to avoid broken hit testing.

## Verification

- The viewer can load a v2 spec, render it interactively, export it, and expose node details without manual file edits.
- Snapshot or screenshot tests cover at least one layered REST graph, one event-driven graph, and one large graph.
- UI tests prove the left sidebar, center diagram, and right detail panel work together as the primary navigation loop.
- Performance checks show acceptable render latency for the representative 100-node fixture.

## Milestone

Human sign-off is required after visual and interaction review. Do not start Milestone 3 until the core viewer feels like a credible product rather than an internal scaffold.
