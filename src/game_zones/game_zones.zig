const std = @import("std");
const Iterator = @import("util").Iterator;
const Allocator = std.mem.Allocator;

pub const types = @import("types.zig");

pub fn Deck(comptime T: type) type {
    return struct {
        elements:       Iterator(T),
        allocator:      Allocator,
    };
}
