# Roadmap

This is a high-level plan. For released changes see [`changelog/`](changelog/).

## Now

Core primitives that are already shipped:

- [x] SMC sensor snapshot (`macli smc`) — temperature, voltage, current
- [x] Streaming monitor (`macli monitor`) — TSV output for shell pipelines
- [x] EventKit access (`macli cal`, `macli event`, `macli reminder`)
- [x] User notifications (`macli notify`)

## Next

- [ ] Battery health (`macli battery`) — cycle count, design capacity, cell voltage, health percentage
- [ ] SSD health (`macli ssd`) — NVMe SMART data: TBW, wear leveling, available spare, media errors

## Later

- More sensor sources inside `monitor` (GPU, power draw)
- Additional output formats only if a clear agent use case appears

## Not planned

- GUI: macli is CLI-only by design
- Linux / Windows: macOS-only by design
- Built-in aggregation or alerting: leave that to `awk` / `jq` / `python` downstream
