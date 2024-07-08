const expression = @import("expression.zig");
const SymbolTable = expression.SymbolTable;

const Statement = @This();

ptr: *anyopaque,
executeFn: *const fn (*anyopaque, SymbolTable) anyerror!void,

pub fn execute(self: *Statement, symbol_table: SymbolTable) !void {
    try self.executeFn(self, symbol_table);
}
