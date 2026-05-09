#!/bin/bash
# Hook script for Claude Code Notification event (idle_prompt only)
# Sends a structured Warp notification when Claude has been idle

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/should-use-structured.sh"

# Legacy fallback for old Warp versions
if ! should_use_structured; then
    [ "$TERM_PROGRAM" = "WarpTerminal" ] && exec "$SCRIPT_DIR/legacy/on-notification.sh"
    exit 0
fi

source "$SCRIPT_DIR/build-payload.sh"

# Read hook input from stdin
INPUT=$(cat)

# Extract notification-specific fields
NOTIF_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"' 2>/dev/null)

# rglaubitz fork: terse "❓ {agent} {project}" summary, matching the
# permission_request format. The default-message ("Input needed") that
# upstream sends here was redundant with the orange badge state.
AGENT=$(detect_agent)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
PROJECT=""
[ -n "$CWD" ] && PROJECT=$(basename "$CWD")
SUMMARY="❓ $AGENT $PROJECT"

BODY=$(build_payload "$INPUT" "$NOTIF_TYPE" \
    --arg summary "$SUMMARY")

"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
