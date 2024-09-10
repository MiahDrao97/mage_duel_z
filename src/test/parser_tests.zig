const std = @import("std");
const parsing = @import("parsing");
const testing = std.testing;

const Parser = parsing.Parser;
const Tokenizer = parsing.Tokenizer;
const Token = parsing.Token;
const CardDef = parsing.CardDef;
const Scope = parsing.Scope;
const Symbol = parsing.Symbol;
const SymbolTable = parsing.SymbolTable;
const FunctionDef = parsing.FunctionDef;
const ExpressionResult = parsing.ExpressionResult;

// result types
const IntResult = parsing.IntResult;
const ListResult = parsing.ListResult;

test "parse() list literal" {
    {
        const script: []const u8 =
            \\[0]: {
            \\  $ = [ 1 | 2 ];
            \\}
            ;

        const tokenizer = Tokenizer.init(testing.allocator);
        const tokens: []Token = try tokenizer.tokenize(script);

        var card_def: *CardDef = undefined;
        {
            defer Token.deinitAllAndFree(testing.allocator, tokens);

            const parser: Parser = Parser.init(testing.allocator);
            card_def = try parser.parseTokens(tokens);
        }
        defer card_def.deinit();

        var sym_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer sym_table.deinit();

        try card_def.actions[0].stmt().execute(&sym_table);

        const result: ?Symbol = sym_table.getSymbol("$");
        try testing.expect(result != null);

        var list_result: ListResult = try (try result.?.unwrapValue()).expectType(ListResult);
        defer list_result.deinit();
        
        for (list_result.items, 1..) |item, expected| {
            const item_result: IntResult = try item.expectType(IntResult);
            try testing.expect(item_result.value == @as(i32, @intCast(expected)));
        }
    }
}
test "parse() additive expressions" {
    {
        const script: []const u8 = "[0]: { $ = 1 + 1; }";

        const tokenizer = Tokenizer.init(testing.allocator);
        const tokens: []Token = try tokenizer.tokenize(script);

        var card_def: *CardDef = undefined;
        {
            defer Token.deinitAllAndFree(testing.allocator, tokens);

            const parser: Parser = Parser.init(testing.allocator);
            card_def = try parser.parseTokens(tokens);
        }
        defer card_def.deinit();

        var sym_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer sym_table.deinit();

        try card_def.actions[0].stmt().execute(&sym_table);

        const result: ?Symbol = sym_table.getSymbol("$");
        try testing.expect(result != null);

        const int_result: IntResult = try (try result.?.unwrapValue()).expectType(IntResult);
        try testing.expect(int_result.value == 2);
    }
}
test "parse() Firebolt" {
    const script: []const u8 =
        \\#attack
        \\#rank=c
        \\#accuracy=4
        \\// firebolt
        \\[1]: {
        \\  $ = target(1 from Player);
        \\  1d6+4 fire => $;
        \\}
        ;

    const tokenizer = Tokenizer.init(testing.allocator);
    const tokens: []Token = try tokenizer.tokenize(script);

    var card_def: *CardDef = undefined;
    {
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        const parser: Parser = Parser.init(testing.allocator);
        card_def = try parser.parseTokens(tokens);
    }
    defer card_def.deinit();

    try testing.expect(card_def.labels.len == 3);
    try testing.expect(card_def.actions.len == 1);

    try testing.expect(card_def.isAttack());
    try testing.expect(!card_def.isOneTimeUse());
    try testing.expect(card_def.getRank() == 'c');
    try testing.expect(card_def.getAccuracy() == 4);

    const scope: *Scope = try card_def.toOwnedScope();
    defer scope.deinit();

    const get_action_cost_func: Symbol = scope.getSymbol("getActionCost").?;
    const func: FunctionDef = try get_action_cost_func.unwrapFunction();
        
    var args: [1]ExpressionResult = [_]ExpressionResult { .{ .integer = .{ .value = 0 } } };
    const result: ExpressionResult = try func(card_def, &args);
    const int_result: IntResult = try result.expectType(IntResult);

    try testing.expect(int_result.value == 1);
    try testing.expect(!int_result.up_to);
}