# Clubhouse Annex — Swift Client Specification

> API version: `1`
> Protocol: HTTP + WebSocket over LAN
> Transport: plaintext HTTP (no TLS) on an OS-assigned port

---

## Table of Contents

1. [Discovery](#1-discovery)
2. [Authentication](#2-authentication)
3. [REST API](#3-rest-api)
4. [WebSocket](#4-websocket)
5. [Data Models](#5-data-models)
6. [Agent Colors](#6-agent-colors)
7. [Error Handling](#7-error-handling)
8. [Lifecycle Notes](#8-lifecycle-notes)

---

## 1. Discovery

The Annex server advertises itself via **mDNS / Bonjour**.

| Field | Value |
|-------|-------|
| Service type | `_clubhouse-annex._tcp` |
| TXT record | `v=1` |
| Service name | User-configured device name (e.g. `"Clubhouse on Mason's Mac"`) |

Browse for the service type to obtain the host and port. The `v` TXT key indicates the API version — only connect if `v == "1"`.

```swift
let browser = NWBrowser(for: .bonjour(type: "_clubhouse-annex._tcp", domain: nil), using: .tcp)
```

---

## 2. Authentication

### 2.1 Pairing

The user is shown a 6-digit PIN in the Clubhouse desktop app. The client sends this PIN to obtain a session token.

**`POST /pair`** — no authentication required

Request:
```json
{ "pin": "041379" }
```

Success `200`:
```json
{ "token": "550e8400-e29b-41d4-a716-446655440000" }
```

Failure `401`:
```json
{ "error": "invalid_pin" }
```

Malformed body `400`:
```json
{ "error": "invalid_json" }
```

### 2.2 Using the Token

**HTTP requests** — send as a Bearer token:
```
Authorization: Bearer <token>
```

**WebSocket** — pass as a query parameter:
```
ws://<host>:<port>/ws?token=<token>
```

### 2.3 Token Invalidation

Tokens are session-only (not persisted server-side). All tokens are revoked when:
- The user regenerates the PIN in the desktop app
- The Annex server restarts

When a token is revoked, the server closes all WebSocket connections. The client should detect this and return to the pairing flow.

---

## 3. REST API

Base URL: `http://<host>:<port>`

All endpoints (except `/pair`) require `Authorization: Bearer <token>`. An invalid or missing token returns:

```json
HTTP 401
{ "error": "unauthorized" }
```

CORS headers are present on all responses (`Access-Control-Allow-Origin: *`) but are not relevant to a native client.

---

### 3.1 `GET /api/v1/status`

Server metadata and summary counts.

Response `200`:
```json
{
  "version": "1",
  "deviceName": "Clubhouse on Mason's Mac",
  "agentCount": 5,
  "orchestratorCount": 1
}
```

| Field | Type | Description |
|-------|------|-------------|
| `version` | `String` | API version, always `"1"` |
| `deviceName` | `String` | User-configured device name |
| `agentCount` | `Int` | Total durable agents across all projects |
| `orchestratorCount` | `Int` | Number of registered orchestrators |

---

### 3.2 `GET /api/v1/projects`

List all projects.

Response `200`: `[Project]`

```json
[
  {
    "id": "proj_abc123",
    "name": "my-app",
    "path": "/Users/mason/source/my-app",
    "color": "emerald",
    "icon": "rocket.png",
    "displayName": "My App",
    "orchestrator": "claude-code"
  }
]
```

See [Project](#52-project) model.

---

### 3.3 `GET /api/v1/projects/{projectId}/agents`

List durable agents for a project.

Response `200`: `[DurableAgent]`

```json
[
  {
    "id": "durable_1737000000000_abc123",
    "name": "faithful-urchin",
    "kind": "durable",
    "color": "emerald",
    "branch": "faithful-urchin/standby",
    "model": "claude-opus-4-5",
    "orchestrator": "claude-code",
    "freeAgentMode": false,
    "icon": null
  }
]
```

Project not found `404`:
```json
{ "error": "project_not_found" }
```

See [DurableAgent](#53-durableagent) model.

---

### 3.4 `GET /api/v1/agents/{agentId}/buffer`

Fetch the accumulated PTY (terminal) output for an agent.

Response `200`:
```
Content-Type: text/plain; charset=utf-8

<raw terminal output>
```

The body is **plain UTF-8 text** containing the full terminal buffer. It may include ANSI escape sequences.

---

## 4. WebSocket

### 4.1 Connection

```
ws://<host>:<port>/ws?token=<token>
```

- Token is validated during the HTTP upgrade handshake.
- Invalid token → `401 Unauthorized`, connection destroyed.
- On successful connection the server immediately sends a `snapshot` message.

### 4.2 Message Envelope

All WebSocket messages are JSON with this shape:

```json
{
  "type": "<message_type>",
  "payload": { ... }
}
```

### 4.3 Message Types

#### `snapshot`

Sent once, immediately after connection. Contains the full current state.

```json
{
  "type": "snapshot",
  "payload": {
    "projects": [Project],
    "agents": {
      "<projectId>": [DurableAgent],
      "<projectId>": [DurableAgent]
    },
    "theme": ThemeColors,
    "orchestrators": {
      "<orchestratorId>": {
        "displayName": "Claude Code",
        "shortName": "CC",
        "badge": null
      }
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `projects` | `[Project]` | All registered projects |
| `agents` | `{String: [DurableAgent]}` | Agents keyed by project ID |
| `theme` | `ThemeColors` | Current desktop theme colors |
| `orchestrators` | `{String: OrchestratorEntry}` | Orchestrator display info keyed by ID |

---

#### `pty:data`

Streaming terminal output from an agent.

```json
{
  "type": "pty:data",
  "payload": {
    "agentId": "durable_1737000000000_abc123",
    "data": "Building project...\n"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `agentId` | `String` | The agent producing output |
| `data` | `String` | Raw terminal output chunk (may contain ANSI escapes) |

---

#### `hook:event`

Agent lifecycle / tool execution events. Use these to show real-time activity indicators.

```json
{
  "type": "hook:event",
  "payload": {
    "agentId": "durable_1737000000000_abc123",
    "event": {
      "kind": "pre_tool",
      "toolName": "EditFile",
      "toolInput": { "path": "/src/main.ts" },
      "message": null,
      "toolVerb": "Editing file",
      "timestamp": 1737000000000
    }
  }
}
```

See [AgentHookEvent](#55-agenthookevent) model.

---

#### `pty:exit`

Agent process terminated.

```json
{
  "type": "pty:exit",
  "payload": {
    "agentId": "durable_1737000000000_abc123",
    "exitCode": 0
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `agentId` | `String` | The agent that exited |
| `exitCode` | `Int` | Process exit code (`0` = success) |

---

#### `theme:changed`

Broadcast when the user changes the desktop theme. Update your UI colors accordingly.

```json
{
  "type": "theme:changed",
  "payload": {
    "base": "#1e1e2e",
    "mantle": "#181825",
    "crust": "#11111b",
    "text": "#cdd6f4",
    "subtext0": "#a6adc8",
    "subtext1": "#bac2de",
    "surface0": "#313244",
    "surface1": "#45475a",
    "surface2": "#585b70",
    "accent": "#89b4fa",
    "link": "#89b4fa"
  }
}
```

See [ThemeColors](#54-themecolors) model.

---

## 5. Data Models

### 5.1 PairResponse

```swift
struct PairResponse: Decodable {
    let token: String
}
```

### 5.2 Project

```swift
struct Project: Decodable, Identifiable {
    let id: String
    let name: String
    let path: String
    let color: String?          // AgentColorId, e.g. "emerald"
    let icon: String?           // Filename from ~/.clubhouse/project-icons/
    let displayName: String?    // User-set override for `name`
    let orchestrator: String?   // e.g. "claude-code"
}
```

### 5.3 DurableAgent

```swift
struct DurableAgent: Decodable, Identifiable {
    let id: String              // e.g. "durable_1737000000000_abc123"
    let name: String            // e.g. "faithful-urchin"
    let kind: String            // Always "durable"
    let color: String           // AgentColorId
    let branch: String          // Git branch
    let model: String           // e.g. "claude-opus-4-5"
    let orchestrator: String?   // e.g. "claude-code"
    let freeAgentMode: Bool     // True = agent runs without guardrails
    let icon: String?           // Filename from ~/.clubhouse/agent-icons/
}
```

### 5.4 ThemeColors

```swift
struct ThemeColors: Decodable {
    let base: String            // Primary background
    let mantle: String          // Slightly darker background
    let crust: String           // Darkest background
    let text: String            // Primary text
    let subtext0: String        // Muted text
    let subtext1: String        // Secondary text
    let surface0: String        // Elevated surface
    let surface1: String        // Higher surface
    let surface2: String        // Highest surface
    let accent: String          // Accent / brand color
    let link: String            // Link color
}
```

All values are CSS hex strings (e.g. `"#1e1e2e"`). Convert with:
```swift
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
```

### 5.5 AgentHookEvent

```swift
struct AgentHookEvent: Decodable {
    let kind: HookEventKind
    let toolName: String?
    let toolInput: [String: AnyCodable]?  // Arbitrary JSON
    let message: String?
    let toolVerb: String?       // Human-readable, e.g. "Editing file"
    let timestamp: Int64        // Unix epoch milliseconds
}

enum HookEventKind: String, Decodable {
    case preTool = "pre_tool"
    case postTool = "post_tool"
    case toolError = "tool_error"
    case stop = "stop"
    case notification = "notification"
    case permissionRequest = "permission_request"
}
```

### 5.6 OrchestratorEntry

```swift
struct OrchestratorEntry: Decodable {
    let displayName: String     // "Claude Code"
    let shortName: String       // "CC"
    let badge: String?          // Optional badge identifier
}
```

### 5.7 StatusResponse

```swift
struct StatusResponse: Decodable {
    let version: String
    let deviceName: String
    let agentCount: Int
    let orchestratorCount: Int
}
```

### 5.8 WebSocket Message Envelope

```swift
struct WSMessage: Decodable {
    let type: String
    let payload: JSON  // Use a flexible JSON type for dispatch
}
```

### 5.9 Snapshot Payload

```swift
struct SnapshotPayload: Decodable {
    let projects: [Project]
    let agents: [String: [DurableAgent]]  // Keyed by project ID
    let theme: ThemeColors
    let orchestrators: [String: OrchestratorEntry]
}
```

### 5.10 PTY Data Payload

```swift
struct PtyDataPayload: Decodable {
    let agentId: String
    let data: String
}
```

### 5.11 PTY Exit Payload

```swift
struct PtyExitPayload: Decodable {
    let agentId: String
    let exitCode: Int
}
```

### 5.12 Hook Event Payload

```swift
struct HookEventPayload: Decodable {
    let agentId: String
    let event: AgentHookEvent
}
```

### 5.13 Error Response

```swift
struct ErrorResponse: Decodable {
    let error: String
}
```

---

## 6. Agent Colors

Agents and projects reference a color by ID. Map to hex values for rendering:

| ID | Label | Hex |
|----|-------|-----|
| `indigo` | Indigo | `#6366f1` |
| `emerald` | Emerald | `#10b981` |
| `amber` | Amber | `#f59e0b` |
| `rose` | Rose | `#f43f5e` |
| `cyan` | Cyan | `#06b6d4` |
| `violet` | Violet | `#8b5cf6` |
| `orange` | Orange | `#f97316` |
| `teal` | Teal | `#14b8a6` |

```swift
enum AgentColor: String, CaseIterable {
    case indigo, emerald, amber, rose, cyan, violet, orange, teal

    var hex: String {
        switch self {
        case .indigo:  return "#6366f1"
        case .emerald: return "#10b981"
        case .amber:   return "#f59e0b"
        case .rose:    return "#f43f5e"
        case .cyan:    return "#06b6d4"
        case .violet:  return "#8b5cf6"
        case .orange:  return "#f97316"
        case .teal:    return "#14b8a6"
        }
    }
}
```

---

## 7. Error Handling

### HTTP Error Codes

| Code | Meaning | When |
|------|---------|------|
| `400` | Bad Request | Malformed JSON in request body |
| `401` | Unauthorized | Invalid PIN (on `/pair`) or invalid/missing token |
| `404` | Not Found | Unknown route or project not found |

All error responses share the shape:
```json
{ "error": "<error_code>" }
```

Known error codes: `invalid_pin`, `invalid_json`, `unauthorized`, `project_not_found`, `not_found`.

### WebSocket Disconnection

The server will close all WebSocket connections when:
- The PIN is regenerated (all tokens invalidated)
- The Annex server is stopped by the user

On unexpected close, implement reconnection with exponential backoff. If reconnection fails with 401, return to the pairing screen.

---

## 8. Lifecycle Notes

### Recommended Client Flow

```
1. Browse mDNS for _clubhouse-annex._tcp
2. Show discovered servers (by service name)
3. User selects server → prompt for PIN
4. POST /pair with PIN → store token in Keychain
5. GET /api/v1/status → verify connection, show device info
6. Connect WebSocket → receive snapshot → populate UI
7. Process streaming pty:data, hook:event, pty:exit, theme:changed
8. On WS disconnect → attempt reconnect → if 401, re-pair
```

### Terminal Buffer vs. Streaming

- `GET /api/v1/agents/{id}/buffer` returns the **full accumulated** terminal output (useful for initial load or reconnection).
- `pty:data` WebSocket messages provide **incremental** chunks in real-time.

On initial load or reconnection, fetch the buffer first, then append incoming `pty:data` messages.

### ANSI Escape Handling

Terminal output (`buffer` endpoint and `pty:data` messages) contains raw ANSI escape sequences. Use a terminal emulator view or strip escapes for plain-text display.

### Theme Synchronization

The `theme` in the snapshot and `theme:changed` events provide hex colors for the desktop's current theme. The client can adopt these colors for a cohesive look, or ignore them and use its own design system.

### Agent Icons / Project Icons

The `icon` fields on agents and projects reference filenames stored on the server filesystem (`~/.clubhouse/agent-icons/` and `~/.clubhouse/project-icons/`). There is currently **no HTTP endpoint to fetch these images**. Use the agent's `color` for visual identification instead.
