# implementation details

technical implementation notes for rio disk benchmark tool.

## platform-specific i/o

### linux

**buffered mode**: standard pread/pwrite syscalls

- uses kernel page cache
- fastest for cached workloads

**direct mode**: O_DIRECT flag

- bypasses kernel page cache
- requires 512-byte aligned buffers (typically 4K for best performance)
- true unbuffered i/o
- reflects actual disk performance

**sync mode**: O_SYNC flag

- writes are synchronous to disk
- slower but guaranteed persistence

**filesystem stats**: direct statfs syscall

- avoids cImport for cross-compilation
- uses linux.syscall2(.statfs, ...)
- works for x86_64 and aarch64

### macos

**buffered mode**: standard pread/pwrite

- uses kernel unified buffer cache
- similar to linux buffered mode

**direct mode**: F_NOCACHE via fcntl

- bypasses buffer cache
- not as strict as linux O_DIRECT
- still uses some kernel buffering

**sync mode**: F_FULLFSYNC via fcntl

- stronger than fsync
- guarantees disk persistence
- required on macos for true durability

**filesystem stats**: statvfs via cImport

- uses BSD statvfs API
- works for native and cross-compilation from macos

### windows

**buffered mode**: standard ReadFile/WriteFile

- uses windows cache manager
- similar semantics to unix buffered

**direct mode**: FILE_FLAG_NO_BUFFERING

- bypasses cache manager
- requires sector-aligned buffers
- similar to linux O_DIRECT

**sync mode**: FILE_FLAG_WRITE_THROUGH

- writes complete only when on disk
- equivalent to unix O_SYNC

**file opening**: kernel32.CreateFileW

- uses wide string (utf-16le) paths
- overlapped i/o structure for offset-based operations
- returns HANDLE, check against INVALID_HANDLE_VALUE

**filesystem stats**: GetDiskFreeSpaceExW

- returns free bytes available to user
- handles quota and disk limits
- uses wide string paths

**terminal support**: windows 10+ VT sequences

- assumes modern windows with virtual terminal support
- older versions may not show colors correctly

## cross-compilation

all 6 platforms build from any host:

```bash
zig build -Dtarget=<arch>-<os> -Doptimize=ReleaseFast -Dcpu=baseline
```

**targets**:

- x86_64-linux
- aarch64-linux
- x86_64-macos
- aarch64-macos
- x86_64-windows
- aarch64-windows

**key considerations**:

- link_libc = true in build.zig for c standard library
- platform-specific code isolated in io/platform/
- avoid cImport where cross-compilation fails (use syscalls on linux)
- error handling uses comparisons not switches (cross-platform error sets)

## safety features

### disk space check

requires 2x test file size available before starting.

**implementation**:

- linux: statfs syscall
- macos: statvfs cImport
- windows: GetDiskFreeSpaceExW

prevents out-of-space errors during benchmark.

### system directory protection

blocks benchmarks in critical system directories:

- /, /boot, /bin, /sbin, /usr, /lib, /lib64, /etc, /sys, /proc, /dev (unix)
- /System, /Library/System (macos)
- C:\Windows, C:\Program Files (windows)

uses prefix matching with directory boundary checks.

### file overwrite protection

auto-generated filenames with timestamp:

```
rio_bench_<unix_timestamp>.dat
```

checks if file exists, requires --force flag to overwrite.

## metrics collection

### throughput

bytes transferred / elapsed time

- reported in MB/s, GB/s
- uses 1000-based units (not 1024)

### iops

operations per second

- operations = total_bytes / block_size
- useful for comparing different block sizes

### latency

per-operation timing using std.time.nanoTimestamp()

- min: fastest operation
- avg: mean of all operations
- p95: 95th percentile
- p99: 99th percentile
- max: slowest operation

collected in array, sorted for percentile calculation.

## progress indicators

### spinner

animated indicator for file preparation:

- rotates through dot states
- shows checkmark on completion
- updates every 100ms

### live throughput

real-time speed display during benchmark:

- color-coded by speed (green >= 5 Gbps, yellow >= 1 Gbps, red < 1 Gbps)
- updates every 100ms via callback
- shows elapsed time and current throughput

### terminal detection

automatically disables ansi codes when:

- not a tty (piped output)
- NO_COLOR environment variable set
- TERM=dumb
- json output mode enabled

## test patterns

### sequential read

reads file sequentially from start to end, repeating until duration expires.

### sequential write

writes file sequentially from start to end, repeating until duration expires.

### random read

reads random blocks using std.Random.Pcg, loops for duration.

### random write

writes random blocks using std.Random.Pcg, loops for duration.

all patterns:

- use same block size
- respect duration limit
- collect per-operation latency
- calculate aggregate metrics

## architecture principles

### strict layering

```
main → cli → bench → io → core
```

lower layers never import upper layers.

### zero dependencies in core

core/ contains pure functions only:

- types (enums, structs)
- statistics (mean, stdev, percentile)
- formatting (sizes, times)

no i/o, no state, fully testable.

### platform abstraction in io

io/platform/ contains all platform-specific code:

- linux.zig (O_DIRECT, pread/pwrite)
- darwin.zig (F_NOCACHE, F_FULLFSYNC)
- windows.zig (CreateFileW, ReadFile, WriteFile, overlapped i/o)

single dispatch point in io/engine.zig.

### separation of concerns

- core: utilities, no dependencies
- io: platform i/o, depends on core
- bench: benchmark logic, depends on io + core
- cli: user interface, depends on bench + io + core
- main: entry point, minimal logic

## json output format

```json
{
  "patterns": [
    {
      "name": "seq-read",
      "throughput_bps": 3450000000,
      "iops": 882000,
      "latency_ns": {
        "min": 800000,
        "avg": 1100000,
        "p95": 1200000,
        "p99": 2100000,
        "max": 3400000
      }
    }
  ]
}
```

machine-readable, includes all metrics.

## building

### debug build

```bash
zig build
```

fast compilation, includes debug symbols, ~175 KB.

### release build

```bash
zig build -Doptimize=ReleaseFast
```

optimized, stripped, ~175 KB.

### tests

```bash
zig build test
```

runs all unit tests in src/_/_.zig files.

## future improvements

see docs/TODO.md for planned features:

- io_uring support (linux async i/o)
- kqueue support (macos/bsd async i/o)
- iocp support (windows async i/o)
- buffer alignment validation
- mixed read/write patterns
- multi-threaded benchmarks
