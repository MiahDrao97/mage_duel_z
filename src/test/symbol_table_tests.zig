const std = @import("std");
const testing = std.testing;
const debug = std.debug;
const parsing = @import("parsing");
const Tokenizer = parsing.Tokenizer;
const Token = parsing.Token;
const types = @import("game_zones").types;
const DamageType = types.DamageType;
const ExpressionResult = parsing.ExpressionResult;
const FunctionDef = parsing.FunctionDef;
const SymbolTable = parsing.SymbolTable;
const Symbol = parsing.Symbol;

fn testFunc(args: []ExpressionResult) !ExpressionResult {
    if (args.len < 1) {
        return ExpressionResult.void;
    }
    return args[0];
}

test "SymbolTable.putValue()" {
    {
        var symbol_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer symbol_table.deinit();

        const symbol_value: ExpressionResult = .{
            .integer = .{
                .value = 3
            }
        };
        try symbol_table.putValue("$", symbol_value);
        if (symbol_table.getSymbol("$")) |symbol| {
            switch (symbol) {
                Symbol.value => |x| {
                    switch (x.*) {
                        ExpressionResult.integer => |i| {
                            try testing.expect(i.value == 3);
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

        const symbol_value: ExpressionResult = .{
            .integer = .{
                .value = 3
            }
        };
        try symbol_table.putValue("$", symbol_value);
        
        try symbol_table.newScope();

        // should still work because this is defined on the outer scope
        if (symbol_table.getSymbol("$")) |symbol| {
            switch (symbol) {
                Symbol.value => |x| {
                    switch (x.*) {
                        ExpressionResult.integer => |i| {
                            try testing.expect(i.value == 3);
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
        const symbol_value: ExpressionResult = .{
            .integer = .{
                .value = 3
            }
        };
        try symbol_table.putValue("$", symbol_value);
        
        symbol_table.endScope();

        // scope is gone
        try testing.expect(symbol_table.getSymbol("$") == null);
    }
}
test "SymbolTable.putFunc()" {
    {
        var symbol_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer symbol_table.deinit();
        
        try symbol_table.putFunc("testFunc", &testFunc);

        const symbol_value: ?Symbol = symbol_table.getSymbol("testFunc");
        try testing.expect(symbol_value != null);

        switch (symbol_value.?) {
            Symbol.function => { },
            else => return error.UnexpectedSymbol
        }
    }
    {
        var symbol_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer symbol_table.deinit();
        
        try symbol_table.putFunc("testFunc", &testFunc);
        const expr_value: ExpressionResult = .{
            .integer = .{
                .value = 3
            }
        };
        try symbol_table.putValue("$", expr_value);

        const func_symbol: ?Symbol = symbol_table.getSymbol("testFunc");
        try testing.expect(func_symbol != null);

        var func: FunctionDef = undefined;
        switch (func_symbol.?) {
            Symbol.function => |f| {
                func = f;
            },
            else => return error.UnexpectedSymbol
        }

        const value_symbol: ?Symbol = symbol_table.getSymbol("$");
        try testing.expect(value_symbol != null);

        var val: ExpressionResult = undefined;
        switch (value_symbol.?) {
            Symbol.value => |v| {
                val = v.*;
            },
            else => return error.UnexpectedSymbol
        }

        var args = [_]ExpressionResult { val };
        const result: ExpressionResult = try func(&args);
        switch (result) {
            ExpressionResult.integer => |i| {
                try testing.expect(i.value == 3);
            },
            else => return error.UnexpectedValue,
        }
    }
}