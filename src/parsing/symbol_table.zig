const std = @import("std");
const HashMap = std.HashMap;

const Allocator = std.mem.Allocator;

pub const SymbolTable = @This();

allocator: Allocator,

pub fn init(allocator: Allocator) SymbolTable {
    return SymbolTable { .allocator = allocator };
}
