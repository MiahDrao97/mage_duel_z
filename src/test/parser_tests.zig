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
        errdefer Token.deinitAllAndFree(testing.allocator, tokens);

        const parser: Parser = Parser.init(testing.allocator);
        card_def = try parser.parseTokens(tokens);
    }
    defer card_def.deinit();

    // free here to make sure our card def is still intact
    Token.deinitAllAndFree(testing.allocator, tokens);

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
    const int_result: parsing.IntResult = try result.expectType(parsing.IntResult);

    try testing.expect(int_result.value == 1);
    try testing.expect(!int_result.up_to);
}