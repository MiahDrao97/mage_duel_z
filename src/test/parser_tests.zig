const std = @import("std");
const parsing = @import("parsing");
const game_zones = @import("game_zones");
const testing = std.testing;

const Parser = parsing.Parser;
const Tokenizer = parsing.Tokenizer;
const Token = parsing.Token;
const CardCost = game_zones.types.CardCost;
const CardDef = parsing.CardDef;
const Scope = parsing.Scope;
const Symbol = parsing.Symbol;
const SymbolTable = parsing.SymbolTable;
const FunctionDef = parsing.FunctionDef;
const ExpressionResult = parsing.ExpressionResult;
const DamageType = game_zones.types.DamageType;
const Crystal = game_zones.types.Crystal;
const TokenIterator = parsing.TokenIterator;

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

        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };
        const tokens: []Token = try tokenizer.tokenize(script);
        errdefer Token.deinitAllAndFree(testing.allocator, tokens);

        var iter: TokenIterator = try TokenIterator.from(testing.allocator, tokens);
        defer iter.deinit();

        const parser: Parser = .{ .allocator = testing.allocator };
        const card_def: *CardDef = try parser.parseTokens(iter);
        defer card_def.deinit();

        var sym_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer sym_table.deinit();

        try card_def.actions[0].stmt().execute(&sym_table);

        const result: ?Symbol = sym_table.getSymbol("$");
        try testing.expect(result != null);

        var list_result: ListResult = try (try result.?.unwrapValue()).expectType(ListResult);
        defer list_result.deinit();
        
        try testing.expect(list_result.items.len == 2);
        try testing.expectEqualStrings(@tagName(.integer), list_result.component_type.?);

        for (list_result.items, 1..) |item, expected| {
            const item_result: IntResult = try item.expectType(IntResult);
            try testing.expect(item_result.value == @as(i32, @intCast(expected)));
        }
    }
    {
        const script: []const u8 =
            \\[0]: {
            \\  $ = [];
            \\}
            ;

        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };
        const tokens: []Token = try tokenizer.tokenize(script);
        errdefer Token.deinitAllAndFree(testing.allocator, tokens);

        var iter: TokenIterator = try TokenIterator.from(testing.allocator, tokens);
        defer iter.deinit();

        const parser: Parser = .{ .allocator = testing.allocator };
        const card_def: *CardDef = try parser.parseTokens(iter);
        defer card_def.deinit();

        var sym_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer sym_table.deinit();

        try card_def.actions[0].stmt().execute(&sym_table);

        const result: ?Symbol = sym_table.getSymbol("$");
        try testing.expect(result != null);

        var list_result: ListResult = try (try result.?.unwrapValue()).expectType(ListResult);
        defer list_result.deinit();
        
        try testing.expect(list_result.items.len == 0);
        try testing.expect(list_result.component_type == null);
    }
}
test "parse() additive expressions" {
    {
        const script: []const u8 = "[0]: { $ = 1 + 1; }";

        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };
        const tokens: []Token = try tokenizer.tokenize(script);
        errdefer Token.deinitAllAndFree(testing.allocator, tokens);

        var iter: TokenIterator = try TokenIterator.from(testing.allocator, tokens);
        defer iter.deinit();

        const parser: Parser = .{ .allocator = testing.allocator };
        const card_def: *CardDef = try parser.parseTokens(iter);
        defer card_def.deinit();

        var sym_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer sym_table.deinit();

        try card_def.actions[0].stmt().execute(&sym_table);

        const result: ?Symbol = sym_table.getSymbol("$");
        try testing.expect(result != null);

        const int_result: IntResult = try (try result.?.unwrapValue()).expectType(IntResult);
        try testing.expect(int_result.value == 2);
    }
    {
        const script: []const u8 = "[0]: { $ = 1 - 2; }";

        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };
        const tokens: []Token = try tokenizer.tokenize(script);
        errdefer Token.deinitAllAndFree(testing.allocator, tokens);

        var iter: TokenIterator = try TokenIterator.from(testing.allocator, tokens);
        defer iter.deinit();

        const parser: Parser = .{ .allocator = testing.allocator };
        const card_def: *CardDef = try parser.parseTokens(iter);
        defer card_def.deinit();

        var sym_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer sym_table.deinit();

        try card_def.actions[0].stmt().execute(&sym_table);

        const result: ?Symbol = sym_table.getSymbol("$");
        try testing.expect(result != null);

        const int_result: IntResult = try (try result.?.unwrapValue()).expectType(IntResult);
        try testing.expect(int_result.value == -1);
    }
}
test "parse() list-literal, additive expression combo" {
    {
        const script: []const u8 =
            \\[0]: {
            \\  $ = [ 1 | 2 ] + 3;
            \\}
            ;

        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };
        const tokens: []Token = try tokenizer.tokenize(script);
        errdefer Token.deinitAllAndFree(testing.allocator, tokens);

        var iter: TokenIterator = try TokenIterator.from(testing.allocator, tokens);
        defer iter.deinit();

        const parser: Parser = .{ .allocator = testing.allocator };
        const card_def: *CardDef = try parser.parseTokens(iter);
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
    {
        const script: []const u8 =
            \\[0]: {
            \\  $ = [ 1 | 2 ] + [];
            \\}
            ;

        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };
        const tokens: []Token = try tokenizer.tokenize(script);
        errdefer Token.deinitAllAndFree(testing.allocator, tokens);

        var iter: TokenIterator = try TokenIterator.from(testing.allocator, tokens);
        defer iter.deinit();

        const parser: Parser = .{ .allocator = testing.allocator };
        const card_def: *CardDef = try parser.parseTokens(iter);
        defer card_def.deinit();

        var sym_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer sym_table.deinit();

        try card_def.actions[0].stmt().execute(&sym_table);

        const result: ?Symbol = sym_table.getSymbol("$");
        try testing.expect(result != null);

        var list_result: ListResult = try (try result.?.unwrapValue()).expectType(ListResult);
        defer list_result.deinit();

        try testing.expect(list_result.items.len == 2);
        try testing.expectEqualStrings(@tagName(.integer), list_result.component_type.?);
        
        for (list_result.items, 1..) |item, expected| {
            const item_result: IntResult = try item.expectType(IntResult);
            try testing.expect(item_result.value == @as(i32, @intCast(expected)));
        }
    }
    {
        const script: []const u8 =
            \\[0]: {
            \\  $ = [ 1 | 2 ] +! [ 1 ];
            \\}
            ;

        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };
        const tokens: []Token = try tokenizer.tokenize(script);
        errdefer Token.deinitAllAndFree(testing.allocator, tokens);

        var iter: TokenIterator = try TokenIterator.from(testing.allocator, tokens);
        defer iter.deinit();

        const parser: Parser = .{ .allocator = testing.allocator };
        const card_def: *CardDef = try parser.parseTokens(iter);
        defer card_def.deinit();

        var sym_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer sym_table.deinit();

        try card_def.actions[0].stmt().execute(&sym_table);

        const result: ?Symbol = sym_table.getSymbol("$");
        try testing.expect(result != null);

        var list_result: ListResult = try (try result.?.unwrapValue()).expectType(ListResult);
        defer list_result.deinit();

        try testing.expect(list_result.items.len == 2);
        try testing.expectEqualStrings(@tagName(.integer), list_result.component_type.?);
        
        for (list_result.items, 1..) |item, expected| {
            const item_result: IntResult = try item.expectType(IntResult);
            try testing.expect(item_result.value == @as(i32, @intCast(expected)));
        }
    }
    {
        const script: []const u8 =
            \\[0]: {
            \\  $ = [ 1 | 2 ] +! [ 1 | 3 ];
            \\}
            ;

        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };
        const tokens: []Token = try tokenizer.tokenize(script);
        errdefer Token.deinitAllAndFree(testing.allocator, tokens);

        var iter: TokenIterator = try TokenIterator.from(testing.allocator, tokens);
        defer iter.deinit();

        const parser: Parser = .{ .allocator = testing.allocator };
        const card_def: *CardDef = try parser.parseTokens(iter);
        defer card_def.deinit();

        var sym_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer sym_table.deinit();

        try card_def.actions[0].stmt().execute(&sym_table);

        const result: ?Symbol = sym_table.getSymbol("$");
        try testing.expect(result != null);

        var list_result: ListResult = try (try result.?.unwrapValue()).expectType(ListResult);
        defer list_result.deinit();

        try testing.expect(list_result.items.len == 3);
        try testing.expectEqualStrings(@tagName(.integer), list_result.component_type.?);
        
        for (list_result.items, 1..) |item, expected| {
            const item_result: IntResult = try item.expectType(IntResult);
            try testing.expect(item_result.value == @as(i32, @intCast(expected)));
        }
    }
    {
        const script: []const u8 =
            \\[0]: {
            \\  $ = [ fire | ice ] - ice;
            \\}
            ;

        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };
        const tokens: []Token = try tokenizer.tokenize(script);
        errdefer Token.deinitAllAndFree(testing.allocator, tokens);

        var iter: TokenIterator = try TokenIterator.from(testing.allocator, tokens);
        defer iter.deinit();

        const parser: Parser = .{ .allocator = testing.allocator };
        const card_def: *CardDef = try parser.parseTokens(iter);
        defer card_def.deinit();

        var sym_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer sym_table.deinit();

        try card_def.actions[0].stmt().execute(&sym_table);

        const result: ?Symbol = sym_table.getSymbol("$");
        try testing.expect(result != null);

        var list_result: ListResult = try (try result.?.unwrapValue()).expectType(ListResult);
        defer list_result.deinit();

        try testing.expect(list_result.items.len == 1);
        try testing.expectEqualStrings(@tagName(.damage_type), list_result.component_type.?);
        
        const dmg_type_result: DamageType = try list_result.items[0].expectType(DamageType);
        try testing.expectEqualStrings(@tagName(.fire), @tagName(dmg_type_result));
    }
    {
        const script: []const u8 =
            \\[0]: {
            \\  $ = [ fire | ice ] - [ ice ];
            \\}
            ;

        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };
        const tokens: []Token = try tokenizer.tokenize(script);
        errdefer Token.deinitAllAndFree(testing.allocator, tokens);

        var iter: TokenIterator = try TokenIterator.from(testing.allocator, tokens);
        defer iter.deinit();

        const parser: Parser = .{ .allocator = testing.allocator };
        const card_def: *CardDef = try parser.parseTokens(iter);
        defer card_def.deinit();

        var sym_table: SymbolTable = try SymbolTable.new(testing.allocator);
        defer sym_table.deinit();

        try card_def.actions[0].stmt().execute(&sym_table);

        const result: ?Symbol = sym_table.getSymbol("$");
        try testing.expect(result != null);

        var list_result: ListResult = try (try result.?.unwrapValue()).expectType(ListResult);
        defer list_result.deinit();

        try testing.expect(list_result.items.len == 1);
        try testing.expectEqualStrings(@tagName(.damage_type), list_result.component_type.?);
        
        const dmg_type_result: DamageType = try list_result.items[0].expectType(DamageType);
        try testing.expectEqualStrings(@tagName(.fire), @tagName(dmg_type_result));
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

    const tokenizer: Tokenizer = .{ .allocator = testing.allocator };
    const tokens: []Token = try tokenizer.tokenize(script);

    var iter: TokenIterator = TokenIterator.from(testing.allocator, tokens) catch |err| {
        Token.deinitAllAndFree(testing.allocator, tokens);
        return err;
    };
    defer iter.deinit();

    const parser: Parser = .{ .allocator = testing.allocator };
    const card_def: *CardDef = try parser.parseTokens(iter);
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
    var cost_result: CardCost = try result.expectType(CardCost);
    const cost: []u8 = cost_result.cost();

    try testing.expect(cost.len == 1);
    try testing.expect(cost[0] == @intFromEnum(Crystal.any));
}