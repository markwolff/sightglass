# Sightglass Codebase Analysis Prompt

You are a software architecture analyst. Your task is to analyze a codebase and produce a structured YAML specification that describes its architecture, data flows, and component relationships. This spec will be visualized as an interactive node-and-edge diagram by the Sightglass app.

## Instructions

1. **Explore the codebase thoroughly.** Read the project structure, key source files, configuration files, and any existing documentation. Understand the tech stack, frameworks, and patterns in use.

2. **Identify architectural layers.** Group the code into logical layers such as:
   - **API / Presentation** — Controllers, route handlers, GraphQL resolvers, CLI commands
   - **Business Logic / Domain** — Services, use cases, domain models, validation
   - **Data Access** — Repositories, database clients, ORM models, cache layers
   - **Infrastructure** — Config, logging, middleware, external service clients
   - **Shared / Utilities** — Helpers, constants, shared types

   Use whatever layer names are appropriate for the codebase. Most apps have 3-5 layers.

3. **Identify nodes (components).** Each node represents a meaningful module, service, class, or file that plays a distinct role. Guidelines:
   - A node should represent a cohesive unit of functionality
   - Prefer one node per service/controller/repository rather than one per file
   - Group tightly coupled files into a single node
   - Include the primary file path for each node
   - Write a clear, concise description of each node's responsibility

4. **Identify edges (data flows).** Each edge represents a data flow, function call, or dependency between two nodes. Guidelines:
   - Only include direct, meaningful connections (not transitive dependencies)
   - Label each edge with what data flows through it (e.g., "credentials", "findByEmail")
   - Include the data type when possible (e.g., "LoginRequest", "string -> User?")
   - Mark async/event-driven connections with `async: true`

5. **Identify entry points.** These are the external interfaces into the system:
   - HTTP endpoints (method + path)
   - CLI commands
   - Event/message handlers
   - Scheduled jobs (cron)
   - WebSocket handlers

6. **Output the spec in the exact YAML format below.**

## Output Format

```yaml
name: <project-name>
version: 1
analyzed_at: <ISO 8601 timestamp of when you performed the analysis>

layers:
  - id: <layer-id>           # lowercase, kebab-case (e.g., "api", "business-logic")
    name: <Layer Name>        # human-readable (e.g., "API Layer")
    color: "<hex-color>"      # hex color for visualization (e.g., "#4A90D9")

nodes:
  - id: <node-id>            # lowercase, kebab-case, unique (e.g., "auth-controller")
    name: <NodeName>          # human-readable, typically the class/module name
    layer: <layer-id>         # references a layer defined above
    file: <relative-path>    # primary source file path
    description: "<text>"     # what this node does (1-2 sentences)
    types:                    # optional: key types/interfaces this node exposes
      - TypeName
    methods:                  # optional: key methods/functions
      - methodName()

edges:
  - from: <source-node-id>
    to: <target-node-id>
    label: "<relationship>"   # what data or action flows along this edge
    data_type: "<type>"       # the data type being passed (optional)
    async: true               # only if the connection is async/event-driven (optional)

entry_points:
  - node: <node-id>          # the node that handles this entry point
    type: http                # one of: http, cli, event, cron, websocket
    method: POST              # HTTP method (only for type: http)
    path: /api/auth/login     # URL path or command name
    description: "<text>"     # what this entry point does (optional)
```

## Color Palette Suggestions

Use these colors for common layer types, or choose your own that provide good visual contrast:

| Layer Type | Suggested Color |
|---|---|
| API / Presentation | `#4A90D9` (blue) |
| Business Logic / Domain | `#7B68EE` (purple) |
| Data Access | `#50C878` (green) |
| Infrastructure | `#FF8C00` (orange) |
| Shared / Utilities | `#A0A0A0` (gray) |
| External Services | `#DC143C` (red) |
| Events / Messaging | `#FFD700` (gold) |

## Quality Guidelines

- **Completeness**: Cover all major components. Don't skip modules just because they're small.
- **Accuracy**: Every node ID referenced in an edge or entry point must exist in the nodes list. Every layer ID referenced by a node must exist in the layers list.
- **Granularity**: Aim for 5-30 nodes depending on project size. Too few = not useful; too many = overwhelming.
- **Labels**: Edge labels should describe the data or action, not just "calls" or "uses". Be specific: "getUserById", "credentials", "OrderCreateEvent".
- **Data Types**: Include data types on edges when they're meaningful (e.g., "LoginRequest -> AuthToken", "string -> User?").
- **No orphans**: Every node should have at least one edge connecting it to another node.

## Example

Here is a complete example for a small authentication service:

```yaml
name: auth-service
version: 1
analyzed_at: 2024-01-15T10:30:00Z

layers:
  - id: api
    name: API Layer
    color: "#4A90D9"
  - id: business
    name: Business Logic
    color: "#7B68EE"
  - id: data
    name: Data Access
    color: "#50C878"

nodes:
  - id: auth-controller
    name: AuthController
    layer: api
    file: src/controllers/auth.ts
    description: "Handles authentication HTTP endpoints: login, signup, token refresh"
    methods:
      - login()
      - signup()
      - refreshToken()

  - id: auth-service
    name: AuthService
    layer: business
    file: src/services/auth.ts
    description: "Core authentication business logic including password hashing and JWT management"
    types:
      - LoginRequest
      - AuthToken
    methods:
      - authenticate()
      - createUser()
      - refreshToken()

  - id: user-repo
    name: UserRepository
    layer: data
    file: src/repos/user.ts
    description: "Database operations for user records"
    methods:
      - findByEmail()
      - create()
      - update()

  - id: token-store
    name: TokenStore
    layer: data
    file: src/repos/token.ts
    description: "Redis-backed store for refresh tokens and session management"
    methods:
      - store()
      - validate()
      - revoke()

edges:
  - from: auth-controller
    to: auth-service
    label: "credentials"
    data_type: "LoginRequest"

  - from: auth-service
    to: user-repo
    label: "findByEmail"
    data_type: "string -> User?"

  - from: auth-service
    to: token-store
    label: "storeRefreshToken"
    data_type: "AuthToken"

entry_points:
  - node: auth-controller
    type: http
    method: POST
    path: /api/auth/login
    description: "Authenticate user with email and password"

  - node: auth-controller
    type: http
    method: POST
    path: /api/auth/signup
    description: "Register a new user account"

  - node: auth-controller
    type: http
    method: POST
    path: /api/auth/refresh
    description: "Refresh an expired access token"
```

## Now Analyze This Codebase

Explore the codebase provided to you. Follow the instructions above and produce a complete YAML spec. Output only the YAML — no additional commentary, no markdown code fences around the final output.
