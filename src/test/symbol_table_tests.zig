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
const IntResult = parsing.IntResult;

fn testFunc(_: ?*anyopaque, args: []ExpressionResult) !ExpressionResult {
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
            const x: ExpressionResult = try symbol.unwrapValue();
            const i: IntResult = try x.expectType(IntResult);
            try testing.expect(i.value == 3);
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
            const x: ExpressionResult = try symbol.unwrapValue();
            const i: IntResult = try x.expectType(IntResult);
            try testing.expect(i.value == 3);
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

        _ = try symbol_value.?.unwrapFunction();
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
        const func: FunctionDef = try func_symbol.?.unwrapFunction();

        const value_symbol: ?Symbol = symbol_table.getSymbol("$");
        try testing.expect(value_symbol != null);
        const val: ExpressionResult = try value_symbol.?.unwrapValue();

        var args: [1]ExpressionResult = [_]ExpressionResult { val };
        const result: ExpressionResult = try func(null, &args);
        const i: IntResult = try result.expectType(IntResult);
        try testing.expect(i.value == 3);
    }
}