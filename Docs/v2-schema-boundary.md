# V2 Schema Boundary

The parser owns the schema boundary. Everything outside `SpecParser` should operate on a normalized CodeFlow v2 `CodeSpec`.

## Rules

- Raw YAML enters the system only through `SpecParser.parse`.
- Version 1 specs are upgraded in memory to v2 before the rest of the app sees them.
- Structural validation also lives at the parser boundary through `SpecParser.validate`.
- Repository-relative file checks happen during validation, not in the renderer or views.
- Rendering, layout, and UI code consume typed models and validation output. They do not reinterpret YAML fields or invent fallback schema behavior.

## Why This Matters

- Later milestones can add diffing and freshness metadata without reshaping the core model again.
- UI code gets a stable contract: either a normalized spec plus warnings, or fatal validation issues.
- The verification harness can exercise parsing, validation, layout, and snapshots from the same canonical fixtures.

## Current Normalized Shape

- project metadata: `metadata`, `commit_sha`
- ranked layers: `layer.rank`
- richer nodes: `technology`, `owner`, `lifecycle`
- richer edges: `type`, `protocol`
- named walkthroughs: `flows`
- reusable schemas: `types`
- typed validation output: fatal errors, warnings, remediation hints

## Non-Goals At This Boundary

- No rendering-specific defaults inside the parser beyond v1-to-v2 migration.
- No filesystem probing from SwiftUI views.
- No YAML-string parsing in layout or diagram code.
