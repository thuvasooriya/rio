# Zig 0.15.1 Coding Guide for AI Agents

**Version**: 0.15.1
**Last Updated**: October 2025
**Target Audience**: AI code generation agents

## Table of Contents

1. [Introduction & Overview](#1-introduction--overview)
2. [Modern Zig Practices (0.15.1)](#2-modern-zig-practices-0151)
3. [Standard Library Usage](#3-standard-library-usage-std)
4. [Comptime Programming](#4-comptime-programming)
5. [Essential Builtins Reference](#5-essential-builtins-reference)
6. [Best Practices & Patterns](#6-best-practices--patterns)
7. [Common Patterns & Idioms](#7-common-patterns--idioms)
8. [Build System (build.zig)](#8-build-system-buildzig)
9. [Testing](#9-testing)
10. [Migration Notes](#10-migration-notes)
11. [Quick Reference](#11-quick-reference)

---

## 1. Introduction & Overview

### What is Zig 0.15.1?

Zig is a general-purpose programming language designed for **robustness, optimality, and clarity**. Version 0.15.1 represents the latest stable release with significant improvements to the standard library, language ergonomics, and tooling.

### Core Philosophy

1. **Explicit Memory Management**: No hidden allocations. Every allocation requires an allocator to be passed explicitly.
2. **No Hidden Control Flow**: What you see is what you get. No exceptions, no hidden function calls.
3. **Compile-Time Execution**: Arbitrary code can run at compile time using `comptime`.
4. **Minimal Runtime**: No garbage collector, minimal runtime overhead.
5. **Incremental Improvements**: Breaking changes for the sake of better design.

### Official Resources

- **Official Documentation**: https://ziglang.org/documentation/0.15.1/
- **Release Notes**: https://ziglang.org/download/0.15.1/release-notes.html
- **Standard Library Reference**: https://ziglang.org/documentation/0.15.1/std/
- **Language Reference**: https://ziglang.org/documentation/0.15.1/#

> **Important**: Zig is pre-1.0, so breaking changes occur between versions. Always target the specific version (0.15.1) when generating code.

---

## 2. Modern Zig Practices (0.15.1)

### Decl Literals (Since 0.14.0)

**Decl literals** are a major ergonomic improvement that allow you to reference declarations without repeating the full type name.

#### Syntax

```zig
.decl_name                    // Reference a declaration
.decl_name{ .field = value }  // With initialization
```

#### Why Decl Literals Matter

They eliminate repetition and make code more maintainable. When a type name changes, you don't need to update dozens of references.

#### DO: Use Decl Literals with Enums

```zig
const Color = enum {
    red,
    green,
    blue,
};

fn setColor(color: Color) void {
    // ...
}

// DO: Use decl literals
setColor(.red);

// DON'T: Repeat the type name unnecessarily
setColor(Color.red);
```

#### DO: Use Decl Literals with Tagged Unions

```zig
const Result = union(enum) {
    success: u32,
    failure: []const u8,
};

fn processResult(result: Result) void {
    switch (result) {
        .success => |value| std.debug.print("Success: {}\n", .{value}),
        .failure => |msg| std.debug.print("Error: {s}\n", .{msg}),
    }
}

// DO: Use decl literals
processResult(.{ .success = 42 });
processResult(.{ .failure = "not found" });
```

#### DO: Use Decl Literals with Structs (When Type is Known)

```zig
const Point = struct {
    x: f32,
    y: f32,
};

fn drawPoint(p: Point) void {
    // ...
}

// DO: When the expected type is known
drawPoint(.{ .x = 10.0, .y = 20.0 });
```

#### DO: Use Decl Literals with Namespaced Functions

```zig
const std = @import("std");

// DO: Decl literals work with namespace constants
const allocator = std.heap.page_allocator;

// When returning from functions
fn getDefaultColor() Color {
    return .blue;  // Type is inferred from return type
}
```

#### Comparison: Old vs New

```zig
// OLD WAY (still valid but verbose)
const status: Status = Status.pending;
switch (status) {
    Status.pending => {},
    Status.active => {},
    Status.completed => {},
}

// NEW WAY (0.14.0+)
const status: Status = .pending;
switch (status) {
    .pending => {},
    .active => {},
    .completed => {},
}
```

---

### Language Changes in 0.15.1

#### REMOVED: `usingnamespace`

The `usingnamespace` keyword has been **completely removed** from the language. Use these alternative patterns:

##### Pattern 1: Explicit Public Declarations

```zig
// OLD: usingnamespace
pub usingnamespace @import("other_module.zig");

// NEW: Explicit re-exports
const other = @import("other_module.zig");
pub const functionA = other.functionA;
pub const functionB = other.functionB;
pub const TypeA = other.TypeA;
```

##### Pattern 2: Conditional Inclusion with Comptime

```zig
// OLD: Conditional usingnamespace
pub usingnamespace if (builtin.os.tag == .windows)
    @import("windows.zig")
else
    @import("posix.zig");

// NEW: Conditional declaration blocks
const impl = if (builtin.os.tag == .windows)
    @import("windows.zig")
else
    @import("posix.zig");

pub const open = impl.open;
pub const close = impl.close;
pub const read = impl.read;

// Alternative: wrapper functions
pub fn open(path: []const u8) !std.fs.File {
    return impl.open(path);
}
```

##### Pattern 3: Mixin Alternatives

```zig
// OLD: Mixins via usingnamespace
fn Mixin(comptime T: type) type {
    return struct {
        pub fn helper(self: *T) void { }
    };
}

const MyType = struct {
    value: u32,
    pub usingnamespace Mixin(@This());
};

// NEW: Explicit inclusion or wrapper
fn Mixin(comptime T: type) type {
    return struct {
        pub fn helper(self: *T) void { }
    };
}

const MyType = struct {
    value: u32,

    const MixinImpl = Mixin(@This());
    pub const helper = MixinImpl.helper;
};
```

#### REMOVED: `async` and `await`

Async/await keywords have been removed as the feature is being redesigned. Do not use them.

```zig
// REMOVED: async/await
async fn fetchData() ![]u8 { }
const data = await fetchData();

// Use blocking I/O or external async libraries for now
fn fetchData() ![]u8 { }
const data = try fetchData();
```

#### NEW: Switch on Non-Exhaustive Enums

```zig
const Status = enum(u8) {
    pending = 0,
    active = 1,
    _,  // Non-exhaustive marker
};

fn handleStatus(status: Status) void {
    switch (status) {
        .pending => std.debug.print("Pending\n", .{}),
        .active => std.debug.print("Active\n", .{}),
        else => std.debug.print("Unknown: {}\n", .{@intFromEnum(status)}),
    }
}
```

#### CHANGED: `@ptrCast` Now Allows Single-Item Pointer to Slice

```zig
const value: u32 = 42;
const ptr: *const u32 = &value;

// NEW in 0.15.1: Can cast pointer to slice
const slice: []const u32 = @ptrCast(ptr);
```

#### CHANGED: Error on Lossy Int-to-Float Coercion

```zig
const x: u64 = 9007199254740993;

// ERROR: Lossy coercion
const f: f64 = x;

// CORRECT: Explicit cast acknowledges precision loss
const f: f64 = @floatFromInt(x);
```

#### CHANGED: Arithmetic on Undefined Values

Operations on `undefined` now have stricter rules:

```zig
// ERROR: Cannot perform arithmetic on undefined
var x: i32 = undefined;
x += 1;  // Compile error

// CORRECT: Initialize first
var x: i32 = 0;
x += 1;
```

---

## 3. Standard Library Usage (std)

### Memory Management & Allocators

**Memory allocation is NEVER hidden in Zig.** Every allocation requires an explicit allocator.

#### Core Allocator Interface

```zig
const std = @import("std");

// All allocators conform to std.mem.Allocator interface
pub const Allocator = struct {
    pub fn alloc(self: Allocator, comptime T: type, n: usize) ![]T
    pub fn free(self: Allocator, slice: anytype) void
    pub fn create(self: Allocator, comptime T: type) !*T
    pub fn destroy(self: Allocator, ptr: anytype) void
    // ... more methods
};
```

#### Key Allocators

##### 1. `std.heap.page_allocator` - OS Allocations

```zig
// DON'T: Use for frequent small allocations (very slow)
const allocator = std.heap.page_allocator;
for (0..1000) |_| {
    const ptr = try allocator.alloc(u8, 16);  // 1000 syscalls!
    defer allocator.free(ptr);
}

// DO: Use for large, long-lived allocations
const large_buffer = try std.heap.page_allocator.alloc(u8, 1024 * 1024);
defer std.heap.page_allocator.free(large_buffer);
```

##### 2. `std.heap.GeneralPurposeAllocator` - Development Default

```zig
const std = @import("std");

pub fn main() !void {
    // DO: Use GPA during development for safety
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.log.err("Memory leak detected!", .{});
        }
    }

    const allocator = gpa.allocator();

    const data = try allocator.alloc(u32, 100);
    defer allocator.free(data);

    // GPA will detect:
    // - Memory leaks
    // - Double frees
    // - Use-after-free (when configured)
}
```

##### 3. `std.heap.ArenaAllocator` - Bulk Deallocation

```zig
const std = @import("std");

fn processRequest(gpa: std.mem.Allocator) !void {
    // DO: Use arena for request-scoped allocations
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();  // Frees everything at once

    const allocator = arena.allocator();

    // Many allocations, no individual frees needed
    const buffer1 = try allocator.alloc(u8, 1024);
    const buffer2 = try allocator.alloc(u8, 2048);
    const config = try allocator.create(Config);

    // No defer statements needed - arena.deinit() cleans up all
}
```

##### 4. `std.heap.FixedBufferAllocator` - Stack-Based

```zig
const std = @import("std");

fn parseSmallJson() !void {
    // DO: Use for bounded, temporary allocations
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const parsed = try std.json.parseFromSlice(
        MyType,
        allocator,
        json_string,
        .{},
    );
    // No need to free - memory is on stack
}
```

##### 5. `std.heap.c_allocator` - C Interop

```zig
// DO: Use when interfacing with C libraries
const c_memory = try std.heap.c_allocator.alloc(u8, 256);
defer std.heap.c_allocator.free(c_memory);

// Pass to C function expecting malloc'd memory
c_library_function(c_memory.ptr);
```

#### Proper Allocation Patterns

```zig
const std = @import("std");

// DO: Single value allocation
const config = try allocator.create(Config);
defer allocator.destroy(config);
config.* = Config{ .timeout = 30 };

// DO: Slice allocation with defer
const buffer = try allocator.alloc(u8, 1024);
defer allocator.free(buffer);

// DO: Error handling with errdefer
const items = try allocator.alloc(Item, count);
errdefer allocator.free(items);  // Only freed if error occurs after this

for (items, 0..) |*item, i| {
    item.* = try createItem(i);  // If this fails, items is freed
}
defer allocator.free(items);  // Normal cleanup

// DO: Reallocation
var buffer = try allocator.alloc(u8, 10);
defer allocator.free(buffer);

buffer = try allocator.realloc(buffer, 20);  // May move memory
```

#### ArrayList Changes (0.15.1)

**IMPORTANT**: The unmanaged variant is now the default implementation.

```zig
const std = @import("std");

// DO: Standard ArrayList (stores allocator)
var list = std.ArrayList(u32).init(allocator);
defer list.deinit();

try list.append(42);
try list.append(100);

// DO: ArrayListUnmanaged (no allocator field, slightly more efficient)
var list_unmanaged = std.ArrayList(u32).Unmanaged{};
defer list_unmanaged.deinit(allocator);

try list_unmanaged.append(allocator, 42);
try list_unmanaged.append(allocator, 100);

// When to use which:
// - ArrayList: When you pass the list around and want allocator bundled
// - ArrayListUnmanaged: When you want to save 8 bytes per instance
```

---

### Error Handling

Zig's error handling is explicit and compile-time checked.

#### Error Unions: `!T`

```zig
// Function that may fail
fn divide(a: f32, b: f32) !f32 {
    if (b == 0) return error.DivisionByZero;
    return a / b;
}

// DO: Handle with try (propagate error)
fn calculate(a: f32, b: f32) !f32 {
    const result = try divide(a, b);
    return result * 2;
}

// DO: Handle with catch (provide fallback)
fn safeCalculate(a: f32, b: f32) f32 {
    const result = divide(a, b) catch |err| {
        std.log.warn("Division failed: {}", .{err});
        return 0;
    };
    return result * 2;
}

// DO: Catch and handle specific errors
fn smartCalculate(a: f32, b: f32) !f32 {
    const result = divide(a, b) catch |err| switch (err) {
        error.DivisionByZero => return error.InvalidInput,
        else => return err,
    };
    return result;
}
```

#### Optional Types: `?T`

```zig
// DO: Use optionals for values that may not exist
fn findUser(id: u32) ?User {
    if (id == 0) return null;
    return User{ .id = id, .name = "Alice" };
}

// DO: Handle with orelse
const user = findUser(id) orelse {
    std.debug.print("User not found\n", .{});
    return;
};

// DO: Unwrap with if
if (findUser(id)) |user| {
    std.debug.print("Found: {s}\n", .{user.name});
} else {
    std.debug.print("Not found\n", .{});
}

// DO: Chain with orelse
const name = findUser(id) orelse return error.UserNotFound;
```

#### Custom Error Sets

```zig
// DO: Define error sets for your module
const ParseError = error{
    UnexpectedCharacter,
    UnexpectedEndOfInput,
    InvalidNumber,
};

const FileError = error{
    FileNotFound,
    PermissionDenied,
};

// DO: Combine error sets
fn parseFile(path: []const u8) !(ParseError || FileError)!Data {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(contents);

    return try parse(contents);
}

// DO: Use anyerror for maximum flexibility (but less type safety)
fn genericOperation() anyerror!void {
    // Can return any error
}
```

#### Error Wrapping Pattern

```zig
// DO: Add context when propagating errors
fn loadConfig(path: []const u8) !Config {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.log.err("Failed to open config at {s}: {}", .{ path, err });
        return err;
    };
    defer file.close();

    return parseConfig(file) catch |err| {
        std.log.err("Failed to parse config: {}", .{err});
        return error.InvalidConfig;
    };
}
```

#### Errors vs Optionals: When to Use Which

```zig
// DO: Use optional when absence is expected and normal
fn getFirstElement(list: []const u32) ?u32 {
    if (list.len == 0) return null;
    return list[0];
}

// DO: Use error when operation failed abnormally
fn readFirstElement(file: std.fs.File) !u32 {
    var buffer: [4]u8 = undefined;
    _ = try file.readAll(&buffer);
    return std.mem.readInt(u32, &buffer, .little);
}
```

---

### I/O and Writers (Writergate Changes in 0.15.1)

The I/O system underwent significant changes in 0.15.1 (nicknamed "Writergate").

#### New Writer API

```zig
const std = @import("std");

pub fn main() !void {
    // DO: Get writer from standard out
    const stdout = std.io.getStdOut().writer();

    // DO: Use print for formatted output
    try stdout.print("Hello, {s}!\n", .{"World"});
    try stdout.print("Number: {d}\n", .{42});
    try stdout.print("Hex: 0x{x}\n", .{255});

    // DO: Use writeAll for raw bytes
    try stdout.writeAll("Raw string\n");
}
```

#### File I/O

```zig
const std = @import("std");

fn fileOperations() !void {
    // DO: Open file and get writer
    const file = try std.fs.cwd().createFile("output.txt", .{});
    defer file.close();

    const writer = file.writer();
    try writer.print("Line 1\n", .{});
    try writer.print("Value: {d}\n", .{42});

    // DO: Read with reader
    const input_file = try std.fs.cwd().openFile("input.txt", .{});
    defer input_file.close();

    const reader = input_file.reader();
    var buffer: [1024]u8 = undefined;
    const bytes_read = try reader.read(&buffer);

    // DO: Read all content
    const allocator = std.heap.page_allocator;
    const contents = try input_file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(contents);
}
```

#### Format Specifiers (CHANGED in 0.15.1)

> **CRITICAL CHANGE**: Format methods no longer accept format strings or options!

```zig
const std = @import("std");

const MyType = struct {
    value: u32,

    // OLD: Format method with format string parameter
    // pub fn format(self: MyType, comptime fmt: []const u8, ...) !void

    // NEW: Format method has no fmt/options parameters
    pub fn format(
        self: MyType,
        writer: anytype,
    ) !void {
        try writer.print("MyType{{ value = {} }}", .{self.value});
    }
};

fn printExample() !void {
    const stdout = std.io.getStdOut().writer();
    const obj = MyType{ .value = 42 };

    // OLD: Using format string on custom type
    // try stdout.print("{s}", .{obj});

    // NEW: Must use {f} to call format method
    try stdout.print("Object: {f}\n", .{obj});
}
```

#### Common Format Specifiers

```zig
const stdout = std.io.getStdOut().writer();

// DO: Use correct format specifiers
try stdout.print("{d}\n", .{@as(i32, 42)});           // Decimal integer
try stdout.print("{x}\n", .{@as(u32, 255)});          // Lowercase hex
try stdout.print("{X}\n", .{@as(u32, 255)});          // Uppercase hex
try stdout.print("{b}\n", .{@as(u8, 5)});             // Binary
try stdout.print("{o}\n", .{@as(u8, 8)});             // Octal
try stdout.print("{s}\n", .{"string"});               // String
try stdout.print("{}\n", .{42});                      // Default format
try stdout.print("{any}\n", .{some_value});           // Debug representation
try stdout.print("{f}\n", .{custom_formattable});     // Custom format method
try stdout.print("{e}\n", .{@as(f64, 1.23e-4)});      // Scientific notation
```

#### REMOVED: CountingWriter and BufferedWriter

```zig
// REMOVED: CountingWriter
// const counting_writer = std.io.countingWriter(underlying_writer);

// REMOVED: BufferedWriter in old API
// var buffered = std.io.bufferedWriter(file.writer());

// NEW: Use std.io.BufferedWriter if available, or implement manually
// Check standard library for current buffering patterns
```

#### String Handling and Unicode

> **IMPORTANT**: Formatted printing (`std.fmt`) no longer deals with Unicode!

```zig
const std = @import("std");

// DO: Use std.unicode for Unicode operations
fn unicodeExample() !void {
    const text = "Hello 👋 World";

    // Count Unicode codepoints (not bytes)
    var iter = std.unicode.Utf8View.init(text) catch unreachable;
    var count: usize = 0;
    while (iter.nextCodepoint()) |_| {
        count += 1;
    }

    std.debug.print("Codepoints: {}\n", .{count});

    // DO: Validate UTF-8
    if (std.unicode.utf8ValidateSlice(text)) {
        std.debug.print("Valid UTF-8\n", .{});
    }
}

// DO: String literals are []const u8
const my_string: []const u8 = "Hello";

// DO: String concatenation
fn concatStrings(allocator: std.mem.Allocator) ![]u8 {
    const a = "Hello";
    const b = "World";
    return std.fmt.allocPrint(allocator, "{s} {s}", .{ a, b });
}
```

---

### Collections & Data Structures

#### ArrayList

```zig
const std = @import("std");

fn arrayListExample(allocator: std.mem.Allocator) !void {
    var list = std.ArrayList(u32).init(allocator);
    defer list.deinit();

    // DO: Append elements
    try list.append(1);
    try list.append(2);
    try list.append(3);

    // DO: Access elements
    std.debug.print("First: {}\n", .{list.items[0]});
    std.debug.print("Length: {}\n", .{list.items.len});

    // DO: Insert at position
    try list.insert(1, 999);

    // DO: Remove elements
    _ = list.pop();
    _ = list.orderedRemove(0);  // Maintains order
    _ = list.swapRemove(0);     // Faster, doesn't maintain order

    // DO: Iterate
    for (list.items) |item| {
        std.debug.print("{} ", .{item});
    }
}
```

#### HashMap and AutoHashMap

```zig
const std = @import("std");

fn hashMapExample(allocator: std.mem.Allocator) !void {
    // DO: Use AutoHashMap for simple key types
    var map = std.AutoHashMap([]const u8, u32).init(allocator);
    defer map.deinit();

    try map.put("apple", 1);
    try map.put("banana", 2);
    try map.put("cherry", 3);

    // DO: Get values
    if (map.get("apple")) |value| {
        std.debug.print("apple: {}\n", .{value});
    }

    // DO: Check existence
    const has_banana = map.contains("banana");

    // DO: Remove
    _ = map.remove("cherry");

    // DO: Iterate
    var iter = map.iterator();
    while (iter.next()) |entry| {
        std.debug.print("{s} = {}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }
}

// DO: Use HashMap with custom hash and equality
fn customHashMapExample(allocator: std.mem.Allocator) !void {
    const Context = struct {
        pub fn hash(self: @This(), key: []const u8) u64 {
            _ = self;
            return std.hash.Wyhash.hash(0, key);
        }

        pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
            _ = self;
            return std.mem.eql(u8, a, b);
        }
    };

    var map = std.HashMap([]const u8, u32, Context, 80).init(allocator);
    defer map.deinit();
}
```

#### ArrayHashMap

```zig
const std = @import("std");

fn arrayHashMapExample(allocator: std.mem.Allocator) !void {
    // DO: Use ArrayHashMap for stable iteration order
    var map = std.AutoArrayHashMap([]const u8, u32).init(allocator);
    defer map.deinit();

    try map.put("first", 1);
    try map.put("second", 2);
    try map.put("third", 3);

    // Iteration order matches insertion order
    for (map.keys(), map.values()) |key, value| {
        std.debug.print("{s}: {}\n", .{ key, value });
    }
}
```

#### LinkedList Changes (0.15.1)

> **CHANGED**: LinkedList has been de-genericified in 0.15.1

```zig
const std = @import("std");

// NEW: Use intrusive linked list pattern
const MyNode = struct {
    next: ?*MyNode = null,
    prev: ?*MyNode = null,
    data: u32,
};

fn linkedListExample() void {
    var head: ?*MyNode = null;
    var node1 = MyNode{ .data = 1 };
    var node2 = MyNode{ .data = 2 };

    // Manual linking
    head = &node1;
    node1.next = &node2;
    node2.prev = &node1;
}

// DO: Check std.SinglyLinkedList if still available
```

#### REMOVED: BoundedArray

```zig
// REMOVED in 0.15.1: std.BoundedArray

// DO: Use alternatives
// Option 1: Fixed array with length tracking
const MyBoundedArray = struct {
    buffer: [100]u32,
    len: usize = 0,

    fn append(self: *MyBoundedArray, value: u32) !void {
        if (self.len >= self.buffer.len) return error.OutOfSpace;
        self.buffer[self.len] = value;
        self.len += 1;
    }

    fn items(self: *const MyBoundedArray) []const u32 {
        return self.buffer[0..self.len];
    }
};

// Option 2: ArrayList with FixedBufferAllocator
```

---

## 4. Comptime Programming

Comptime is Zig's most powerful feature - arbitrary code execution at compile time.

### Comptime Basics

#### The `comptime` Keyword

```zig
// DO: Comptime parameters create generic functions
fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}

const x = max(i32, 10, 20);    // Specialized for i32
const y = max(f64, 3.14, 2.71); // Specialized for f64

// DO: Comptime variables are evaluated at compile time
fn fibonacci(comptime n: u32) u32 {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

const fib_10 = fibonacci(10);  // Computed at compile time

// DO: Comptime blocks run at compile time
fn example() void {
    comptime {
        var sum: u32 = 0;
        for (0..10) |i| {
            sum += i;
        }
        // sum is known at compile time
    }
}
```

#### Generic Data Structures

```zig
const std = @import("std");

// DO: Generic types
fn Stack(comptime T: type) type {
    return struct {
        items: std.ArrayList(T),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .items = std.ArrayList(T).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit();
        }

        pub fn push(self: *Self, value: T) !void {
            try self.items.append(value);
        }

        pub fn pop(self: *Self) ?T {
            return self.items.popOrNull();
        }
    };
}

// Usage
var int_stack = Stack(i32).init(allocator);
defer int_stack.deinit();
try int_stack.push(42);
```

### Compile-Time Reflection

#### Type Inspection

```zig
const std = @import("std");

// DO: Get type information
fn printTypeInfo(comptime T: type) void {
    const info = @typeInfo(T);

    switch (info) {
        .Struct => |struct_info| {
            std.debug.print("Struct with {} fields:\n", .{struct_info.fields.len});
            inline for (struct_info.fields) |field| {
                std.debug.print("  {s}: {}\n", .{ field.name, field.type });
            }
        },
        .Int => |int_info| {
            std.debug.print("Integer: {} bits, signed={}\n", .{
                int_info.bits,
                int_info.signedness == .signed,
            });
        },
        else => std.debug.print("Other type\n", .{}),
    }
}

// DO: Check for declarations
fn hasMethod(comptime T: type, comptime name: []const u8) bool {
    return @hasDecl(T, name);
}

// DO: Check for fields
fn hasField(comptime T: type, comptime name: []const u8) bool {
    return @hasField(T, name);
}

// NEW in 0.14.0: @FieldType builtin
fn getFieldType(comptime T: type, comptime field_name: []const u8) type {
    return @FieldType(T, field_name);
}

const Point = struct { x: f32, y: f32 };
const XType = @FieldType(Point, "x");  // f32
```

#### Building Types at Compile Time

```zig
const std = @import("std");

// DO: Generate structs dynamically
fn Tuple(comptime types: []const type) type {
    var fields: [types.len]std.builtin.Type.StructField = undefined;

    inline for (types, 0..) |T, i| {
        var name_buf: [20]u8 = undefined;
        const field_name = std.fmt.bufPrint(&name_buf, "{d}", .{i}) catch unreachable;

        fields[i] = .{
            .name = field_name,
            .type = T,
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(T),
        };
    }

    return @Type(.{
        .Struct = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = true,
        },
    });
}

const MyTuple = Tuple(&.{ i32, []const u8, bool });
const instance = MyTuple{ .@"0" = 42, .@"1" = "hello", .@"2" = true };
```

### Common Comptime Patterns

#### Compile-Time Validation

```zig
// DO: Validate at compile time
fn createBuffer(comptime size: usize) [size]u8 {
    if (size == 0) {
        @compileError("Buffer size must be greater than 0");
    }
    if (size > 1024 * 1024) {
        @compileError("Buffer size too large");
    }
    return undefined;
}

// DO: Type constraints
fn sortedArray(comptime T: type, array: []T) void {
    const info = @typeInfo(T);
    if (info != .Int and info != .Float) {
        @compileError("sortedArray requires numeric type");
    }
    // Sort logic...
}
```

#### Comptime String Processing

```zig
const std = @import("std");

// DO: Process strings at compile time
fn toUpperComptime(comptime str: []const u8) []const u8 {
    comptime {
        var result: [str.len]u8 = undefined;
        for (str, 0..) |c, i| {
            result[i] = std.ascii.toUpper(c);
        }
        const final = result;
        return &final;
    }
}

const HELLO = toUpperComptime("hello");  // "HELLO" at compile time
```

---

## 5. Essential Builtins Reference

Zig provides many `@builtin` functions for low-level operations.

### Imports and Embedding

```zig
// DO: Import other Zig files
const other_module = @import("other_module.zig");
const std = @import("std");

// DO: Embed files at compile time
const shader_source = @embedFile("shader.glsl");
const config_json = @embedFile("config.json");

// The data is embedded directly in the binary
```

### Type Operations

```zig
// DO: Get type of expression
const x: i32 = 42;
const T = @TypeOf(x);  // i32

// DO: Get size and alignment
const size = @sizeOf(u64);      // 8
const align = @alignOf(u64);    // 8

// DO: Get type information
const info = @typeInfo(i32);
```

### Casting

```zig
const std = @import("std");

// DO: Cast integers explicitly
const a: u32 = 42;
const b: u64 = @intCast(a);         // Widen
const c: u16 = @intCast(a);         // Narrow (runtime safety check)

// DO: Cast floats explicitly
const f: f64 = 3.14;
const g: f32 = @floatCast(f);

// DO: Convert between int and float
const i: i32 = 42;
const f2: f64 = @floatFromInt(i);
const i2: i32 = @intFromFloat(f2);

// DO: Cast pointers (with care!)
const ptr: *u32 = &some_u32;
const bytes: *[4]u8 = @ptrCast(ptr);

// NEW in 0.15.1: Pointer to slice
const single_ptr: *const u32 = &value;
const slice: []const u32 = @ptrCast(single_ptr);

// DO: Convert enum to/from integer
const Status = enum(u8) { pending = 0, active = 1 };
const status: Status = .active;
const value: u8 = @intFromEnum(status);  // 1
const back: Status = @enumFromInt(value);
```

### Memory Operations

```zig
// DO: Copy memory (CHANGED in 0.14.0+)
const src = [_]u8{ 1, 2, 3, 4, 5 };
var dest: [5]u8 = undefined;
@memcpy(&dest, &src);

// For slices
const slice_src: []const u8 = &src;
var slice_dest: []u8 = &dest;
@memcpy(slice_dest, slice_src);

// DO: Set memory
var buffer: [100]u8 = undefined;
@memset(&buffer, 0);
```

### NEW: `@branchHint()` (Replaces `@setCold`)

```zig
// REMOVED: @setCold
// @setCold(true);

// NEW in 0.14.0+: @branchHint
fn processValue(value: i32) void {
    if (value < 0) {
        @branchHint(.unlikely);  // Hint: this branch is unlikely
        handleError();
        return;
    }

    // Common case
    processNormal(value);
}
```

### CHANGED: `@splat()` Now Supports Arrays

```zig
// NEW in 0.14.0+: Splat to arrays
const vec: @Vector(4, f32) = @splat(1.0);  // [1.0, 1.0, 1.0, 1.0]

// Also works with arrays
const arr: [4]f32 = @splat(2.0);  // [2.0, 2.0, 2.0, 2.0]
```

### CHANGED: `@export` Operand is Now a Pointer

```zig
// OLD: Export by value
// @export(myFunction, .{ .name = "my_function" });

// NEW in 0.14.0+: Export by pointer
fn myFunction() callconv(.C) void {
    // ...
}

comptime {
    @export(&myFunction, .{ .name = "my_function" });
}
```

### CHANGED: `@src` Gains Module Field

```zig
// NEW in 0.14.0+: @src includes module information
fn logCurrentLocation() void {
    const src = @src();
    std.debug.print("File: {s}\n", .{src.file});
    std.debug.print("Function: {s}\n", .{src.fn_name});
    std.debug.print("Line: {}\n", .{src.line});
    std.debug.print("Module: {s}\n", .{src.module});  // NEW in 0.14.0+
}
```

### Intrusive Data Structures

```zig
const std = @import("std");

// DO: Use @fieldParentPtr for intrusive structures
const Node = struct {
    next: ?*Node,
    data: u32,
};

fn getNodeFromField(next_ptr: *?*Node) *Node {
    return @fieldParentPtr("next", next_ptr);
}
```

### Other Useful Builtins

```zig
// DO: Compile-time assertions
const assert = std.debug.assert;
comptime {
    assert(@sizeOf(u64) == 8);
}

// DO: Panic with message
fn criticalError() noreturn {
    @panic("Critical error occurred");
}

// DO: Trap (undefined behavior in safe modes, useful in unsafe)
fn unreachableCode() noreturn {
    @trap();
}
```

---

## 6. Best Practices & Patterns

### Code Organization

#### Module Structure

```zig
// DO: Organize modules clearly

// --- math.zig ---
const std = @import("std");

// Public API
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub fn subtract(a: i32, b: i32) i32 {
    return a - b;
}

// Private helpers
fn validateInput(x: i32) bool {
    return x >= 0;
}

// Tests in same file
test "add" {
    try std.testing.expectEqual(@as(i32, 5), add(2, 3));
}
```

#### Public API Design

```zig
// DO: Be intentional with pub

const std = @import("std");

// Public API
pub const Config = struct {
    timeout: u32,
    retries: u32,

    // Public method
    pub fn init() Config {
        return .{ .timeout = 30, .retries = 3 };
    }

    // Private method (no pub)
    fn validate(self: Config) bool {
        return self.timeout > 0 and self.retries > 0;
    }
};

// Private type (no pub)
const ConnectionState = enum {
    disconnected,
    connecting,
    connected,
};

// Public function
pub fn connect(config: Config) !void {
    if (!config.validate()) return error.InvalidConfig;
    // ...
}
```

#### Namespace Patterns (Post-usingnamespace)

```zig
// DO: Create clear namespaces with struct

pub const math = struct {
    pub fn add(a: i32, b: i32) i32 {
        return a + b;
    }

    pub fn subtract(a: i32, b: i32) i32 {
        return a - b;
    }
};

pub const string = struct {
    pub fn len(s: []const u8) usize {
        return s.len;
    }

    pub fn isEmpty(s: []const u8) bool {
        return s.len == 0;
    }
};

// Usage
const result = math.add(10, 20);
const empty = string.isEmpty("hello");
```

---

### Safety & Correctness

#### Assertions and Invariants

```zig
const std = @import("std");

// DO: Use assertions for invariants
fn processArray(array: []u32) void {
    std.debug.assert(array.len > 0);  // Removed in ReleaseSmall
    std.debug.assert(array.len <= 1000);

    // Process...
}

// DO: Use compile-time assertions
comptime {
    std.debug.assert(@sizeOf(usize) >= @sizeOf(u32));
}

// DO: Runtime checks that can't be optimized away
fn validateConfig(config: Config) !void {
    if (config.timeout == 0) return error.InvalidTimeout;
    if (config.retries > 10) return error.TooManyRetries;
}
```

#### Resource Cleanup with defer and errdefer

```zig
const std = @import("std");

// DO: Use defer for cleanup
fn processFile(path: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();  // Always runs

    // Work with file...
}

// DO: Use errdefer for error-only cleanup
fn complexOperation(allocator: std.mem.Allocator) !Result {
    const buffer = try allocator.alloc(u8, 1024);
    errdefer allocator.free(buffer);  // Only runs if error returned

    const data = try loadData(buffer);
    errdefer data.deinit();

    const result = try processData(data);

    return result;  // Success: nothing freed
}

// DO: Combine defer and errdefer
fn createResource(allocator: std.mem.Allocator) !*Resource {
    const resource = try allocator.create(Resource);
    errdefer allocator.destroy(resource);  // Free on error

    try resource.initialize();

    return resource;  // Caller responsible for cleanup
}
```

#### Proper Error Propagation

```zig
// DO: Propagate errors with context
fn openAndParse(path: []const u8) !Data {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.log.err("Failed to open {s}: {}", .{ path, err });
        return error.FileOpenFailed;
    };
    defer file.close();

    const contents = file.readToEndAlloc(allocator, 1_000_000) catch |err| {
        std.log.err("Failed to read {s}: {}", .{ path, err });
        return error.FileReadFailed;
    };
    defer allocator.free(contents);

    return parseData(contents) catch |err| {
        std.log.err("Failed to parse {s}: {}", .{ path, err });
        return error.ParseFailed;
    };
}
```

---

### Performance

#### Inline Assembly (with Typed Clobbers in 0.15.1)

```zig
// DO: Inline assembly for critical sections
fn readCycleCounter() u64 {
    return asm volatile ("rdtsc"
        : [ret] "={eax}" (-> u64),
        :
        : "edx"
    );
}

// NEW in 0.15.1: Typed clobbers
```

#### SIMD Operations

```zig
const std = @import("std");

// DO: Use SIMD for data parallelism
fn addVectors(a: []const f32, b: []const f32, result: []f32) void {
    std.debug.assert(a.len == b.len and b.len == result.len);

    const vec_len = 4;
    const Vec = @Vector(vec_len, f32);

    var i: usize = 0;
    while (i + vec_len <= a.len) : (i += vec_len) {
        const va: Vec = a[i..][0..vec_len].*;
        const vb: Vec = b[i..][0..vec_len].*;
        const vr = va + vb;
        result[i..][0..vec_len].* = vr;
    }

    // Handle remainder
    while (i < a.len) : (i += 1) {
        result[i] = a[i] + b[i];
    }
}
```

#### Cache-Friendly Data Structures

```zig
// DO: Structure of Arrays (SoA) for better cache performance
const Entities = struct {
    positions_x: []f32,
    positions_y: []f32,
    velocities_x: []f32,
    velocities_y: []f32,
    count: usize,

    fn update(self: *Entities, dt: f32) void {
        // Better cache locality: process all x positions together
        for (0..self.count) |i| {
            self.positions_x[i] += self.velocities_x[i] * dt;
        }
        for (0..self.count) |i| {
            self.positions_y[i] += self.velocities_y[i] * dt;
        }
    }
};

// DON'T: Array of Structures (AoS) for hot loops
const Entity = struct {
    position_x: f32,
    position_y: f32,
    velocity_x: f32,
    velocity_y: f32,
};
// Less cache-friendly when processing many entities
```

#### Zero-Cost Abstractions

```zig
// DO: Use comptime for zero-cost generics
fn BoundedQueue(comptime T: type, comptime capacity: usize) type {
    return struct {
        buffer: [capacity]T = undefined,
        head: usize = 0,
        tail: usize = 0,

        pub fn push(self: *@This(), item: T) !void {
            if (self.isFull()) return error.QueueFull;
            self.buffer[self.tail] = item;
            self.tail = (self.tail + 1) % capacity;
        }

        pub fn pop(self: *@This()) ?T {
            if (self.isEmpty()) return null;
            const item = self.buffer[self.head];
            self.head = (self.head + 1) % capacity;
            return item;
        }

        fn isFull(self: *const @This()) bool {
            return (self.tail + 1) % capacity == self.head;
        }

        fn isEmpty(self: *const @This()) bool {
            return self.head == self.tail;
        }
    };
}

// Each instantiation is fully specialized at compile time
var queue = BoundedQueue(u32, 16){};
```

---

## 7. Common Patterns & Idioms

### Builder Pattern

```zig
const std = @import("std");

pub const HttpRequest = struct {
    method: []const u8,
    url: []const u8,
    headers: std.ArrayList(Header),
    body: ?[]const u8,

    pub const Header = struct {
        name: []const u8,
        value: []const u8,
    };

    pub const Builder = struct {
        allocator: std.mem.Allocator,
        method: []const u8 = "GET",
        url: []const u8 = "",
        headers: std.ArrayList(Header),
        body: ?[]const u8 = null,

        pub fn init(allocator: std.mem.Allocator) Builder {
            return .{
                .allocator = allocator,
                .headers = std.ArrayList(Header).init(allocator),
            };
        }

        pub fn setMethod(self: *Builder, method: []const u8) *Builder {
            self.method = method;
            return self;
        }

        pub fn setUrl(self: *Builder, url: []const u8) *Builder {
            self.url = url;
            return self;
        }

        pub fn addHeader(self: *Builder, name: []const u8, value: []const u8) !*Builder {
            try self.headers.append(.{ .name = name, .value = value });
            return self;
        }

        pub fn setBody(self: *Builder, body: []const u8) *Builder {
            self.body = body;
            return self;
        }

        pub fn build(self: *Builder) HttpRequest {
            return .{
                .method = self.method,
                .url = self.url,
                .headers = self.headers,
                .body = self.body,
            };
        }
    };
};

// Usage
var builder = HttpRequest.Builder.init(allocator);
const request = try builder
    .setMethod("POST")
    .setUrl("https://api.example.com/data")
    .addHeader("Content-Type", "application/json")
    .setBody("{\"key\": \"value\"}")
    .build();
```

### Iterator Pattern

```zig
const std = @import("std");

pub fn RangeIterator(comptime T: type) type {
    return struct {
        current: T,
        end: T,
        step: T,

        const Self = @This();

        pub fn init(start: T, end: T, step: T) Self {
            return .{ .current = start, .end = end, .step = step };
        }

        pub fn next(self: *Self) ?T {
            if (self.current >= self.end) return null;
            const value = self.current;
            self.current += self.step;
            return value;
        }
    };
}

// Usage
var iter = RangeIterator(u32).init(0, 10, 2);
while (iter.next()) |value| {
    std.debug.print("{} ", .{value});  // 0 2 4 6 8
}
```

### Testing Patterns

```zig
const std = @import("std");
const testing = std.testing;

// DO: Use std.testing.allocator for tests
test "allocations are tracked" {
    const allocator = testing.allocator;

    const buffer = try allocator.alloc(u8, 100);
    defer allocator.free(buffer);

    // If we forget defer, test will fail with leak detection
}

// DO: Use expectEqual with explicit types
test "math operations" {
    try testing.expectEqual(@as(i32, 5), add(2, 3));
    try testing.expect(5 == add(2, 3));
}

// DO: Group related tests
test "HashMap operations" {
    var map = std.AutoHashMap(u32, u32).init(testing.allocator);
    defer map.deinit();

    try map.put(1, 100);
    try testing.expectEqual(@as(?u32, 100), map.get(1));
    try testing.expect(map.contains(1));
}
```

### Logging Patterns

```zig
const std = @import("std");

// DO: Use std.log for application logging
pub fn main() !void {
    std.log.debug("Starting application", .{});
    std.log.info("Listening on port 8080", .{});
    std.log.warn("Cache size exceeded", .{});
    std.log.err("Failed to connect: {s}", .{"timeout"});
}

// DO: Define custom log scope
const log = std.log.scoped(.network);

fn handleConnection() void {
    log.info("New connection established", .{});
    log.debug("Buffer size: {}", .{buffer_size});
}
```

### Option Parsing

```zig
const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <input_file>\n", .{args[0]});
        return;
    }

    const input_file = args[1];
    std.debug.print("Processing: {s}\n", .{input_file});
}
```

---

## 8. Build System (build.zig)

### Basic build.zig Structure

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // Target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create executable
    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Install to output directory
    b.installArtifact(exe);

    // Create run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Forward args: zig build run -- arg1 arg2
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
```

### Adding Dependencies

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link system libraries
    exe.linkLibC();
    exe.linkSystemLibrary("sqlite3");

    // Add module dependency
    const dep = b.dependency("some_package", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("some_package", dep.module("some_package"));

    b.installArtifact(exe);
}
```

### Cross-Compilation

```zig
// DO: Cross-compile by specifying target
// zig build -Dtarget=x86_64-linux-gnu
// zig build -Dtarget=aarch64-macos-none
// zig build -Dtarget=wasm32-freestanding-musl

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    // Target is automatically applied to all artifacts
    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
    });

    b.installArtifact(exe);
}
```

### File System Watching (NEW macOS Support in 0.15.1)

```zig
// NEW in 0.15.1: Better file system watching on macOS
// zig build --watch

pub fn build(b: *std.Build) void {
    // Build configuration...
    // Watch mode now works on macOS with proper FSEvents support
}
```

### WriteFile and RemoveDir Steps

```zig
pub fn build(b: *std.Build) void {
    // DO: Generate files during build
    const write_file = b.addWriteFiles();
    _ = write_file.add("generated.txt", "This is generated content");

    // DO: Clean up directories
    const clean = b.step("clean", "Clean build artifacts");
    const remove_dir = b.addRemoveDirTree(b.path("zig-out"));
    clean.dependOn(&remove_dir.step);
}
```

---

## 9. Testing

### Test Declarations

```zig
const std = @import("std");
const testing = std.testing;

// DO: Simple tests
test "basic addition" {
    try testing.expectEqual(@as(i32, 4), 2 + 2);
}

// DO: Tests with setup/teardown
test "complex operation" {
    const allocator = testing.allocator;

    var list = std.ArrayList(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);

    try testing.expectEqual(@as(usize, 3), list.items.len);
    try testing.expectEqual(@as(u32, 1), list.items[0]);
}
```

### Testing Allocator

```zig
const std = @import("std");
const testing = std.testing;

// DO: Use testing.allocator for leak detection
test "no memory leaks" {
    const allocator = testing.allocator;

    const buffer = try allocator.alloc(u8, 100);
    defer allocator.free(buffer);  // Must free!

    // If defer is missing, test will fail
}
```

### Common Testing Functions

```zig
const std = @import("std");
const testing = std.testing;

test "testing functions" {
    // Equality (requires explicit type on expected)
    try testing.expectEqual(@as(i32, 42), getValue());

    // Boolean
    try testing.expect(getValue() > 0);

    // String equality
    try testing.expectEqualStrings("hello", getString());

    // Slice equality
    const a = [_]u32{ 1, 2, 3 };
    const b = [_]u32{ 1, 2, 3 };
    try testing.expectEqualSlices(u32, &a, &b);

    // Error checking
    try testing.expectError(error.FileNotFound, openFile());

    // Approximate float equality
    try testing.expectApproxEqAbs(@as(f64, 1.0), 0.99999, 0.0001);
}

fn getValue() i32 {
    return 42;
}

fn getString() []const u8 {
    return "hello";
}

fn openFile() !void {
    return error.FileNotFound;
}
```

### Running Tests

```zig
// Run all tests in a file
// zig test src/main.zig

// Run tests with build system
// zig build test

// Run specific test
// zig test src/main.zig --test-filter "basic addition"

// Run with coverage (0.11.0+)
// zig test src/main.zig --test-coverage
```

---

## 10. Migration Notes

### Breaking Changes from 0.14.0 to 0.15.1

#### 1. REMOVED: `usingnamespace`

**Impact**: High  
**Action Required**: Replace all `usingnamespace` with explicit declarations

```zig
// BEFORE
pub usingnamespace @import("module.zig");

// AFTER
const module = @import("module.zig");
pub const funcA = module.funcA;
pub const funcB = module.funcB;
```

#### 2. REMOVED: `async`/`await`

**Impact**: High (if used)  
**Action Required**: Use synchronous I/O or external libraries

```zig
// BEFORE
async fn fetchData() ![]u8 { }

// AFTER
fn fetchData() ![]u8 { }
```

#### 3. REMOVED: `std.BoundedArray`

**Impact**: Medium  
**Action Required**: Use custom bounded array or ArrayList with FixedBufferAllocator

#### 4. CHANGED: Format Methods No Longer Accept Format Strings

**Impact**: Medium  
**Action Required**: Update custom `format` methods

```zig
// BEFORE
pub fn format(
    self: MyType,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    // ...
}

// AFTER
pub fn format(self: MyType, writer: anytype) !void {
    try writer.print("MyType{{ ... }}", .{});
}
```

#### 5. CHANGED: LinkedList De-genericified

**Impact**: Low  
**Action Required**: Use intrusive linked list pattern

#### 6. CHANGED: `@ptrCast` Allows Pointer-to-Slice

**Impact**: Low (improvement)  
**Benefit**: More flexible pointer casting

#### 7. CHANGED: Error on Lossy Int-to-Float Coercion

**Impact**: Medium  
**Action Required**: Use explicit `@floatFromInt`

```zig
// BEFORE
const f: f64 = int_value;

// AFTER
const f: f64 = @floatFromInt(int_value);
```

### Deprecated Features to Avoid

```zig
// Don't use these (removed or being removed)
// - usingnamespace (removed)
// - async/await (removed)
// - @setCold (removed, use @branchHint)
// - std.BoundedArray (removed)
// - CountingWriter (removed)
// - Old BufferedWriter API (changed)
```

---

## 11. Quick Reference

### Memory Management Checklist

- [ ] All allocations have corresponding deallocations
- [ ] Using appropriate allocator for use case
  - [ ] GPA for development
  - [ ] Arena for request-scoped allocations
  - [ ] Fixed buffer for bounded, temporary allocations
- [ ] `defer` or `errdefer` immediately after allocation
- [ ] No hidden allocations
- [ ] Testing with `std.testing.allocator` to detect leaks

### Error Handling Decision Tree

```
Does the operation need a value?
├─ Yes: Can it fail to produce one?
│  ├─ Yes: Is the failure exceptional?
│  │  ├─ Yes: Use error union (!T)
│  │  └─ No: Use optional (?T)
│  └─ No: Return T directly
└─ No: Can it fail?
   ├─ Yes: Return !void
   └─ No: Return void
```

### Allocator Selection Guide

| Use Case              | Allocator                 | Notes                             |
| --------------------- | ------------------------- | --------------------------------- |
| Development/Testing   | `GeneralPurposeAllocator` | Detects leaks, safe               |
| Request-scoped        | `ArenaAllocator`          | Bulk deallocation                 |
| Fixed-size, temporary | `FixedBufferAllocator`    | Stack-based                       |
| Large, long-lived     | `page_allocator`          | Direct OS allocations             |
| C interop             | `c_allocator`             | Compatible with C `malloc`/`free` |
| Production (general)  | `GeneralPurposeAllocator` | Good balance                      |

### Common Compiler Errors and Fixes

#### "error: expected type '[]const u8', found '\*const [N:0]u8'"

```zig
// String literal type mismatch
fn process(s: []const u8) void { }
process("hello");  // Error

// Coerce to slice
process(&[_]u8{'h', 'e', 'l', 'l', 'o'});
// OR
const s: []const u8 = "hello";
process(s);
```

#### "error: cannot assign to constant"

```zig
// Trying to mutate const
const x: i32 = 10;
x = 20;  // Error

// Use var for mutable
var x: i32 = 10;
x = 20;
```

#### "error: use of undeclared identifier"

```zig
// Wrong import or missing pub
const other = @import("other.zig");
other.privateFunc();  // Error if not pub

// Ensure function is pub in other.zig
pub fn privateFunc() void { }
```

#### "error: unable to evaluate constant expression"

```zig
// Runtime value in comptime context
var x: i32 = 10;
const T = if (x > 5) i32 else i64;  // Error

// Use comptime
comptime var x: i32 = 10;
const T = if (x > 5) i32 else i64;
```

#### "error: expected type 'type', found 'comptime_int'"

```zig
// Wrong generic usage
fn process(T: type) void { }
process(42);  // Error

// Pass a type
process(i32);
```

---

## Summary

This guide covers the essential patterns and practices for writing idiomatic Zig 0.15.1 code:

1. **Use decl literals** (`.enum_value`, `.{ .field = value }`) for cleaner code
2. **Avoid removed features** (`usingnamespace`, `async`/`await`)
3. **Pass allocators explicitly** - no hidden memory allocation
4. **Handle errors with `!T`** and optionals with `?T`
5. **Use proper I/O APIs** with the new Writer/Reader system
6. **Leverage comptime** for zero-cost abstractions
7. **Follow explicit practices** - no hidden control flow
8. **Test with leak detection** using `std.testing.allocator`

### Key Principles

- **Explicit over implicit**: Memory, errors, control flow
- **Compile-time over runtime**: Use comptime when possible
- **Safety first**: Use GPA during development
- **Zero-cost abstractions**: Generics have no runtime cost
- **Simple over clever**: Zig favors clarity

### Further Learning

- Read the official documentation: https://ziglang.org/documentation/0.15.1/
- Explore the standard library source code
- Join the Zig community: https://ziglang.org/community/
- Follow Zig development: https://github.com/ziglang/zig

---

**Document Version**: 1.0
**Zig Version**: 0.15.1
**Last Updated**: October 2025

This guide is intended for AI agents generating Zig code. Always verify against official documentation for the most current information.
