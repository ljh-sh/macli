#!/bin/bash
# SMC: JSON output format

for cmd in temp volt curr all; do
    RESULT=$($BIN smc $cmd 2>&1)
    
    if echo "$RESULT" | grep -q '"ok"'; then
        pass "smc $cmd JSON has 'ok'"
    else
        fail "smc $cmd JSON missing 'ok'"
    fi
    
    if echo "$RESULT" | grep -q '"source"'; then
        pass "smc $cmd JSON has 'source'"
    else
        fail "smc $cmd JSON missing 'source'"
    fi
done
