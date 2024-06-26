const testing = @import("std").testing;
const debug = @import("std").debug;
const Tokenizer = @import("tokenizer.zig");
const Token = @import("tokens.zig").Token;

const TestError = error {
    UnexpectedToken
};

test "tokenize whitespace" {
    const script = "     \n";
    const tokenizer = Tokenizer.init(testing.allocator);

    const tokens: []Token = try tokenizer.tokenize(script);
    try testing.expect(tokens.len == 1);
    switch (tokens) {
        Token.eof => { },
        else => return TestError.UnexpectedToken
    }
}