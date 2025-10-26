# rio

cross-platform disk benchmark tool written in zig. rio measures storage performance through read/write benchmarks with multiple access patterns. it provides throughput, IOPS, and latency metrics for sequential and random I/O operations.

## features

- sequential and random read/write benchmarks
- multiple I/O modes: buffered, direct (O_DIRECT), sync
- precise latency tracking (min, avg, p95, p99, max)
- throughput and IOPS measurement
- JSON output for automation
- cross-platform support (Linux, macOS, Windows)

## installation

### download pre-built binaries

download the latest release for your platform from the [releases page](https://github.com/thuvasooriya/rio/releases).

### build from source

```bash
# clone repository
git clone https://github.com/YOUR_USERNAME/rio.git
cd rio

# build release binary
zig build -Doptimize=ReleaseFast

# run benchmark (defaults to home directory)
./zig-out/bin/rio

# benchmark specific directory
./zig-out/bin/rio /tmp
```

## usage

```bash
# benchmark home directory (default)
./rio

# benchmark current directory
./rio .

# benchmark specific directory
./rio /tmp

# customize test parameters
./rio /tmp --size 1G --block-size 1M --duration 10

# test raw disk performance (bypass cache)
./rio . --mode direct

# run specific test pattern
./rio . --pattern seq-read
./rio /tmp --pattern rand-write

# JSON output for automation
./rio /tmp --json > results.json
```

### example output

```
╭────────────────────────────────────────────────────────────────────╮
│ path: /Users/sooriya                                               │
│ size: 1GB  |  block: 4 KB  |  duration: 5s  |  mode: buffered      │
├────────────────────────────────────────────────────────────────────┤
│ ✓ Sequential Read    3.77 Gbps  |  987K IOPS  |  0.92μs avg        │
│ ✓ Sequential Write   1.75 Gbps  |  486K IOPS  |  1.97μs avg        │
│ ✓ Random Read        2.41 Gbps  |  633K IOPS  |  1.50μs avg        │
│ ✓ Random Write       1.28 Gbps  |  366K IOPS  |  2.64μs avg        │
╰────────────────────────────────────────────────────────────────────╯
```

## command-line options

```
rio [directory] [OPTIONS]

arguments:
  [directory]         directory to benchmark (default: home directory)
                      test file auto-generated with timestamp

options:
  --size <size>           test file size (default: 256M)
                          suffixes: K, M, G, T (e.g., 1G, 512M)

  --block-size <size>     I/O block size (default: 4K)
                          suffixes: K, M (e.g., 4K, 1M, 128K)

  --duration <seconds>    test duration per pattern (default: 3)

  --mode <mode>           I/O mode (default: buffered)
                          buffered: use OS page cache
                          direct:   bypass cache (O_DIRECT)
                          sync:     synchronous writes

  --pattern <pattern>     run specific pattern (default: all)
                          seq-read, seq-write, rand-read, rand-write, all

  --json                  output results in JSON format
  --force, -f             allow overwriting existing test files
  --help, -h              show help message
```

## safety considerations

rio includes built-in safety features to prevent accidents:

- **system directory protection**: cannot benchmark in /, /usr, /boot, /System, etc.
- **disk space verification**: ensures 2x test file size available before starting
- **auto-generated filenames**: test files named `rio_bench_<timestamp>.dat` to avoid conflicts
- **automatic cleanup**: test files deleted after benchmark completes
- **overwrite protection**: use `--force` to overwrite existing files

**safe practice**:

```bash
# benchmark home directory (safe default)
./rio

# benchmark dedicated test locations
./rio /tmp
./rio /mnt/external_drive

# current directory
./rio .
```

## development

### requirements

- zig 0.15.2 or later
- supported platforms: Linux, macOS, Windows (x86_64, aarch64)

### build

```bash
# debug build
zig build

# release build (optimized)
zig build -Doptimize=ReleaseFast

# run tests
zig build test
```

see `docs/IMPLEMENTATION.md` for cross-compilation instructions.

### continuous integration

CI automatically runs on all pull requests and pushes to main:

- tests on Linux, macOS, Windows
- format checking with `zig fmt`
- debug and release builds

### releases

releases are automated via GitHub Actions:

- tag a commit with `v*` (e.g., `v0.1.0`)
- CI builds binaries for all supported platforms
- release is automatically created with artifacts

## architecture

```
src/
├── core/           # types, statistics, formatting utilities
├── io/             # I/O engine and platform-specific implementations
├── bench/          # benchmarking logic and metrics
├── cli/            # argument parsing, reporting, application logic
└── main.zig        # entry point
```

dependency flow: main → cli → bench → io → core

## documentation

- `docs/CHANGELOG.md` - track changes and progress
- `docs/IMPLEMENTATION.md` - technical implementation details
- `docs/TODO.md` - planned improvements and tasks
- `docs/CONTRIBUTING.md` - contribution guidelines
- `AGENTS.md` - coding standards and conventions

## license

MIT
