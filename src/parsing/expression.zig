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

pub const Result = union(enum) {
    integer: i32,
    boolean: bool,
    damage_type: DamageType,
    dice: Dice,
    list: ListResult,
    // TODO: add player, cards, decks, etc.
};

pub const ListResult = struct {
    items: []Result,
};

pub const Error = error {
    AllocatorRequired
};

pub const Expression = @This();

ptr: *anyopaque,
requires_alloc: bool,
evaluateFn: *const fn (*anyopaque, SymbolTable) Error!Result,
evaluateAllocFn: *const fn (Allocator, *anyopaque, SymbolTable) Error!Result,

pub fn evaluate(self: Expression, symbol_table: SymbolTable) Error!Result {
    if (self.requires_alloc) {
        return Error.AllocatorRequired;
    }
    return self.evaluateFn(self.ptr, symbol_table);
}

pub fn evaluateAlloc(self: Expression, allocator: Allocator, symbol_table: SymbolTable) Error!Result {
    return self.evaluateAllocFn(allocator, self.ptr, symbol_table);
}

/// Simply returns `AllocatorRequired` error.
/// Used for the various expressions that need an allocator but also must implement `evaluteFn`.
pub fn errRequireAlloc(_: *anyopaque, _: SymbolTable) Error!Result {
    return Error.AllocatorRequired;
}
