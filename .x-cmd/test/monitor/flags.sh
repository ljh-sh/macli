#!/bin/bash
# Monitor: flag handling

RESULT=$($BIN monitor --help 2>&1)
if echo "$RESULT" | grep -q -- "--metric"; then
    pass "monitor help shows --metric option"
else
    fail "monitor help missing --metric option"
fi

if echo "$RESULT" | grep -q -- "--metrics"; then
    pass "monitor help mentions --metrics legacy alias"
else
    fail "monitor help missing --metrics alias"
fi

RESULT=$($BIN monitor --unknown-flag 2>&1 || true)
if echo "$RESULT" | grep -q '"ok" *: *false'; then
    pass "monitor rejects unknown flag"
else
    fail "monitor did not reject unknown flag"
fi
if echo "$RESULT" | grep -q "unknown flag: --unknown-flag"; then
    pass "unknown flag error names the flag"
else
    fail "unknown flag error does not name the flag"
fi

# Sensor-dependent assertions are skipped in CI where MACLI_SKIP_SENSOR_DATA=1,
# because the HID sensor bridge returns no data and monitor yields empty columns.
if [ "${MACLI_SKIP_SENSOR_DATA:-}" = "1" ]; then
    info "skipping sensor-dependent monitor filter tests in CI (MACLI_SKIP_SENSOR_DATA=1)"
    exit 0
fi

RESULT=$($BIN monitor --count 1 --metric smc_temp 2>&1)
HEADER=$(echo "$RESULT" | head -1)
if echo "$HEADER" | grep -q $'\tsmc_temp_'; then
    pass "--metric smc_temp filters to smc_temp columns"
else
    fail "--metric smc_temp did not filter columns"
fi
if echo "$HEADER" | grep -q "smc_volt_"; then
    fail "--metric smc_temp included smc_volt columns"
else
    pass "--metric smc_temp excluded other sources"
fi

# Legacy alias still works
RESULT=$($BIN monitor --count 1 --metrics battery_power 2>&1)
HEADER=$(echo "$RESULT" | head -1)
if echo "$HEADER" | grep -q $'\tbattery_power_' && ! echo "$HEADER" | grep -q "smc_temp_"; then
    pass "--metrics alias still filters sources"
else
    fail "--metrics alias did not filter sources"
fi

# Prefix filtering within a source
RESULT=$($BIN monitor --count 1 --metric smc_temp_PMU_tdie1 2>&1)
HEADER=$(echo "$RESULT" | head -1)
COLS=$(echo "$HEADER" | tr '\t' '\n' | grep -c "smc_temp_PMU_tdie1" || true)
if [ "$COLS" -ge 1 ]; then
    pass "--metric supports column-prefix filter"
else
    fail "--metric prefix filter returned no columns"
fi
