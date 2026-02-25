#!/bin/bash
# Build: Compressed size (tar.xz)

TMPDIR=$(mktemp -d)
tar -cJf "$TMPDIR/macli.tar.xz" -C "$BUILD_DIR" macli 2>/dev/null
XZ_SIZE=$(stat -f%z "$TMPDIR/macli.tar.xz")
XZ_SIZE_KB=$((XZ_SIZE / 1024))
rm -rf "$TMPDIR"

info "Compressed: ${XZ_SIZE_KB}KB ($XZ_SIZE bytes)"

if [[ $XZ_SIZE_KB -lt 250 ]]; then
    pass "tar.xz under 250KB"
else
    fail "tar.xz too large: ${XZ_SIZE_KB}KB (limit: 250KB)"
fi
