# Contract Bugs — Annex Client vs Server

Discrepancies between the API spec and actual server behavior discovered during integration testing.

## 1. Many `DurableAgent` fields not always present

- **Spec says**: `name`, `kind`, `color`, `branch`, `model`, `freeAgentMode` are required fields (§5.3)
- **Server sends**: Agents in the snapshot `payload.agents` frequently omit these fields
- **Observed missing**: `model`, `branch`, `freeAgentMode`, potentially others
- **Workaround**: Made all non-`id` fields optional in client model
- **Example path**: `payload.agents["proj_1771095672646_a2myyt"][0]` — missing `model` key; `payload.agents["proj_1771484668646_hbid6g"][0]` — missing `branch` key

## 3. Agent/project `icon` field references local filesystem paths

- **Spec says**: Agents and projects have an optional `icon: String?` field
- **Server sends**: The `icon` value (when present) is a local filesystem path (e.g. `/Users/mason/.clubhouse/icons/agent.png`)
- **Impact**: Mobile clients cannot fetch these icons — there is no HTTP endpoint to retrieve icon data
- **Suggestion**: Server should add `GET /api/v1/icons/{filename}` endpoint or include base64-encoded icon data inline in the snapshot payload
- **Workaround**: Client renders generated initials (2-letter for agents, single letter for projects) as avatars instead of custom icons

## 4. `detailedStatus` not always populated in snapshot

- **Spec says**: `detailedStatus` provides `state`, `message`, `toolName`, `timestamp` for running agents (§5.3)
- **Server sends**: `detailedStatus` is frequently `null` even for agents with `status: "running"`
- **Impact**: Client cannot determine `working` vs `needsPermission` vs `toolError` state for ring animations; falls back to static ring based on `status` alone
- **Suggestion**: Server should always populate `detailedStatus` for running agents, even if just `{"state":"idle","message":"","toolName":null,"timestamp":<now>}`

## 5. No bidirectional permission response channel for remote approval

- **Current behavior**: `hook:event` with `kind: "permission_request"` is broadcast over WebSocket as a fire-and-forget notification — clients can observe it but cannot respond
- **Impact**: The Annex iOS app can _see_ that an agent needs permission but has no way to approve or deny. Users must be at the Mac to interact with the CLI prompt or a macOS-side hook script
- **Desired flow**:
  1. Agent's `PreToolUse` hook fires → hook script POSTs to Annex server with tool name, input, agent ID
  2. Annex server queues the pending approval and pushes it to connected iOS clients via WebSocket
  3. User taps Allow/Deny on iPhone (actionable notification or in-app prompt)
  4. iOS app calls `POST /api/v1/agents/:id/permission-response` with `{ "decision": "allow" | "deny" }`
  5. Annex server relays decision back to the waiting hook script
  6. Hook script returns `permissionDecision` to Claude Code within the 600s hook timeout
- **Server needs**:
  - `POST /api/v1/agents/:id/permission-response` endpoint accepting `{ "decision": "allow" | "deny", "reason": "..." }`
  - A pending-approvals queue that pairs incoming permission requests with responses
  - New WebSocket message type `permission:request` (distinct from `hook:event`) carrying request ID, agent name, tool name, tool input summary, and timeout deadline
  - New WebSocket message type `permission:response` for server→client confirmation that the decision was recorded
- **Client needs** (Annex iOS):
  - Actionable push notification / in-app approval UI with Allow and Deny buttons
  - REST call to submit the decision
- **Complementary macOS approach**: A local `PreToolUse` hook script using `osascript` can pop a native dialog for instant approval when at the desk; the Annex remote path serves as the away-from-desk fallback
- **Note**: Claude Code hooks already support `permissionDecision: "allow" | "deny" | "ask"` in `hookSpecificOutput`, so the CLI side is ready — the missing piece is the Annex server acting as the relay

## 6. Bonjour-resolved host includes interface scope ID

- **Issue**: `NWConnection` endpoint resolution returns host with `%en0` suffix (e.g. `192.168.1.26%en0`)
- **Impact**: `URL(string:)` returns nil due to `%` in hostname
- **Resolution**: Client-side fix — strip `%` suffix from resolved addresses
- **Note**: This is an Apple/NWConnection behavior, not a server bug
