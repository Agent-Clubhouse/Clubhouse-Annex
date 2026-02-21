# Annex Server — Requested API Changes

Changes the iOS client needs to match the Clubhouse desktop UI.

---

## 1. Add theme colors to snapshot

The iOS client needs the active Clubhouse theme so it can match the desktop appearance. Send the current theme's color map in the WebSocket `snapshot` payload (and update it if the user changes themes while connected).

### `snapshot` payload addition

```json
{
  "type": "snapshot",
  "payload": {
    "projects": [ ... ],
    "agents": { ... },
    "theme": {
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
}
```

### New WebSocket message: `theme:changed`

When the user switches themes on desktop, push the new colors:

```json
{
  "type": "theme:changed",
  "payload": {
    "base": "#282a36",
    "mantle": "#21222c",
    ...
  }
}
```

---

## 2. Add orchestrator info to snapshot

The iOS client renders orchestrator chips (colored badges) on each agent row. We need the orchestrator registry so we can map IDs to display names and colors.

### `snapshot` payload addition

```json
{
  "type": "snapshot",
  "payload": {
    "projects": [ ... ],
    "agents": { ... },
    "theme": { ... },
    "orchestrators": {
      "claude-code": {
        "displayName": "Claude Code",
        "shortName": "CC",
        "badge": null
      },
      "copilot-cli": {
        "displayName": "Copilot CLI",
        "shortName": "CP",
        "badge": null
      }
    }
  }
}
```

---

## 3. Expand agent fields in API responses

The following fields exist on agents in Clubhouse but are missing from the Annex API spec. The iOS client needs them for feature parity with the desktop agent widget.

### New fields on durable agents

| Field | Type | Description |
|-------|------|-------------|
| `orchestrator` | `string?` | Orchestrator ID (e.g. `"claude-code"`) — used for the orchestrator chip |
| `freeAgentMode` | `bool?` | If `true`, show red "Free" badge — agent skips permission prompts |
| `icon` | `string?` | Custom agent icon filename (from `~/.clubhouse/agent-icons/`) |
| `headless` | `bool?` | If `true`, agent runs without terminal — affects status display |

### New fields on quick agents

| Field | Type | Description |
|-------|------|-------------|
| `orchestrator` | `string?` | Orchestrator ID |
| `parentAgentId` | `string?` | ID of the parent durable agent |

### Updated example response

```json
{
  "id": "durable_1737000000000_abc123",
  "name": "faithful-urchin",
  "kind": "durable",
  "color": "emerald",
  "status": "running",
  "branch": "faithful-urchin/standby",
  "model": "claude-opus-4-5",
  "orchestrator": "claude-code",
  "freeAgentMode": false,
  "icon": null,
  "headless": false,
  "detailedStatus": { ... },
  "mission": null,
  "quickAgents": [
    {
      "id": "quick_1737000100000_def456",
      "name": "quick-agent-1",
      "kind": "quick",
      "status": "running",
      "mission": "Fix the login bug",
      "model": "claude-sonnet-4-5",
      "orchestrator": "claude-code",
      "parentAgentId": "durable_1737000000000_abc123",
      "detailedStatus": { ... }
    }
  ]
}
```

---

## 4. Include `GET /api/v1/status` expansion (nice to have)

Add theme and orchestrator count so the client can prepare UI before the WebSocket connects:

```json
{
  "version": "1",
  "deviceName": "Clubhouse on Mason's Mac",
  "agentCount": 3,
  "orchestratorCount": 1
}
```

---

## Summary of changes

| Area | What | Priority |
|------|------|----------|
| `snapshot` payload | Add `theme` color map | High — drives entire iOS appearance |
| WebSocket message | Add `theme:changed` event | Medium — live theme sync |
| `snapshot` payload | Add `orchestrators` registry | High — needed for chip rendering |
| Agent fields | Add `orchestrator`, `freeAgentMode`, `icon`, `headless` | High — feature parity with desktop widget |
| Quick agent fields | Add `orchestrator`, `parentAgentId` | Medium |
