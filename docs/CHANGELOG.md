# changelog

## unreleased

### ui improvements

- changed path separator in second line from @ to · for cleaner visual appearance (src/cli/app.zig:139)
- reduced minimum box width from 66 to 0 to eliminate excessive whitespace (src/cli/app.zig:186)
- box now automatically sizes to content instead of enforcing minimum width

### code cleanup

- removed dead code from src/cli/reporter.zig
  - deleted unused printText(), printHeader(), printFooter(), printResultsBox() functions
  - deleted duplicate getThroughputColor() (theme.zig version is used instead)
  - deleted unused formatThroughput() function
  - all functionality now handled by app.zig with proper theme integration
- completed comprehensive pre-release codebase review
  - verified all core/, io/, bench/, cli/ modules for safety and consistency
  - verified build.zig, version.zig, main.zig, test.zig clean and minimal
  - all tests passing, no critical issues found
  - ready for release

### improvements

- centralized theme configuration in cli/theme.zig
  - created Theme struct with all UI color definitions (border, app_name, version, spinner, checkmark, elapsed_time)
  - extracted threshold constants for throughput and latency color coding
  - getThroughputColor() and getLatencyColor() as module-level helper functions
  - default theme instance for easy access
  - all color decisions now in one place for easy customization
- enhanced output styling with colored box borders and header
  - box borders and dividers: magenta color for visual distinction
  - header line: "rio" in green, version in blue, followed by path and settings
  - unified header format: "rio v{version}      | path: {dir}"
  - second line shows test parameters: size, block size, duration, mode
  - consistent box width with proper ANSI escape code handling
- added color highlighting to benchmark metrics
  - throughput: green (>=5 Gbps), cyan (>=1 Gbps), yellow (<1 Gbps)
  - IOPS: bold text for emphasis
  - latency: green (<1μs), cyan (<10μs), yellow (>=10μs)
  - spinner frames: cyan color
  - elapsed time: dim color
  - checkmarks: green color
  - colors applied to both spinner progress and completed results
- fixed box width calculation to handle ANSI escape codes and UTF-8
  - added visualWidth() function to strip ANSI codes from width calculation
  - properly handles multi-byte UTF-8 characters (checkmark, etc.)
  - box borders now align correctly regardless of embedded colors
  - padding calculations use visual width instead of byte length

- centralized version management using build.zig.zon
  - created src/version.zig that exports version from build_options
  - updated build.zig to parse version from build.zig.zon using std.zon.parse
  - updated src/cli/args.zig to use dynamic version in help text
  - updated src/cli/reporter.zig to use dynamic version in header
  - updated src/cli/app.zig to use dynamic version in output
  - version only needs to be changed in build.zig.zon (single source of truth)

### bug fixes

- fixed Windows build errors in src/core/safety.zig
  - changed callconv(std.os.windows.WINAPI) to callconv(.winapi) for extern GetDiskFreeSpaceExW declaration
  - removed duplicate builtin import in get_filesystem_stats()
  - removed unused windows constant in get_windows_disk_space()
- fixed memory management in src/bench/runner.zig
  - replaced incorrect self.allocator.free(buffer) with Pattern.freePattern() at lines 190 and 356
  - all pattern buffers now use consistent cleanup
- fixed buffer alignment in src/bench/pattern.zig
  - changed incorrect @enumFromInt(12) to std.mem.Alignment.fromByteUnits(4096)
  - ensures proper alignment for direct I/O operations
- added zig build run step in build.zig
  - can now run: zig build run -- --help
  - simplifies development workflow
- all 6 platforms now build successfully:
  - x86_64-linux, aarch64-linux
  - x86_64-macos, aarch64-macos
  - x86_64-windows, aarch64-windows

### documentation cleanup

- improved error handling in src/core/safety.zig
  - replaced catch with proper SafetyError.DiskSpaceCheckFailed propagation
  - return SafetyError.UnsupportedPlatform for unsupported platforms
  - removed silent error handling
- simplified README.md
  - moved platform-specific implementation details to docs/IMPLEMENTATION.md
  - moved cross-compilation instructions to docs/IMPLEMENTATION.md
  - cleaner user-facing documentation
- reorganized documentation structure
  - moved TODO.md to docs/TODO.md
  - updated all references in README.md, AGENTS.md, docs/IMPLEMENTATION.md
  - removed outdated files: BUILD_NOTES.md, PHASE2_NOTES.md, PHASE3_NOTES.md, PHASE3_SUMMARY.md
- updated docs/TODO.md with completion status
  - marked disk space check as completed
  - marked file overwrite warning as completed
  - marked system directory protection as completed
  - marked Windows I/O implementation as completed (pending actual Windows testing)
  - marked JSON output as completed

### phase 8: documentation and final polish (complete)

- updated README.md with comprehensive usage documentation
  - added example output showing progress indicators and metrics
  - platform-specific notes for Linux, macOS, Windows
  - cross-compilation instructions for all 6 supported targets
  - updated available platforms to include aarch64-windows
- verified all 6 target platforms build successfully
  - x86_64-linux, aarch64-linux
  - x86_64-macos, aarch64-macos
  - x86_64-windows, aarch64-windows
- code formatting verification with zig fmt
- all tests passing on native platform
- ready for initial release

### phase 7: github actions ci/cd (complete)

- created .github/workflows/release.yml for automated releases
  - triggers on version tags (v\*)
  - builds for 6 platforms: x86_64-linux, aarch64-linux, x86_64-macos, aarch64-macos, x86_64-windows, aarch64-windows
  - uses Zig 0.15.2 with ReleaseFast optimization and baseline CPU
  - creates tar.gz archives for Unix, zip for Windows
  - automatic GitHub release creation with generated release notes
- created .github/workflows/ci.yml for continuous integration
  - runs on push to main/master and on pull requests
  - tests on ubuntu-latest, macos-latest, windows-latest
  - verifies code formatting with zig fmt
  - runs full test suite on all platforms
- fixed cross-compilation issues for all target platforms
  - build.zig: added link_libc = true for C library linking
  - src/core/safety.zig: implemented platform-specific filesystem stats
    - Linux: direct syscall using linux.syscall2(.statfs) to avoid cImport cross-compilation issues
    - macOS: cImport approach (works for native and cross-compilation)
    - Windows: dummy values (no disk space check currently)
  - src/cli/terminal.zig: fixed Windows environment variable access
    - Windows: assumes VT support (Windows 10+)
    - Unix: checks NO_COLOR and TERM environment variables
  - src/cli/app.zig: fixed error handling for cross-platform compatibility
    - changed from switch on error type to if comparisons
    - avoids compile-time error set issues on different platforms
  - src/io/platform/windows.zig: updated for Zig 0.15 API changes
    - utf8ToUtf16LeWithNull -> utf8ToUtf16LeAllocZ
    - windows.CreateFileW -> windows.kernel32.CreateFileW
    - proper INVALID_HANDLE_VALUE checking
- release workflow architecture
  - matrix build strategy for parallel compilation
  - artifact upload/download pattern for release assembly
  - proper permissions for release creation
- ready for tagging and release automation
- all 6 platforms verified building successfully

### phase 6: terminal ui and progress indicators (complete)

- created cli/terminal.zig with ANSI escape code abstraction
  - auto-detects terminal capabilities (TTY, NO_COLOR, TERM=dumb)
  - color support: reset, bold, dim, red, green, yellow, blue, cyan, magenta
  - cursor control: clearLine, cursorUp, cursorDown, cursorToColumn
  - cursor visibility: hideCursor, showCursor
  - conditional ANSI: disabled for JSON output or non-TTY
- created cli/progress.zig with three progress indicator types
  - Spinner: animated dots/line/arc with custom messages
  - ProgressBar: percentage-based with custom width and labels
  - LiveProgress: real-time throughput display with color-coded speed
- integrated Terminal into cli/app.zig and cli/reporter.zig
  - replaced direct stdout writes with Terminal abstraction
  - unified writer pattern using std.fs.File.Writer with proper buffering
  - added flush() calls at key synchronization points
- added progress callbacks to bench/runner.zig
  - all four benchmark patterns (seq-read, seq-write, rand-read, rand-write)
  - callbacks fire every 100ms with elapsed_s, total_s, throughput_bps
  - consistent pattern across all IO operations
- integrated progress indicators into benchmarks
  - file preparation shows animated spinner with checkmark on completion
  - each benchmark pattern shows live throughput with color coding:
    - green: >= 5.0 Gbps
    - yellow: >= 1.0 Gbps
    - red: < 1.0 Gbps
  - final results show checkmark + formatted metrics
- fixed Zig 0.15.2 API compatibility issues
  - std.io.getStdOut() → std.fs.File.stdout()
  - writer requires explicit buffer parameter
  - Terminal.writer type: std.fs.File.Writer instead of AnyWriter
  - enum literals require explicit Color type in runtime expressions
- fixed JSON output formatting
  - reporter now uses terminal writer (unified buffer)
  - proper comma placement between array elements
  - no trailing comma before closing bracket
  - valid JSON with proper indentation
- all tests passing, binary builds successfully
- user-facing output now includes:
  - animated file preparation spinner
  - live benchmark progress with throughput
  - color-coded results based on performance
  - clean completion message

### ux improvement: directory-based interface

- switched from file-path-based to directory-based interface
- users now specify directory instead of full file path
- test files auto-generated with timestamp: `rio_bench_<timestamp>.dat`
- defaults to home directory if no directory specified
- updated cli/args.zig: renamed test_path to target_dir
- updated cli/app.zig: directory verification and filename generation
- updated core/safety.zig: added generate_test_filename() function
- safety checks now operate on directories (more intuitive)
- automatic cleanup after benchmark completes
- new usage pattern: `rio [directory]` instead of `rio <file-path>`

### safety checks implementation

- created core/safety.zig with comprehensive safety checks
- added disk space verification (requires 2x test file size available)
- added file overwrite protection with --force flag requirement
- added system directory protection (blocks /, /boot, /usr, /sys, etc.)
- improved path matching to avoid false positives (e.g., /tmp vs /)
- integrated safety checks into cli/app.zig with clear error messages
- added --force/-f flag to args.zig for overwriting existing files
- all safety checks include tests and work cross-platform
- binary size: 158 KB (from 156 KB, +2KB for safety features)

### documentation consolidation

- created TODO.md with all planned improvements organized by priority
- safety checks (disk space, file overwrite warnings, system directory protection)
- performance improvements (io_uring, kqueue, IOCP research)
- platform audit items (buffer alignment, windows verification)
- output formats (json, csv) and usability enhancements

### phase 5: integration (complete)

- added print_size() to core/format.zig for direct writer output
- created cli/app.zig with application orchestration logic
- refactored main.zig to minimal 18-line entry point (target: <50 lines)
- extracted all application logic from main.zig to cli/app.zig
- all formatting now through core/format.zig (no duplication)
- all tests passing (9/9), build successful
- release binary: 156 KB (smaller than previous 162 KB)

### phase 4: cli layer (complete)

- renamed Args.zig → cli/args.zig (snake_case convention)
- renamed Reporter.zig → cli/reporter.zig (snake_case convention)
- removed dead code: cli/root.zig, cli/UI.zig, src/root.zig
- updated all imports in main.zig and test.zig
- all tests passing (7/7), build successful

### phase 3: bench layer (complete)

- created src/bench/ directory for benchmarking logic
- migrated lib/Metrics.zig → bench/metrics.zig
- updated metrics.zig to use core/stats.zig (removed circular dependency)
- migrated lib/Pattern.zig → bench/pattern.zig
- migrated lib/Benchmark.zig → bench/runner.zig with updated imports
- removed redundant lib/Stats.zig (now using core/stats.zig)
- updated all imports across main.zig, Args.zig, Reporter.zig
- removed old src/lib/ directory entirely
- all tests passing (7/7), build successful

### phase 2: io layer (complete)

- created src/io/ and src/io/platform/ directories
- migrated IoEngine.zig → src/io/engine.zig with refactored imports
- updated engine.zig to use core/types.IOMode instead of local enum
- copied platform-specific code to src/io/platform/ (linux.zig, darwin.zig, windows.zig)
- updated all import paths:
  - Benchmark.zig: imports from ../io/engine.zig
  - Args.zig: imports from ../core/types.zig for IOMode
  - test.zig: imports io/engine.zig
- removed old src/lib/IoEngine.zig
- all tests passing (7/7), build successful

### phase 1: clean structure (complete)

- created docs/ directory
- moved BUILD_NOTES.md, PHASE2_NOTES.md, PHASE3_NOTES.md, PHASE3_SUMMARY.md, QUICKREF.md to docs/
- created ROADMAP.md with detailed reorganization plan
- created AGENTS.md with coding standards for AI agents
- created src/core/ directory with foundation layer modules:
  - core/types.zig: IOMode and IOPattern enums (zero dependencies)
  - core/stats.zig: pure statistical functions (coefficient_of_variation, percentile, RunningStats)
  - core/format.zig: size and time formatting utilities
- verified core modules compile and tests pass independently (4 tests)
- fixed Pattern.zig allocator alignment bug with freePattern() helper
- updated all Pattern memory management in Benchmark.zig (5 locations)

### resolved issues

- build.zig.zon format issue resolved
- Pattern.zig alignment mismatch fixed
- circular dependency between Metrics and Stats resolved
- all dead code removed
- all tests passing (7/7)

### new architecture

final structure:

```
src/
├── core/           # zero dependencies (types, stats, formatting)
├── io/             # depends on: core (engine, platform abstraction)
├── bench/          # depends on: io, core (benchmarking logic)
├── cli/            # depends on: bench, io, core (user interface)
├── main.zig        # entry point
└── test.zig        # test imports
```

dependency flow: main → cli → bench → io → core

## 0.1.0 - phase 3 complete

- full CLI implementation
- argument parsing with --help, --json, --pattern filters
- JSON output support
- pattern filtering (sequential-read, sequential-write, random-read, random-write, all)
- 7/7 tests passing
- 123 KB release binary
