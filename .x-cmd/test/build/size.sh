#!/bin/bash
# Build: Binary size verification

SIZE=$(stat -f%z "$BIN")
SIZE_KB=$((SIZE / 1024))

info "Binary size: ${SIZE_KB}KB ($SIZE bytes)"

if [[ $SIZE_KB -lt 700 ]]; then
    pass "Binary under 700KB"
else
    fail "Binary too large: ${SIZE_KB}KB (limit: 700KB)"
fi
