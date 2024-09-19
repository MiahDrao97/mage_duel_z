const std = @import("std");
const testing = std.testing;
const debug = std.debug;
const parsing = @import("parsing");
const Tokenizer = parsing.Tokenizer;
const Token = parsing.Token;
const types = @import("game_zones").types;
const DamageType = types.DamageType;

const TestError = error {
    UnexpectedToken
};

test "tokenize whitespace" {
    const script = "     \n";
    const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

    const tokens: []Token = try tokenizer.tokenize(script);
    defer testing.allocator.free(tokens);

    try testing.expect(tokens.len == 1);
    try tokens[0].expectMatches(@tagName(Token.eof));
}
test "tokenize numeric" {
    const script = "4";
    const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

    const tokens: []Token = try tokenizer.tokenize(script);
    defer Token.deinitAllAndFree(testing.allocator, tokens);

    try testing.expect(tokens.len == 2);
    try tokens[0].expectStringEquals("4");
    try tokens[0].expectMatches(@tagName(Token.numeric));
    try testing.expect(tokens[0].getNumericValue().? == 4);
    try tokens[1].expectMatches(@tagName(Token.eof));
}
test "tokenize boolean" {
    {
        const script = "false";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("false");
        try tokens[0].expectMatches(@tagName(Token.boolean));
        try testing.expect(!tokens[0].getBoolValue().?);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "true";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("true");
        try tokens[0].expectMatches(@tagName(Token.boolean));
        try testing.expect(tokens[0].getBoolValue().?);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
}
test "tokenize damage type" {
    {
        const script = "fire";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("fire");
        try tokens[0].expectMatches(@tagName(Token.damage_type));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Fire);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "lightning";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("lightning");
        try tokens[0].expectMatches(@tagName(Token.damage_type));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Lightning);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "divine";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("divine");
        try tokens[0].expectMatches(@tagName(Token.damage_type));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Divine);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "force";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("force");
        try tokens[0].expectMatches(@tagName(Token.damage_type));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Force);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "acid";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("acid");
        try tokens[0].expectMatches(@tagName(Token.damage_type));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Acid);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "necrotic";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("necrotic");
        try tokens[0].expectMatches(@tagName(Token.damage_type));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Necrotic);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "ice";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("ice");
        try tokens[0].expectMatches(@tagName(Token.damage_type));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Ice);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "psychic";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("psychic");
        try tokens[0].expectMatches(@tagName(Token.damage_type));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Psychic);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
}
test "tokenize identifier" {
    {
        const script = "$";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("$");
        try tokens[0].expectMatches(@tagName(Token.identifier));
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "_";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("_");
        try tokens[0].expectMatches(@tagName(Token.identifier));
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "$my_var";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("$my_var");
        try tokens[0].expectMatches(@tagName(Token.identifier));
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
}
test "tokenize syntax" {
    {
        const script = "!";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("!");
        try tokens[0].expectMatches(@tagName(Token.symbol));
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "+!";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("+!");
        try tokens[0].expectMatches(@tagName(Token.symbol));
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "+ !";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 3);
        try tokens[0].expectStringEquals("+");
        try tokens[0].expectMatches(@tagName(Token.symbol));
        try tokens[1].expectStringEquals("!");
        try tokens[1].expectMatches(@tagName(Token.symbol));
        try tokens[2].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "=> >= <= == ~=";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 6);
        try tokens[0].expectStringEquals("=>");
        try tokens[0].expectMatches(@tagName(Token.symbol));
        try tokens[1].expectStringEquals(">=");
        try tokens[1].expectMatches(@tagName(Token.symbol));
        try tokens[2].expectStringEquals("<=");
        try tokens[2].expectMatches(@tagName(Token.symbol));
        try tokens[3].expectStringEquals("==");
        try tokens[3].expectMatches(@tagName(Token.symbol));
        try tokens[4].expectStringEquals("~=");
        try tokens[4].expectMatches(@tagName(Token.symbol));
        try tokens[5].expectMatches(@tagName(Token.eof));
    }
}
test "tokenize comment" {
    {
        const script = "// this is a comment";
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        // comments are not added to the token list
        try testing.expect(tokens.len == 1);
        try tokens[0].expectMatches(@tagName(Token.eof));
    }
}
test "tokenize real script" {
    {
        const script: []const u8 =
        \\#attack
        \\// firebolt
        \\[1]: {
        \\  $ = target(1 from Player);
        \\  1d6+4 fire => $;
        \\}
        ;
        const tokenizer: Tokenizer = .{ .allocator = testing.allocator };

        const tokens: []Token = try tokenizer.tokenize(script);
        defer Token.deinitAllAndFree(testing.allocator, tokens);

        try testing.expect(tokens.len == 26);

        try tokens[0].expectStringEquals("#");
        try tokens[0].expectMatches(@tagName(Token.symbol));

        try tokens[1].expectStringEquals("attack");
        try tokens[1].expectMatches(@tagName(Token.identifier));
        
        try tokens[2].expectStringEquals("[");
        try tokens[2].expectMatches(@tagName(Token.symbol));
        
        try tokens[3].expectStringEquals("1");
        try tokens[3].expectMatches(@tagName(Token.numeric));
        try testing.expect(tokens[3].getNumericValue().? == 1);

        try tokens[4].expectStringEquals("]");
        try tokens[4].expectMatches(@tagName(Token.symbol));

        try tokens[5].expectStringEquals(":");
        try tokens[5].expectMatches(@tagName(Token.symbol));
        
        try tokens[6].expectStringEquals("{");
        try tokens[6].expectMatches(@tagName(Token.symbol));

        try tokens[7].expectStringEquals("$");
        try tokens[7].expectMatches(@tagName(Token.identifier));

        try tokens[8].expectStringEquals("=");
        try tokens[8].expectMatches(@tagName(Token.symbol));

        try tokens[9].expectStringEquals("target");
        try tokens[9].expectMatches(@tagName(Token.symbol));

        try tokens[10].expectStringEquals("(");
        try tokens[10].expectMatches(@tagName(Token.symbol));

        try tokens[11].expectStringEquals("1");
        try tokens[11].expectMatches(@tagName(Token.numeric));
        try testing.expect(tokens[11].getNumericValue().? == 1);
        
        try tokens[12].expectStringEquals("from");
        try tokens[12].expectMatches(@tagName(Token.symbol));

        try tokens[13].expectStringEquals("Player");
        try tokens[13].expectMatches(@tagName(Token.identifier));

        try tokens[14].expectStringEquals(")");
        try tokens[14].expectMatches(@tagName(Token.symbol));

        try tokens[15].expectStringEquals(";");
        try tokens[15].expectMatches(@tagName(Token.symbol));
        
        try tokens[16].expectStringEquals("1");
        try tokens[16].expectMatches(@tagName(Token.numeric));
        try testing.expect(tokens[16].getNumericValue().? == 1);

        try tokens[17].expectStringEquals("d6");
        try tokens[17].expectMatches(@tagName(Token.dice));
        try testing.expect(tokens[17].getDiceValue().?.sides == 6);

        try tokens[18].expectStringEquals("+");
        try tokens[18].expectMatches(@tagName(Token.symbol));

        try tokens[19].expectStringEquals("4");
        try tokens[19].expectMatches(@tagName(Token.numeric));
        try testing.expect(tokens[19].getNumericValue().? == 4);

        try tokens[20].expectStringEquals("fire");
        try tokens[20].expectMatches(@tagName(Token.damage_type));
        try testing.expect(tokens[20].getDamageTypeValue().? == DamageType.Fire);
        
        try tokens[21].expectStringEquals("=>");
        try tokens[21].expectMatches(@tagName(Token.symbol));

        try tokens[22].expectStringEquals("$");
        try tokens[22].expectMatches(@tagName(Token.identifier));

        try tokens[23].expectStringEquals(";");
        try tokens[23].expectMatches(@tagName(Token.symbol));

        try tokens[24].expectStringEquals("}");
        try tokens[24].expectMatches(@tagName(Token.symbol));

        try tokens[25].expectMatches(@tagName(Token.eof));
        try testing.expect(tokens[25].toString() == null);
    }
    {
        // with arena allocator
        const script: []const u8 =
        \\#attack
        \\// firebolt
        \\[1]: {
        \\  $ = target(1 from Player);
        \\  1d6+4 fire => $;
        \\}
        ;

        var arena = std.heap.ArenaAllocator.init(testing.allocator);
        defer arena.deinit();

        // all freeing is handled by the arena
        const tokenizer: Tokenizer = .{ .allocator = arena.allocator() };
        _ = try tokenizer.tokenize(script);
    }
}