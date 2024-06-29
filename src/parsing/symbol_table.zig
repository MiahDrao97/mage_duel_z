const std = @import("std");
const ExpressionResult = @import("expression.zig").Result;

const HashMap = std.AutoHashMap([]const u8, ExpressionResult);

const Allocator = std.mem.Allocator;

pub const SymbolTable = @This();

allocator: Allocator,
symbols: HashMap,

pub fn init(allocator: Allocator) SymbolTable {
    return SymbolTable {
        .allocator = allocator,
        .symbols = HashMap.init(allocator),
    };
}

pub fn registerSymbol(self: SymbolTable, name: []const u8, val: ExpressionResult) Allocator.Error!void {
    self.symbols.put(name, val);
}

pub fn getSymbol(self: SymbolTable, name: []const u8) ?ExpressionResult {
    return self.symbols.get(name);
}

pub fn deinit(self: *SymbolTable) void {
    self.symbols.deinit();
    self.* = undefined;
}
