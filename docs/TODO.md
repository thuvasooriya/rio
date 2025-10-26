# rio todo

This file tracks planned improvements and open issues for rio.

## high priority

### safety checks

- [x] add disk space check before creating test file
  - warn if less than 2x test file size available
  - fail if insufficient space for test file
- [x] add file overwrite warning
  - check if test file exists before benchmark
  - prompt user for confirmation or provide --force flag
- [x] add system directory protection
  - block benchmarks in /, /boot, /System, C:\Windows, etc.
  - maintain allowlist/blocklist of protected paths
- [ ] validate buffer alignment for O_DIRECT
  - ensure block_size is 512-byte aligned
  - verify allocated buffers meet platform alignment requirements
  - add alignment tests for all platforms

### windows platform audit

- [x] verify windows io implementation correctness
  - FILE_FLAG_NO_BUFFERING implemented
  - overlapped I/O working correctly
  - GetDiskFreeSpaceExW for disk space check
- [ ] test on actual windows system
- [ ] research IOCP (I/O completion ports) for async I/O
  - compare performance vs synchronous pread/pwrite equivalent
  - evaluate complexity vs benefit for rio's use case

## medium priority

### performance improvements

- [ ] research io_uring for linux
  - modern async I/O interface (kernel 5.1+)
  - potentially much faster than pread/pwrite
  - fallback to existing implementation if unavailable
- [ ] research kqueue for macOS
  - BSD async I/O interface
  - compare performance vs pread/pwrite
  - evaluate complexity vs benefit

### output improvements

- [x] add json output format option
  - machine-readable results for scripting
  - include all metrics and metadata
- [ ] add csv output format option
  - useful for importing into spreadsheets
  - include all metrics in tabular format

### additional benchmarks

- [ ] add mixed read/write patterns
  - realistic workload simulation
  - configurable read/write ratio
- [ ] add random access patterns
  - test seek performance
  - compare with sequential patterns
- [ ] add multiple file size options
  - small files (1MB, 10MB)
  - medium files (100MB, 1GB)
  - large files (10GB+)

## low priority

### usability

- [x] add progress indicators for benchmarks
  - show real-time spinner with elapsed time during execution
  - color-coded metrics (throughput and latency)
  - checkmark on completion
- [ ] add quiet mode flag
  - minimal output (just final results)
  - useful for scripting
- [ ] add verbose mode flag
  - detailed per-iteration output
  - useful for debugging

### documentation

- [ ] add ARCHITECTURE.md
  - document layer responsibilities
  - explain dependency flow
  - describe platform abstraction approach
- [ ] add BENCHMARKING.md
  - explain what rio measures
  - interpret results (what's good/bad)
  - platform-specific considerations
- [ ] add CONTRIBUTING.md
  - coding standards
  - how to add new platforms
  - testing requirements

## research

- [ ] investigate SMART health checks integration
  - warn if disk health is degraded
  - avoid benchmarking failing drives
- [ ] investigate SSD wear concerns
  - document expected write amplification
  - provide guidance on benchmark frequency
- [ ] investigate multi-threaded I/O
  - measure scaling with multiple threads
  - compare with single-threaded performance

## notes

Items are organized by priority but can be tackled in any order. High priority items focus on safety and correctness. Medium priority items improve performance and usability. Low priority items are nice-to-have enhancements.

When implementing items, follow the patterns established in the codebase:

- maintain clean layer separation (core/io/bench/cli)
- add tests for new functionality
- update docs/CHANGELOG.md with changes
- keep commits focused and atomic
