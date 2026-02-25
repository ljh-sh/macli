#!/bin/bash
# Help: smc command help

RESULT=$($BIN smc 2>&1)

if echo "$RESULT" | grep -q "Apple Silicon"; then
    pass "smc help mentions Apple Silicon"
else
    fail "smc help missing Apple Silicon"
fi

if echo "$RESULT" | grep -q "TLDR:"; then
    pass "smc has TLDR section"
else
    fail "smc missing TLDR section"
fi

if echo "$RESULT" | grep -q "macli smc all"; then
    pass "smc TLDR has example command"
else
    fail "smc TLDR missing example"
fi
