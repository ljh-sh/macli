#!/usr/bin/env sh

set -e

init_common() {
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

    if [ -n "$PROJECT_DIR" ]; then
        PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
    else
        PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    fi

    if [ -n "$OUT_DIR" ]; then
        OUT_DIR="$(cd "$OUT_DIR" && pwd)"
    else
        OUT_DIR="$PROJECT_DIR/.release-artifacts"
    fi

    BIN_NAME="${BIN_NAME:-macli}"
}

get_targets() {
    echo "arm64:darwin:arm64"
    echo "x86_64:darwin:x64"
}

get_current_arch() {
    uname -m
}

do_build() {
    local arch="$1"
    local os="$2"
    local arch_name="$3"
    local bin_name="${BIN_NAME:-macli}"
    local out_subdir="${os}-${arch_name}/bin"

    echo "Building for $os-$arch_name ($arch)..."

    cd "$PROJECT_DIR"

    rm -rf ".build/$arch-apple-macosx"
    swift build -c release --arch "$arch"

    local src=".build/$arch-apple-macosx/release/${bin_name}"
    local dst="$OUT_DIR/$out_subdir/${bin_name}"

    if [ ! -f "$src" ]; then
        echo "  Warning: $src not found, skipping"
        return 0
    fi

    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    chmod +x "$dst"
    
    local size=$(stat -f%z "$dst" 2>/dev/null || stat -c%s "$dst" 2>/dev/null || echo "unknown")
    echo "  -> $dst ($size bytes)"
}

build_all_targets() {
    rm -rf "$OUT_DIR"
    mkdir -p "$OUT_DIR"

    while IFS=: read -r arch os arch_name; do
        do_build "$arch" "$os" "$arch_name" || true
    done <<EOF
$(get_targets)
EOF

    echo ""
    echo "Done! Artifacts in: $OUT_DIR"
    echo ""
    ls -la "$OUT_DIR"/*/bin/ 2>/dev/null || true
}

show_usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Environment variables:"
    echo "  PROJECT_DIR       Project directory (default: script parent dir)"
    echo "  OUT_DIR           Output directory (default: PROJECT_DIR/.release-artifacts)"
    echo "  BIN_NAME          Binary name (default: macli)"
    echo ""
    echo "Commands:"
    echo "  all               Build all targets"
    echo "  <target>          Build specific target (see below)"
    echo ""
    echo "Targets:"
    echo "  darwin-arm64      arm64 (Apple Silicon)"
    echo "  darwin-x64        x86_64 (Intel Mac)"
    echo "  arm64             Alias for darwin-arm64"
    echo "  x86_64            Alias for darwin-x64"
    echo ""
    echo "Examples:"
    echo "  $0 all            # Build all targets"
    echo "  $0 darwin-arm64   # Build for Apple Silicon only"
}
