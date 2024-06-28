const std = @import("std");

const imports = struct {
    usingnamespace @import("tokens.zig");
    usingnamespace @import("util");
    usingnamespace @import("game_zones");
};

const DamageType = imports.types.DamageType;
const Dice = imports.types.Dice;

const Allocator = std.mem.Allocator;
const TokenIterator = imports.TokenIterator;

pub const ExpressionResult = union(enum) {
    integer: i32,
    boolean: bool,
    damage_type: DamageType,
    dice: Dice,
    list: ListResult,
    // TODO: add player, cards, decks, etc.
};

pub const ListResult = struct {
    items: []ExpressionResult,
};

pub const EvaluateExprErr = error {

};

pub const Expression = @This();

this: *anyopaque,
evaluate: *const fn (*anyopaque) EvaluateExprErr!ExpressionResult,
