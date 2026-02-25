#!/bin/bash
# Help: smc86 command help

RESULT=$($BIN smc86 2>&1)

if echo "$RESULT" | grep -q "Intel"; then
    pass "smc86 help mentions Intel"
else
    fail "smc86 help missing Intel"
fi

if echo "$RESULT" | grep -q "fans"; then
    pass "smc86 has fans subcommand"
else
    fail "smc86 missing fans subcommand"
fi
