# Contract Bugs — Annex Client vs Server

Discrepancies between the API spec and actual server behavior discovered during integration testing.

## 1. Many `DurableAgent` fields not always present

- **Spec says**: `name`, `kind`, `color`, `branch`, `model`, `freeAgentMode` are required fields (§5.3)
- **Server sends**: Agents in the snapshot `payload.agents` frequently omit these fields
- **Observed missing**: `model`, `branch`, `freeAgentMode`, potentially others
- **Workaround**: Made all non-`id` fields optional in client model
- **Example path**: `payload.agents["proj_1771095672646_a2myyt"][0]` — missing `model` key; `payload.agents["proj_1771484668646_hbid6g"][0]` — missing `branch` key

## 3. Bonjour-resolved host includes interface scope ID

- **Issue**: `NWConnection` endpoint resolution returns host with `%en0` suffix (e.g. `192.168.1.26%en0`)
- **Impact**: `URL(string:)` returns nil due to `%` in hostname
- **Resolution**: Client-side fix — strip `%` suffix from resolved addresses
- **Note**: This is an Apple/NWConnection behavior, not a server bug
