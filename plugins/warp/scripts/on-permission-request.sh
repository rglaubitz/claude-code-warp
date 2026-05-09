#!/bin/bash
# Hook script for Claude Code PermissionRequest event
# Sends a structured Warp notification when Claude needs permission to run a tool

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/should-use-structured.sh"

# No legacy equivalent for this hook
if ! should_use_structured; then
    exit 0
fi

source "$SCRIPT_DIR/build-payload.sh"

# Read hook input from stdin
INPUT=$(cat)

# Extract permission-request-specific fields
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null)
# Fallback to empty object if jq failed or returned empty
[ -z "$TOOL_INPUT" ] && TOOL_INPUT='{}'

# rglaubitz fork: terse summary format → "{emoji} {agent} {project}".
# Driven entirely by tool category; no command/filename preview, since
# the badge state is the signal and the text just identifies the
# session at a glance from the Warp banner / vertical-tab view.
case "$TOOL_NAME" in
    Bash|PowerShell)            EMOJI="🔧" ;;
    Edit|Write|MultiEdit|NotebookEdit) EMOJI="📝" ;;
    Read)                       EMOJI="📖" ;;
    Grep|Glob|LSP|ToolSearch)   EMOJI="🔍" ;;
    WebFetch|WebSearch)         EMOJI="🌐" ;;
    Task|Agent|SendMessage)     EMOJI="🤖" ;;
    AskUserQuestion)            EMOJI="❓" ;;
    *)                          EMOJI="🔧" ;;
esac

AGENT=$(detect_agent)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
PROJECT=""
[ -n "$CWD" ] && PROJECT=$(basename "$CWD")

SUMMARY="$EMOJI $AGENT $PROJECT"

BODY=$(build_payload "$INPUT" "permission_request" \
    --arg summary "$SUMMARY" \
    --arg tool_name "$TOOL_NAME" \
    --argjson tool_input "$TOOL_INPUT")

"$SCRIPT_DIR/warp-notify.sh" "warp://cli-agent" "$BODY"
