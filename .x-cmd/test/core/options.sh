#!/bin/bash
# Core: Subcommand options

for cmd in temp volt curr power fans batt all; do
    RESULT=$($BIN smc $cmd --help 2>&1)
    
    if echo "$RESULT" | grep -q -- "--tsv"; then
        pass "smc $cmd has --tsv option"
    else
        fail "smc $cmd missing --tsv option"
    fi
done
