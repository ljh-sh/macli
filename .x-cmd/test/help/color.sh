#!/bin/bash
# Help: No color when piped

RESULT=$($BIN 2>&1 | head -5)

if echo "$RESULT" | grep -q $'\x1b'; then
    fail "Help has ANSI codes when piped"
else
    pass "Help has no ANSI codes when piped"
fi

RESULT2=$($BIN 2>&1)
if echo "$RESULT2" | grep -q $'\x1b'; then
    pass "Help has ANSI codes in terminal"
else
    info "Help has no ANSI codes (may be dim terminal)"
fi
