const testing = @import("std").testing;
const debug = @import("std").debug;
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
    const tokenizer = Tokenizer.init(testing.allocator);

    const tokens: []Token = try tokenizer.tokenize(script);
    defer testing.allocator.free(tokens);

    try testing.expect(tokens.len == 1);
    try tokens[0].expectMatches(@tagName(Token.eof));
}
test "tokenize numeric" {
    const script = "4";
    const tokenizer = Tokenizer.init(testing.allocator);

    const tokens: []Token = try tokenizer.tokenize(script);
    defer testing.allocator.free(tokens);
    defer Token.deinitAll(tokens);

    try testing.expect(tokens.len == 2);
    try tokens[0].expectStringEquals("4");
    try tokens[0].expectMatches(@tagName(Token.numeric));
    try testing.expect(tokens[0].getNumericValue().? == 4);
    try tokens[1].expectMatches(@tagName(Token.eof));
}
test "tokenize boolean" {
    {
        const script = "false";
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("false");
        try tokens[0].expectMatches(@tagName(Token.boolean));
        try testing.expect(!tokens[0].getBoolValue().?);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "true";
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

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
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("fire");
        try tokens[0].expectMatches(@tagName(Token.damageType));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Fire);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "lightning";
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("lightning");
        try tokens[0].expectMatches(@tagName(Token.damageType));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Lightning);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "divine";
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("divine");
        try tokens[0].expectMatches(@tagName(Token.damageType));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Divine);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "force";
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("force");
        try tokens[0].expectMatches(@tagName(Token.damageType));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Force);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "acid";
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("acid");
        try tokens[0].expectMatches(@tagName(Token.damageType));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Acid);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "necrotic";
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("necrotic");
        try tokens[0].expectMatches(@tagName(Token.damageType));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Necrotic);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "ice";
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("ice");
        try tokens[0].expectMatches(@tagName(Token.damageType));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Ice);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "psychic";
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("psychic");
        try tokens[0].expectMatches(@tagName(Token.damageType));
        try testing.expect(tokens[0].getDamageTypeValue().? == DamageType.Psychic);
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
}
test "tokenize identifier" {
    {
        const script = "$";
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("$");
        try tokens[0].expectMatches(@tagName(Token.identifier));
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "_";
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("_");
        try tokens[0].expectMatches(@tagName(Token.identifier));
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "$my_var";
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("$my_var");
        try tokens[0].expectMatches(@tagName(Token.identifier));
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
}
test "tokenize syntax" {
    {
        const script = "!";
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("!");
        try tokens[0].expectMatches(@tagName(Token.symbol));
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "+!";
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

        try testing.expect(tokens.len == 2);
        try tokens[0].expectStringEquals("+!");
        try tokens[0].expectMatches(@tagName(Token.symbol));
        try tokens[1].expectMatches(@tagName(Token.eof));
    }
    {
        const script = "+ !";
        const tokenizer = Tokenizer.init(testing.allocator);

        const tokens: []Token = try tokenizer.tokenize(script);
        defer testing.allocator.free(tokens);
        defer Token.deinitAll(tokens);

        try testing.expect(tokens.len == 3);
        try tokens[0].expectStringEquals("+");
        try tokens[0].expectMatches(@tagName(Token.symbol));
        try tokens[1].expectStringEquals("!");
        try tokens[1].expectMatches(@tagName(Token.symbol));
        try tokens[2].expectMatches(@tagName(Token.eof));
    }
}