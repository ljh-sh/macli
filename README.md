# macli

macOS system tools CLI with JSON/YAML output. Zero dependencies.

## Install

```bash
swift build -c release
cp .build/release/macli /usr/local/bin/
```

## Commands

### cal - Calendar Management

```bash
macli cal ls                  # List all calendars
macli cal add --name Work     # Create calendar
macli cal rm --name Work      # Delete calendar
```

### event - Calendar Events

```bash
macli event ls --calendar Work                    # List events
macli event add --calendar Work --title Meeting \
                --start "2024-01-15 10:00" \
                --end "2024-01-15 11:00"          # Create event
macli event rm --id <event-id>                    # Delete event
```

### reminder - Reminders

```bash
macli reminder ls             # List reminder lists
macli reminder add --name Shopping  # Create list
```

### notify - System Notifications

```bash
macli notify --title "Alert" --body "Task done"
macli notify --title "Test" --sound    # With sound
```

### location - Current Location

```bash
macli location                # Get current coordinates
```

### speak - Text to Speech

```bash
macli speak "Hello World"     # Speak text
```

### speech - Speech Recognition

```bash
macli speech recognize --file audio.m4a  # Transcribe audio
```

---

### smc - Apple Silicon SMC Sensors (M1/M2/M3/M4/M5)

```bash
macli smc temp        # Temperature sensors (JSON)
macli smc temp --tsv  # Temperature sensors (TSV)
macli smc volt        # Voltage sensors
macli smc curr        # Current sensors
macli smc all         # All sensors
```

**Subcommands:** `temp`, `volt`, `curr`, `power`, `fans`, `batt`, `all`

**Options:** `--tsv` - Output TSV instead of JSON

### smc86 - Intel SMC Sensors (Legacy)

```bash
macli smc86 temp      # Temperature sensors
macli smc86 fans      # Fan speeds
macli smc86 batt      # Battery status
macli smc86 all       # All sensors
```

## Output Format

### JSON (default)

```json
{
  "ok": true,
  "source": "HID",
  "sensors": [
    {"name": "PMU tdie1", "value": 57.5, "unit": "°C"}
  ],
  "count": 45
}
```

### TSV (--tsv)

```
name    value   unit
PMU tdie1       57.5    °C
```

## Binary Size

- Binary: ~580KB
- Compressed (tar.xz): ~136KB

## License

Apache 2.0

---

For development docs, see [DEV.md](DEV.md)
