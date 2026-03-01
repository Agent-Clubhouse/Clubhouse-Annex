# Clubhouse Annex iOS Client — Comprehensive Audit

> Audited: 2026-03-01
> Auditor: bold-gazelle
> Spec refs: ANNEX_CLIENT_SPEC.md (§1–§8), CONTRACT_IMPROVEMENTS.md (#1–#8)

---

## Table of Contents

1. [Networking Layer](#1-networking-layer)
2. [Data Models](#2-data-models)
3. [State Management](#3-state-management)
4. [Views](#4-views)
5. [Spec Divergences](#5-spec-divergences)
6. [Contract Improvements Coverage](#6-contract-improvements-coverage)
7. [Client Assumptions About Server Behavior](#7-client-assumptions-about-server-behavior)
8. [TODOs, Stubs, and Workarounds](#8-todos-stubs-and-workarounds)
9. [Test Coverage](#9-test-coverage)
10. [Recommendations](#10-recommendations)

---

## 1. Networking Layer

### 1.1 AnnexAPIClient (`Networking/AnnexAPIClient.swift`)

**Implemented endpoints:**

| Endpoint | Spec Ref | Status |
|----------|----------|--------|
| `POST /pair` | §2.1 | Implemented |
| `GET /api/v1/status` | §3.1 | Implemented |
| `GET /api/v1/projects` | §3.2 | Implemented |
| `GET /api/v1/projects/{projectId}/agents` | §3.3 | Implemented |
| `GET /api/v1/agents/{agentId}/buffer` | §3.4 | Implemented |
| `POST /api/v1/projects/{projectId}/agents/quick` | CI#6 | Implemented |
| `POST /api/v1/agents/{agentId}/agents/quick` | CI#6 | Implemented |
| `POST /api/v1/agents/{agentId}/cancel` | CI#6 | Implemented |
| `POST /api/v1/agents/{agentId}/wake` | CI#7 | Implemented |
| `POST /api/v1/agents/{agentId}/message` | CI#7 | Implemented |
| `POST /api/v1/agents/{agentId}/permission-response` | CI#4 | Implemented |
| `GET /api/v1/icons/agent/{agentId}` | CI#2 | Implemented |
| `GET /api/v1/icons/project/{projectId}` | CI#2 | Implemented |

**Error handling:**
- All HTTP error codes from spec §7 handled: 400, 401, 404
- 409 Conflict also handled (for `agent_already_running`, `agent_not_running`)
- Error codes mapped to `APIError` enum with user-facing messages
- `invalid_pin` correctly distinguished from generic `unauthorized` on 401
- Handles `200` and `201` for success (correct for spawn endpoint)

**Observations:**
- Class is `Sendable` (good for concurrency safety)
- IPv6 address handling includes `%` → `%25` percent-encoding for scope IDs (CI#5 resolution)
- Icon fetch methods return `Data?` (nil on failure) — no error propagation, which is appropriate for non-critical icons
- WebSocket URL helper builds `ws://` URL with token as query param (matches spec §2.2)
- The `projectId` in URL path is not percent-encoded. If project IDs ever contain special characters, this could fail. Low risk since IDs appear to be `proj_xxx` format.

**Not implemented:**
- `POST /api/v1/agents/{agentId}/pty-input` — spec CI#4 mentions this as an alternative to the permission-response endpoint. Current implementation uses a dedicated REST endpoint instead of PTY injection, which is a cleaner approach.

### 1.2 WebSocketClient (`Networking/WebSocketClient.swift`)

**Handled message types:**

| Message Type | Spec Ref | Status |
|-------------|----------|--------|
| `snapshot` | §4.3 | Handled |
| `pty:data` | §4.3 | Handled |
| `pty:exit` | §4.3 | Handled |
| `hook:event` | §4.3 | Handled |
| `theme:changed` | §4.3 | Handled |
| `agent:spawned` | CI#6 | Handled |
| `agent:status` | CI#6 | Handled |
| `agent:completed` | CI#6 | Handled |
| `agent:woken` | CI#7 | Handled |
| `permission:request` | CI#4 | Handled |
| `permission:response` | CI#4 | Handled |

**Architecture:**
- Uses `URLSessionWebSocketTask` with an `AsyncStream<WSEvent>` pattern
- Message parsing: two-pass decode (envelope first, then typed payload extraction)
- `WSEvent` enum covers all message types plus `.disconnected(Error?)`
- `nonisolated(unsafe)` on `task` and `isConnected` — minor concurrency concern for racing connect/disconnect

**Not implemented:**
- Client→server `replay` message (CI#8 event replay) — no bidirectional WS messaging
- `permission:expired` message (CI#4) — not handled, unknown messages logged and skipped
- `replay:start`, `replay:end`, `replay:gap` (CI#8) — not handled
- `seq` field on events (CI#8) — not parsed or stored

**Observations:**
- No ping/pong keepalive mechanism. Relies on `URLSessionWebSocketTask` defaults.
- The `disconnect()` method uses `.goingAway` close code, which is correct.
- Unrecognized message types are logged but silently dropped (reasonable forward-compatibility).

### 1.3 BonjourDiscovery (`Networking/BonjourDiscovery.swift`)

**Implemented features:**
- Browses for `_clubhouse-annex._tcp` service type (matches spec §1)
- Uses `NWBrowser` + `NWConnection` for endpoint resolution
- Resolves IPv4 and IPv6 addresses
- Strips interface scope ID (`%en0`) from resolved addresses (CI#5 fix)
- Service name extracted from `.service` endpoint case
- Tracks and removes stale servers when browse results change
- `@Observable` for SwiftUI reactivity

**Not implemented:**
- TXT record `v=1` version check (spec §1 says "only connect if `v == "1"`"). The client connects without checking the API version.

**Observations:**
- Connections are cleaned up on both success and failure
- `stopSearching()` properly cancels all pending connections
- The `NWBrowser` starts on `queue: .main`, and state updates dispatch to `@MainActor` — correct for UI updates
- `params.includePeerToPeer = true` — broader discovery, acceptable

### 1.4 KeychainHelper (`Networking/KeychainHelper.swift`)

**Implemented:**
- Stores token, server host, and server port in Keychain
- Generic CRUD operations using `Security` framework
- Service identifier: `com.Agent-Clubhouse.Annex`
- `clearAll()` for full credential wipe

**Observations:**
- `save()` deletes before inserting (upsert pattern) — correct
- No error reporting from `SecItemAdd` — failures are silent
- Token stored as plain `GenericPassword` — no additional access control (e.g., `kSecAttrAccessibleWhenUnlocked`)
- Spec §2.3 says tokens are session-only server-side, but client persists them for session restore — this is intentional for reconnection

---

## 2. Data Models

### 2.1 Core Models

| Model | File | Spec Ref | Status |
|-------|------|----------|--------|
| `PairResponse` | NetworkModels.swift | §5.1 | Matches spec |
| `StatusResponse` | NetworkModels.swift | §5.7 | Matches spec |
| `ErrorResponse` | NetworkModels.swift | §5.13 | Matches spec |
| `Project` | Project.swift | §5.2 | Matches spec |
| `DurableAgent` | Agent.swift | §5.3 | Diverges — see below |
| `QuickAgent` | Agent.swift | CI#6 | Matches CI spec |
| `ThemeColors` | Theme.swift | §5.4 | Matches spec |
| `HookEvent` | HookEvent.swift | §5.5 | Partial — see below |
| `HookEventKind` | HookEvent.swift | §5.5 | Matches spec |
| `OrchestratorEntry` | Agent.swift | §5.6 | Matches spec |
| `AgentDetailedStatus` | AgentStatus.swift | CI#3 | Matches CI spec |
| `AgentStatus` | AgentStatus.swift | CI#1 | Client-defined enum |
| `AgentState` | AgentStatus.swift | CI#3 | Client-defined enum |

### 2.2 DurableAgent Divergences from Spec §5.3

**Spec says required:** `name`, `kind`, `color`, `branch`, `model`, `freeAgentMode`

**Client makes optional:** All non-`id` fields are optional (`String?`, `Bool?`)

**Reason:** CI#1 documents that the server frequently omits these fields in snapshot data.

**Additional client-only fields:**
- `status: AgentStatus?` — Not in spec §5.3 but CI#1 says server will add it
- `mission: String?` — Not in any spec. Client-only concept.
- `detailedStatus: AgentDetailedStatus?` — CI#3 addition
- `quickAgents: [QuickAgent]?` — Nested quick agents from ANNEX_SERVER_REQUESTS.md §3

### 2.3 HookEvent / ServerHookEvent Split

The client splits the hook event model:
- `ServerHookEvent` (NetworkModels.swift) — wire format, matches spec §5.5
  - `timestamp: Int` (spec says `Int64` — **type mismatch**, uses `Int` which is 64-bit on iOS but semantically different)
  - `toolInput: JSONValue?` — uses custom `JSONValue` instead of spec's `[String: AnyCodable]?`
- `HookEvent` (HookEvent.swift) — app-domain model with `UUID` identity
  - Drops `toolInput` field during conversion (data loss, but only used for display)

### 2.4 WebSocket Payload Models

All payload models in `NetworkModels.swift` use `Codable + Sendable`:
- `SnapshotPayload` — includes optional `quickAgents` and `pendingPermissions` (beyond spec §5.9)
- `PtyDataPayload` — matches spec §5.10
- `PtyExitPayload` — matches spec §5.11
- `HookEventPayload` — matches spec §5.12
- `AgentSpawnedPayload` — matches CI#6
- `AgentStatusPayload` — matches CI#6
- `AgentCompletedPayload` — matches CI#6 (all completion fields optional)
- `AgentWokenPayload` — matches CI#7
- `PermissionRequestPayload` — matches CI#4
- `PermissionResponsePayload` — matches CI#4

### 2.5 JSONValue

Custom recursive JSON enum for arbitrary payloads. Replaces spec's `AnyCodable`. Supports: string, number (Double), bool, object, array, null. Has `Hashable` conformance (needed for `PermissionRequest.Identifiable`).

### 2.6 AgentColor (ColorToken.swift)

Matches spec §6 exactly — 8 colors with correct hex values:
- indigo `#6366f1`, emerald `#10b981`, amber `#f59e0b`, rose `#f43f5e`
- cyan `#06b6d4`, violet `#8b5cf6`, orange `#f97316`, teal `#14b8a6`

### 2.7 Color(hex:) Extension (Theme.swift)

Matches spec §5.4 reference implementation exactly.

---

## 3. State Management (AppStore)

### 3.1 State Shape

| Property | Type | Source |
|----------|------|--------|
| `projects` | `[Project]` | Snapshot |
| `agentsByProject` | `[String: [DurableAgent]]` | Snapshot |
| `quickAgentsByProject` | `[String: [QuickAgent]]` | Snapshot + WS events |
| `activityByAgent` | `[String: [HookEvent]]` | WS `hook:event` |
| `pendingPermissions` | `[String: PermissionRequest]` | WS `permission:request` |
| `ptyBufferByAgent` | `[String: String]` | WS `pty:data` |
| `isPaired` | `Bool` | Set on successful pair/snapshot |
| `hasCompletedOnboarding` | `Bool` | UserDefaults |
| `theme` | `ThemeColors` | Snapshot + `theme:changed` |
| `serverName` | `String` | GET /status |
| `orchestrators` | `[String: OrchestratorEntry]` | Snapshot |
| `connectionState` | `ConnectionState` | Internal lifecycle |
| `lastError` | `String?` | Error display |
| `agentIcons` | `[String: Data]` | Fetched via icon API |
| `projectIcons` | `[String: Data]` | Fetched via icon API |

### 3.2 Connection Lifecycle

```
Disconnected → [pair()] → Pairing → Connecting → Connected
                                                      ↓
                                              [WS disconnect]
                                                      ↓
                                              Reconnecting(1..10) → Disconnected
                                                      ↓
                                              [401] → Disconnected (token cleared)
```

- Session restore: checks Keychain → validates with GET /status → connects WS
- Reconnection: exponential backoff (1s, 2s, 4s...30s cap), max 10 attempts
- On 401 during reconnect: clears credentials, returns to pairing
- `disconnectInternal()` fully resets all state

### 3.3 WebSocket Event Handling

| Event | Handler Behavior |
|-------|-----------------|
| `snapshot` | Full state replacement. Clears activity + PTY buffers. Loads pending permissions. Triggers icon fetch. |
| `pty:data` | Appends to per-agent buffer, caps at 64KB (trims to 48KB) |
| `pty:exit` | **No-op** — comment says "snapshot updates will cover this" |
| `hook:event` | Appends to activity array. No pruning. |
| `theme:changed` | Direct theme replacement |
| `agent:spawned` | Creates QuickAgent, deduplicates with existing |
| `agent:status` | Updates quick agent status in-place |
| `agent:completed` | Updates quick agent with summary, files, duration, cost, tools |
| `agent:woken` | Finds durable agent across all projects, sets status to `.running` |
| `permission:request` | Replaces any existing permission for same agent, adds to map |
| `permission:response` | Removes permission from pending map |
| `disconnected` | Triggers reconnect if still paired |

### 3.4 Agent Actions

| Action | Implementation |
|--------|---------------|
| Spawn quick agent (standalone) | REST POST + optimistic local add |
| Spawn quick agent (under parent) | REST POST + optimistic local add |
| Cancel quick agent | REST POST + optimistic status update |
| Remove quick agent (local only) | Local array removal |
| Wake durable agent | REST POST, state updated via WS event |
| Send message to running agent | REST POST |
| Respond to permission | REST POST + local removal |

Optimistic updates with deduplication guard against WS events arriving before/after REST responses.

### 3.5 Icon Cache

- Fetched on snapshot receipt
- Only fetches icons for agents/projects where `icon != nil`
- Skips already-cached icons
- URL helper methods available for views (`agentIconURL`, `projectIconURL`)

---

## 4. Views

### 4.1 App Shell

| View | Purpose | Status |
|------|---------|--------|
| `AnnexApp` | Root scene; routes to Welcome/Pairing/Root based on state | Complete |
| `RootNavigationView` | TabView with Agents + Projects tabs | Complete |
| `WelcomeView` | Onboarding splash with logo animation | Complete |
| `PairingPlaceholderView` | Bonjour discovery + PIN entry | Complete |
| `SettingsView` | Server info, connection status, disconnect/reset | Complete |

### 4.2 Agent Views

| View | Purpose | Status |
|------|---------|--------|
| `AllAgentsView` | Flat list of all durable agents with inline activity expansion | Complete |
| `AgentListView` | Per-project agent list (durable + quick sections) | Complete |
| `AgentRowView` | Durable agent row with avatar, chips, status preview | Complete |
| `QuickAgentRowView` | Quick agent row with status icon and summary | Complete |
| `AgentDetailView` | Full agent detail: status bar, branch, activity feed, permission banner | Complete |
| `QuickAgentDetailView` | Quick agent detail: status, prompt, completion summary, cancel | Complete |
| `StatusIndicatorView` | Shared components: AgentAvatarView, ProjectIconView, StatusDotView, ChipView | Complete |

### 4.3 Action Sheets

| View | Purpose | Status |
|------|---------|--------|
| `WakeAgentSheet` | Wake sleeping agent with message + optional model override | Complete |
| `SendMessageSheet` | Send message to running agent | Complete |
| `SpawnQuickAgentSheet` | Spawn quick agent with prompt, model, orchestrator, free agent mode | Complete |
| `PermissionRequestSheet` | Full permission detail with allow/deny + countdown timer | Complete |
| `PermissionBanner` | Inline banner in AgentDetailView with quick allow/deny buttons | Complete |

### 4.4 Data Display

| View | Purpose | Status |
|------|---------|--------|
| `ActivityFeedView` | Scrollable activity feed with event rows, permission tap targets | Complete |
| `LiveTerminalView` | Raw PTY output in monospace green text, auto-scroll | Complete |
| `ProjectListView` | Sidebar project list for NavigationSplitView | Complete |
| `ProjectRowView` | Project row with icon and agent count | Complete |

### 4.5 View Observations

- **Theme integration**: All views use `store.theme.*Color` for backgrounds, text, and accents
- **Chip system**: Orchestrator (OrchestratorColors) + Model (ModelColors hash-based palette) + Free agent chips
- **Avatar system**: Initials from hyphenated names, status ring animation, error badge pulse, custom icon overlay
- **ANSI handling**: LiveTerminalView renders raw text with no ANSI escape processing (spec §8 recommends stripping or emulating)
- **Relative time**: Two independent implementations of relative time formatting (AllAgentsView + AgentRowView) — could be unified
- **DateFormatter**: ActivityFeedView creates a new DateFormatter per call in `formatTime()` — minor performance concern

---

## 5. Spec Divergences

### 5.1 Against ANNEX_CLIENT_SPEC.md

| # | Spec Section | Divergence | Severity |
|---|-------------|------------|----------|
| D1 | §1 Discovery | TXT record `v=1` not checked | Medium — could connect to incompatible server |
| D2 | §3.4 Buffer | Buffer not fetched on initial load or reconnect | Medium — spec §8 says "fetch buffer first, then append pty:data" |
| D3 | §4.3 pty:exit | Exit event is a no-op; agent status not updated | Low — works because snapshot refreshes cover it |
| D4 | §5.3 DurableAgent | All fields made optional (spec says several required) | Low — justified by CI#1 |
| D5 | §5.5 AgentHookEvent | `timestamp` is `Int` not `Int64`; `toolInput` dropped in conversion | Low — Int is 64-bit on iOS; toolInput not needed for display |
| D6 | §5.8 WSMessage | Uses `JSONValue` for payload instead of generic JSON dispatch | None — equivalent functionality |
| D7 | §7 Error Handling | 409 Conflict not in spec but handled anyway | None — forward-compatible |
| D8 | §8 Lifecycle | No initial buffer fetch before WS streaming | Medium — may miss output between connect and first pty:data |
| D9 | §8 ANSI | Terminal output not stripped or emulated | Low — functional but ugly rendering |

### 5.2 Endpoint Not in Spec But Implemented

| Endpoint | Notes |
|----------|-------|
| `POST /api/v1/agents/{agentId}/permission-response` | Not in ANNEX_CLIENT_SPEC.md or CONTRACT_IMPROVEMENTS.md as a REST endpoint. CI#4 discusses PTY injection approach. Client assumes a dedicated REST endpoint exists. |
| `GET /api/v1/icons/agent/{agentId}` | CI#2 proposes these endpoints but they may not be implemented server-side yet |
| `GET /api/v1/icons/project/{projectId}` | Same as above |

---

## 6. Contract Improvements Coverage

| CI# | Feature | Client Status | Notes |
|-----|---------|---------------|-------|
| CI#1 | DurableAgent optional fields + `status` in snapshot | **Implemented** | All fields optional; `status` on DurableAgent model |
| CI#2 | Icon HTTP endpoints + `iconHash` | **Partially implemented** | Endpoints called; `iconHash` not used for cache invalidation |
| CI#3 | `detailedStatus` cache with staleness | **Partially implemented** | Model exists, displayed in UI; 30-second staleness logic not implemented client-side |
| CI#4 | Permission approval (PTY injection) | **Implemented differently** | Uses REST `permission-response` endpoint instead of PTY injection. `permission:request` and `permission:response` WS messages handled. `permission:expired` not handled. |
| CI#5 | Bonjour scope ID | **Resolved** | Scope ID stripped in BonjourDiscovery.swift |
| CI#6 | Spawn quick agents | **Fully implemented** | Standalone + under parent, cancel, WS events (spawned/status/completed), snapshot `quickAgents` |
| CI#7 | Wake sleeping agents + message running agents | **Fully implemented** | Wake with model override, message running agents, `agent:woken` WS event |
| CI#8 | Event replay buffer | **Not implemented** | No `replay` client→server message, no `seq` tracking, no `lastSeq` storage |

---

## 7. Client Assumptions About Server Behavior

### 7.1 Assumed Endpoints (Not Yet Confirmed Server-Side)

1. **`POST /api/v1/agents/{agentId}/permission-response`** — CI#4 discusses PTY injection, but client implements a dedicated REST endpoint with `requestId` + `decision` body. **Server must provide this exact endpoint or client permission flow will fail.**

2. **`GET /api/v1/icons/agent/{agentId}` and `GET /api/v1/icons/project/{projectId}`** — CI#2 proposes these. Client calls them but gracefully handles failure (returns nil). **Non-blocking.**

### 7.2 Assumed Snapshot Shape

Client expects:
```json
{
  "projects": [...],
  "agents": { "projectId": [DurableAgent] },
  "quickAgents": { "projectId": [QuickAgent] },  // optional
  "theme": ThemeColors,
  "orchestrators": { "id": OrchestratorEntry },
  "pendingPermissions": [PermissionRequest]        // optional
}
```

- `quickAgents` and `pendingPermissions` are optional (decoded with `?`)
- `orchestrators` is **required** — if server omits it, snapshot decode will fail

### 7.3 Assumed DurableAgent Shape in Snapshot

Client expects agents in `snapshot.agents` to include:
- `status: AgentStatus` — for determining sleeping/running/error state
- `detailedStatus: AgentDetailedStatus?` — for working/needsPermission indicators
- `mission: String?` — for display in agent rows
- `quickAgents: [QuickAgent]?` — nested quick agents

**These fields go beyond spec §5.3.** If server sends vanilla spec-compliant DurableAgent objects, the client will still work but with reduced functionality (no status indicators, no missions, no nested quick agents).

### 7.4 Assumed WS Message Types Beyond Spec

| Message | Assumption |
|---------|-----------|
| `permission:request` | Server sends with `requestId`, `agentId`, `toolName`, `toolInput`, `message`, `deadline` |
| `permission:response` | Server broadcasts when any client responds, with `requestId` + `decision` |
| `agent:spawned` | Server sends when quick agent created from any source |
| `agent:status` | Server sends on quick agent status transitions |
| `agent:completed` | Server sends with rich completion data (summary, files, cost, tools) |
| `agent:woken` | Server sends with `agentId`, `message`, `source` |

### 7.5 Timing Assumptions

- **Reconnect window**: Client tries 10 reconnect attempts with exponential backoff up to 30s. Total max reconnect time ≈ 5 minutes before giving up.
- **Permission deadline**: Client reads `deadline` as Unix timestamp in milliseconds. Displays countdown. Does not auto-expire locally — relies on UI showing "Expired" text.
- **PTY buffer cap**: Client caps at 64KB (trims to 48KB). Assumes server buffer can be larger.

### 7.6 Data Assumptions

- **Project IDs** are stable strings safe for URL path segments
- **Agent IDs** are stable, unique across all projects
- **Token format** is a simple string (no parsing/validation)
- **Color IDs** are one of the 8 known values; unknown colors fall back to gray
- **Model strings** contain "opus", "sonnet", or "haiku" for label extraction

---

## 8. TODOs, Stubs, and Workarounds

### 8.1 Explicit Workarounds

| Location | Workaround | Reason |
|----------|-----------|--------|
| Agent.swift:6-8 | All DurableAgent fields optional | CI#1: server omits fields |
| BonjourDiscovery.swift:112-116 | Strip `%` scope ID from addresses | CI#5: Apple NW framework behavior |
| AppStore.swift:247-248 | `pty:exit` is no-op | Relies on snapshot for status updates |
| StatusIndicatorView.swift:59-63 | Initials generated from hyphenated name | CI#2: no icon endpoint yet |

### 8.2 Implicit Stubs / Missing Features

| Feature | Location | Impact |
|---------|----------|--------|
| Bonjour `v=1` TXT record check | BonjourDiscovery.swift | Could connect to wrong service version |
| Initial buffer fetch | AppStore.swift | Misses terminal output between pair and first pty:data |
| ANSI escape processing | LiveTerminalView.swift | Raw escapes shown as garbage characters |
| `iconHash`-based cache invalidation | AppStore.swift:517-537 | Icons re-fetched on every snapshot instead of only on change |
| DetailedStatus staleness (30s) | AgentRowView/AgentDetailView | Stale status text not automatically cleared |
| Event replay (CI#8) | WebSocketClient.swift / AppStore.swift | No reconnection gap recovery |
| `permission:expired` handling | WebSocketClient.swift | Expired permissions may linger in UI |
| Quick agent PTY streaming | AppStore.swift | Quick agents don't accumulate PTY buffer (treated same as durable) |
| `headless` agent field | ANNEX_SERVER_REQUESTS.md §3 | Requested in server requests doc but not in client model |
| Push notifications for permissions | CI#4 | Only in-app UI implemented |
| Durable agent status update on `pty:exit` | AppStore.swift:247 | Agent appears "running" until next snapshot |

### 8.3 Code-Level Concerns

| File | Line | Issue |
|------|------|-------|
| WebSocketClient.swift:22 | `nonisolated(unsafe)` | `task` and `isConnected` have potential data races between connect/disconnect calls |
| AppStore.swift:239-245 | PTY buffer trim | Trims by character count not byte count; multi-byte UTF-8 could cause issues at trim boundary |
| ActivityFeedView.swift:145-151 | `formatTime()` | Creates new `DateFormatter` per call; should be static |
| AllAgentsView.swift:191-198 | `compactTime()` duplicate | Same relative time logic exists in AgentRowView.swift:152-160 |
| SpawnQuickAgentSheet.swift:18-22 | Hardcoded model list | Model list ("opus", "sonnet", "haiku") hardcoded; won't pick up new models |
| WakeAgentSheet.swift:14-18 | Same hardcoded model list | Same issue |
| AppStore.swift:361-362 | Reconnect backoff | Uses `pow(2.0, ...)` which returns Double, then `min()` with 30.0 — works but `Task.sleep` with fractional seconds is fine |
| PermissionRequestSheet.swift:32-37 | Countdown timer | `timeRemaining` is computed but never refreshes on a timer — shows stale time |

---

## 9. Test Coverage

**Total tests: 34** (in `AnnexTests/AnnexTests.swift`)

| Test Group | Count | Coverage |
|------------|-------|----------|
| Model Decoding | 10 | PairResponse, StatusResponse, ErrorResponse, Project, DurableAgent (full + minimal), ThemeColors, OrchestratorEntry, HookEventKind, QuickAgent |
| WebSocket Parsing | 5 | snapshot, pty:data, pty:exit, hook:event, theme:changed |
| Hook Event Conversion | 1 | ServerHookEvent → HookEvent |
| API Client | 2 | Base URL formatting (IPv4 + IPv6) |
| AppStore State | 3 | agents(for:), project(for:), allAgents sort |
| JSONValue | 5 | String, number, bool, object, null |
| ConnectionState | 3 | Labels, isConnected |
| AgentColor | 2 | Known color, unknown fallback |
| Initials | 2 | Agent initials, project initials |
| isDark | 1 | ThemeColors luminance |

**Gaps:**
- No tests for: WS `agent:spawned`, `agent:status`, `agent:completed`, `agent:woken`, `permission:request`, `permission:response` message parsing
- No tests for: `SpawnQuickAgentRequest`, `WakeAgentRequest`, `SendMessageRequest`, `PermissionResponseRequest` encoding
- No tests for: `SpawnQuickAgentResponse`, `WakeAgentResponse`, `CancelAgentResponse`, `SendMessageResponse` decoding
- No tests for: AppStore agent action methods (spawn, wake, message, cancel, permission respond)
- No tests for: Reconnection logic, error mapping in `perform()`
- No tests for: BonjourDiscovery (hard to unit test)
- No tests for: KeychainHelper (requires Keychain entitlement)
- No integration/UI tests

---

## 10. Recommendations

### 10.1 High Priority

1. **Implement initial buffer fetch** (D2/D8): After WS connects and receives snapshot, fetch `GET /buffer` for each running agent before appending `pty:data`. This prevents missing output.

2. **Handle `pty:exit` properly** (D3): Update the corresponding durable agent's `status` to `.sleeping` (or remove from running set) on exit, rather than relying on the next snapshot.

3. **Add `permission:expired` handler**: Remove expired permissions from `pendingPermissions` when the server sends this event, preventing stale permission banners.

4. **Add TXT record version check** (D1): Before connecting to a discovered server, verify `v=1` in the Bonjour TXT record to prevent connecting to incompatible API versions.

5. **Confirm server has `permission-response` endpoint**: The current permission flow depends on `POST /api/v1/agents/{agentId}/permission-response`. This must be coordinated with server team — it's not in the original spec or CI document.

### 10.2 Medium Priority

6. **Implement detailedStatus staleness** (CI#3): Add a 30-second timer to clear stale `detailedStatus` messages, matching the server's staleness threshold.

7. **Add event replay support** (CI#8): Store `lastSeq` from snapshots, send `replay` message on reconnect, handle `replay:start`/`replay:end`/`replay:gap`.

8. **Add ANSI escape processing** (D9): Use a lightweight ANSI parser for the LiveTerminalView, or at minimum strip escape sequences for readable plain text.

9. **Implement `iconHash`-based cache** (CI#2): Check `iconHash` field before refetching icons to avoid unnecessary network requests.

10. **Fix countdown timer in PermissionRequestSheet**: Use a `Timer` or `TimelineView` to refresh the `timeRemaining` computation periodically.

### 10.3 Low Priority

11. **Unify relative time formatting**: Extract the duplicate `relativeTime`/`compactTime` functions into a shared utility.

12. **Cache DateFormatter**: Make the `formatTime()` DateFormatter a static property.

13. **Fix WebSocketClient concurrency**: Replace `nonisolated(unsafe)` with proper actor isolation or `@unchecked Sendable` with explicit locking.

14. **Make model list dynamic**: Source available models from the orchestrator info instead of hardcoding three model names.

15. **Add missing test coverage**: Especially for new WS message types (agent:spawned, permission:request, etc.) and REST request/response codables.
