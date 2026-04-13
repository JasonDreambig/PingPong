#!/bin/sh
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DEPLOY_DIR="$PROJECT_DIR/deploy_muos"
GITHUB_OUT_DIR="$PROJECT_DIR/release/github"
STORE_OUT_DIR="$PROJECT_DIR/release/store"
STAGE_DIR="$PROJECT_DIR/release/.stage"
VERSION="${1:-$(date +%Y%m%d-%H%M%S)}"
BASE_NAME="PingPong-$VERSION"
GITHUB_ZIP="$GITHUB_OUT_DIR/$BASE_NAME-github.zip"
STORE_ZIP="$STORE_OUT_DIR/$BASE_NAME-store.zip"

if [ ! -d "$DEPLOY_DIR" ]; then
  echo "Missing deploy_muos/ payload. Export the game first."
  exit 1
fi

for required in PingPong.sh PingPong.pck godot_runtime; do
  if [ ! -e "$DEPLOY_DIR/$required" ]; then
    echo "deploy_muos/ is missing $required."
    exit 1
  fi
done

mkdir -p "$GITHUB_OUT_DIR" "$STORE_OUT_DIR" "$STAGE_DIR"
rm -rf "$STAGE_DIR/$BASE_NAME"
mkdir -p "$STAGE_DIR/$BASE_NAME"
rm -f "$GITHUB_ZIP" "$STORE_ZIP"

cp "$DEPLOY_DIR/PingPong.sh" "$STAGE_DIR/$BASE_NAME/"
cp "$DEPLOY_DIR/PingPong.pck" "$STAGE_DIR/$BASE_NAME/"
if [ -d "$DEPLOY_DIR/godot_runtime" ]; then
  cp -R "$DEPLOY_DIR/godot_runtime" "$STAGE_DIR/$BASE_NAME/"
else
  cp "$DEPLOY_DIR/godot_runtime" "$STAGE_DIR/$BASE_NAME/"
fi

cd "$STAGE_DIR/$BASE_NAME"
zip -r "$GITHUB_ZIP" .
zip -r "$STORE_ZIP" .

rm -rf "$STAGE_DIR/$BASE_NAME"

echo "Created:"
echo "  $GITHUB_ZIP"
echo "  $STORE_ZIP"
