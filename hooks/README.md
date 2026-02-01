# SSHGuard Hooks

## pre-ssh.sh

**Claude Code integration hook** that checks SSH authorization before allowing connections.

### How It Works

```
Claude Code → Bash tool → pre-ssh hook → checks state file → allow/block
```

### Installation

**Automatic (via install script):**
```bash
cd ~/Development/ssh-guard
./scripts/install.sh
```

**Manual:**
```bash
# Symlink to Claude Code hooks directory
ln -sf ~/Development/ssh-guard/hooks/pre-ssh.sh \
       ~/.config/pai-private/hooks/pre-ssh.sh
```

### Testing

**Test the hook directly:**
```bash
# Test allowed host
~/Development/ssh-guard/hooks/pre-ssh.sh ssh rico@10.71.1.8
# Expected: ✅ SSH to rico@10.71.1.8 is ALLOWED (exit 0)

# Test unknown host
~/Development/ssh-guard/hooks/pre-ssh.sh ssh rico@10.71.20.99
# Expected: ❓ Unknown host, added to pending (exit 1)

# Test blocked host
~/Development/ssh-guard/hooks/pre-ssh.sh ssh root@10.71.20.55
# Expected: 🔴 SSH to root@10.71.20.55 is BLOCKED (exit 1)
```

**Check the log:**
```bash
tail -f ~/.config/pai/logs/ssh-guard-hook.log
```

### Hook Behavior

| State | Icon | Exit Code | Behavior |
|-------|------|-----------|----------|
| `allowed` | 🟢 | 0 | SSH proceeds, updates lastUsed timestamp |
| `ask` | ⚪ | 1 | SSH blocked, prompts to check menu bar app |
| `blocked` | 🔴 | 1 | SSH blocked with explicit denial |
| Unknown | ❓ | 1 | SSH blocked, host added to pending queue |

### State File Location

**Reads from:** `~/.config/pai/infrastructure/ssh-permissions.json`

If the file doesn't exist, the hook:
1. Creates empty state file
2. Blocks the SSH attempt
3. Adds host to pending queue
4. Prompts to run SSHGuard app

### Logging

**Log location:** `~/.config/pai/logs/ssh-guard-hook.log`

**Log format:**
```
[2026-01-31T23:55:00Z] [INFO] SSH attempt: rico@10.71.1.8
[2026-01-31T23:55:00Z] [INFO] ✅ SSH to rico@10.71.1.8 is ALLOWED
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
ls -la ~/.config/pai-private/hooks/pre-ssh.sh

# Check if hook is executable
ls -l ~/Development/ssh-guard/hooks/pre-ssh.sh
```

**Hook always blocks:**
```bash
# Check state file exists
cat ~/.config/pai/infrastructure/ssh-permissions.json

# Validate JSON
jq . ~/.config/pai/infrastructure/ssh-permissions.json
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
rm ~/.config/pai-private/hooks/pre-ssh.sh

# After emergency, restore:
ln -sf ~/Development/ssh-guard/hooks/pre-ssh.sh \
       ~/.config/pai-private/hooks/pre-ssh.sh
```

**Or edit state file manually:**
```bash
# Add host to allowed state
jq '.hosts += [{
  "id": "emergency-host",
  "ip": "10.71.20.99",
  "user": "rico",
  "state": "allowed",
  "note": "Emergency access"
}]' ~/.config/pai/infrastructure/ssh-permissions.json \
  > ~/.config/pai/infrastructure/ssh-permissions.json.tmp

mv ~/.config/pai/infrastructure/ssh-permissions.json.tmp \
   ~/.config/pai/infrastructure/ssh-permissions.json
```

## Future Hooks

**Potential additional hooks:**
- `post-ssh.sh` - Log successful connections, track usage
- `pre-scp.sh` - Authorize file transfers
- `pre-rsync.sh` - Authorize sync operations
