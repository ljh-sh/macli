# macli Development Docs

## Build

```bash
swift build -c release
```

Output: `.build/release/macli`

## Testing

### Run All Tests

```bash
./runtest
```

### Run Single Test

```bash
./runtest size
./runtest smc-json
```

### List All Tests

```bash
./runtest --help
```

### Test Directory Structure

```
.x-cmd/test/
├── build/          # Build-related tests
│   ├── size.sh     # Binary size (< 700KB)
│   └── compress.sh # tar.xz size (< 250KB)
├── core/           # Core functionality tests
│   └── options.sh  # Subcommand options
├── help/           # Help output tests
│   ├── main-help.sh
│   ├── smc-help.sh
│   ├── smc86-help.sh
│   └── color.sh    # Terminal color detection
├── smc/            # Apple Silicon sensor tests
│   ├── smc-json.sh
│   ├── smc-tsv.sh
│   └── sensor-data.sh
└── smc86/          # Intel SMC tests
    └── smc86-json.sh
```

### Adding New Tests

Create a `.sh` file in `.x-cmd/test/<category>/`:

```bash
#!/bin/bash

RESULT=$($BIN your-command 2>&1)

if echo "$RESULT" | grep -q "expected"; then
    pass "Test passed"
else
    fail "Test failed"
fi
```

**Available Functions:**
- `pass "msg"` - Mark as passed
- `fail "msg"` - Mark as failed
- `info "msg"` - Print info

**Available Variables:**
- `$BIN` - Path to macli binary
- `$BUILD_DIR` - Build directory (.build/release)

## Release

### Build Release Binaries

```bash
.x-cmd/release all           # Build all targets
.x-cmd/release darwin-arm64  # Apple Silicon only
.x-cmd/release darwin-x64    # Intel Mac only
```

### Output Directory

```
.release-artifacts/
├── darwin-arm64/bin/macli  # ~580KB
└── darwin-x64/bin/macli    # ~604KB
```

## Project Structure

```
Sources/
├── Main.swift              # Entry point
├── cli/                    # Command definitions
│   ├── Cal.swift
│   ├── Event.swift
│   ├── Notify.swift
│   ├── Smc.swift
│   └── ...
├── ctrl/                   # Controllers
│   ├── AccessCtrl.swift
│   ├── CalendarCtrl.swift
│   ├── SmcCtrl.swift       # Intel SMC (IOKit)
│   ├── HidSensorCtrl.swift # Apple Silicon wrapper
│   └── ...
├── x-cmd/                  # Core framework
│   ├── Cmd.swift           # Command system
│   ├── Cfg.swift           # Config
│   ├── Log.swift           # Logging
│   ├── SimpleYaml.swift    # YAML parser
│   └── ...
└── HidSensorObjC/          # ObjC bridging (Apple Silicon HID)
    ├── HidSensorClient.h
    ├── HidSensorClient.m
    └── module.modulemap
```

## Code Style

See `X-CMD-库规范.md` (in parent directory)

## Binary Size

| Metric | Value |
|--------|-------|
| Binary | ~580KB |
| tar.xz | ~136KB |
| Dependencies | 0 |
