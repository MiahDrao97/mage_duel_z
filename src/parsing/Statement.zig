const expression = @import("expression.zig");
const SymbolTable = expression.SymbolTable;

pub const Statement = @This();

ptr: *anyopaque,
execute_fn: *const fn (*anyopaque, *SymbolTable) anyerror!void,
deinit_fn: ?*const fn (*anyopaque) void = null,

pub fn execute(self: Statement, symbol_table: *SymbolTable) !void {
    try self.execute_fn(self.ptr, symbol_table);
}

pub fn deinit(self: Statement) void {
    if (self.deinit_fn) |call_deinit| {
        call_deinit(self.ptr);
    }
}

pub fn deinitAll(statements: []Statement) void {
    for (statements) |stmt| {
        stmt.deinit();
    }
}
