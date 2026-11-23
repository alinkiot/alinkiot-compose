#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
FRONTEND_URL=${FRONTEND_URL:-https://github.com/alinkiot/alinkiot_dashboard/releases/download/v0.0.2/dist.zip}

MODE=install
if [ "${1:-}" = "update" ]; then
    MODE=update
fi

need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Required command not found: $1" >&2
        exit 1
    fi
}

need_cmd docker
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
    if [ -n "$STAGING_DIR" ] && [ -d "$STAGING_DIR" ]; then
        rm -rf "$STAGING_DIR"
    fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# 解压前端压缩包到 www/dist（先落到临时目录，成功后原子替换）
install_frontend_archive() {
    need_cmd unzip
    unzip -q "$1" -d "$WORK_DIR/extracted"

    if [ -d "$WORK_DIR/extracted/dist" ]; then
        FRONTEND_DIR="$WORK_DIR/extracted/dist"
    else
        FRONTEND_DIR="$WORK_DIR/extracted"
    fi

    if [ ! -f "$FRONTEND_DIR/index.html" ]; then
        echo "Frontend archive does not contain index.html" >&2
        exit 1
    fi

    STAGING_DIR=$(mktemp -d "$PROJECT_DIR/www/.dist.XXXXXX")
    cp -R "$FRONTEND_DIR"/. "$STAGING_DIR"/
    chmod -R a+rX "$STAGING_DIR"
    rm -rf "$PROJECT_DIR/www/dist"
    mv "$STAGING_DIR" "$PROJECT_DIR/www/dist"
    STAGING_DIR=
}

if [ "$MODE" = "update" ]; then
    # update：从 HTTP 下载最新前端并覆盖
    echo ">>> Updating frontend from $FRONTEND_URL"
    need_cmd curl
    curl -fL --retry 3 -o "$WORK_DIR/frontend.zip" "$FRONTEND_URL"
    install_frontend_archive "$WORK_DIR/frontend.zip"
    echo ">>> Frontend updated from $FRONTEND_URL"
else
    # 默认（install）：每次都从仓库自带 dist.zip 解压覆盖，全程不联网
    if [ ! -f "$PROJECT_DIR/www/dist.zip" ]; then
        echo "www/dist.zip not found. Run with 'update' to download." >&2
        exit 1
    fi
    echo ">>> Extracting bundled frontend from www/dist.zip"
    install_frontend_archive "$PROJECT_DIR/www/dist.zip"
fi

echo ">>> Starting AlinkIoT services"
if docker compose version >/dev/null 2>&1; then
    docker compose up -d
else
    docker-compose up -d
fi
