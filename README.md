# rio

rio is a cross-platform disk benchmark tool written in zig. it measures storage performance through read/write benchmarks with multiple access patterns. it provides throughput, IOPS, and latency metrics for sequential and random I/O operations.

> [!WARNING]
> this project is in alpha
>
> expect memory leaks, inconsistencies, and missing features.

<img src="https://i.imgur.com/qfgPUDe.png">

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
```

## usage

```sh
# dumps super useful information
rio --help

# customize test parameters
rio /tmp --size 1G --block-size 1M --duration 10

# test raw disk performance (bypass cache)
rio . --mode direct

# run specific test pattern
rio . --pattern seq-read
rio /tmp --pattern rand-write

# JSON output for automation
rio /tmp --json > results.json
```

## documentation

- [CHANGELOG.md](docs/CHANGELOG.md) - track changes and progress
- [IMPLEMENTATOIN.md](docs/IMPLEMENTATOIN.md) - technical implementation details
- [TODO.md](docs/TODO.md) planned improvements and tasks
- [CONTRIBUTING.md](docs/CONTRIBUTING.md) - contribution guidelines
- [AGENTS.md](AGENTS.md) - coding standards and conventions

## license

authored by @thuvasooriya and co-authored by claude-sonnet-4.5
MIT
