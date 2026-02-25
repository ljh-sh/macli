#!/bin/bash
# SMC86: JSON output format

for cmd in temp fans volt curr power all; do
    RESULT=$($BIN smc86 $cmd 2>&1)
    
    if echo "$RESULT" | grep -q '"ok"'; then
        pass "smc86 $cmd JSON has 'ok'"
    else
        fail "smc86 $cmd JSON missing 'ok'"
    fi
done
