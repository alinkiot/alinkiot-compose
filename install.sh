#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
FRONTEND_URL=${FRONTEND_URL:-https://github.com/alinkiot/alinkiot_dashboard/releases/download/v0.0.2/dist.zip}

for command in curl unzip docker; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Required command not found: $command" >&2
        exit 1
    fi
done

if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
    echo "Docker Compose is required (docker compose or docker-compose)." >&2
    exit 1
fi

cd "$PROJECT_DIR"
mkdir -p www
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/alinkiot-install.XXXXXX")
STAGING_DIR=

cleanup() {
    rm -rf "$WORK_DIR"
    if [ -d "$STAGING_DIR" ]; then
        rm -rf "$STAGING_DIR"
    fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

STAGING_DIR=$(mktemp -d "$PROJECT_DIR/www/.dist.XXXXXX")

echo ">>> Downloading frontend from $FRONTEND_URL"
curl -fL --retry 3 -o "$WORK_DIR/frontend.zip" "$FRONTEND_URL"
unzip -q "$WORK_DIR/frontend.zip" -d "$WORK_DIR/extracted"

if [ -d "$WORK_DIR/extracted/dist" ]; then
    FRONTEND_DIR="$WORK_DIR/extracted/dist"
else
    FRONTEND_DIR="$WORK_DIR/extracted"
fi

if [ ! -f "$FRONTEND_DIR/index.html" ]; then
    echo "Frontend archive does not contain index.html" >&2
    exit 1
fi

cp -R "$FRONTEND_DIR"/. "$STAGING_DIR"/
chmod -R a+rX "$STAGING_DIR"
rm -rf "$PROJECT_DIR/www/dist"
mv "$STAGING_DIR" "$PROJECT_DIR/www/dist"
STAGING_DIR=

echo ">>> Starting AlinkIoT services"
if docker compose version >/dev/null 2>&1; then
    docker compose up -d
else
    docker-compose up -d
fi
