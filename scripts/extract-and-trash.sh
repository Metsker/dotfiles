# File manager action: extract each archive next to itself, then trash it only if that succeeded.

failed=""
for archive in "$@"; do
  # -r renames rather than overwrites; closed stdin turns a password prompt into a failure, not a hang.
  if ! unar -q -r -o "$(dirname "$archive")" "$archive" </dev/null >/dev/null 2>&1; then
    failed="$failed$(basename "$archive"): not extracted, kept"$'\n'
  elif ! gio trash -- "$archive" 2>/dev/null; then
    failed="$failed$(basename "$archive"): extracted, not trashed"$'\n'
  fi
done

if [ -n "$failed" ]; then
  notify-send --app-name=extract-and-trash --icon=dialog-error "Extract and trash archive" "${failed%$'\n'}"
fi
