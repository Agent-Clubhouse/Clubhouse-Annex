# Contract Improvements — Annex Client & Server

Discrepancies and feature requests for the Annex API, discovered during integration and ongoing development. Incorporates feedback from both the Annex client developer and the Clubhouse server developer.

---

## Existing Issues

### 1. Many `DurableAgent` fields not always present

- **Spec says**: `name`, `kind`, `color`, `branch`, `model`, `freeAgentMode` are required fields (§5.3)
- **Server sends**: Agents in the snapshot `payload.agents` frequently omit these fields
- **Observed missing**: `model`, `branch`, `freeAgentMode`, potentially others
- **Workaround**: Made all non-`id` fields optional in client model

**Agreed resolution**:
- Server will provide explicit `null` for missing optional fields rather than omitting keys
- `freeAgentMode` will default to `false` when not set
- **Addition**: Server will include `status` in snapshot agent entries so the client knows agent state (running/sleeping/error) on initial connect — currently the snapshot only sends config data, not runtime state

### 2. Agent/project `icon` field references local filesystem paths

- **Spec says**: Agents and projects have an optional `icon: String?` field
- **Server sends**: The `icon` value (when present) is a local filesystem path
- **Impact**: Mobile clients cannot fetch these icons
- **Workaround**: Client renders generated initials as avatars

**Agreed resolution**:
- Server will add `GET /api/v1/icons/agent/{agentId}` and `GET /api/v1/icons/project/{projectId}` endpoints (preferred over inline base64 to avoid snapshot bloat)
- Server already has `readAgentIconData()` and `readIconData()` utilities that return base64 data URLs — just needs HTTP serving
- **Addition**: Include `iconHash` field on agents and projects in the snapshot so the client can cache icons and only re-fetch when the hash changes

### 3. `detailedStatus` not always populated in snapshot

- **Spec says**: `detailedStatus` provides `state`, `message`, `toolName`, `timestamp` for running agents
- **Server sends**: `detailedStatus` is frequently `null` even for `status: "running"` agents
- **Impact**: Client cannot determine `working` vs `needsPermission` vs `toolError` state
- **Priority**: **High** — prerequisite for permission approval (#4) and event replay (#8)

**Agreed resolution**:
- Server will maintain a `detailedStatus` cache per agent, updated as hook events flow through the event bus
- Cache will be included in snapshot agent entries
- 30-second staleness threshold applies (matches renderer behavior) — except `needs_permission` which persists until resolved
- Client should mirror the staleness logic to avoid showing stale activity text

### 4. Bidirectional permission approval from Annex

- **Current behavior**: `hook:event` with `kind: "permission_request"` is fire-and-forget — clients can observe but not respond
- **Impact**: Annex can see permission requests but cannot approve/deny remotely

**Important correction**: Hook timeout is 5 seconds (not 600s as originally proposed). This changes the architecture significantly.

**Agreed approach — PTY injection** (simpler alternative to hook-blocking):
- Instead of blocking the hook script while waiting for a remote response, the hook always returns `"ask"` (defer to Claude Code's built-in prompt)
- The Annex server injects keystrokes into the agent's PTY (`y\n` or `n\n`) when the user responds from the iOS app
- Avoids the complexity of blocking hooks, pending-request queues, and long-poll

**Server needs**:
- `permission:request` WebSocket message with `requestId`, agent name, tool name, tool input summary, and timeout deadline
- `POST /api/v1/agents/{agentId}/pty-input` endpoint for injecting keystrokes (or a WebSocket client→server message)
- `permission:expired` WebSocket message for when the prompt times out before the user responds

**Client needs** (Annex iOS):
- Actionable push notification / in-app approval UI with Allow and Deny buttons
- Send keystroke injection on user decision

**Open question**: Exact timeout value — 120 seconds suggested as a reasonable balance for the built-in Claude Code prompt.

### 5. Bonjour-resolved host includes interface scope ID

- **Status**: Resolved — client-side fix (strip `%` suffix from resolved addresses)
- **Note**: Apple/NWConnection behavior, not a server bug

---

## New Features

### 6. Spawn quick agents from Annex

Allow the iOS client to spawn quick agents on the server. Quick agents are short-lived, single-task agents that run a prompt and exit. They can run standalone within a project or as children of a durable agent.

#### `POST /api/v1/projects/{projectId}/agents/quick`

Spawn a standalone quick agent in a project.

Request:
```json
{
  "prompt": "Fix the failing unit tests in src/auth/",
  "orchestrator": "claude-code",
  "model": "claude-sonnet-4-5",
  "freeAgentMode": false,
  "systemPrompt": null
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `prompt` | `String` | **Yes** | The task/instruction for the agent |
| `orchestrator` | `String` | No | Orchestrator ID; defaults to project's orchestrator |
| `model` | `String` | No | Model ID; defaults to orchestrator's default model |
| `freeAgentMode` | `Bool` | No | Skip permission prompts; defaults to `false` |
| `systemPrompt` | `String` | No | Custom system prompt; defaults to orchestrator's default |

Success `201`:
```json
{
  "id": "quick_1737000100000_xyz789",
  "name": "quick-agent-3",
  "kind": "quick",
  "status": "starting",
  "prompt": "Fix the failing unit tests in src/auth/",
  "model": "claude-sonnet-4-5",
  "orchestrator": "claude-code",
  "freeAgentMode": false,
  "parentAgentId": null,
  "projectId": "proj_abc123"
}
```

Errors:
- `404` — `{ "error": "project_not_found" }`
- `400` — `{ "error": "missing_prompt" }`
- `400` — `{ "error": "invalid_orchestrator" }`

#### `POST /api/v1/agents/{agentId}/agents/quick`

Spawn a quick agent as a child of a durable agent. Inherits the parent's project, working directory, orchestrator, and `quickAgentDefaults.systemPrompt` from the parent's config.

Request:
```json
{
  "prompt": "Write tests for the new UserService class",
  "model": "claude-haiku-4-5",
  "freeAgentMode": false,
  "systemPrompt": null
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `prompt` | `String` | **Yes** | The task/instruction for the agent |
| `orchestrator` | `String` | No | Defaults to parent agent's orchestrator |
| `model` | `String` | No | Defaults to parent agent's model |
| `freeAgentMode` | `Bool` | No | Defaults to parent agent's `freeAgentMode` |
| `systemPrompt` | `String` | No | Defaults to parent's `quickAgentDefaults.systemPrompt` if set |

Success `201`:
```json
{
  "id": "quick_1737000200000_abc999",
  "name": "quick-agent-4",
  "kind": "quick",
  "status": "starting",
  "prompt": "Write tests for the new UserService class",
  "model": "claude-haiku-4-5",
  "orchestrator": "claude-code",
  "freeAgentMode": false,
  "parentAgentId": "durable_1737000000000_abc123",
  "projectId": "proj_abc123"
}
```

Errors:
- `404` — `{ "error": "agent_not_found" }`
- `400` — `{ "error": "missing_prompt" }`

#### `POST /api/v1/agents/{agentId}/cancel`

Cancel a running quick agent.

Success `200`:
```json
{
  "id": "quick_1737000200000_abc999",
  "status": "cancelled"
}
```

Errors:
- `404` — `{ "error": "agent_not_found" }`
- `409` — `{ "error": "agent_not_running" }`

#### WebSocket: `agent:spawned`

Broadcast when a quick agent is created (from Annex or desktop).

```json
{
  "type": "agent:spawned",
  "payload": {
    "id": "quick_1737000200000_abc999",
    "kind": "quick",
    "status": "starting",
    "prompt": "Write tests for the new UserService class",
    "model": "claude-haiku-4-5",
    "orchestrator": "claude-code",
    "freeAgentMode": false,
    "parentAgentId": "durable_1737000000000_abc123",
    "projectId": "proj_abc123"
  }
}
```

#### WebSocket: `agent:status`

Broadcast on status transitions for quick agents (`starting` → `running` → `completed`/`failed`/`cancelled`).

```json
{
  "type": "agent:status",
  "payload": {
    "id": "quick_1737000200000_abc999",
    "kind": "quick",
    "status": "running",
    "projectId": "proj_abc123",
    "parentAgentId": "durable_1737000000000_abc123"
  }
}
```

#### WebSocket: `agent:completed`

Broadcast when a quick agent finishes. Supplements `pty:exit` with semantic completion data — `pty:exit` indicates process termination, `agent:completed` provides the summary. Durable agents only receive `pty:exit`.

```json
{
  "type": "agent:completed",
  "payload": {
    "id": "quick_1737000200000_abc999",
    "kind": "quick",
    "status": "completed",
    "exitCode": 0,
    "projectId": "proj_abc123",
    "parentAgentId": "durable_1737000000000_abc123",
    "summary": "Added 12 unit tests for UserService covering create, update, delete, and auth flows.",
    "filesModified": ["src/services/__tests__/UserService.test.ts"],
    "durationMs": 45200,
    "costUsd": 0.12,
    "toolsUsed": ["Read", "Write", "Bash"]
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `summary` | `String?` | Agent-generated summary of what it did |
| `filesModified` | `[String]?` | List of files created or modified |
| `durationMs` | `Int?` | Wall-clock duration of the agent run |
| `costUsd` | `Float?` | Estimated API cost |
| `toolsUsed` | `[String]?` | Distinct tool names used during the run |

#### Quick agents in the snapshot

Add a top-level `quickAgents` key to the snapshot payload, keyed by project ID:

```json
{
  "type": "snapshot",
  "payload": {
    "projects": [ ... ],
    "agents": { ... },
    "quickAgents": {
      "proj_abc123": [
        {
          "id": "quick_1737000100000_xyz789",
          "kind": "quick",
          "status": "running",
          "prompt": "Fix the failing unit tests",
          "model": "claude-sonnet-4-5",
          "orchestrator": "claude-code",
          "freeAgentMode": false,
          "parentAgentId": null,
          "projectId": "proj_abc123"
        }
      ]
    },
    "theme": { ... },
    "orchestrators": { ... }
  }
}
```

#### Client model

```swift
struct QuickAgent: Decodable, Identifiable {
    let id: String
    let name: String?
    let kind: String              // Always "quick"
    let status: String            // "starting", "running", "completed", "failed", "cancelled"
    let prompt: String
    let model: String?
    let orchestrator: String?
    let freeAgentMode: Bool?
    let parentAgentId: String?    // Non-nil when spawned under a durable agent
    let projectId: String
    let detailedStatus: DetailedStatus?
    // Populated on completion:
    let summary: String?
    let filesModified: [String]?
    let durationMs: Int?
    let costUsd: Double?
    let toolsUsed: [String]?
}
```

---

### 7. Wake sleeping agents with a message from Annex

Allow the iOS client to send a message to a sleeping (idle/standby) durable agent, starting it on the main app.

#### `POST /api/v1/agents/{agentId}/wake`

Wake a sleeping durable agent by sending it a prompt.

Request:
```json
{
  "message": "Rebase your branch on latest main and fix any conflicts",
  "model": "claude-sonnet-4-5"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `message` | `String` | **Yes** | The prompt/instruction to start the agent with |
| `model` | `String` | No | Override the agent's default model for this run |

Success `200` — returns the full updated agent object:
```json
{
  "id": "durable_1737000000000_abc123",
  "name": "faithful-urchin",
  "kind": "durable",
  "color": "emerald",
  "status": "starting",
  "branch": "faithful-urchin/standby",
  "model": "claude-sonnet-4-5",
  "orchestrator": "claude-code",
  "freeAgentMode": false,
  "icon": null,
  "detailedStatus": null
}
```

Errors:
- `404` — `{ "error": "agent_not_found" }`
- `409` — `{ "error": "agent_already_running" }`
- `400` — `{ "error": "missing_message" }`

**Note**: If the agent's worktree or branch is in a bad state (e.g., merge conflict), the wake will still succeed — the agent handles that situation itself.

#### WebSocket: `agent:woken`

Broadcast when a sleeping agent is woken (from Annex or desktop).

```json
{
  "type": "agent:woken",
  "payload": {
    "agentId": "durable_1737000000000_abc123",
    "message": "Rebase your branch on latest main and fix any conflicts",
    "source": "annex"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `agentId` | `String` | The agent that was woken |
| `message` | `String` | The prompt sent to the agent |
| `source` | `String` | `"annex"` or `"desktop"` — where the wake originated |

After waking, the agent follows the normal lifecycle: `pty:data` for terminal output, `hook:event` for tool activity, `pty:exit` on completion.

#### `POST /api/v1/agents/{agentId}/message`

Send a message to an **already-running** durable agent (injects into PTY stdin). Companion to wake — wake starts a stopped agent, message talks to a running one.

Request:
```json
{
  "message": "Also update the README when you're done"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `message` | `String` | **Yes** | Text to inject into the agent's PTY stdin (appends `\n`) |

Success `200`:
```json
{
  "id": "durable_1737000000000_abc123",
  "status": "running",
  "delivered": true
}
```

Errors:
- `404` — `{ "error": "agent_not_found" }`
- `409` — `{ "error": "agent_not_running" }`

---

### 8. Event replay buffer for reconnection

Server-proposed feature. The Annex iOS app may disconnect (backgrounded, network switch, app killed) and miss events. When it reconnects, it only gets a fresh snapshot with no history.

#### Server implementation

- Maintain a time-bounded ring buffer of all WebSocket events per agent in memory
- Each event gets a `seq` (monotonic sequence number) field added to its payload
- The snapshot includes a `lastSeq` field indicating the current sequence position
- Clear an agent's buffer when it goes to sleep or is removed

**Buffer limits**:
- Max 1 hour of events per agent
- Max 10,000 events per agent (whichever limit is hit first)

#### Reconnection flow

1. Client connects, receives snapshot with `lastSeq: 1234`
2. Client stores `lastSeq` locally
3. Client disconnects (backgrounded, etc.)
4. Client reconnects, receives new snapshot with `lastSeq: 1290`
5. Client sends `{ "type": "replay", "since": 1234 }` over WebSocket
6. Server sends buffered events 1235–1290 in order
7. Client processes them to rebuild missed state

#### WebSocket messages

Client → Server:
```json
{ "type": "replay", "since": 1234 }
```

Server → Client (start):
```json
{ "type": "replay:start", "fromSeq": 1235, "toSeq": 1290, "count": 56 }
```

Server → Client (individual events replayed in order, then):
```json
{ "type": "replay:end" }
```

If the client's `since` is older than the buffer:
```json
{ "type": "replay:gap", "oldestAvailable": 500 }
```

On `replay:gap`, the client should treat the snapshot as authoritative and do a full buffer re-fetch (`GET /api/v1/agents/{id}/buffer`) rather than trying to partially reconcile.

**Note**: This is the first client→server WebSocket message type, making the connection bidirectional.

---

## Summary

| # | Area | What | Priority |
|---|------|------|----------|
| 1 | Data | `DurableAgent` fields missing + add `status` to snapshot | Medium |
| 2 | Data | Icon HTTP endpoints + `iconHash` for caching | Low |
| 3 | Data | `detailedStatus` server-side cache with staleness | **High** |
| 4 | Feature | Permission approval via PTY injection | High |
| 5 | Client | Bonjour scope ID | Resolved |
| 6 | Feature | Spawn quick agents + `systemPrompt` + cancel + rich completion data | High |
| 7 | Feature | Wake sleeping agents + model override + message running agents | High |
| 8 | Feature | Event replay buffer with sequence numbers | Medium |
