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
const DamageType = imports.types.DamageType;
const Dice = imports.types.Dice;
const ParseTokenError = imports.ParseTokenError;

const InnerError = error {
    UnexpectedToken
};

pub const ParseError = InnerError || imports.ParseTokenError;

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
            .evaluateFn = &evaluate,
            .evaluateAllocFn = &evaluateAlloc
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
            .evaluateFn = &evaluate,
            .evaluateAllocFn = &evaluateAlloc
        };
    }
};

pub const DamageTypeLiteral = struct {
    val: DamageType,

    pub fn from(iter: TokenIterator) ParseError!DamageTypeLiteral {
        if (iter.next()) |token| {
            if (token.getDamageTypeValue()) |d| {
                return .{ .val = d };
            }
        }
        return ParseError.UnexpectedToken;
    }

    pub fn evaluate(this_ptr: *anyopaque, _: SymbolTable) Expression.Error!Expression.Result {
        const self: *DamageTypeLiteral = @ptrCast(@alignCast(this_ptr));
        return .{ .damage_type = self.val };
    }

    pub fn evaluateAlloc(_: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        return evaluate(this_ptr, symbol_table);
    }

    pub fn expr(self: *DamageTypeLiteral) Expression {
        return Expression {
            .ptr = self,
            .requires_alloc = false,
            .evaluateFn = &evaluate,
            .evaluateAllocFn = &evaluateAlloc
        };
    }
};

pub const DiceLiteral = struct {
    val: Dice,

    pub fn from(iter: TokenIterator) ParseError!DiceLiteral {
        if (iter.next()) |token| {
            if (token.getDiceValue()) |d| {
                return DiceLiteral { .val = d };
            }
        }
        return ParseError.UnexpectedToken;
    }

    pub fn evaluate(this_ptr: *anyopaque, _: SymbolTable) Expression.Error!Expression.Result {
        const self: *DiceLiteral = @ptrCast(@alignCast(this_ptr));
        return .{ .dice = self.val };
    }

    pub fn evaluateAlloc(_: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        return evaluate(this_ptr, symbol_table);
    }

    pub fn expr(self: *DiceLiteral) Expression {
        return Expression {
            .ptr = self,
            .requires_alloc = false,
            .evaluateFn = &evaluate,
            .evaluateAllocFn = &evaluateAlloc
        };
    }
};

/// No `from` function is defined because this literal holds a slice of expressions,
/// and we can't parse other expressions in this scope.
pub const ListLiteral = struct {
    vals: []Expression,

    pub fn evaluateAlloc(
        allocator: Allocator,
        this_ptr: *anyopaque,
        symbol_table: SymbolTable
    ) Expression.Error!Expression.Result {
        const self: *ListLiteral = @ptrCast(@alignCast(this_ptr));
        const evaluated: []Expression.Result = try allocator.alloc(Expression.Result);

        // since we require the allocator here, we're gonna assume each item needs one too
        for (0..self.vals.len) |i| {
            evaluated[i] = try self.vals[i].evaluateAlloc(allocator, symbol_table);
        }

        return .{ .list = try Expression.ListResult.from(allocator, evaluated) };
    }

    pub fn expr(self: *ListLiteral) Expression {
        return Expression {
            .ptr = self,
            .requires_alloc = true,
            .evaluateFn = &Expression.errRequireAlloc,
            .evaluateAllocFn = &evaluateAlloc
        };
    }
};

pub const Label = struct {
    label: []const u8,

    pub fn from(iter: TokenIterator) ParseError!Label {
        _ = try iter.require("#");
        const label_token: Token = try iter.requireType(@tagName(Token.identifier));

        return .{ .str = label_token.toString().? };
    }

    pub fn evaluate(this_ptr: *anyopaque, _: SymbolTable) Expression.Error!Expression.Result {
        const self: *Label = @ptrCast(@alignCast(this_ptr));
        if (Expression.Label.from(self.label)) |l| {
            return .{ .label = l };
        }
        return Expression.Error.InvalidLabel;
    }

    pub fn evaluateAlloc(_: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        return evaluate(this_ptr, symbol_table);
    }

    pub fn expr(self: *Label) Expression {
        return Expression {
            .ptr = self,
            .requires_alloc = false,
            .evaluateFn = &evaluate,
            .evaluateAllocFn = &evaluateAlloc
        };
    }
};

pub const Identifier = struct {
    name: []const u8,

    pub fn from(iter: TokenIterator) ParseError!Identifier {
        const identifier_token: Token = try iter.requireType(@tagName(Token.identifier));
        return .{ .name = identifier_token.toString().? };
    }

    pub fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        const self: *Identifier = @ptrCast(@alignCast(this_ptr));

        if (symbol_table.getSymbol(self.name)) |value| {
            return .{ .identifier = value };
        }
        return Expression.Result.UndefinedIdentifier;
    }

    pub fn evaluateAlloc(_: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        return evaluate(this_ptr, symbol_table);
    }

    pub fn expr(self: *Identifier) Expression {
        return Expression {
            .ptr = self,
            .requires_alloc = false,
            .evaluateFn = &evaluate,
            .evaluateAllocFn = &evaluateAlloc
        };
    }
};

pub const UnaryExpression = struct {
    rhs: Expression,
    op: Token,

    pub fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        const self: *UnaryExpression = @ptrCast(@alignCast(this_ptr));

        const rh_result: Expression.Result = try self.rhs.evaluate(symbol_table);
        return self.evaluate_internal(rh_result);
    }

    pub fn evaluateAlloc(allocator: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        const self: *UnaryExpression = @ptrCast(@alignCast(this_ptr));

        const rh_result: Expression.Result = try self.rhs.evaluateAlloc(allocator, symbol_table);
        return self.evaluate_internal(rh_result);
    }

    fn evaluate_internal(self: UnaryExpression, result: Expression.Result) Expression.Error!Expression.Result {
        switch (result) {
            Expression.Result.boolean => |x| {
                if (self.op.expectStringEquals("~")) {
                    return !x;
                } else |err| {
                    return err;
                }
                return Expression.Error.OperandTypeNotSupported;
            },
            Expression.Result.integer => |x| {
                if (self.op.expectStringEquals("-")) {
                    return -x;
                } else |err| {
                    return err;
                }
                return Expression.Error.OperandTypeNotSupported;
            },
            else => return Expression.Error.OperandTypeNotSupported
        }
    }

    pub fn expr(self: *UnaryExpression) Expression {
        return Expression {
            .ptr = self,
            .requires_alloc = self.rhs.requires_alloc,
            .evaluateFn = &evaluate,
            .evaluateAllocFn = &evaluateAlloc
        };
    }
};

pub const AdditiveExpression = struct {
    lhs: Expression,
    rhs: Expression,
    op: Token,
    allocator: Allocator,


};
