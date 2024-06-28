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
    InvalidToken
};

pub const ParseTokenError = InnerError || std.fmt.ParseIntError || Allocator.Error;

pub const StringToken = struct {
    value: []const u8,
    allocator: Allocator,

    /// Copies `str` with `allocator` so that the passed-in `str` can be freed by the caller.
    pub fn from(allocator: Allocator, str: []const u8) ParseTokenError!*StringToken {
        var str_copy: []u8 = try allocator.alloc(u8, str.len);
        _ = &str_copy;
        errdefer allocator.free(str_copy);
        @memcpy(str_copy, str);

        const ptr: *StringToken = try allocator.create(StringToken);
        ptr.* = StringToken {
            .value = str_copy,
            .allocator = allocator
        };

        return ptr;
    }

    pub fn deinit(self: *StringToken) void {
        self.allocator.free(self.value);
        self.allocator.destroy(self);
    }
};

pub const NumericToken = struct {
    string_value: []const u8,
    allocator: Allocator,
    value: u32,

    /// Copies `str` with `allocator` so that the passed-in `str` can be freed by the caller.
    pub fn from(allocator: Allocator, str: []const u8) ParseTokenError!*NumericToken {
        var str_copy: []u8 = try allocator.alloc(u8, str.len);
        _ = &str_copy;
        errdefer allocator.free(str_copy);
        @memcpy(str_copy, str);

        const num: u32 = try std.fmt.parseUnsigned(u32, str_copy, 10);

        const ptr: *NumericToken = try allocator.create(NumericToken);
        ptr.* = NumericToken {
            .string_value = str_copy,
            .value = num,
            .allocator = allocator
        };

        return ptr;
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

        var str_copy: []u8 = try allocator.alloc(u8, str.len);
        _ = &str_copy;
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

        var str_copy: []u8 = try allocator.alloc(u8, str.len);
        _ = &str_copy;
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

        var str_copy: []u8 = try allocator.alloc(u8, str.len);
        errdefer allocator.free(str_copy);
        _ = &str_copy;
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

    pub fn matches(a: Token, b: Token) bool {
        const a_tag: [:0]const u8 = @tagName(a);
        const b_tag: [:0]const u8 = @tagName(b);

        return std.mem.eql(u8, a_tag, b_tag);
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
        const self_str: ?[]const u8 = self.toString();
        if (self_str == null) {
            return false;
        }
        return std.mem.eql(u8, self_str.?, str);
    }

    pub fn expectStringEquals(self: Token, str: []const u8) ParseTokenError!void {
        if (!self.stringEquals(str)) {
            std.log.err("Expected string value '{s}' but was '{s}'", .{ self.toString().?, str });
            return ParseTokenError.InvalidToken;
        }
    }

    pub fn expectMatches(self: Token, tagName: []const u8) ParseTokenError!void {
        if (!std.mem.eql(u8, @tagName(self), tagName)) {
            return ParseTokenError.InvalidToken;
        }
    }

    pub fn getNumericValue(self: Token) ?u32 {
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

    pub fn from(tokens: []Token) TokenIterator {
        return .{ .internal_iter = Iterator(Token).from(tokens) };
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
};
