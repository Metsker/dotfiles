# Parakeet's TDT decoder writes each utterance as a standalone sentence. Strip the opening capital and
# the closing period so dictated fragments splice into a line already in progress.
text=$(cat)

# English keeps "I" and its contractions capitalized wherever they land, so leave that one word alone.
case $text in
  "I" | "I "* | "I'"*) ;;
  *) text=${text,} ;;
esac

printf '%s' "${text%.}"
