#!/usr/bin/env bash
# One-time Flathub submission script.
#
# Prerequisites:
#   - gh CLI authenticated (gh auth login)
#   - The flathub-update GitHub Action has run at least once
#     (so packaging/flatpak/flathub/ directory exists on the flathub branch)
#
# Usage:
#   ./scripts/submit-to-flathub.sh
#
set -euo pipefail

APP_ID="io.github.noah_peeters.ChimpStackr"
FLATHUB_REPO="flathub/flathub"

echo "=== ChimpStackr Flathub Submission ==="
echo ""
echo "This script will:"
echo "  1. Fork flathub/flathub to your account"
echo "  2. Create a branch with your manifest"
echo "  3. Open a PR for Flathub review"
echo ""

# Check prerequisites
if ! gh auth status &>/dev/null; then
    echo "Error: gh CLI not authenticated. Run: gh auth login"
    exit 1
fi

GITHUB_USER=$(gh api user --jq '.login')
echo "Logged in as: $GITHUB_USER"

# Check that flathub files exist
if ! git show flathub:packaging/flatpak/flathub/${APP_ID}.yml &>/dev/null; then
    echo "Error: Flathub manifest not found on the 'flathub' branch."
    echo "Run the 'Update Flathub' GitHub Action first, or push a new tag."
    exit 1
fi

echo ""
echo "Step 1: Forking flathub/flathub..."
gh repo fork "$FLATHUB_REPO" --clone=false 2>/dev/null || echo "Fork already exists"

echo ""
echo "Step 2: Preparing submission files..."
TMPDIR=$(mktemp -d)
cd "$TMPDIR"

gh repo clone "${GITHUB_USER}/flathub" -- --branch=new-pr --single-branch
cd flathub
git checkout -b "add-${APP_ID}"

# Copy all files from the flathub branch
git -C "$OLDPWD" show "flathub:packaging/flatpak/flathub/${APP_ID}.yml" > "${APP_ID}.yml"
git -C "$OLDPWD" show "flathub:packaging/flatpak/flathub/python-deps.json" > "python-deps.json"
git -C "$OLDPWD" show "flathub:packaging/flatpak/flathub/flathub.json" > "flathub.json"
git -C "$OLDPWD" show "flathub:packaging/flatpak/flathub/${APP_ID}.desktop" > "${APP_ID}.desktop"
git -C "$OLDPWD" show "flathub:packaging/flatpak/flathub/${APP_ID}.metainfo.xml" > "${APP_ID}.metainfo.xml"

git add .
git commit -m "Add ${APP_ID}"
git push origin "add-${APP_ID}"

echo ""
echo "Step 3: Creating PR..."
PR_URL=$(gh pr create \
    --repo "$FLATHUB_REPO" \
    --base "new-pr" \
    --title "Add ${APP_ID}" \
    --body "$(cat <<'BODY'
## New app submission: ChimpStackr

**App ID:** `io.github.noah_peeters.ChimpStackr`
**Homepage:** https://github.com/noah-peeters/ChimpStackr
**License:** GPL-3.0-or-later

ChimpStackr is a free, multi-platform focus stacking application for combining
multiple photos taken at different focus distances into a single sharp image.

**Features:**
- Multiple stacking algorithms (Laplacian pyramid, weighted average, depth map, exposure fusion)
- Automatic image alignment with ECC and DFT registration
- RAW image support (CR2, NEF, ARW, DNG, etc.)
- GPU acceleration via CUDA (optional)
- CLI for batch processing

**Manifest details:**
- Runtime: org.kde.Platform 6.9
- Base: io.qt.PySide.BaseApp 6.9
- Native deps built from source: FFTW3 (float+double), LibRaw
- Python deps via offline pip sources
- Auto-updates via x-checker-data on git tags
BODY
)")

echo ""
echo "=== Done! ==="
echo "PR created: $PR_URL"
echo ""
echo "Next steps:"
echo "  1. Comment 'bot, build' on the PR to trigger a test build"
echo "  2. Wait for Flathub reviewers (~1-2 weeks)"
echo "  3. Once merged, your app appears on Flathub!"
echo ""
echo "After acceptance, updates are automatic via x-checker-data."

# Cleanup
rm -rf "$TMPDIR"
