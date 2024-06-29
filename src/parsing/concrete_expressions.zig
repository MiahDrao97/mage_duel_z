const std = @import("std");

const imports = struct {
    usingnamespace @import("tokens.zig");
    usingnamespace @import("symbol_table.zig");
    usingnamespace @import("util");
    usingnamespace @import("game_zones");
    usingnamespace @import("expression.zig");
};

const Allocator = std.mem.Allocator;
const Expression = imports.Expression;
const Token = imports.Token;
const TokenIterator = imports.TokenIterator;
const SymbolTable = imports.SymbolTable;

pub const ParseError = error {
    UnexpectedToken
};

pub const IntegerLiteral = struct {
    val: u16,

    pub fn from(iter: TokenIterator) ParseError!IntegerLiteral {
        if (iter.next()) |token| {
            if (token.getNumericValue()) |n| {
                return IntegerLiteral { .val = n };
            }
        }
        return ParseError.UnexpectedToken;
    }

    pub fn evaluate(this_ptr: *anyopaque, _: SymbolTable) Expression.Error!Expression.Result {
        const self: *IntegerLiteral = @ptrCast(@alignCast(this_ptr));
        return .{ .integer = self.val };
    }

    pub fn evaluateAlloc(_: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        return evaluate(this_ptr, symbol_table);
    }

    pub fn expr(self: *IntegerLiteral) Expression {
        return Expression {
            .ptr = self,
            .requires_alloc = false,
        };
    }
};

pub const BooleanLiteral = struct {
    val: bool,

    pub fn from(iter: TokenIterator) ParseError!BooleanLiteral {
        if (iter.next()) |token| {
            if (token.getBoolValue()) |b| {
                return BooleanLiteral { .val = b };
            }
        }
        return ParseError.UnexpectedToken;
    }

    pub fn evaluate(this_ptr: *anyopaque, _: SymbolTable) Expression.Error!Expression.Result {
        const self: *BooleanLiteral = @ptrCast(@alignCast(this_ptr));
        return .{ .boolean = self.val };
    }

    pub fn evaluateAlloc(_: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        return evaluate(this_ptr, symbol_table);
    }

    pub fn expr(self: *BooleanLiteral) Expression {
        return Expression {
            .ptr = self,
            .requires_alloc = false,
        };
    }
};
