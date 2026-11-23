#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RELEASES_API="https://api.github.com/repos/alinkiot/alinkiot_dashboard/releases/latest"
DOWNLOAD_BASE="https://github.com/alinkiot/alinkiot_dashboard/releases/download"
DEFAULT_TAG="v0.0.2"

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

# 解压前端压缩包到 www/dist（先落到临时目录，成功后原子替换）。失败返回 1，不退出脚本。
install_frontend_archive() {
    if ! command -v unzip >/dev/null 2>&1; then
        echo "Required command not found: unzip" >&2
        return 1
    fi
    rm -rf "$WORK_DIR/extracted"
    unzip -q "$1" -d "$WORK_DIR/extracted" || return 1

    if [ -d "$WORK_DIR/extracted/dist" ]; then
        FRONTEND_DIR="$WORK_DIR/extracted/dist"
    else
        FRONTEND_DIR="$WORK_DIR/extracted"
    fi
    if [ ! -f "$FRONTEND_DIR/index.html" ]; then
        echo "Frontend archive does not contain index.html" >&2
        return 1
    fi

    STAGING_DIR=$(mktemp -d "$PROJECT_DIR/www/.dist.XXXXXX") || return 1
    if ! cp -R "$FRONTEND_DIR"/. "$STAGING_DIR"/; then
        rm -rf "$STAGING_DIR"; STAGING_DIR=; return 1
    fi
    chmod -R a+rX "$STAGING_DIR"
    rm -rf "$PROJECT_DIR/www/dist"
    if ! mv "$STAGING_DIR" "$PROJECT_DIR/www/dist"; then
        rm -rf "$STAGING_DIR"; STAGING_DIR=; return 1
    fi
    STAGING_DIR=
}

# 解析下载地址：FRONTEND_URL 覆盖优先，否则 API 取最新 tag，失败回退默认 tag。
# 成功时 stdout 输出 URL，提示信息走 stderr。
resolve_frontend_url() {
    if [ -n "${FRONTEND_URL:-}" ]; then
        echo ">>> Using FRONTEND_URL override: $FRONTEND_URL" >&2
        echo "$FRONTEND_URL"
        return 0
    fi
    LATEST_TAG=$(curl -fsSL --retry 3 --max-time 15 \
        -H 'Accept: application/vnd.github+json' "$RELEASES_API" 2>/dev/null \
        | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
        | sed 's/.*"\([^"]*\)"$/\1/') || LATEST_TAG=""
    if [ -n "$LATEST_TAG" ]; then
        echo ">>> Latest alinkiot_dashboard release: $LATEST_TAG" >&2
        echo "$DOWNLOAD_BASE/$LATEST_TAG/dist.zip"
    else
        echo ">>> Could not resolve latest tag, falling back to $DEFAULT_TAG" >&2
        echo "$DOWNLOAD_BASE/$DEFAULT_TAG/dist.zip"
    fi
}

# 联网获取最新前端并安装；任一步失败返回 1（供 install 回退、update 报错）。
fetch_and_install_online() {
    if ! command -v curl >/dev/null 2>&1; then
        echo "curl not available for online fetch" >&2
        return 1
    fi
    URL=$(resolve_frontend_url) || return 1
    echo ">>> Downloading frontend from $URL"
    curl -fL --retry 3 --max-time 180 -o "$WORK_DIR/frontend.zip" "$URL" || return 1
    install_frontend_archive "$WORK_DIR/frontend.zip"
}

if [ "$MODE" = "update" ]; then
    # update：强制联网更新，失败即退出
    if fetch_and_install_online; then
        echo ">>> Frontend updated"
    else
        echo "Frontend update failed." >&2
        exit 1
    fi
else
    # install：优先联网拉最新，失败回退仓库自带 dist.zip（离线兜底）
    if fetch_and_install_online; then
        echo ">>> Frontend installed from latest release"
    else
        echo ">>> Online fetch failed, falling back to bundled www/dist.zip" >&2
        if [ ! -f "$PROJECT_DIR/www/dist.zip" ]; then
            echo "www/dist.zip not found, cannot install offline." >&2
            exit 1
        fi
        echo ">>> Extracting bundled frontend from www/dist.zip"
        if ! install_frontend_archive "$PROJECT_DIR/www/dist.zip"; then
            echo "Bundled frontend extraction failed." >&2
            exit 1
        fi
    fi
fi

echo ">>> Starting AlinkIoT services"
if docker compose version >/dev/null 2>&1; then
    docker compose up -d
else
    docker-compose up -d
fi
