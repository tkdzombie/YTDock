#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"
VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="v$VERSION"

say() { printf '\n\033[1;36m%s\033[0m\n' "$1"; }
die() { printf '\nERROR: %s\n' "$1" >&2; exit 1; }

[[ "$(uname -s)" == Darwin ]] || die "This helper is intended for macOS."
command -v git >/dev/null || die "git is required. Install Xcode Command Line Tools with: xcode-select --install"

if ! command -v gh >/dev/null; then
  echo "GitHub CLI (gh) is not installed."
  if command -v brew >/dev/null; then
    printf "Install it now with Homebrew? [Y/n] "
    read -r answer
    answer="${answer:-Y}"
    if [[ "$answer" == [Yy]* ]]; then
      brew install gh
    else
      die "Install GitHub CLI, then run this script again: brew install gh"
    fi
  else
    die "Install GitHub CLI from https://cli.github.com/ then run this script again."
  fi
fi

say "1/6 GitHub login"
if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "A browser window will open for GitHub sign-in. No token is stored in this project."
  gh auth login --hostname github.com --web --git-protocol https
fi
OWNER="$(gh api user --jq .login)"
echo "Signed in as: $OWNER"

say "2/6 Repository settings"
printf "Repository name [YTDock]: "
read -r REPO_NAME
REPO_NAME="${REPO_NAME:-YTDock}"
[[ "$REPO_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid repository name: $REPO_NAME"

printf "Visibility: public or private [public]: "
read -r VISIBILITY
VISIBILITY="${VISIBILITY:-public}"
[[ "$VISIBILITY" == "public" || "$VISIBILITY" == "private" ]] || die "Visibility must be public or private."
REPO="$OWNER/$REPO_NAME"

if gh repo view "$REPO" >/dev/null 2>&1; then
  die "GitHub repository $REPO already exists. Choose another name or use Scripts/publish-tag.sh for an existing repository."
fi

say "3/6 Local Git repository"
if [[ ! -d .git ]]; then
  git init -b main
fi

git checkout -B main >/dev/null 2>&1 || true

if [[ -z "$(git config user.name || true)" ]]; then
  DEFAULT_GIT_NAME="$OWNER"
  printf "Git commit name [%s]: " "$DEFAULT_GIT_NAME"
  read -r GIT_NAME
  GIT_NAME="${GIT_NAME:-$DEFAULT_GIT_NAME}"
  git config user.name "$GIT_NAME"
  echo "Using Git commit name: $GIT_NAME"
fi
if [[ -z "$(git config user.email || true)" ]]; then
  GH_EMAIL="$(gh api user --jq '.email // empty' 2>/dev/null || true)"
  DEFAULT_GIT_EMAIL="${GH_EMAIL:-$OWNER@users.noreply.github.com}"
  printf "Git commit email [%s]: " "$DEFAULT_GIT_EMAIL"
  read -r GIT_EMAIL
  GIT_EMAIL="${GIT_EMAIL:-$DEFAULT_GIT_EMAIL}"
  git config user.email "$GIT_EMAIL"
  echo "Using Git commit email: $GIT_EMAIL"
fi

git add -A
if ! git diff --cached --quiet; then
  git commit -m "Release YTDock $VERSION"
fi

say "4/6 Create GitHub repository and push source"
gh repo create "$REPO" \
  "--$VISIBILITY" \
  --description "A focused macOS video/audio download manager with a clean queue workflow." \
  --source=. \
  --remote=origin \
  --push

gh repo set-default "$REPO" >/dev/null 2>&1 || true

say "5/6 Create release tag"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Local tag $TAG already exists; using it."
else
  git tag -a "$TAG" -m "YTDock $VERSION"
fi
git push origin "$TAG"

say "6/6 GitHub Actions build and Release"
echo "Waiting for the macOS build triggered by $TAG ..."
RUN_ID=""
for _ in {1..40}; do
  RUN_ID="$(gh run list --repo "$REPO" --workflow build-macos.yml --limit 20 --json databaseId,headBranch,event --jq '.[] | select(.headBranch == "'"$TAG"'" and .event == "push") | .databaseId' | head -n 1)"
  [[ -n "$RUN_ID" ]] && break
  sleep 3
done

if [[ -z "$RUN_ID" ]]; then
  echo "The repository and tag were pushed successfully, but the workflow run was not visible yet."
  echo "Open Actions: https://github.com/$REPO/actions"
  exit 0
fi

echo "Workflow run: $RUN_ID"
if gh run watch "$RUN_ID" --repo "$REPO" --compact --exit-status; then
  RELEASE_URL="$(gh release view "$TAG" --repo "$REPO" --json url --jq .url 2>/dev/null || true)"
  echo
  echo "SUCCESS"
  echo "Repository: https://github.com/$REPO"
  [[ -n "$RELEASE_URL" ]] && echo "Release:    $RELEASE_URL"
else
  echo
  echo "The repository was created, but the macOS build failed."
  echo "Inspect the run with: gh run view $RUN_ID --repo $REPO --log-failed"
  exit 1
fi
