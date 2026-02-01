# State File Design

## Location

**Production:** `~/.config/aishellguard/hosts.json`

**Why this location:**
- Survives app uninstall
- Can be backed up with other configs
- Readable by both menu bar app and bash hook

## Schema Design Decisions

### Host Identification

**`id` field is the stable identifier:**
```json
{
  "id": "lxc-202-n8n",    // Stable, doesn't change
  "hostname": "n8n",       // Might change
  "ip": "192.0.2.51"      // Might change
}
```

**Why separate id/hostname/ip:**
- IP addresses can change (DHCP, reconfiguration)
- Hostnames can change (renaming)
- ID is permanent reference across changes

### State Enum

- **`allowed`** (🟢) - SSH permitted without prompts
- **`ask`** (⚪) - Requires confirmation before SSH
- **`blocked`** (🔴) - SSH explicitly denied

**Default for unknown hosts:** Not in file = blocked by default

### Pending Queue

Unknown SSH attempts go into `pending[]` array:

```json
{
  "pending": [
    {
      "ip": "192.0.2.99",
      "user": "root",
      "detectedAt": "2026-01-31T23:45:00Z",
      "attemptedBy": "user"
    }
  ]
}
```

**Workflow:**
1. Hook detects unknown host → adds to pending
2. Menu bar app shows notification badge
3. User clicks notification → sees pending hosts
4. User clicks 🟢/⚪/🔴 → moved from pending to hosts[]
5. Pending entry removed

### Metadata Fields

**`lastUsed`** - Track stale hosts
- `null` = never used
- ISO timestamp = last connection
- Helps identify abandoned/unused hosts

**`tags`** - Grouping and filtering
- `["lxc", "production"]` enables filtering in UI
- Could add "show only production hosts" filter
- Useful for organizing many hosts

**`note`** - Human context
- Reminds you why host exists
- Warning notes ("production - caution")
- Free-form text

## File Format

**JSON, not YAML/TOML:**
- Swift has native JSON support (Codable)
- Bash can parse with `jq` (installed by default on macOS)
- Human-readable, standard format

**Pretty-printed:**
- Easier to read/edit manually if needed
- Git diffs show meaningful changes

## Validation

**JSON Schema:** `schemas/ssh-permissions.schema.json`

**Validation points:**
1. App startup: Validate state file, warn if invalid
2. Before write: Validate changes
3. Hook runtime: Graceful degradation if malformed

## Migration Strategy

**Version field enables future schema changes:**

```json
{
  "version": "1.0",  // Current
  ...
}

// Future version 2.0 might add new fields
{
  "version": "2.0",
  "hosts": [...],
  "groups": [...],     // New feature
  "auditLog": [...]    // New feature
}
```

**Backward compatibility:**
- v1.0 state files always supported
- App can upgrade v1.0 → v2.0 automatically
- Never break existing state files

## Thread Safety

**File locking not needed:**
- Single writer (menu bar app)
- Hook is read-only
- Atomic writes (write temp file → rename)

**Write strategy:**
```swift
// Write to temp file
let tempPath = statePath + ".tmp"
try data.write(to: tempPath)

// Atomic rename (POSIX guarantees)
try FileManager.default.replaceItemAt(statePath, withItemAt: tempPath)
```

This prevents hook from reading partial/corrupted file.

## Example Use Cases

### 1. Adding new LXC
```
User: "SSH to new LXC at 192.0.2.60"
Hook: "Unknown host, blocked"
App: Shows notification "Unknown host 192.0.2.60"
User: Clicks notification → Add as "lxc-207-test"
User: Clicks 🟢 allowed
Hook: Now allows SSH to 192.0.2.60
```

### 2. IP change
```
User: Changes LXC 202 IP: 192.0.2.51 → 192.0.2.61
Hook: "192.0.2.61 unknown, blocked"
App: User edits "lxc-202-n8n" → change IP to 192.0.2.61
Hook: Now allows SSH to new IP
```

### 3. Temporary block
```
User: Running risky operation on postgres
User: Clicks "lxc-200-postgres" → 🔴 blocked
AI: Tries SSH → blocked
User: Operation complete
User: Clicks "lxc-200-postgres" → ⚪ ask (safe default)
```

## Future Enhancements

**Possible additions (not v1.0):**
- Host groups (production, dev, homelab)
- Time-based rules (allow only during work hours)
- Audit log of state changes
- Import/export host lists
- SSH key fingerprint tracking
- Connection history graphs
