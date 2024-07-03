const std = @import("std");
const Expression = @import("expression.zig");
const StringHashMap = std.StringHashMap;

const Allocator = std.mem.Allocator;

pub const SymbolTable = @This();

pub const FunctionDef = *const fn (anytype) anyerror!Expression.Result;

allocator: Allocator,
symbols: StringHashMap(Expression.Result),
functions: StringHashMap(FunctionDef),

pub fn init(allocator: Allocator) SymbolTable {
    return .{
        .allocator = allocator,
        .symbols = StringHashMap(Expression.Result).init(allocator),
        .functions = StringHashMap(FunctionDef).init(allocator)
    };
}

pub fn registerSymbol(self: SymbolTable, name: []const u8, val: Expression.Result) Allocator.Error!void {
    self.symbols.put(name, val);
}

pub fn getSymbol(self: SymbolTable, name: []const u8) ?Expression.Result {
    return self.symbols.get(name);
}

pub fn deinit(self: *SymbolTable) void {
    self.symbols.deinit();
    self.functions.deinit();
    self.* = undefined;
}
