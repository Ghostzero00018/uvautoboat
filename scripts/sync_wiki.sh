#!/usr/bin/env bash
# Sync wiki/*.md from this repo to the published GitHub Wiki.
#
# Usage:
#   scripts/sync_wiki.sh                     # default commit message
#   scripts/sync_wiki.sh "Custom message"    # custom commit message
#
# Side effects:
#   - Clones the wiki repo to ../uvautoboat.wiki/ (sibling to this repo) on first run.
#   - Pushes to origin/master on the wiki repo.
#   - Skips UPLOAD_INSTRUCTIONS.md (stays in the main repo only).
#
# Prerequisites:
#   - SSH access to git@github.com configured (see ~/.ssh/config for the 443 fallback if port 22 is blocked).

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
WIKI_SRC="$REPO_ROOT/wiki"
WIKI_CLONE="$REPO_ROOT/../uvautoboat.wiki"
WIKI_REMOTE="git@github.com:Ghostzero00018/uvautoboat.wiki.git"
EXCLUDE_FILE="UPLOAD_INSTRUCTIONS.md"
MSG="${1:-Sync wiki from main repo}"

# 1. Ensure wiki clone exists alongside the main repo
if [ ! -d "$WIKI_CLONE/.git" ]; then
    echo "Wiki clone not found. Cloning to $WIKI_CLONE ..."
    git clone "$WIKI_REMOTE" "$WIKI_CLONE"
fi

cd "$WIKI_CLONE"

# 2. Pull latest to avoid non-fast-forward pushes
git pull --rebase origin master

# 3. Clobber-copy every source page, then strip the excluded meta file
cp "$WIKI_SRC"/*.md .
rm -f "$EXCLUDE_FILE"

# 4. Bail cleanly if the copy produced no tracked diff
if [ -z "$(git status --porcelain)" ]; then
    echo "No wiki changes to sync."
    exit 0
fi

# 5. Commit and push
git add -A
git commit -m "$MSG"
git push origin master

echo "Wiki synced: $MSG"
