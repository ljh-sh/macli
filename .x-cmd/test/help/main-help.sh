#!/bin/bash
# Help: Main command help

RESULT=$($BIN 2>&1)

if echo "$RESULT" | grep -q "NAME:"; then
    pass "Main help has NAME section"
else
    fail "Main help missing NAME section"
fi

if echo "$RESULT" | grep -q "SUBCOMMANDS:"; then
    pass "Main help has SUBCOMMANDS section"
else
    fail "Main help missing SUBCOMMANDS section"
fi

if echo "$RESULT" | grep -q "smc"; then
    pass "Main help lists smc command"
else
    fail "Main help missing smc command"
fi

if echo "$RESULT" | grep -q "cal"; then
    pass "Main help lists cal command"
else
    fail "Main help missing cal command"
fi
