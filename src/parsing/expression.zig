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
    label: Label,
    // TODO: add player, cards, decks, etc.

    pub fn as(self: Result, T: type) ?T {
        switch (self) {
            inline else => |x| {
                if (@TypeOf(x) == T) {
                    return x;
                }
            }
        }
        return null;
    }

    pub fn expectType(self: Result, T: type) Error!T {
        return self.as(T) orelse Error.UnexpectedType;
    }

    pub fn UnderlyingType(self: Result) type {
        return switch (self) {
            inline else => |x| @TypeOf(x)
        };
    }
};

pub const ListResult = struct {
    items: []Result,
    // needs add functions and stuff

    // TODO: need component type (how to handle empty?)
};

pub const Label = enum {
    one_time_use,
    attack,
    s_rank,
    a_rank,
    b_rank,
    c_rank,

    pub fn from(label: []const u8) ?Label {
        if (std.mem.eql(u8, @tagName(Label.one_time_use), label)) {
            return Label.one_time_use;
        } else if (std.mem.eql(u8, @tagName(Label.attack), label)) {
            return Label.attack;
        } else if (std.mem.eql(u8, @tagName(Label.s_rank), label)) {
            return Label.s_rank;
        } else if (std.mem.eql(u8, @tagName(Label.a_rank), label)) {
            return Label.a_rank;
        } else if (std.mem.eql(u8, @tagName(Label.b_rank), label)) {
            return Label.b_rank;
        } else if (std.mem.eql(u8, @tagName(Label.c_rank), label)) {
            return Label.c_rank;
        }
        return null;
    }
};

const InnerError = error {
    AllocatorRequired,
    InvalidLabel,
    UndefinedIdentifier,
    OperandTypeNotSupported,
    UnexpectedType,
    ElementTypesVary
};

pub const Error = InnerError || Allocator.Error;

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
