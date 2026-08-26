# Parakeet's TDT decoder writes each utterance as a standalone sentence. Strip the opening capital and
# the closing period, and end with a space, so dictated fragments splice into a line already in progress.
text=$(cat)
text=${text%.}

# Silence transcribes as an empty string, where a lone trailing space would still be typed.
[ -n "$text" ] || exit 0

# English keeps "I" and its contractions capitalized wherever they land, so leave that one word alone.
case $text in
  "I" | "I "* | "I'"*) ;;
  *) text=${text,} ;;
esac

printf '%s ' "$text"
