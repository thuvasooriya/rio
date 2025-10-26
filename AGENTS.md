# agents coding guide for rio

## general principles

- **think from first principles**: understand the "why" before the "how"
- **keep it simple**: avoid unnecessary abstraction or complexity
- **be concise**: code and documentation should be clear and to-the-point
- **verify incrementally**: build and test after each significant change

## style and formatting

- **never use emojis** in code, comments, or commit messages
- **use snake_case** for most identifiers (functions, variables, files)
- **use PascalCase** for types (structs, enums, unions)
- **use UPPER_CASE** for constants and enum values
- **avoid multiline comments** whenever possible (use single-line // comments)
- **file names** should match primary type: IoEngine.zig, BenchmarkResult.zig

## zig-specific practices

refer to `docs/ZIG_PATTENRS.md` for detailed patterns

### modern zig idioms

- **files as structs**: organize related functions in a struct namespace

  ```zig
  // stats.zig
  pub fn mean(values: []const f64) f64 { ... }
  pub fn stdev(values: []const f64, avg: f64) f64 { ... }
  ```

- **decl literals**: use struct literals for initialization

  ```zig
  const config = .{
      .size = 1024,
      .mode = .read,
  };
  ```

- **labeled switches**: always use labeled switch for exhaustiveness

  ```zig
  const result = switch (mode) {
      .read => try do_read(),
      .write => try do_write(),
  };
  ```

- **error unions**: prefer explicit error handling over optionals when errors need context
  ```zig
  pub fn parse() !Config {
      return error.InvalidFormat;
  }
  ```

### dependency management

- **strict layering**: enforce dependency direction
  - core/ depends on nothing
  - io/ depends on core/
  - bench/ depends on io/ and core/
  - cli/ depends on bench/, io/, core/
  - main.zig depends on cli/

- **no circular dependencies**: if A imports B, B must not import A
- **minimize coupling**: prefer passing data over sharing state

### testing

- **test at module level**: each .zig file should have test blocks

  ```zig
  test "mean calculates average correctly" {
      const values = [_]f64{ 1.0, 2.0, 3.0 };
      try std.testing.expectEqual(2.0, mean(&values));
  }
  ```

- **test edge cases**: empty inputs, zero values, overflow conditions
- **verify after changes**: always run `zig build test` after refactoring

## architectural standards

### separation of concerns

- **core/**: pure functions, data types, utilities (no I/O, no state)
- **io/**: I/O operations, platform abstractions (no business logic)
- **bench/**: benchmarking logic (no I/O details, no presentation)
- **cli/**: user interface, argument parsing, output formatting (no benchmarking logic)

### platform-specific code

- **isolate platform code**: all platform-specific implementations in io/platform/
- **single dispatch point**: one switch on std.Target.Os in io/engine.zig
- **abstract interfaces**: use comptime or vtable for platform abstraction

### output and formatting

- **abstract output**: use cli/output.zig interface, not hardcoded stdout
- **centralize formatting**: size and time formatting in core/format.zig
- **consistent presentation**: all user-facing output through cli layer

## commit and documentation practices

### commits

- **track changes in docs/CHANGELOG.md**: bullet points with important changes only
- **concise messages**: focus on "why" not "what" (code shows "what")
- **no generic messages**: avoid "update" or "fix" without context
  - bad: "update IoEngine"
  - good: "refactor IoEngine to consolidate platform dispatch"

### documentation

- **keep docs simple**: discrete, clear, to-the-point
- **avoid summaries for trivial tasks**: only summarize incomplete work
- **provide clear next steps**: if work is incomplete, document what's needed

### markdown

- **use lowercase headers**: `## overview` not `## Overview`
- **use code blocks**: triple backticks with language identifier
- **use lists**: bullet points for readability
- **keep it scannable**: headers, bold, code formatting for key terms

## refactoring workflow

when refactoring rio codebase:

1. **read existing code**: understand current implementation before changing
2. **check dependencies**: use grep/glob to find all imports and references
3. **update one layer at a time**: follow phase order in docs/ROADMAP.md
4. **verify incrementally**: `zig build test` after each change
5. **update imports everywhere**: grep for old paths, update all references
6. **clean up dead code**: remove unused files, functions, types
7. **update docs/CHANGELOG.md**: document what changed and why
8. **verify incrementally**: `zig build test` after each change
9. **update imports everywhere**: grep for old paths, update all references
10. **clean up dead code**: remove unused files, functions, types
11. **update CHANGELOG.md**: document what changed and why

## common patterns

### extracting functions to core/

```zig
// before (in main.zig)
fn format_size(bytes: u64) ![]const u8 { ... }

// after (in core/format.zig)
pub fn format_size(bytes: u64) ![]const u8 { ... }

// update main.zig
const format = @import("core/format.zig");
// use format.format_size()
```

### breaking circular dependencies

```zig
// before: A imports B, B imports A (circular)
// after: extract shared code to C, A imports C, B imports C

// core/types.zig (new)
pub const IOMode = enum { read, write };

// io/engine.zig (updated)
const types = @import("../core/types.zig");
mode: types.IOMode,

// bench/runner.zig (updated)
const types = @import("../core/types.zig");
fn run(mode: types.IOMode) !void { ... }
```

### adding abstraction interfaces

```zig
// cli/output.zig
pub const Output = struct {
    write_fn: *const fn (*anyopaque, []const u8) anyerror!void,
    context: *anyopaque,

    pub fn write(self: Output, data: []const u8) !void {
        return self.write_fn(self.context, data);
    }
};

// implementation
pub fn stdout_output() Output {
    const impl = struct {
        fn write_impl(ctx: *anyopaque, data: []const u8) !void {
            _ = ctx;
            const stdout = std.io.getStdOut().writer();
            try stdout.writeAll(data);
        }
    };
    return .{
        .write_fn = impl.write_impl,
        .context = undefined,
    };
}
```

## tools

- **use uv** for python dependency management (if needed)
- **use just** for organizing build commands (if needed)
- **use zig build** for all compilation and testing

## reference

see also:

- `docs/ROADMAP.md` - reorganization plan and phases
- `docs/ZIG_PATTERNS.md` - comprehensive zig patterns
- `docs/CHANGELOG.md` - track changes made to codebase
- `docs/TODO.md` - planned improvements and tasks
- `docs/CONTRIBUTING.md` - contribution guidelines
