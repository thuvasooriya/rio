# changelog

## 0.0.3-alpha

### performance

- eliminated UI freeze when benchmarks complete
  - implemented reservoir sampling: limits latency samples to 10k instead of millions
  - percentile calculation now instant (O(10k) instead of O(millions))
  - maintains accurate statistics using total_sum/total_count across all samples
- added "Calculating results..." spinner between benchmarks for smooth transitions
- fixed reservoir sampling randomization bug (persistent PRNG instance)

### platform optimizations

- added access pattern hints for accurate benchmarking
  - linux: posix_fadvise() with POSIX_FADV.SEQUENTIAL, POSIX_FADV.RANDOM, POSIX_FADV.DONTNEED
  - macos: no-op stubs (lacks fadvise)
  - windows: FILE_FLAG_SEQUENTIAL_SCAN and FILE_FLAG_RANDOM_ACCESS
- optimized file preparation using platform-specific fast writes
  - linux: pwrite() + fsync()
  - macos: pwrite() + F_FULLFSYNC
  - windows: WriteFile() + FlushFileBuffers()

### bug fixes

- fixed Linux cross-compilation (changed linux.FADV to linux.POSIX_FADV for Zig 0.15 API)
- all 6 platforms build successfully (x86_64/aarch64 on linux/macos/windows)

## 0.0.2-alpha

### ui improvements

- cleaner output styling
  - changed path separator from @ to · 
  - removed minimum box width (auto-sizes to content)
  - added color highlighting for metrics (green/cyan/yellow based on performance)
- centralized theme configuration in cli/theme.zig
- fixed box width calculation to properly handle ANSI codes and UTF-8

### improvements

- centralized version management in build.zig.zon (single source of truth)
- removed dead code from src/cli/reporter.zig
- comprehensive pre-release code review completed

### bug fixes

- fixed Windows build errors (callconv, alignment, API compatibility)
- fixed memory management (Pattern.freePattern() usage)
- all 6 platforms now build successfully (x86_64/aarch64 on linux/macos/windows)

## 0.0.1-alpha

### features

- directory-based interface: `rio [directory]` instead of file paths
- test files auto-generated with timestamps: `rio_bench_<timestamp>.dat`
- automatic cleanup after benchmarks complete
- safety checks: disk space verification, file overwrite protection, system directory blocking
- JSON output support with `--json` flag
- pattern filtering: `--pattern sequential-read|sequential-write|random-read|random-write|all`
- terminal UI with animated spinners and live progress indicators
- color-coded performance metrics (throughput, IOPS, latency)

### ci/cd

- GitHub Actions for automated releases on version tags
- cross-platform CI testing (linux, macos, windows)
- builds for 6 platforms: x86_64/aarch64 on linux/macos/windows

### architecture

- clean layered structure: core → io → bench → cli
- platform-specific I/O in io/platform/ (linux, darwin, windows)
- zero circular dependencies
- comprehensive test coverage

initial release: 123 KB binary, all tests passing
