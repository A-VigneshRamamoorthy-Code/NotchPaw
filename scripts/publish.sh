#!/bin/bash
# Publishes NotchPaw to GitHub: creates the repo, pushes, builds a Release with
# the DMG attached, and adds discovery topics.
#
# PREREQUISITES (one-time, must be done by you — they need your credentials):
#   1. Install GitHub CLI:   https://cli.github.com  (or: brew install gh)
#   2. Authenticate:         gh auth login
#
# Then just run:  ./scripts/publish.sh
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

APP_NAME="NotchPaw"
VERSION="${VERSION:-v1.0.0}"
DMG_FILE="$ROOT/NotchPaw.dmg"

# --- Prerequisite checks -----------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
    echo "✗ GitHub CLI (gh) is not installed."
    echo "  Install it from https://cli.github.com (or 'brew install gh'), then re-run."
    exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
    echo "✗ Not logged in to GitHub. Run:  gh auth login"
    exit 1
fi
GITHUB_USERNAME="$(gh api user --jq .login)"
echo "▶ Publishing as @$GITHUB_USERNAME"

# --- Ensure the DMG exists ---------------------------------------------------
if [ ! -f "$DMG_FILE" ]; then
    echo "▶ DMG missing — building it…"
    ./scripts/build_app.sh release
    ./scripts/make_dmg.sh
fi

# --- Stage 1: create the repo & push (skip if origin already exists) ---------
if git remote get-url origin >/dev/null 2>&1; then
    echo "▶ Remote 'origin' already set — pushing…"
    git push -u origin HEAD
else
    echo "▶ Creating public repo and pushing…"
    gh repo create "$APP_NAME" --public --source=. --remote=origin --push
fi

# --- Stage 2: create the Release and upload the DMG --------------------------
if gh release view "$VERSION" >/dev/null 2>&1; then
    echo "▶ Release $VERSION exists — uploading DMG (clobbering)…"
    gh release upload "$VERSION" "$DMG_FILE" --clobber
else
    echo "▶ Creating release $VERSION…"
    gh release create "$VERSION" "$DMG_FILE" \
        --title "$APP_NAME $VERSION - Initial Release 🐾" \
        --notes "🚀 First release of NotchPaw

## What is it?
A playful critter that lives under your MacBook notch and tries to catch your
cursor — fluid, springy, animal-like motion. 7 styles incl. cat, fox & tails.
0% CPU when idle, no Dock or menu-bar icon.

## Install
Download the DMG, open it, and drag NotchPaw into Applications.

⚠️ First launch: Right-click → Open."
fi

# --- Stage 3: discovery topics ----------------------------------------------
echo "▶ Adding topics…"
gh repo edit \
    --add-topic macos \
    --add-topic mac-app \
    --add-topic notch \
    --add-topic menubar \
    --add-topic productivity \
    --add-topic swift

echo ""
echo "✅ Published: https://github.com/$GITHUB_USERNAME/$APP_NAME"
echo "   Release:   https://github.com/$GITHUB_USERNAME/$APP_NAME/releases/latest"
echo ""
echo "Next: post the copy in launch_posts/ and add a screenshot/GIF to the README."
