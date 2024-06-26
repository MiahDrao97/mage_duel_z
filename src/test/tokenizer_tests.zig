const testing = @import("std").testing;
const debug = @import("std").debug;
const parsing = @import("parsing");
const Tokenizer = parsing.Tokenizer;
const Token = parsing.Token;

const TestError = error {
    UnexpectedToken
};

test "tokenize whitespace" {
    const script = "     \n";
    const tokenizer = Tokenizer.init(testing.allocator);

    const tokens: []Token = try tokenizer.tokenize(script);
    defer testing.allocator.free(tokens);

    try testing.expect(tokens.len == 1);
    if (!tokens[0].matches(Token.eof)) {
        return TestError.UnexpectedToken;
    }
}
test "tokenize numeric" {
    const script = "4";
    const tokenizer = Tokenizer.init(testing.allocator);

    const tokens: []Token = try tokenizer.tokenize(script);
    defer testing.allocator.free(tokens);
    defer Token.deinitAll(tokens);

    try testing.expect(tokens.len == 2);
    switch (tokens[0]) {
        Token.numeric => |num_tok| {
            try testing.expectEqualStrings(num_tok.string_value, "4");
            try testing.expectEqual(num_tok.value, 4);
        },
        else => return TestError.UnexpectedToken
    }
    if (!tokens[1].matches(Token.eof)) {
        return TestError.UnexpectedToken;
    }
}