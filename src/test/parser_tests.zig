const std = @import("std");
const parsing = @import("parsing");
const testing = std.testing;

const Parser = parsing.Parser;
const Tokenizer = parsing.Tokenizer;
const Token = parsing.Token;
const CardDef = parsing.CardDef;

test {
    {
        const script: []const u8 =
        \\#attack
        \\#rank=c
        \\// firebolt
        \\[1]: {
        \\  $ = target(1 from Player);
        \\  1d6+4 fire => $;
        \\}
        ;
        const tokenizer = Tokenizer.init(testing.allocator);
        const tokens: []Token = try tokenizer.tokenize(script);

        const parser: Parser = Parser.init(testing.allocator);
        var card_def: CardDef = try parser.parseTokens(tokens);
        defer card_def.deinit();
        // free here to make sure our card def is still intact
        testing.allocator.free(tokens);

        try testing.expect(card_def.labels.len == 1);
        try testing.expect(card_def.actions.len == 1);
    }
}