#!/bin/bash
# SMC: Sensor data validity

if [[ -n "$MACLI_SKIP_SENSOR_DATA" ]]; then
    info "Skipping hardware sensor data checks in CI environment"
    return 0 2>/dev/null || exit 0
fi

TEMPS=$($BIN smc temp 2>&1 | grep -c '"name"' || echo 0)
if [[ $TEMPS -gt 10 ]]; then
    pass "smc temp returns $TEMPS sensors (>10 expected)"
else
    fail "smc temp returns only $TEMPS sensors (expected >10)"
fi

VOLTS=$($BIN smc volt 2>&1 | grep -c '"name"' || echo 0)
if [[ $VOLTS -gt 0 ]]; then
    pass "smc volt returns $VOLTS sensors"
else
    fail "smc volt returns no sensors"
fi

CURRS=$($BIN smc curr 2>&1 | grep -c '"name"' || echo 0)
if [[ $CURRS -gt 0 ]]; then
    pass "smc curr returns $CURRS sensors"
else
    fail "smc curr returns no sensors"
fi

TEMP_VAL=$($BIN smc temp 2>&1 | grep -o '"value" : [0-9.]*' | head -1 | grep -o '[0-9.]*$')
if [[ -n "$TEMP_VAL" ]] && [[ $(echo "$TEMP_VAL > 0" | bc) -eq 1 ]]; then
    pass "Temperature values are numeric and positive"
else
    fail "Temperature values invalid"
fi
