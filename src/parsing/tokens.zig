const std = @import("std");
const types = @import("game_zones").types;
const Iterator = @import("util").Iterator;
const DamageType = types.DamageType;
const Dice = types.Dice;
const Allocator = std.mem.Allocator;

pub const static_tokens: [32][]const u8 = [_][]const u8 {
    "{",
    "}",
    "(",
    ")",
    "[",
    "]",
    "@",
    "^",
    "#",
    ":",
    ";",
    "&",
    "+",
    "-",
    "*",
    "/",
    "|",
    ".",
    ",",
    "!",
    "~",
    "=",
    ">",
    "<",
    "in",
    "from",
    "for",
    "if",
    "else",
    "when",
    "func",
    "target"
};

const InnerError = error {
    ParseDiceError,
    ParseDamageTypeError,
    ParseBoolError,
    InvalidToken,
    EOF
};

pub const ParseTokenError = InnerError || std.fmt.ParseIntError || Allocator.Error;

pub const StringToken = struct {
    value: []const u8,
    allocator: Allocator,

    /// Copies `str` with `allocator` so that the passed-in `str` can be freed by the caller.
    pub fn from(allocator: Allocator, str: []const u8) ParseTokenError!*StringToken {
        const str_copy: []u8 = try allocator.alloc(u8, str.len);
        errdefer allocator.free(str_copy);
        @memcpy(str_copy, str);

        const ptr: *StringToken = try allocator.create(StringToken);
        ptr.* = StringToken {
            .value = str_copy,
            .allocator = allocator
        };

        return ptr;
    }

    pub fn clone(self: StringToken) ParseTokenError!*StringToken {
        return from(self.allocator, self.value);
    }

    pub fn deinit(self: *StringToken) void {
        self.allocator.free(self.value);
        self.allocator.destroy(self);
    }
};

pub const NumericToken = struct {
    string_value: []const u8,
    allocator: Allocator,
    value: u16,

    /// Copies `str` with `allocator` so that the passed-in `str` can be freed by the caller.
    pub fn from(allocator: Allocator, str: []const u8) ParseTokenError!*NumericToken {
        const str_copy: []u8 = try allocator.alloc(u8, str.len);
        errdefer allocator.free(str_copy);
        @memcpy(str_copy, str);

        const num: u16 = try std.fmt.parseUnsigned(u16, str_copy, 10);

        const ptr: *NumericToken = try allocator.create(NumericToken);
        ptr.* = NumericToken {
            .string_value = str_copy,
            .value = num,
            .allocator = allocator
        };

        return ptr;
    }

    pub fn clone(self: NumericToken) ParseTokenError!*NumericToken {
        return from(self.allocator, self.string_value);
    }

    pub fn deinit(self: *NumericToken) void {
        self.allocator.free(self.string_value);
        self.allocator.destroy(self);
    }
};

pub const BooleanToken = struct {
    string_value: []const u8,
    allocator: Allocator,
    value: bool,

    /// Copies `str` with `allocator` so that the passed-in `str` can be freed by the caller.
    pub fn from(allocator: Allocator, str: []const u8) ParseTokenError!*BooleanToken {
        var bool_val: bool = undefined;
        if (std.mem.eql(u8, str, "true")) {
            bool_val = true;
        } else if (std.mem.eql(u8, str, "false")) {
            bool_val = false;
        } else {
            return ParseTokenError.ParseBoolError;
        }

        const str_copy: []u8 = try allocator.alloc(u8, str.len);
        errdefer allocator.free(str_copy);
        @memcpy(str_copy, str);

        const ptr: *BooleanToken = try allocator.create(BooleanToken);
        ptr.* = BooleanToken {
            .string_value = str_copy,
            .value = bool_val,
            .allocator = allocator
        };

        return ptr;
    }

    pub fn clone(self: BooleanToken) ParseTokenError!*BooleanToken {
        return from(self.allocator, self.string_value);
    }

    pub fn deinit(self: *BooleanToken) void {
        self.allocator.free(self.string_value);
        self.allocator.destroy(self);
    }
};

pub const DamageTypeToken = struct {
    string_value: []const u8,
    allocator: Allocator,
    value: DamageType,

    /// Copies `str` with `allocator` so that the passed-in `str` can be freed by the caller.
    pub fn from(allocator: Allocator, str: []const u8) ParseTokenError!*DamageTypeToken {
        const dmg_type: DamageType = try DamageType.from(str);

        const str_copy: []u8 = try allocator.alloc(u8, str.len);
        errdefer allocator.free(str_copy);
        @memcpy(str_copy, str);

        const ptr: *DamageTypeToken = try allocator.create(DamageTypeToken);
        ptr.* = DamageTypeToken {
            .string_value = str_copy,
            .value = dmg_type,
            .allocator = allocator
        };

        return ptr;
    }

    pub fn clone(self: DamageTypeToken) ParseTokenError!*DamageTypeToken {
        return from(self.allocator, self.string_value);
    }

    pub fn deinit(self: *DamageTypeToken) void {
        self.allocator.free(self.string_value);
        self.allocator.destroy(self);
    }
};

pub const DiceToken = struct {
    string_value: []const u8,
    allocator: Allocator,
    sides: u8,

    /// Copies `str` with `allocator` so that the passed-in `str` can be freed by the caller.
    pub fn from(allocator: Allocator, str: []const u8) ParseTokenError!*DiceToken {
        if (str.len < 2) {
            return ParseTokenError.ParseDiceError;
        }
        if (str[0] != 'd') {
            return ParseTokenError.ParseDiceError;
        }

        const sides_str: []const u8 = str[1..];
        const sides: u8 = try std.fmt.parseUnsigned(u8, sides_str, 10);

        if (sides < 1) {
            return ParseTokenError.ParseDiceError;
        }

        const str_copy: []u8 = try allocator.alloc(u8, str.len);
        errdefer allocator.free(str_copy);
        @memcpy(str_copy, str);

        const ptr: *DiceToken = try allocator.create(DiceToken);
        ptr.* = DiceToken {
            .string_value = str_copy,
            .sides = sides,
            .allocator = allocator
        };

        return ptr;
    }

    pub fn getDice(self: DiceToken) Dice {
        return Dice.new(self.sides) catch unreachable;
    }

    pub fn clone(self: DiceToken) ParseTokenError!*DiceToken {
        return from(self.allocator, self.string_value);
    }

    pub fn deinit(self: *DiceToken) void {
        self.allocator.free(self.string_value);
        self.allocator.destroy(self);
    }
};

pub const Token = union(enum) {
    identifier: *StringToken,
    symbol: *StringToken,
    numeric: *NumericToken,
    boolean: *BooleanToken,
    dice: *DiceToken,
    damage_type: *DamageTypeToken,
    comment: void,
    eof: void,

    pub fn deinit(self: Token) void {
        switch (self) {
            inline
                Token.identifier,
                Token.numeric,
                Token.symbol,
                Token.boolean,
                Token.dice,
                Token.damage_type => |x| x.deinit(),
            else => { }
        }
    }

    pub fn deinitAll(tokens: []Token) void {
        for (tokens) |token| {
            token.deinit();
        }
    }

    /// Allocates a clone of `self`, except in the cases of `comment` or `eof`, which just return `self`.
    pub fn clone(self: Token) ParseTokenError!Token {
        switch (self) {
            Token.identifier => |i| return .{ .identifier = try i.clone() },
            Token.numeric => |n| return .{ .numeric = try n.clone() },
            Token.symbol => |s| return .{ .symbol = try s.clone() },
            Token.boolean => |b| return .{ .boolean = try b.clone() },
            Token.dice => |d| return .{ .dice = try d.clone() },
            Token.damage_type => |d| return .{ .damage_type = try d.clone() },
            else => return self
        }
    }

    pub fn matches(a: Token, b: Token) bool {
        const a_tag: [:0]const u8 = @tagName(a);
        const b_tag: [:0]const u8 = @tagName(b);

        return std.mem.eql(u8, a_tag, b_tag);
    }

    pub fn matchesType(self: Token, tag: []const u8) bool {
        return std.mem.eql(u8, @tagName(self), tag);
    }

    pub fn toString(this: Token) ?[]const u8 {
        return switch (this) {
            Token.identifier => |x| x.*.value,
            Token.numeric => |x| x.*.string_value,
            Token.symbol => |x| x.*.value,
            Token.boolean => |x| x.*.string_value,
            Token.dice => |x| x.*.string_value,
            Token.damage_type => |x| x.*.string_value,
            else => null
        };
    }

    pub fn stringEquals(self: Token, str: []const u8) bool {
        if (self.toString()) |self_str| {
            return std.mem.eql(u8, self_str, str);
        }
        return false;
    }

    pub fn symbolEquals(self: Token, str: []const u8) bool {
        if (std.mem.eql(u8, @tagName(self), @tagName(Token.symbol))) {
            return self.stringEquals(str);
        }
        return false;
    }

    pub fn expectStringEquals(self: Token, str: []const u8) ParseTokenError!void {
        if (!self.stringEquals(str)) {
            std.log.err("Expected string value '{s}' but was '{s}'", .{ self.toString().?, str });
            return ParseTokenError.InvalidToken;
        }
    }

    pub fn expectSymbolEquals(self: Token, str: []const u8) ParseTokenError!void {
        try self.expectMatches(@tagName(Token.symbol));
        if (!self.stringEquals(str)) {
            std.log.err("Expected string value '{s}' but was '{s}'", .{ self.toString().?, str });
            return ParseTokenError.InvalidToken;
        }
    }

    pub fn expectStringEqualsOneOf(self: Token, str_values: []const []const u8) ParseTokenError!void {
        for (str_values) |val| {
            if (self.stringEquals(val)) {
                return;
            }
        }
        return ParseTokenError.InvalidToken;
    }

    pub fn expectSymbolEqualsOneOf(self: Token, str_values: []const []const u8) ParseTokenError!void {
        for (str_values) |val| {
            if (std.mem.eql(u8, @tagName(self), @tagName(Token.symbol)) and self.stringEquals(val)) {
                return;
            }
        }
        return ParseTokenError.InvalidToken;
    }

    pub fn expectMatches(self: Token, tag: []const u8) ParseTokenError!void {
        if (!self.matchesType(tag)) {
            return ParseTokenError.InvalidToken;
        }
    }

    pub fn getNumericValue(self: Token) ?u16 {
        return switch (self) {
            Token.numeric => |n| n.*.value,
            else => null
        };
    }

    pub fn getBoolValue(self: Token) ?bool {
        return switch (self) {
            Token.boolean => |b| b.*.value,
            else => null
        };
    }

    pub fn getDamageTypeValue(self: Token) ?DamageType {
        return switch (self) {
            Token.damage_type => |d| d.*.value,
            else => null
        };
    }

    pub fn getDiceValue(self: Token) ?Dice {
        return switch (self) {
            Token.dice => |d| d.getDice(),
            else => null
        };
    }
};

pub const TokenIterator = struct {
    internal_iter: Iterator(Token),

    pub fn from(allocator: Allocator, tokens: []Token) Allocator.Error!TokenIterator {
        const iter: Iterator(Token) = try Iterator(Token).from(allocator, tokens);

        return .{ .internal_iter = iter };
    }

    pub fn next(self: TokenIterator) ?Token {
        if (self.internal_iter.next()) |t| {
            return switch (t) {
                inline Token.comment, Token.eof => null,
                else => t
            };
        }
        return null;
    }

    /// If there's a next token that's a symbol that matches any of the following `vals`,
    /// then the iterator returns that token and moves forward.
    pub fn nextMatchesSymbol(self: TokenIterator, vals: []const []const u8) ?Token {
        if (self.peek()) |next_tok| {
            for (vals) |val| {
                if (next_tok.symbolEquals(val)) {
                    return self.next().?;
                }
            }
        }
        return null;
    }

    pub fn peek(self: TokenIterator) ?Token {
        const next_tok: ?Token = self.next();
        // as if we hadn't moved forward
        self.internal_iter.scroll(-1);
        return next_tok;
    }

    /// Assumes that the next token needs to be a symbol with a given string value
    pub fn require(self: TokenIterator, str_value: []const u8) ParseTokenError!Token {
        if (self.internal_iter.next()) |t| {
            try t.expectSymbolEquals(str_value);
            return t;
        }
        return ParseTokenError.EOF;
    }

    /// Assumes that the next token needs to be a symbol with a given string value
    pub fn requireOneOf(self: TokenIterator, str_values: []const []const u8) ParseTokenError!Token {
        if (self.internal_iter.next()) |t| {
            try t.expectSymbolEqualsOneOf(str_values);
            return t;
        }
        return ParseTokenError.EOF;
    }

    pub fn requireType(self: TokenIterator, tag_names: []const []const u8) ParseTokenError!Token {
        if (self.internal_iter.next()) |t| {
            for (tag_names) |tag| {
                if (t.matchesType(tag)) {
                    return t;
                }
            }
            return ParseTokenError.InvalidToken;
        }
        return ParseTokenError.EOF;
    }

    pub fn deinit(self: *TokenIterator) void {
        self.internal_iter.deinit();
    }
};
