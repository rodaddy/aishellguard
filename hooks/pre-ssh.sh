#!/bin/bash
# pre-ssh.sh - SSHGuard hook for Claude Code
#
# Checks SSH authorization before allowing connection.
# Integrates with menu bar app via shared state file.
#
# Usage: Called automatically by Claude Code before SSH commands
# Returns: 0 (allow), 1 (block)

set -euo pipefail

# Configuration
STATE_FILE="${HOME}/.config/pai/infrastructure/ssh-permissions.json"
HOOK_LOG="${HOME}/.config/pai/logs/ssh-guard-hook.log"

# Ensure log directory exists
mkdir -p "$(dirname "$HOOK_LOG")"

# Extract SSH target from command line
# Handles: ssh user@host, ssh host, ssh -p 22 user@host, etc.
extract_ssh_target() {
    local args=("$@")
    local target=""

    # Find the target (last argument that doesn't start with -)
    for arg in "${args[@]}"; do
        if [[ ! "$arg" =~ ^- ]]; then
            target="$arg"
        fi
    done

    echo "$target"
}

# Parse user@host or just host
parse_target() {
    local target="$1"
    local user=""
    local host=""

    if [[ "$target" =~ @ ]]; then
        user="${target%@*}"
        host="${target#*@}"
    else
        user="$USER"
        host="$target"
    fi

    # Output as JSON for jq processing
    echo "{\"user\": \"$user\", \"host\": \"$host\"}"
}

# Log to both stderr and log file
log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    echo "[$timestamp] [$level] $msg" | tee -a "$HOOK_LOG" >&2
}

# Add unknown host to pending queue
add_to_pending() {
    local host="$1"
    local user="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Check if state file exists
    if [[ ! -f "$STATE_FILE" ]]; then
        log "WARN" "State file not found, creating empty state"
        echo '{"version":"1.0","machine":"mac-studio","hosts":[],"pending":[]}' > "$STATE_FILE"
    fi

    # Add to pending queue using jq
    jq --arg ip "$host" \
       --arg user "$user" \
       --arg ts "$timestamp" \
       '.pending += [{
           "ip": $ip,
           "user": $user,
           "detectedAt": $ts,
           "attemptedBy": "claude-code"
       }]' "$STATE_FILE" > "$STATE_FILE.tmp"

    mv "$STATE_FILE.tmp" "$STATE_FILE"
    log "INFO" "Added $user@$host to pending queue"
}

# Check authorization state
check_authorization() {
    local host="$1"
    local user="$2"

    # Check if state file exists
    if [[ ! -f "$STATE_FILE" ]]; then
        log "WARN" "State file not found at $STATE_FILE"
        log "INFO" "Run SSHGuard app to initialize"
        return 1
    fi

    # Query state file with jq
    # Match by IP or hostname
    local state=$(jq -r --arg host "$host" \
        '.hosts[] | select(.ip == $host or .hostname == $host) | .state' \
        "$STATE_FILE" 2>/dev/null || echo "")

    case "$state" in
        "allowed")
            log "INFO" "✅ SSH to $user@$host is ALLOWED"

            # Update lastUsed timestamp
            local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            jq --arg host "$host" --arg ts "$timestamp" \
                '(.hosts[] | select(.ip == $host or .hostname == $host) | .lastUsed) |= $ts' \
                "$STATE_FILE" > "$STATE_FILE.tmp"
            mv "$STATE_FILE.tmp" "$STATE_FILE"

            return 0
            ;;
        "blocked")
            log "ERROR" "🔴 SSH to $user@$host is BLOCKED by SSHGuard"
            return 1
            ;;
        "ask")
            log "WARN" "⚪ SSH to $user@$host requires confirmation"
            log "INFO" "Open SSHGuard menu bar app to authorize"
            return 1
            ;;
        "")
            log "WARN" "❓ Unknown host: $user@$host"
            log "INFO" "Adding to pending queue - check SSHGuard app"
            add_to_pending "$host" "$user"
            return 1
            ;;
        *)
            log "ERROR" "Invalid state '$state' for $user@$host"
            return 1
            ;;
    esac
}

# Main execution
main() {
    # Check if this is an SSH command
    local cmd="$1"
    shift

    if [[ "$cmd" != "ssh" ]]; then
        # Not an SSH command, allow
        return 0
    fi

    # Extract and parse SSH target
    local target=$(extract_ssh_target "$@")

    if [[ -z "$target" ]]; then
        log "WARN" "Could not extract SSH target from: $*"
        return 0  # Allow if we can't parse
    fi

    local parsed=$(parse_target "$target")
    local user=$(echo "$parsed" | jq -r '.user')
    local host=$(echo "$parsed" | jq -r '.host')

    log "INFO" "SSH attempt: $user@$host"

    # Check authorization
    check_authorization "$host" "$user"
}

# Run main with all arguments
main "$@"
