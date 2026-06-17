#!/bin/bash
# battery: Battery parser and command output

section "Battery parser tests"
if swift run --package-path "$SCRIPT_DIR" batteryTests > /tmp/battery-tests.log 2>&1; then
    pass "batteryTests parser suite passed"
else
    cat /tmp/battery-tests.log
    fail "batteryTests parser suite failed"
fi

section "Battery command output"

BATT_OK=$($BIN battery 2>&1 | grep -c '"ok" : true' || echo 0)
if [[ $BATT_OK -ge 1 ]]; then
    pass "macli battery returns ok=true"
else
    fail "macli battery did not return ok=true"
fi

BATT_PRESENT=$($BIN battery 2>&1 | grep -c '"present"' || echo 0)
if [[ $BATT_PRESENT -ge 1 ]]; then
    pass "macli battery includes present field"
else
    fail "macli battery missing present field"
fi

BATT_TSV=$($BIN battery --tsv 2>&1 | grep -c $'\t' || echo 0)
if [[ $BATT_TSV -ge 2 ]]; then
    pass "macli battery --tsv produces tab-separated rows"
else
    fail "macli battery --tsv output malformed"
fi

BATT_PLIST=$($BIN battery --plist 2>&1 | file - | grep -c 'Apple binary property list\|XML 1.0' || echo 0)
if [[ $BATT_PLIST -ge 1 ]]; then
    pass "macli battery --plist produces XML plist"
else
    fail "macli battery --plist did not produce XML plist"
fi
