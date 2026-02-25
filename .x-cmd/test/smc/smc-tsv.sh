#!/bin/bash
# SMC: TSV output format

for cmd in temp volt curr; do
    RESULT=$($BIN smc $cmd --tsv 2>&1)
    HEADER=$(echo "$RESULT" | head -1)
    
    if echo "$HEADER" | grep -q $'\t'; then
        pass "smc $cmd --tsv has tabs"
    else
        fail "smc $cmd --tsv missing tabs"
    fi
    
    if echo "$HEADER" | grep -qi "name.*value\|value.*name"; then
        pass "smc $cmd --tsv has name/value columns"
    else
        fail "smc $cmd --tsv missing columns"
    fi
done

RESULT=$($BIN smc all --tsv 2>&1)
if echo "$RESULT" | grep -q "# temperature"; then
    pass "smc all --tsv has section headers"
else
    fail "smc all --tsv missing section headers"
fi
