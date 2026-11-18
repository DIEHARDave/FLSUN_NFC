#!/bin/sh
# Copies the FF_NFC core (python/ffnfc) at a tag or commit into python/ffnfc
# and records it in FFNFC_VERSION. FLSUN_NFC's own code is python/flsunnfc;
# don't edit python/ffnfc here: fix FF_NFC, then sync.
#
#   tools/sync_ffnfc.sh v0.2.7            from GitHub
#   tools/sync_ffnfc.sh v0.2.7 ../FF_NFC  from a local clone
set -e
REF="${1:?usage: tools/sync_ffnfc.sh <tag or commit> [FF_NFC clone]}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$2"
TMP=""
if [ -z "$SRC" ]; then
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT
    git clone -q --filter=blob:none https://github.com/DIEHARDave/FF_NFC.git "$TMP/FF_NFC"
    SRC="$TMP/FF_NFC"
fi
COMMIT="$(git -C "$SRC" rev-parse "${REF}^{commit}")"
rm -rf "$REPO_DIR/python/ffnfc"
git -C "$SRC" archive "$COMMIT" python/ffnfc | tar -x -C "$REPO_DIR"
echo "$COMMIT $REF" > "$REPO_DIR/FFNFC_VERSION"
echo "python/ffnfc is now FF_NFC $REF ($COMMIT). Run the tests, then commit."
