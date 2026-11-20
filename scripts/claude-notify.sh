# Claude Code Stop and PermissionRequest hook: sends finished turns and permission prompts to a Telegram bot.

input=$(cat)
# A turn that ends on running background agents is a pause - they wake the session again.
agents=$(jq '[.background_tasks[]? | select(.type != "shell" and .type != "monitor")] | length' <<<"$input")
[ "$agents" = 0 ] || exit 0
# Off unless the notify mod's /notify left a flag for this session; it stays until /notify again.
session=$(jq -r '.session_id // ""' <<<"$input")
[ -e "${XDG_RUNTIME_DIR:-/tmp}/claude-notify/$session" ] || exit 0

env_file="$HOME/.claude/telegram-notify.env"
[ -r "$env_file" ] || exit 0
# shellcheck source=/dev/null
. "$env_file"

event=$(jq -r '.hook_event_name // ""' <<<"$input")
cwd=$(jq -r '.cwd // ""' <<<"$input")
text="$HOSTNAME: ${cwd/#"$HOME"/\~}"

if [ "$event" = Stop ]; then
  last=$(jq -r '.last_assistant_message // ""
    | if length > 1500 then .[:1500] + "..." else . end' <<<"$input")
  text+=$'\nDone.\n\n'"$last"
else
  text+=$'\n'"Claude needs your permission to use $(jq -r '.tool_name // "a tool"' <<<"$input")."
fi

curl -fsS --max-time 10 -o /dev/null \
  --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \
  --data-urlencode "text=$text" \
  "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"
