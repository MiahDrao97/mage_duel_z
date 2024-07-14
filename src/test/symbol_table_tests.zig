const std = @import("std");
const testing = std.testing;
const debug = std.debug;
const parsing = @import("parsing");
const Tokenizer = parsing.Tokenizer;
const Token = parsing.Token;
const types = @import("game_zones").types;
const DamageType = types.DamageType;
const ExpressionResult = parsing.ExpressionResult;
const SymbolTable = parsing.SymbolTable;
const Symbol = parsing.Symbol;

test {
    {
        var symbol_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer symbol_table.deinit();

        const symbol_value: ExpressionResult = .{ .integer = 3 };
        try symbol_table.putValue("$", symbol_value);
        if (symbol_table.getSymbol("$")) |symbol| {
            switch (symbol) {
                Symbol.value => |x| {
                    switch (x.*) {
                        ExpressionResult.integer => |i| {
                            try testing.expect(i == 3);
                        },
                        else => return error.UnexpectedValue,
                    }
                },
                else => return error.UnexpectedSymbol,
            }
        } else {
            return error.SymbolNotFound;
        }
    }
    {
        var symbol_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer symbol_table.deinit();

        const symbol_value: ExpressionResult = .{ .integer = 3 };
        try symbol_table.putValue("$", symbol_value);
        
        try symbol_table.newScope();

        // should still work because this is defined on the outer scope
        if (symbol_table.getSymbol("$")) |symbol| {
            switch (symbol) {
                Symbol.value => |x| {
                    switch (x.*) {
                        ExpressionResult.integer => |i| {
                            try testing.expect(i == 3);
                        },
                        else => return error.UnexpectedValue,
                    }
                },
                else => return error.UnexpectedSymbol,
            }
        } else {
            return error.SymbolNotFound;
        }
    }
    {
        var symbol_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer symbol_table.deinit();

        try symbol_table.newScope();

        // define symbol on inner scope
        const symbol_value: ExpressionResult = .{ .integer = 3 };
        try symbol_table.putValue("$", symbol_value);
        
        symbol_table.endScope();

        // scope is gone
        try testing.expect(symbol_table.getSymbol("$") == null);
    }
}
