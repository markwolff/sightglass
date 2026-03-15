# Sightglass — Product Vision & Requirements

**X-Ray Vision for Your Codebase**

A native macOS app that uses AI to analyze code and produce interactive architecture diagrams that stay in sync with the source.

---

## 1. Executive Summary

Sightglass analyzes a codebase using AI and renders the result as an interactive, layered architecture diagram. An LLM reads the code, produces a structured YAML spec (the CodeFlow format), and Sightglass renders it as a navigable node-and-edge graph with layers, data flows, entry points, and animated flow walkthroughs. No existing tool auto-generates architecture diagrams from code using AI. Sightglass fills the gap between manual diagramming tools (Mermaid, Structurizr) that drift from reality and static analysis tools (CodeScene, Dependency Cruiser) that lack architectural understanding.

---

## 2. Problem Statement

### The Pain

**Architecture diagrams are always stale.** Manually authored diagrams in Mermaid, Lucidchart, or draw.io drift from the actual code within weeks. Nobody updates them because the effort is high and the payoff is invisible until someone needs them.

**Vibe coding creates codebases nobody understands.** AI agents generate code without architectural coherence. Individual files work, but the system design is incoherent. The developer who prompted the AI often cannot explain how the pieces fit together.

**Onboarding is slow.** New developers spend days or weeks reading code to build a mental model of the architecture. There is no "map" of the codebase — just the code itself.

**Code review lacks architectural context.** Reviewers see file diffs but have no view of how changes affect the overall system. A seemingly small change might have wide-reaching architectural implications.

### Who Feels It

- **Vibe coders** who need to understand what AI generated
- **New team members** onboarding to unfamiliar codebases
- **Tech leads** reviewing PRs for architectural impact
- **Senior engineers** planning refactors or architecture reviews
- **Anyone inheriting a codebase** they did not write

### Why Now

- AI generates more code than ever, but understanding that code has not gotten easier
- The "manager of agents" archetype needs tools to understand what agents built
- Context windows are now large enough (100K-1M tokens) for AI to analyze entire codebases in one pass
- The vibe coding backlash is growing — developers want visibility, not just velocity

### Current Alternatives and Their Gaps

| Tool | What It Does | Gap |
|------|-------------|-----|
| Mermaid / D2 / Structurizr | Manual diagram authoring as code | Diagrams drift. Requires human maintenance. Not auto-generated. |
| CodeScene | Behavioral analysis from git history | Coarse-grained (folder-level). No AI. No interactive diagrams. |
| Understand (SciTools) | Deep static analysis + visualization | Dated UI. No AI. Expensive. Code-level only, no architecture view. |
| Sourcetrail | Interactive code exploration | Discontinued. Symbol-level only, no architecture. |
| Dependency Cruiser | JS/TS import graph | Module-level only. No AI understanding. Static images. |
| CodeSee | Auto-generated service maps | Acquired by GitHub. File/folder-level. No AI analysis. |
| IDE Call Hierarchy | Real-time symbol navigation | Single-symbol at a time. Not visual. Not persistent. Not shareable. |
| Copilot / Claude Code | Can generate Mermaid on request | Ad-hoc. Not systematic. No interactive rendering. No persistence. |

**The gap**: No tool uses AI to automatically generate and maintain multi-level architecture diagrams that stay in sync with code changes.

---

## 3. Vision & Principles

### Vision

Every codebase should have a living, AI-generated architecture diagram that developers can see, explore, and eventually edit to drive code changes. The diagram should be as natural a part of the development workflow as the README or the test suite.

### The Three-Phase Vision

**Phase 1 (V1): Analyze and Visualize**
AI agent generates a CodeFlow spec → Sightglass renders it as an interactive diagram. One-way: code → diagram.

**Phase 2 (V1.x): Continuous Sync**
Sightglass detects code changes, triggers incremental re-analysis, and updates the diagram automatically. The diagram stays current as the codebase evolves.

**Phase 3 (V2+): Diagram-to-Code**
Developers edit the diagram (add a caching layer, split a module, add a new service) and Sightglass generates prompts that an AI agent executes to modify the actual code. Two-way: code ↔ diagram.

### Design Principles

1. **AI-generated, human-refined** — Start automated. Allow manual annotations and overrides. Never require human authoring from scratch.

2. **Always current** — Detect when the diagram has drifted from code. Prompt re-analysis. Show freshness indicators.

3. **Interactive, not static** — Pan, zoom, click, explore. Filter by layer. Trace data flows. The diagram is a tool for understanding, not a picture to look at.

4. **Spec-as-code** — The CodeFlow YAML spec lives in the repo alongside the code. It is version-controlled, diffable, and reviewable in PRs.

5. **Privacy-first** — Analysis runs locally using your own API keys. Code never leaves your machine unless you send it to an LLM API you control.

---

## 4. Target Users & Personas

### Persona 1: The Vibe Coder

**Profile**: Developer who uses AI agents extensively for code generation. Ships fast but worries about understanding.
**Need**: "Show me what Claude just built." A map of the generated code that reveals structure without reading every file.
**Sightglass fit**: Point at the repo, run analysis, get an interactive diagram in 2 minutes.

### Persona 2: The New Team Member

**Profile**: Developer who just joined a team and needs to understand an existing codebase.
**Need**: A starting point for understanding. "What are the main components? How do they connect? Where is the entry point for X?"
**Sightglass fit**: Open the team's `.sightglass.yaml` spec, explore the diagram, click nodes to see file paths and methods.

### Persona 3: The Tech Lead

**Profile**: Engineering lead responsible for architecture quality across the team.
**Need**: Architectural awareness during code review. "Does this PR introduce a new dependency between layers? Does it violate our architecture patterns?"
**Sightglass fit**: Compare specs before and after a PR to see architectural diff. Run analysis in CI to detect drift.

### Persona 4: The Refactoring Engineer

**Profile**: Senior developer planning a major refactor or migration.
**Need**: Clear picture of the current architecture before planning changes. "What depends on this module? What would break if I moved it?"
**Sightglass fit**: Explore the diagram to understand dependencies. Use flow walkthroughs to trace data paths through the system.

---

## 5. Product Overview

### How It Works

```
┌──────────────────────────────────────────────────────────────┐
│                       Your Codebase                          │
│  src/controllers/  src/services/  src/models/  package.json  │
└──────────────────────┬───────────────────────────────────────┘
                       │ (1) Pre-scan: tree-sitter extracts
                       │     symbol index + dependency graph
                       v
              ┌─────────────────┐
              │  SpecGenerator  │
              │  Builds prompt: │
              │  - File tree    │
              │  - Symbol index │
              │  - Key files    │
              │  - Prompt tmpl  │
              └────────┬────────┘
                       │ (2) Send to LLM (Claude / GPT)
                       v
              ┌─────────────────┐
              │    LLM API      │
              │  Analyzes code  │
              │  Produces YAML  │
              └────────┬────────┘
                       │ (3) Parse + validate
                       v
              ┌─────────────────┐
              │   SpecParser    │
              │  YAML → Model   │
              └────────┬────────┘
                       │ (4) Layout + render
                       v
              ┌─────────────────┐
              │ DiagramRenderer │
              │ SwiftUI Canvas  │
              │ Interactive UX  │
              └─────────────────┘
```

### Developer Experience Walkthrough

**Minute 0**: Install with one pasted command: `curl -fsSL https://raw.githubusercontent.com/markwolff/sightglass/main/install.sh | sh`.

**Minute 1**: Launch Sightglass. An empty workspace greets you with "Open a folder or drop a .sightglass.yaml file."

**Minute 2**: Click "Open Folder" and select your project root. Sightglass scans the directory, identifies the language and framework, and shows a preview of what it found (file count, detected framework, estimated token count).

**Minute 3**: Click "Analyze". Sightglass builds the analysis prompt (file tree + symbol index + key file contents), sends it to Claude, and shows a progress indicator. After 15-30 seconds, the CodeFlow spec is generated and the diagram appears.

**Minute 4**: The diagram renders — nodes grouped into colored layers (API, Business Logic, Data Access, External Services). You pan and zoom to explore. Click a node to see its methods, types, and file path in the detail panel.

**Minute 5**: Select "Create Order Flow" from the Flows dropdown. The diagram animates a step-by-step walkthrough of how data moves from the API controller through the service layer to the database and event queue.

**Minute 6**: Save the spec as `.sightglass.yaml` in the project root. Commit it to the repo. Future team members can open it directly in Sightglass without re-running the analysis.

---

## 6. The CodeFlow Spec Format (v2)

The CodeFlow spec is the structured YAML output of the AI analysis. It is the bridge between AI understanding and human visualization.

### Design Goals

- **AI-generatable**: The format must be producible by an LLM from a single prompt
- **Human-readable**: A developer should be able to read and edit the YAML directly
- **Machine-parseable**: Strict schema for reliable rendering
- **Version-controlled**: Clean diffs when architecture changes
- **Extensible**: Optional fields that add richness without breaking basic rendering

### Full Specification

```yaml
# ─── Metadata ──────────────────────────────────────────────
name: string              # Required. Project/service name
version: 2                # Required. Spec format version
analyzed_at: datetime     # When the analysis was performed
commit_sha: string        # Git SHA of the analyzed code state

metadata:                 # Optional. Project-level context
  repository: url         # Repository URL
  language: string        # Primary language (TypeScript, Python, Go, etc.)
  framework: string       # Framework (NestJS, Express, Django, Rails, etc.)
  description: string     # One-line project description

# ─── Layers ────────────────────────────────────────────────
layers:                   # Required. Architectural groupings
  - id: string            # Unique layer identifier
    name: string          # Display name
    color: hex-string     # Layer color (e.g., "#4A90D9")
    rank: number          # Vertical order (0 = top)

# ─── Nodes ─────────────────────────────────────────────────
nodes:                    # Required. Architectural components
  - id: string            # Unique node identifier
    name: string          # Display name
    layer: string         # Layer ID reference
    file: string          # Source file path (relative to project root)
    description: string   # What this component does
    technology: string    # Optional. Framework/runtime (e.g., "NestJS Controller")
    owner: string         # Optional. Team that owns this component
    lifecycle: string     # Optional. production | experimental | deprecated
    types: [string]       # Optional. Data types this component works with
    methods: [string]     # Optional. Key methods/functions

# ─── Edges ─────────────────────────────────────────────────
edges:                    # Required. Connections between nodes
  - from: string          # Source node ID
    to: string            # Target node ID
    label: string         # Connection description
    data_type: string     # Optional. Data flowing on this edge (e.g., "CreateOrderDto -> OrderResponse")
    type: string          # Optional. Relationship type:
                          #   calls | triggers | reads | writes | publishes | subscribes | returns
    async: boolean        # Optional. Is this an asynchronous connection?
    protocol: string      # Optional. Communication protocol:
                          #   function | https | grpc | graphql | kafka | amqp | websocket | jdbc | redis

# ─── Entry Points ──────────────────────────────────────────
entry_points:             # Optional. External interfaces
  - node: string          # Node ID that serves as entry point
    type: string          # http | grpc | graphql | cli | event | cron | websocket
    method: string        # Optional. HTTP method (GET, POST, etc.)
    path: string          # Optional. Route path
    description: string   # What this endpoint does
    request_type: string  # Optional. Input data type
    response_type: string # Optional. Output data type

# ─── Flows ─────────────────────────────────────────────────
flows:                    # Optional. Named data flow sequences
  - id: string            # Unique flow identifier
    name: string          # Display name (e.g., "Create Order Flow")
    description: string   # What this flow represents
    trigger:              # What initiates this flow
      type: string        # http | event | cron | manual
      method: string      # Optional. HTTP method
      path: string        # Optional. Route path
    steps:                # Ordered sequence of data flow steps
      - from: string      # Source node ID
        to: string        # Target node ID
        label: string     # Step description
        data_type: string # Optional. Data at this step
        sequence: number  # Order in the flow (1, 2, 3, ...)
        async: boolean    # Optional. Is this step asynchronous?

# ─── Types ─────────────────────────────────────────────────
types:                    # Optional. Data type definitions
  - id: string            # Type name
    description: string   # What this type represents
    fields:               # Type fields/properties
      - name: string      # Field name
        type: string      # Field type (string, number, boolean, CustomType, etc.)
        required: boolean # Is this field required?
```

### v2 Additions (vs. v1)

| Feature | v1 | v2 | Inspiration |
|---------|----|----|-------------|
| `metadata` block | None | Repo URL, language, framework | Backstage catalog |
| `layer.rank` | None | Rendering order | ArchiMate layers |
| `node.technology` | None | Framework/runtime label | C4 model |
| `node.owner` | None | Team ownership | Backstage catalog |
| `node.lifecycle` | None | production/deprecated/experimental | Backstage catalog |
| `edge.type` | None | calls/triggers/reads/writes/publishes/subscribes | ArchiMate relationships |
| `edge.protocol` | None | function/https/grpc/kafka/etc. | Microservice patterns |
| `flows` section | None | Named, ordered step sequences | Ilograph perspectives |
| `types` section | None | Data type schema definitions | OpenAPI schemas |
| `commit_sha` | None | Git SHA of analyzed state | Incremental analysis |

### Why `flows` Is the Key Addition

The `flows` section captures something no other diagram format does well: **named, ordered sequences of data movement through the architecture**. While the `edges` section describes the static topology (what CAN connect to what), `flows` describe the dynamic behavior (what DOES happen when a user creates an order).

This enables:
- Animated step-by-step walkthroughs in the UI
- Understanding of specific user journeys through the code
- Identification of critical paths and bottlenecks
- Documentation of business processes alongside technical architecture

### Example: REST API Service

```yaml
name: user-service
version: 2
analyzed_at: 2026-03-15T14:00:00Z
commit_sha: a1b2c3d

metadata:
  language: TypeScript
  framework: Express
  description: User registration and authentication service

layers:
  - { id: api, name: API Routes, color: "#4A90D9", rank: 0 }
  - { id: service, name: Services, color: "#7B68EE", rank: 1 }
  - { id: data, name: Data Layer, color: "#50C878", rank: 2 }

nodes:
  - id: auth-routes
    name: AuthRoutes
    layer: api
    file: src/routes/auth.ts
    methods: [POST /login, POST /register, POST /logout]

  - id: auth-service
    name: AuthService
    layer: service
    file: src/services/auth.service.ts
    methods: [login(), register(), validateToken(), hashPassword()]
    types: [LoginRequest, AuthToken, UserCredentials]

  - id: user-repo
    name: UserRepository
    layer: data
    file: src/repos/user.repo.ts
    technology: Prisma
    methods: [findByEmail(), create(), update()]

  - id: token-store
    name: TokenStore
    layer: data
    file: src/services/token.store.ts
    technology: Redis
    methods: [set(), get(), delete()]

edges:
  - { from: auth-routes, to: auth-service, label: authenticate, type: calls }
  - { from: auth-service, to: user-repo, label: findByEmail, type: calls }
  - { from: auth-service, to: token-store, label: storeToken, type: writes, protocol: redis }

entry_points:
  - { node: auth-routes, type: http, method: POST, path: /api/auth/login }
  - { node: auth-routes, type: http, method: POST, path: /api/auth/register }

flows:
  - id: user-login
    name: User Login Flow
    trigger: { type: http, method: POST, path: /api/auth/login }
    steps:
      - { from: auth-routes, to: auth-service, label: validate credentials, sequence: 1 }
      - { from: auth-service, to: user-repo, label: find user by email, sequence: 2 }
      - { from: auth-service, to: token-store, label: store session token, sequence: 3 }
```

### Example: Event-Driven Microservice

```yaml
name: notification-service
version: 2
metadata:
  language: Python
  framework: FastAPI + Celery
  description: Sends notifications via email, SMS, and push

layers:
  - { id: api, name: API + Events, color: "#4A90D9", rank: 0 }
  - { id: processing, name: Processing, color: "#7B68EE", rank: 1 }
  - { id: delivery, name: Delivery Channels, color: "#E89040", rank: 2 }
  - { id: data, name: Storage, color: "#50C878", rank: 3 }

nodes:
  - id: event-consumer
    name: EventConsumer
    layer: api
    file: src/consumers/events.py
    technology: Kafka Consumer

  - id: notification-router
    name: NotificationRouter
    layer: processing
    file: src/services/router.py
    methods: [route(), determine_channels()]

  - id: email-sender
    name: EmailSender
    layer: delivery
    file: src/channels/email.py
    technology: SendGrid Client

  - id: sms-sender
    name: SmsSender
    layer: delivery
    file: src/channels/sms.py
    technology: Twilio Client

  - id: push-sender
    name: PushSender
    layer: delivery
    file: src/channels/push.py
    technology: Firebase FCM

  - id: notification-log
    name: NotificationLog
    layer: data
    file: src/repos/notification_log.py
    technology: PostgreSQL

edges:
  - { from: event-consumer, to: notification-router, label: NotificationEvent, type: triggers, async: true, protocol: kafka }
  - { from: notification-router, to: email-sender, label: sendEmail, type: calls }
  - { from: notification-router, to: sms-sender, label: sendSms, type: calls }
  - { from: notification-router, to: push-sender, label: sendPush, type: calls }
  - { from: notification-router, to: notification-log, label: logDelivery, type: writes, protocol: jdbc }

flows:
  - id: send-notification
    name: Send Notification
    trigger: { type: event, path: notifications.send }
    steps:
      - { from: event-consumer, to: notification-router, label: route notification, sequence: 1 }
      - { from: notification-router, to: email-sender, label: send email, sequence: 2 }
      - { from: notification-router, to: sms-sender, label: send SMS, sequence: 2 }
      - { from: notification-router, to: push-sender, label: send push, sequence: 2 }
      - { from: notification-router, to: notification-log, label: log delivery, sequence: 3 }
```

---

## 7. Core Features — V1

### 7.1 Spec Loading

Load `.sightglass.yaml` files via file picker, drag-and-drop, or CLI argument. Parse with Yams (Swift YAML parser). Validate structural integrity: all edge endpoints reference existing nodes, all node layer references are valid, no duplicate IDs.

### 7.2 Interactive Diagram

**Canvas**: SwiftUI `Canvas` view with custom `GraphicsContext` rendering. Full viewport culling (only draw visible elements).

**Pan**: `DragGesture` translates the viewport. Inertial scrolling for polish.

**Zoom**: `MagnifyGesture` (trackpad pinch) + scroll wheel. Zoom anchored to cursor/pinch point. Range: 10% to 500%.

**Selection**: Click a node to select it. Selected node highlights with a glow effect. Detail panel populates with node information.

**Hover**: macOS `onContinuousHover` highlights nodes on mouseover. Cursor changes to pointing hand.

### 7.3 Node Rendering

Rounded rectangles colored by layer. Each node shows:
- **Name** (bold, centered)
- **Description** (smaller text, below name, truncated)
- **Type badge** (technology label, top-right corner)

At higher zoom levels, additionally show:
- Method list
- Type list

### 7.4 Edge Rendering

Cubic Bezier curves with vertical control points (suited for hierarchical layouts). Each edge shows:
- **Arrowhead** at the target end
- **Label** at the midpoint (edge description or data type)
- **Style** varies by type: solid for `calls`, dashed for `async`, dotted for `publishes`/`subscribes`

### 7.5 Layer Backgrounds

Translucent rounded rectangles behind each layer's nodes. Dashed border in the layer's color. Layer name label in the top-left corner.

### 7.6 Detail Panel

Right sidebar, visible when a node is selected:
- Node name and description
- Layer membership
- File path (clickable — opens in default editor)
- Technology label
- Methods list
- Types list
- Incoming edges (what connects TO this node)
- Outgoing edges (what this node connects TO)
- Owner and lifecycle (if specified)

### 7.7 Sidebar

Left sidebar:
- Layer list with visibility toggles (show/hide layers)
- Node search (filter by name)
- Flow list (select a flow for walkthrough)
- Entry points list (jump to entry point nodes)

### 7.8 Analysis Prompt Template

A bundled markdown prompt template that guides the AI to produce a valid CodeFlow spec. Includes:
- Role framing ("You are a software architect analyzing a codebase")
- Exact YAML schema with field descriptions
- Complete annotated example
- Quality guidelines and common mistakes
- Chain-of-thought instructions (entry points first, trace flows, identify shared utilities)

### 7.9 Toolbar

- Layout algorithm toggle (force-directed / hierarchical)
- Zoom controls (+, -, fit-to-screen)
- Export: PNG, SVG
- Analyze button (triggers re-analysis)
- Freshness indicator (time since last analysis, green/yellow/red)

---

## 8. The Analysis Approach

### Pre-Scan (No LLM Required)

Before sending anything to an LLM, Sightglass performs a local pre-scan:

1. **File tree**: Walk the directory, filter by language extensions, respect `.gitignore`
2. **Symbol index**: Use tree-sitter to extract classes, functions, exports, and imports from key files
3. **Dependency graph**: Parse import/require/use statements to build a module dependency graph
4. **Identify key files**: Heuristics for "architecturally significant" files:
   - Entry points (main.ts, app.ts, index.ts, server.ts)
   - Configuration (package.json, tsconfig.json, Cargo.toml, pyproject.toml)
   - Route definitions (routes/, controllers/, handlers/)
   - Most-imported files (highest in-degree in the dependency graph)

### Prompt Construction

The analysis prompt is assembled from:

```
┌──────────────────────────────────────┐
│ 1. Role + instructions (from template)│
│ 2. CodeFlow schema definition         │
│ 3. Complete annotated example          │
│ 4. Quality guidelines                  │
│ 5. ──── Codebase context ────         │
│    a. File tree listing                │
│    b. Compressed symbol index          │
│    c. Full contents of key files       │
│    d. Dependency graph summary         │
│ 6. Output instruction                  │
└──────────────────────────────────────┘
```

### Token Budget

| Codebase Size | Source Tokens | Compressed (symbol index + key files) | Fits in |
|---------------|--------------|---------------------------------------|---------|
| Small (< 50 files) | ~25K | ~8K | Single pass, any model |
| Medium (50-200 files) | ~100K | ~20K | Single pass, 100K+ context |
| Large (200-1000 files) | ~500K | ~50K | Single pass, 200K+ context |
| Very large (1000+ files) | ~2M | ~100K+ | Chunked analysis with synthesis |

### Chunking Strategy (Large Codebases)

For codebases exceeding the model's context window:

1. Build full dependency graph (no LLM needed)
2. Topologically sort modules
3. Analyze leaf modules first (no dependencies)
4. Work up the dependency tree, each analysis referencing already-analyzed modules
5. Final synthesis pass: merge sub-analyses into a unified CodeFlow spec

### Two-Pass Analysis (Quality Improvement)

**Pass 1**: Generate the initial CodeFlow spec from the codebase context.

**Pass 2**: Send the spec back to the LLM with a validation prompt:
- "Review this spec. Are there nodes that should be merged? Missing edges? Orphan nodes?"
- "Verify: does every edge reference existing nodes? Does every node reference an existing layer?"
- Correct and return the refined spec.

---

## 9. Diagram Visualization

### Layout Algorithms

**Hybrid Sugiyama + Force-Directed** (default):

1. **Layer assignment**: Pre-defined from the spec's `layer.rank` field
2. **Crossing minimization**: Barycenter heuristic — order nodes within each layer to minimize edge crossings (sweep top-down then bottom-up, 2-4 iterations)
3. **Coordinate assignment**: Brandes-Kopf algorithm for x-coordinates
4. **Force refinement**: Run 20-50 iterations of force-directed adjustment with strong layer gravity to fine-tune spacing without breaking the hierarchical structure

This hybrid produces clean hierarchical layouts that respect layer structure while avoiding the rigid "grid" look of pure Sugiyama.

**Pure Force-Directed** (alternative):

Fruchterman-Reingold with layer gravity. Better for codebases without clear layer boundaries. Organic, non-hierarchical layout.

### Rendering Pipeline

```swift
func render(in context: inout GraphicsContext, size: CGSize) {
    // 1. Apply camera transform (pan + zoom)
    context.translateBy(x: panOffset.width, y: panOffset.height)
    context.scaleBy(x: zoom, y: zoom)

    // 2. Compute visible rect for culling
    let visibleRect = computeVisibleRect(size: size, zoom: zoom, pan: panOffset)

    // 3. Draw layer backgrounds
    drawLayerBackgrounds(in: &context, visibleRect: visibleRect)

    // 4. Draw edges (below nodes)
    drawEdges(in: &context, visibleRect: visibleRect)

    // 5. Draw nodes (above edges)
    drawNodes(in: &context, visibleRect: visibleRect)

    // 6. Draw selection highlight
    drawSelection(in: &context)
}
```

### Level-of-Detail Rendering

| Zoom Level | Render |
|-----------|--------|
| < 30% | Colored dots (no text, no borders) |
| 30% - 70% | Simplified rectangles + name only |
| 70% - 150% | Full rendering (name, description, type badge) |
| > 150% | Full rendering + method list, type details |

### Edge Styles

| Edge Type | Style |
|-----------|-------|
| calls (sync) | Solid line, filled arrowhead |
| async | Dashed line, open arrowhead |
| publishes / subscribes | Dotted line, diamond arrowhead |
| reads / writes | Solid line, half arrowhead |

### Flow Animation

When a flow is selected from the sidebar:
1. Dim all nodes and edges to 20% opacity
2. Highlight the flow's nodes and edges at full opacity
3. Animate a "pulse" along each step in sequence order
4. Steps with the same sequence number animate simultaneously (parallel steps)
5. The animation loops continuously until deselected

---

## 10. Technical Architecture

### Application Structure

```
SightglassApp (@main SwiftUI App)
├── Three-Column Layout
│   ├── SidebarView (layers, search, flows, entry points)
│   ├── DiagramView (Canvas + gestures)
│   └── DetailPanel (selected node info)
├── AppState (ObservableObject)
│   ├── spec: CodeSpec?
│   ├── nodePositions: [String: CGPoint]
│   ├── selectedNodeID: String?
│   ├── hoveredNodeID: String?
│   ├── zoomLevel: CGFloat
│   ├── panOffset: CGSize
│   └── selectedFlowID: String?
├── Sources/
│   ├── Models/
│   │   ├── CodeSpec.swift
│   │   ├── SpecNode.swift
│   │   ├── SpecEdge.swift
│   │   ├── SpecLayer.swift
│   │   └── EntryPoint.swift
│   ├── Parser/
│   │   └── SpecParser.swift (YAML → CodeSpec)
│   ├── Analysis/
│   │   ├── SpecGenerator.swift (builds prompt, calls LLM)
│   │   └── AnalysisPrompt.swift (loads prompt template)
│   └── Diagram/
│       ├── GraphLayout.swift (force-directed + Sugiyama)
│       ├── DiagramRenderer.swift (Canvas drawing)
│       ├── DiagramView.swift (gestures + interaction)
│       ├── NodeView.swift
│       └── EdgeView.swift
└── Resources/
    └── prompts/analyze-codebase.md
```

### Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Rendering | SwiftUI Canvas | Native SwiftUI, sufficient for 20-500 nodes, custom drawing with full control |
| Layout | Hybrid Sugiyama + force-directed | Respects layer structure while producing organic layouts |
| YAML parser | Yams (Swift) | Most popular Swift YAML parser, well-maintained |
| LLM integration | Direct API calls (Anthropic/OpenAI SDKs) | No framework dependency, full control over prompt construction |
| Coordinate system | Separate pan/zoom transform | Standard canvas approach, enables viewport culling |
| Persistence | YAML file on disk | Spec-as-code philosophy, version-controllable |

---

## 11. Scope & Phasing

### V1 — MVP: Analyze and Visualize

| Feature | Included |
|---------|----------|
| Load and render CodeFlow YAML specs | Yes |
| Interactive diagram (pan, zoom, click, hover) | Yes |
| Node rendering with layer colors | Yes |
| Edge rendering with Bezier curves | Yes |
| Layer backgrounds | Yes |
| Detail panel (node info, methods, types, edges) | Yes |
| Sidebar (layers, search, flows, entry points) | Yes |
| Built-in analysis prompt template | Yes |
| Export as PNG/SVG | Yes |
| Save/load .sightglass.yaml | Yes |

### V1.x — Continuous Sync

| Feature | Priority |
|---------|----------|
| Direct LLM API integration (click "Analyze") | P0 |
| Framework auto-detection (NestJS, Express, Django, etc.) | P1 |
| Incremental re-analysis (git diff-based) | P1 |
| Spec diff view (compare two specs, highlight changes) | P1 |
| Flow animation (step-by-step walkthrough) | P1 |
| Two-pass analysis with self-review | P2 |
| Node dragging (manual position adjustment) | P2 |
| Keyboard navigation (Tab through nodes, arrow keys) | P2 |
| Accessibility (VoiceOver support) | P2 |

### V2 — Diagram-to-Code

| Feature | Description |
|---------|-------------|
| Diagram editing | Add, remove, rename nodes and edges in the diagram |
| Change-to-prompt mapping | Map visual changes to natural language descriptions |
| Agent execution | Send the change prompt to a coding agent (Claude Code, Codex) |
| Verification | Re-analyze after agent changes, compare specs to verify correctness |
| Interactive refactoring | "I want to add a caching layer between Service and Repository" → agent adds the code |

### Future (Explicitly Parked)

These ideas stay parked until the desktop app ships with the one-command install path above.

| Feature | Description |
|---------|-------------|
| CI/CD integration | GitHub Action that generates/updates .sightglass.yaml on every merge |
| Multi-repo support | Unified diagram across microservice repos |
| Runtime correlation | Overlay OpenTelemetry traces on the static architecture diagram |
| Sentry integration | Show error hotspots on the diagram (which nodes have the most errors) |
| Natural language queries | "Show me how authentication flows through the system" |
| Web viewer | Browser-based read-only rendering of specs for sharing |
| Team annotations | Multiple team members annotate the same spec |
| Architecture fitness functions | Define rules ("no data layer → API layer edges") and validate in CI |

### Explicitly Not in Scope

| Exclusion | Rationale |
|-----------|-----------|
| Code editing | Sightglass visualizes architecture. Agents edit code. |
| Runtime monitoring / APM | Use Datadog, Sentry, etc. Sightglass may overlay their data in the future. |
| Windows/Linux | macOS native only. SwiftUI Canvas is Apple-only. No web viewer is on the current roadmap. |
| Full IDE replacement | Sightglass is a companion tool, not an editor. |
| Real-time collaboration | Single-user desktop app. Team features via shared spec files + CI. |

---

## 12. Success Metrics

### Adoption

| Metric | Target (6 months) | Measurement |
|--------|-------------------|-------------|
| Installs | 500 | GitHub release downloads + install script runs or Homebrew installs |
| Weekly active users | 300 | Opt-in analytics |
| GitHub stars | 1,000 | GitHub |
| Repos with .sightglass.yaml | 200 (12 months) | GitHub code search |

### Quality

| Metric | Target | Measurement |
|--------|--------|-------------|
| Time from install to first diagram | < 5 minutes | Manual testing |
| Spec generation accuracy (nodes match real modules) | > 85% | Manual evaluation on 20 test repos |
| Diagram render time (100-node spec) | < 500ms | Performance testing |
| Layout quality (subjective, no overlapping nodes) | > 90% | Manual evaluation |

### Engagement

| Metric | Target | Measurement |
|--------|--------|-------------|
| Specs re-generated (repeat usage) | > 40% of users | Analytics |
| Detail panel usage | > 50% of sessions | Analytics |
| Flow walkthrough usage | > 20% of sessions | Analytics |

---

## 13. Competitive Landscape

| Dimension | Sightglass | CodeScene | Understand | Dep. Cruiser | Structurizr | Mermaid | IDE Hierarchy |
|-----------|-----------|-----------|------------|-------------|-------------|---------|---------------|
| Auto-generated | AI-powered | Git history | Static parse | Import parse | Manual DSL | Manual text | Live parse |
| AI-powered | Yes | Partial | No | No | No | No | No |
| Interactive | Yes | Limited | Desktop | No | Web | No | Tree only |
| Architecture-level | Yes | Partial (folder) | Partial | Module only | Yes (C4) | Any (manual) | No |
| Code-level detail | Methods, types | No | Yes | No | No | Any (manual) | Yes |
| Real-time updates | Planned V1.x | On git push | On re-parse | On CLI run | Manual | Manual | Yes |
| Multi-language | Yes (AI-driven) | Yes | Yes (20+) | JS/TS only | N/A | N/A | Yes (LSP) |
| Data flow visualization | Flows + edges | No | Call graphs | Import graph | Relationships | Sequence diagrams | Call hierarchy |
| Stays in sync | Planned V1.x | On push | Manual re-run | Manual re-run | Manual | Manual | Always |
| Pricing | Freemium | $15-20/user/mo | ~$800/seat | Free OSS | Free-$5/mo | Free OSS | Free (built-in) |

### Positioning Statement

Sightglass is the only tool that combines AI-powered analysis with interactive architecture visualization. It bridges the gap between code-level static analysis tools (which are accurate but low-level) and architecture diagramming tools (which are high-level but manually authored and always stale).

---

## 14. Distribution & Monetization

### Distribution

| Channel | Method |
|---------|--------|
| Primary | Repo-hosted one-command install: `curl -fsSL https://raw.githubusercontent.com/markwolff/sightglass/main/install.sh | sh` |
| Developer channel | Homebrew once it is also a single command end to end |
| Source | GitHub (MIT license) |
| Updates | Re-run the install command or use `brew upgrade` when the Homebrew path exists |

### Technical Requirements

GitHub Releases with a stable asset shape, plus Apple Developer Program, Developer ID certificate, notarization, hardened runtime (non-sandboxed for file system access and LLM API calls), and universal binaries once the signed app path becomes the default installer.

### Pricing Model

| Tier | Price | Features |
|------|-------|----------|
| Free | $0 | Load specs, view diagrams, manual analysis (copy prompt, paste result) |
| Pro | $49/year | Direct LLM API integration (one-click analyze), spec diff, flow animation, CI/CD integration |
| Team | $99/year per seat | Web viewer for sharing, team annotations, architecture fitness functions |

---

## 15. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| AI hallucinated architecture (phantom nodes/edges) | High | High | Cross-reference spec against actual file system. Flag nodes whose `file` path doesn't exist. Two-pass analysis with self-review. |
| Inconsistent analysis results (same codebase, different specs) | Medium | High | Temperature=0, explicit chain-of-thought instructions, few-shot examples, deterministic pre-scan. |
| Large codebases exceed context window | Medium | Medium | Dependency-ordered chunking with synthesis pass. Token budget estimation before analysis. |
| macOS-only limits reach | Medium | Medium | Web-based spec viewer for sharing (V2). Spec format is platform-independent. |
| Users don't commit .sightglass.yaml | Medium | Medium | GitHub Action that auto-generates on merge. Freshness warnings in the app. |
| Competition from IDE vendors (JetBrains, VS Code adding AI architecture views) | Medium | Medium | Stay focused on the spec format as the differentiator. The spec is portable; IDE integrations would consume it. |
| Analysis prompt produces poor results for unfamiliar frameworks | Medium | Medium | Framework-specific prompt variations. Community-contributed prompt templates. |

---

## 16. Cross-Project Synergies

### The Ecosystem

```
┌──────────┐          ┌──────────┐          ┌────────────┐
│  Relay   │─analyze─→│ Sightglass│←─watch──│  Bullpen   │
│ Define & │          │ Understand│          │  Observe   │
│ Execute  │          │ & Explore │          │            │
└──────────┘          └────────────┘          └────────────┘
```

### Sightglass + Relay

A Relay pipeline can include a step that runs codebase analysis and produces a CodeFlow spec. This enables automated architecture documentation:

```yaml
name: post-merge-analysis
steps:
  - id: analyze-architecture
    type: llm
    provider: anthropic
    model: claude-sonnet-4-20250514
    system: "{{sightglass-analysis-prompt}}"
    prompt: "Analyze this codebase:\n\n{{codebase-context}}"
```

Run this pipeline in CI after every merge to main — the `.sightglass.yaml` spec stays automatically current.

### Sightglass + Bullpen

Bullpen shows what agents are currently doing (reading files, writing code). Sightglass shows the architectural result. A natural integration: clicking an agent's current file in Bullpen could highlight the corresponding node in Sightglass, connecting real-time activity to architectural context.

### Combined Value

**"Define, Observe, Understand"**:
- **Relay** defines structured agent workflows (the "how")
- **Bullpen** monitors agent execution in real time (the "what's happening now")
- **Sightglass** maps the resulting code architecture (the "what was built")

Together, they form a complete toolkit for developers who direct AI agents to build software — providing visibility and understanding at every stage of the process.
