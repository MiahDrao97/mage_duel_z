const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Error = error {
    ReachedCapacity,
};

pub fn BufferStringBuilder(capacity: comptime_int) type {
    if (capacity < 1) {
        @compileError("Buffer size must be 1 or greater. Was: " ++ capacity);
    }

    return struct {
        buf: [ capacity ]u8 = [_]u8 { 0 } ** capacity,
        idx: usize = 0,

        const Self = @This();

        pub fn append(self: *Self, char: u8) Error!void {
            if (self.idx >= capacity) {
                return Error.ReachedCapacity;
            }
            self.buf[self.idx] = char;
            self.idx += 1;
        }

        pub fn appendStr(self: *Self, str: []const u8) Error!void {
            if (self.idx + str.len > capacity) {
                return Error.ReachedCapacity;
            }
            if (str.len == 0) {
                return;
            }
            @memcpy(self.buf[self.idx..(self.idx + str.len)], str);
            self.idx += str.len;
        }

        pub fn appendLine(self: *Self, str: []const u8) Error!void {
            if (self.idx + str.len + 1 > capacity) {
                return Error.ReachedCapacity;
            }
            self.appendStr(str) catch unreachable;
            self.append('\n') catch unreachable;
        }

        pub fn toString(self: Self) []u8 {
            return self.buf[0..self.idx];
        }

        pub fn reset(self: *Self) void {
            @memset(&self.buf, 0);
        }
    };
}

pub const DynamicStringBuilder = struct {
    allocator: Allocator,
    buf: []u8,
    idx: usize = 0,
    capacity: usize = 0,

    pub fn init(allocator: Allocator) DynamicStringBuilder {
        return DynamicStringBuilder {
            .allocator = allocator,
            .buf = &[_]u8 {}
        };
    }

    pub fn initCapacity(allocator: Allocator, size: usize) Allocator.Error!DynamicStringBuilder {
        const buf: []u8 = try allocator.alloc(u8, size);
        return DynamicStringBuilder {
            .allocator = allocator,
            .buf = buf,
            .capacity = size
        };
    }

    fn grow(self: *DynamicStringBuilder, amt: usize) Allocator.Error!void {
        if (amt > 1) {
            var increase: usize = self.capacity * 2;
            while (increase < amt) {
                increase *= 2;
            }
            self.capacity += increase;
        } else {
            if (self.capacity == 0) {
                self.capacity = 4;
            } else {
                self.capacity *= 2;
            }
        }
        const new_slice: []u8 = try self.allocator.alloc(u8, self.capacity);
        @memcpy(new_slice[0..self.capacity], self.buf);

        self.allocator.free(self.buf);
        self.buf = new_slice;
    }

    pub fn append(self: *DynamicStringBuilder, char: u8) Allocator.Error!void {
        if (self.idx >= self.capacity) {
            try self.grow(1);
        }
        self.buf[self.idx] = char;
        self.idx += 1;
    }

    pub fn appendStr(self: *DynamicStringBuilder, str: []const u8) Allocator.Error!void {
        if (str.len == 0) {
            return;
        }
        if (self.idx + str.len > self.capacity) {
            try self.grow(str.len);
        }

        @memcpy(self.buf[self.idx..(self.idx + str.len)], str);
        self.idx += str.len;
    }

    pub fn appendLine(self: *DynamicStringBuilder, str: []const u8) Allocator.Error!void {
        if (str.len > 0 and self.idx + str.len + 1 > self.capacity) {
            try self.grow(str.len + 1);
        }
        self.appendStr(str) catch unreachable;
        self.append('\n') catch unreachable;
    }

    pub fn toString(self: DynamicStringBuilder) []u8 {
        return self.buf[0..self.idx];
    }

    pub fn reset(self: *DynamicStringBuilder) void {
        @memset(&self.buf, 0);
    }

    pub fn deinit(self: *DynamicStringBuilder) void {
        if (self.buf.len > 0) {
            self.allocator.free(self.buf);
        }
        self.* = undefined;
    }
};
