#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DERIVED="${ROOT}/.build/install"

if [[ -w /Applications ]]; then
  DEST="/Applications"
else
  DEST="${HOME}/Applications"
  mkdir -p "${DEST}"
fi

echo "Building LanguageTraining (Release)..."
xcodebuild \
  -project "${ROOT}/LanguageTraining.xcodeproj" \
  -scheme LanguageTraining \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "${DERIVED}" \
  -quiet \
  build

APP="${DERIVED}/Build/Products/Release/LanguageTraining.app"
if [[ ! -d "${APP}" ]]; then
  echo "Build succeeded but LanguageTraining.app was not found at ${APP}" >&2
  exit 1
fi

echo "Installing to ${DEST}/LanguageTraining.app"
ditto "${APP}" "${DEST}/LanguageTraining.app"
echo "Installed. You can open it from Launchpad, Spotlight, or:"
echo "  open ${DEST}/LanguageTraining.app"
open "${DEST}/LanguageTraining.app"
