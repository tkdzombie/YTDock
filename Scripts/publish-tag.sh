#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"
command -v git >/dev/null || { echo "git is required" >&2; exit 2; }
command -v gh >/dev/null || { echo "GitHub CLI (gh) is required" >&2; exit 2; }
gh auth status -h github.com >/dev/null 2>&1 || { echo "Run: gh auth login" >&2; exit 2; }

VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="v$VERSION"
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit your changes before publishing." >&2
  exit 3
fi

git fetch origin main --tags
LOCAL_HEAD="$(git rev-parse HEAD)"
REMOTE_HEAD="$(git rev-parse origin/main)"
[[ "$LOCAL_HEAD" == "$REMOTE_HEAD" ]] || {
  echo "Local main and origin/main differ. Push/pull before publishing." >&2
  exit 3
}

if git rev-parse "$TAG" >/dev/null 2>&1 || git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists. Bump VERSION before publishing another release." >&2
  exit 4
fi

git tag -a "$TAG" -m "YTDock $VERSION"
git push origin "$TAG"
echo "Pushed $TAG. GitHub Actions will build and publish the Release."

RUN_ID=""
for _ in {1..40}; do
  RUN_ID="$(gh run list --repo "$REPO" --workflow build-macos.yml --limit 20 --json databaseId,headBranch,event --jq '.[] | select(.headBranch == "'"$TAG"'" and .event == "push") | .databaseId' | head -n 1)"
  [[ -n "$RUN_ID" ]] && break
  sleep 3
done

if [[ -n "$RUN_ID" ]]; then
  gh run watch "$RUN_ID" --repo "$REPO" --compact --exit-status
  gh release view "$TAG" --repo "$REPO" --web || true
else
  echo "Workflow not visible yet. Check: https://github.com/$REPO/actions"
fi
