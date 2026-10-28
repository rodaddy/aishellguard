# AIShell Guard Hooks

## pre-ssh.sh

**Claude Code integration hook** that checks SSH authorization before allowing connections.

### How It Works

```
Claude Code → Bash tool → pre-ssh hook → checks state file → allow/block
```

### Installation

**Automatic (via install script):**
```bash
cd /path/to/aishellguard
./scripts/install.sh
```

**Manual:**
```bash
# Symlink to Claude Code hooks directory
ln -sf /path/to/aishellguard/hooks/pre-ssh.sh \
       ~/.config/aishellguard/hooks/pre-ssh.sh
```

### Testing

**Test the hook directly** (against the example state that `scripts/install.sh` copies from `schemas/example-state.json`):
```bash
# Test allowed host
/path/to/aishellguard/hooks/pre-ssh.sh ssh user@192.0.2.10
# Expected: ✅ SSH to user@192.0.2.10 is ALLOWED (exit 0)

# Test unknown host
/path/to/aishellguard/hooks/pre-ssh.sh ssh user@192.0.2.99
# Expected: ❓ Unknown host, added to pending (exit 1)

# Test blocked host
/path/to/aishellguard/hooks/pre-ssh.sh ssh root@192.0.2.60
# Expected: 🔴 SSH to root@192.0.2.60 is BLOCKED (exit 1)
```

**Check the log:**
```bash
tail -f ~/.config/aishellguard/hook.log
```

### Hook Behavior

| State | Icon | Exit Code | Behavior |
|-------|------|-----------|----------|
| `allowed` | 🟢 | 0 | SSH proceeds, updates lastUsed timestamp |
| `ask` | ⚪ | 1 | SSH blocked, prompts to check menu bar app |
| `blocked` | 🔴 | 1 | SSH blocked with explicit denial |
| Unknown | ❓ | 1 | SSH blocked, host added to pending queue |

### State File Location

**Reads from**, first match wins: `$AISHELLGUARD_STATE_FILE`, the path set in the app's preferences, `~/.config/pai/infrastructure/ssh-permissions.json` if it exists, then `~/.config/aishellguard/hosts.json`.

If the file doesn't exist, the hook blocks the SSH attempt (exit 1) and logs a prompt to run the AIShell Guard app.

### Logging

**Log location:** `~/.config/aishellguard/hook.log`

**Log format:**
```
[2026-01-31T23:55:00Z] [INFO] SSH attempt: user@192.0.2.10
[2026-01-31T23:55:00Z] [INFO] ✅ SSH to user@192.0.2.10 is ALLOWED
```

**Log levels:**
- `INFO` - Normal operations
- `WARN` - Unusual but non-critical (unknown hosts, missing state)
- `ERROR` - Blocked attempts, invalid state

### Integration with Menu Bar App

**Workflow:**
1. Hook blocks unknown host → adds to `pending[]` in state file
2. Menu bar app watches state file for changes
3. App shows notification badge for pending hosts
4. User clicks notification → authorizes host
5. Hook allows future SSH attempts

### Troubleshooting

**Hook not running:**
```bash
# Check if symlink exists
ls -la ~/.config/aishellguard/hooks/pre-ssh.sh

# Check if hook is executable
ls -l /path/to/aishellguard/hooks/pre-ssh.sh
```

**Hook always blocks:**
```bash
# Check state file exists
cat ~/.config/aishellguard/hosts.json

# Validate JSON
jq . ~/.config/aishellguard/hosts.json
```

**Can't find jq:**
```bash
# Install jq (required dependency)
brew install jq
```

### Emergency Bypass

**If hook is broken and you need SSH immediately:**

```bash
# Temporary: Remove hook symlink
rm ~/.config/aishellguard/hooks/pre-ssh.sh

# After emergency, restore:
ln -sf /path/to/aishellguard/hooks/pre-ssh.sh \
       ~/.config/aishellguard/hooks/pre-ssh.sh
```

**Or edit state file manually:**
```bash
# Add host to allowed state
jq '.hosts += [{
  "id": "emergency-host",
  "ip": "192.0.2.99",
  "user": "$USER",
  "state": "allowed",
  "note": "Emergency access"
}]' ~/.config/aishellguard/hosts.json \
  > ~/.config/aishellguard/hosts.json.tmp

mv ~/.config/aishellguard/hosts.json.tmp \
   ~/.config/aishellguard/hosts.json
```

## Future Hooks

**Potential additional hooks:**
- `post-ssh.sh` - Log successful connections, track usage
- `pre-scp.sh` - Authorize file transfers
- `pre-rsync.sh` - Authorize sync operations
