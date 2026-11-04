# Claude Code Notification hook: sends idle and permission prompts to a Telegram bot.

input=$(cat)
# Off unless the notify mod's /notify left a flag for this session.
session=$(jq -r '.session_id // ""' <<<"$input")
[ -f "${XDG_RUNTIME_DIR:-/tmp}/claude-notify/$session" ] || exit 0

env_file="$HOME/.claude/telegram-notify.env"
[ -r "$env_file" ] || exit 0
# shellcheck source=/dev/null
. "$env_file"

kind=$(jq -r '.notification_type // ""' <<<"$input")
cwd=$(jq -r '.cwd // ""' <<<"$input")
transcript=$(jq -r '.transcript_path // ""' <<<"$input")
text="$HOSTNAME: ${cwd/#"$HOME"/\~}"

if [ "$kind" = idle_prompt ] && [ -r "$transcript" ]; then
  # The hook gets no reply text, so the last one comes from the transcript.
  last=$(tac "$transcript" | jq -rn 'first(inputs | select(.type == "assistant")
    | .message.content[]? | select(.type == "text") | .text)
    | if length > 1500 then .[:1500] + "..." else . end' || true)
  text+=$'\nDone.\n\n'"$last"
else
  text+=$'\n'"$(jq -r '.message // "Claude needs you."' <<<"$input")"
fi

curl -fsS --max-time 10 -o /dev/null \
  --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \
  --data-urlencode "text=$text" \
  "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"
