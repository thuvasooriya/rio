# contributing to rio

## getting started

1. fork the repository
2. clone your fork: `git clone https://github.com/thuvasooriya/rio.git`
3. create a branch: `git checkout -b feature/your-feature`
4. make your changes
5. run tests: `zig build test`
6. check formatting: `zig fmt --check src/`
7. commit changes: `git commit -m "add: your feature description"`
8. push to your fork: `git push origin feature/your-feature`
9. open a pull request

## development workflow

### building

```bash
# debug build (fast compilation, includes debug symbols)
zig build

# release build (optimized, stripped)
zig build -Doptimize=ReleaseFast
```

### testing

```bash
# run all tests
zig build test

# run specific test file
zig test src/core/stats.zig
```

### code formatting

rio uses standard zig formatting:

```bash
# check formatting
zig fmt --check src/

# auto-format code
zig fmt src/
```

### ci checks

all pull requests run through automated CI:

- **tests**: run on Linux, macOS, Windows
- **format check**: ensures code follows zig standards
- **build verification**: debug and release builds

fix any CI failures before requesting review.

## coding standards

see `AGENTS.md` for detailed coding standards. key points:

- **no emojis** in code, comments, or commit messages
- **snake_case** for functions and variables
- **PascalCase** for types (structs, enums, unions)
- **UPPER_CASE** for constants and enum values
- **think from first principles** before adding complexity
- **keep it simple** - avoid unnecessary abstractions

## architecture

rio follows strict dependency layering:

```
main → cli → bench → io → core
```

- **core/**: types, statistics, formatting (zero dependencies)
- **io/**: I/O engine and platform abstractions (depends on core)
- **bench/**: benchmarking logic (depends on io, core)
- **cli/**: user interface, argument parsing (depends on bench, io, core)
- **main.zig**: entry point (depends on cli)

**rules**:

- lower layers never import upper layers
- platform-specific code isolated in `io/platform/`
- no circular dependencies

## commit messages

- **be concise**: focus on "why" not "what" (code shows "what")
- **no generic messages**: avoid "update" or "fix" without context
- **use prefixes**: `add:`, `fix:`, `refactor:`, `docs:`

**examples**:

- bad: "update IoEngine"
- good: "refactor IoEngine to consolidate platform dispatch"
- bad: "fix bug"
- good: "fix overflow in latency calculation for durations > 1 hour"

## documentation

update relevant documentation:

- `docs/CHANGELOG.md` - track important changes
- `README.md` - if adding user-facing features

recommended reading:

- `docs/ZIG_PATTERNS.md` - comprehensive zig patterns
- `docs/CHANGELOG.md` - track recent changes
- `AGENTS.md` - coding standards for the project

## releasing

releases are handled by maintainers:

1. update version in source files (`src/cli/app.zig`, `src/cli/reporter.zig`, `src/cli/args.zig`)
2. document changes in `docs/CHANGELOG.md`
3. tag commit: `git tag v0.1.0`
4. push tag: `git push origin v0.1.0`
5. GitHub Actions automatically builds and publishes release

## questions

- open an issue for bugs or feature requests
- discussions welcome for architectural questions
- check `docs/` for detailed technical documentation
