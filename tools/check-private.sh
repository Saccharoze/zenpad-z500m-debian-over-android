#!/bin/bash
# check-private.sh: fail if a folder holds private data or files that must never be published.
#
# Usage: check-private.sh <dir> [patterns-file ...]
#   Without pattern files, it uses $CHECK_PRIVATE_PATTERNS (colon-separated list of files),
#   then ~/.config/check-private/patterns.txt.
#
# A patterns file holds one extended regex per line ('#' starts a comment), matched
# case-insensitively. Keep pattern files OUTSIDE the repo: a checker that lists your
# serial number or email would publish them.
#
# Checks:
#   1. forbidden file types (disk images, APKs, archives, keys, dex)
#   2. files over 5 MB (almost always a binary that slipped in)
#   3. private strings in every text file
#   4. metadata of PNG/JPEG images (text chunks, EXIF); pixels still need a human look
#   5. any other binary file is reported, so nothing passes unseen
# Exit code: 0 = clean, 1 = something found, 2 = usage error.
set -u
DIR=${1:?usage: check-private.sh <dir> [patterns-file ...]}
shift
[ -d "$DIR" ] || { echo "not a directory: $DIR" >&2; exit 2; }

if [ $# -gt 0 ]; then PATS=("$@")
elif [ -n "${CHECK_PRIVATE_PATTERNS:-}" ]; then IFS=: read -r -a PATS <<< "$CHECK_PRIVATE_PATTERNS"
else PATS=("$HOME/.config/check-private/patterns.txt")
fi
for p in "${PATS[@]}"; do [ -r "$p" ] || { echo "patterns file not readable: $p" >&2; exit 2; }; done

RULES=$(mktemp); trap 'rm -f "$RULES"' EXIT
cat "${PATS[@]}" | grep -vE '^[[:space:]]*(#|$)' > "$RULES"
fail=0
report() { echo "== $1"; printf '%s\n' "$2" | sed 's/^/   /'; fail=1; }

# 1. forbidden file types
bad=$(find "$DIR" -type f -not -path '*/.git/*' \( -iname '*.img' -o -iname '*.apk' -o -iname '*.zip' \
  -o -iname '*.tar' -o -iname '*.tar.*' -o -iname '*.tgz' -o -iname '*.xz' -o -iname '*.dex' -o -iname '*.bin' \
  -o -iname '*.pem' -o -iname '*.der' -o -iname '*.key' -o -iname '*.jks' -o -iname '*.keystore' -o -iname '*.p12' \))
[ -n "$bad" ] && report "FORBIDDEN FILE TYPES" "$bad"

# 2. big files
big=$(find "$DIR" -type f -size +5M -not -path '*/.git/*')
[ -n "$big" ] && report "FILES OVER 5 MB" "$big"

# 3. private strings in text files (-I skips binaries)
hits=$(grep -rnIiE -f "$RULES" --exclude-dir=.git "$DIR" | cut -c1-220)
[ -n "$hits" ] && report "PRIVATE STRINGS" "$hits"

# 4 + 5. binaries: image metadata is checked, anything else is reported
while IFS= read -r -d '' f; do
  grep -qI . "$f" 2>/dev/null && continue            # text file: already checked in step 3
  [ -s "$f" ] || continue                            # empty file
  case "${f,,}" in
    *.png|*.jpg|*.jpeg|*.webp)
      meta=$(python3 -I -c '
import sys
from PIL import Image
im = Image.open(sys.argv[1])
for k, v in im.info.items():
    if isinstance(v, (str, bytes)): print(k, v if isinstance(v, str) else v[:200])
for k, v in im.getexif().items(): print("exif", k, v)
' "$f" 2>&1)
      m=$(printf '%s\n' "$meta" | grep -iE -f "$RULES")
      [ -n "$m" ] && report "IMAGE METADATA: $f" "$m" ;;
    *) report "UNEXPECTED BINARY" "$f" ;;
  esac
done < <(find "$DIR" -type f -not -path '*/.git/*' -size -5M -print0)

n=$(find "$DIR" -type f -not -path '*/.git/*' | wc -l)
if [ $fail = 0 ]; then echo "check-private: CLEAN ($n files)"; else echo "check-private: FAILED ($n files)"; fi
exit $fail
