const expression = @import("expression.zig");
const SymbolTable = expression.SymbolTable;

pub const Statement = @This();

ptr: *anyopaque,
executeFn: *const fn (*anyopaque, SymbolTable) anyerror!void,
deinitFn: ?*const fn (*anyopaque) void = null,

pub fn execute(self: *Statement, symbol_table: SymbolTable) !void {
    try self.executeFn(self, symbol_table);
}

pub fn deinit(self: *Statement) void {
    if (self.deinitFn) |call_deinit| {
        call_deinit(self.ptr);
    }
}

pub fn deinitAll(statements: []Statement) void {
    for (statements) |stmt| {
        stmt.deinit();
    }
}
