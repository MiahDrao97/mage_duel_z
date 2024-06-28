const import_tokens = @import("tokens.zig");
const std = @import("std");
const util = @import("util");
const Iterator = util.Iterator;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Token = import_tokens.Token;

const StringToken = import_tokens.StringToken;
const NumericToken = import_tokens.NumericToken;
const DamageTypeToken = import_tokens.DamageTypeToken;
const DiceToken = import_tokens.DiceToken;
const BooleanToken = import_tokens.BooleanToken;

pub const Tokenizer = @This();

allocator: Allocator,

/// Allocator is used for the individual tokens and resulting slice when calling `tokenize()`.
/// There is no `deinit()` on this structure because all resulting memory belongs to the caller.
/// Using an arena is recommended (or maybe even further up when parsing statements/expressions).
pub fn init(allocator: Allocator) Tokenizer {
    return Tokenizer { .allocator = allocator };
}

const InnerErrors = error {
    InvalidSyntax
};

pub const TokenizerError = InnerErrors || import_tokens.ParseTokenError;

/// `Tokenizer` instance does not own the resulting `Token` slice or `Token`'s.
/// Thus, there is no `deinit()` on this structure.
pub fn tokenize(self: Tokenizer, script: []const u8) TokenizerError![]Token {
    var tokens_list = try ArrayList(Token).initCapacity(self.allocator, script.len);
    errdefer {
        Token.deinitAll(tokens_list.items);
        tokens_list.deinit();
    }

    var tokens_iter = Iterator(u8).from(script);
    var next_first: ?u8 = null;

    while (true) {
        var first: u8 = undefined;

        if (next_first) |a| {
            next_first = null;
            if (!util.isWhiteSpace(a)) {
                first = a;
            } else {
                continue;
            }
        } else if (consumeWhitespace(&tokens_iter)) |b| {
            first = b;
        } else {
            break;
        }

        const next_token: Token = self.readNextToken(first, &tokens_iter, &next_first) catch |err| {
            std.log.debug("Successfully parsed:\n", .{});
            for (tokens_list.items) |token| {
                std.log.debug("\t'{s}'\n", .{ token.toString() orelse "[null]" });
            }
            return err;
        };
        switch (next_token) {
            Token.comment => {
                readUntilNewlineOrEof(&tokens_iter);
                continue;
            },
            else => {
                try tokens_list.append(next_token);
            }
        }
    }

    try tokens_list.append(Token.eof);
    return tokens_list.toOwnedSlice();
}

fn consumeWhitespace(tokens: *Iterator(u8)) ?u8 {
    while (tokens.next()) |char| {
        if (!util.isWhiteSpace(char)) {
            return char;
        }
    }
    return null;
}

fn readUntilNewlineOrEof(tokens: *Iterator(u8)) void {
    while (tokens.next()) |char| {
        if (char == '\n') {
            break;
        }
    }
}

fn readNextToken(self: Tokenizer, first: u8, tokens: *Iterator(u8), next_first: *?u8) TokenizerError!Token {
    if (util.isAlpha(first) or first == '$' or first == '_') {
        return self.parseAlphaNumericToken(first, tokens, next_first);
    } else if (util.isNumeric(first)) {
        return self.parseNumeric(first, tokens, next_first);
    } else {
        return self.parseSyntax(first, tokens, next_first);
    }
}

fn parseAlphaNumericToken(self: Tokenizer, first: u8, tokens: *Iterator(u8), next_first: *?u8) TokenizerError!Token {
    var chars = ArrayList(u8).init(self.allocator);
    defer chars.deinit();

    try chars.append(first);

    while (tokens.next()) |next| {
        if (first == 'd' and util.isNumeric(next)) {
            // dice token
            try chars.append(next);
            return self.parseDiceToken(&chars, tokens, next_first);
        }
        else if (util.isAlphaNumeric(next) or next == '$' or next == '_') {
            try chars.append(next);
        } else {
            next_first.* = next;
            break;
        }
    }
    
    const str: []u8 = try chars.toOwnedSlice();
    defer self.allocator.free(str);

    if (util.containerHasSlice(u8, &import_tokens.static_tokens, str)) {
        // static token (i.e. keyword)
        return .{ .symbol = try StringToken.from(self.allocator, str) };
    }
    
    if (DamageTypeToken.from(self.allocator, str)) |dmg_type_token| {
        // damage type
        return .{ .damage_type = dmg_type_token };
    } else |_| { }
    
    if (BooleanToken.from(self.allocator, str)) |bool_token| {
        // bool
        return .{ .boolean = bool_token };
    } else |_| { }

    // just an identifier
    return .{ .identifier = try StringToken.from(self.allocator, str) };
}

fn parseNumeric(self: Tokenizer, first: u8, tokens: *Iterator(u8), next_first: *?u8) TokenizerError!Token {
    var chars = ArrayList(u8).init(self.allocator);
    defer chars.deinit();

    try chars.append(first);

    while (tokens.next()) |next| {
        if (util.isNumeric(next)) {
            try chars.append(next);
        } else {
            next_first.* = next;
            break;
        }
    }

    const str: []u8 = try chars.toOwnedSlice();
    defer self.allocator.free(str);

    return .{ .numeric = try NumericToken.from(self.allocator, str) };
}

fn parseDiceToken(self: Tokenizer, chars: *ArrayList(u8), tokens: *Iterator(u8), next_first: *?u8) TokenizerError!Token {
    while (tokens.next()) |token| {
        if (util.isNumeric(token)) {
            try chars.append(token);
        } else {
            next_first.* = token;
            break;
        }
    }

    const str: []u8 = try chars.toOwnedSlice();
    defer self.allocator.free(str);

    return .{ .dice = try DiceToken.from(self.allocator, str) };
}

fn parseSyntax(self: Tokenizer, first: u8, tokens: *Iterator(u8), next_first: *?u8) TokenizerError!Token {
    var str: []const u8 = &[_]u8 { first };
    if (util.containerHasSlice(u8, &import_tokens.static_tokens, str)) {
        if (first == '=') {
            if (tokens.next()) |next| {
                if (next == '=') {
                    str = "==";
                    return .{ .symbol = try StringToken.from(self.allocator, str) };
                } else if (next == '>') {
                    str = "=>";
                    return .{ .symbol = try StringToken.from(self.allocator, str) };
                } else {
                    next_first.* = next;
                }
            }
        } else if (first == '>') {
            if (tokens.next()) |next| {
                if (next == '=') {
                    str = ">=";
                    return .{ .symbol = try StringToken.from(self.allocator, str) };
                } else {
                    next_first.* = next;
                }
            }
        } else if (first == '<') {
            if (tokens.next()) |next| {
                if (next == '=') {
                    str = "<=";
                    return .{ .symbol = try StringToken.from(self.allocator, str) };
                } else {
                    next_first.* = next;
                }
            }
        } else if (first == '/') {
            if (tokens.next()) |next| {
                if (next == '/') {
                    // comment
                    return .comment;
                } else {
                    next_first.* = next;
                }
            }
        } else if (first == '~') {
            if (tokens.next()) |next| {
                if (next == '=') {
                    str = "~=";
                    return .{ .symbol = try StringToken.from(self.allocator, str) };
                } else {
                    next_first.* = next;
                }
            }
        } else if (first == '+') {
            if (tokens.next()) |next| {
                if (next == '!') {
                    str = "+!";
                    return .{ .symbol = try StringToken.from(self.allocator, str) };
                } else {
                    next_first.* = next;
                }
            }
        }

        // syntax from here is just 1 character in length
        return .{ .symbol = try StringToken.from(self.allocator, str) };
    }
    
    std.log.err("Encountered invalid syntax: '{s}'\n", .{ str });
    return TokenizerError.InvalidSyntax;
}
