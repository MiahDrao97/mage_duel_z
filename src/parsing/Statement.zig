const expression = @import("expression.zig");
const SymbolTable = expression.SymbolTable;
const Allocator = @import("std").mem.Allocator;

pub const Statement = @This();

ptr: *anyopaque,
execute_fn: *const fn (*anyopaque, *SymbolTable) anyerror!void,
deinit_fn: *const fn (*anyopaque) void,

pub fn execute(self: Statement, symbol_table: *SymbolTable) !void {
    try self.execute_fn(self.ptr, symbol_table);
}

pub fn deinit(self: Statement) void {
    self.deinit_fn(self.ptr);
}

pub fn deinitAll(statements: []Statement) void {
    for (statements) |stmt| {
        stmt.deinit();
    }
}

pub fn deinitAllAndFree(allocator: Allocator, statements: []Statement) void {
    deinitAll(statements);
    allocator.free(statements);
}
