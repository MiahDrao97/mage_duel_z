const std = @import("std");

const imports = struct {
    usingnamespace @import("tokens.zig");
    usingnamespace @import("symbol_table.zig");
    usingnamespace @import("util");
    usingnamespace @import("game_zones");
};

const DamageType = imports.types.DamageType;
const Dice = imports.types.Dice;

const Allocator = std.mem.Allocator;
const TokenIterator = imports.TokenIterator;
const SymbolTable = imports.SymbolTable;

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
    AllocatorRequired
};

pub const Expression = @This();

ptr: *anyopaque,
requires_alloc: bool,
evaluateFn: *const fn (*anyopaque, SymbolTable) EvaluateExprErr!ExpressionResult,
evaluateAllocFn: *const fn (Allocator, *anyopaque, SymbolTable) EvaluateExprErr!ExpressionResult,

pub fn evaluate(self: Expression, symbol_table: SymbolTable) EvaluateExprErr!ExpressionResult {
    if (self.requires_alloc) {
        return EvaluateExprErr.AllocatorRequired;
    }
    return self.evaluateFn(self.ptr, symbol_table);
}

pub fn evaluateAlloc(self: Expression, allocator: Allocator, symbol_table: SymbolTable) EvaluateExprErr!ExpressionResult {
    return self.evaluateAllocFn(allocator, self.ptr, symbol_table);
}
