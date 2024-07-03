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
                return .{ .val = n };
            }
            return ParseError.UnexpectedToken;
        }
        return ParseError.EOF;
    }

    pub fn evaluate(this_ptr: *anyopaque, _: SymbolTable) Expression.Error!Expression.Result {
        const self: *IntegerLiteral = @ptrCast(@alignCast(this_ptr));
        return .{ .integer = self.val };
    }

    pub fn evaluateAlloc(_: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        return evaluate(this_ptr, symbol_table);
    }

    pub fn expr(self: *IntegerLiteral) Expression {
        return .{
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
                return .{ .val = b };
            }
            return ParseError.UnexpectedToken;
        }
        return ParseError.EOF;
    }

    pub fn evaluate(this_ptr: *anyopaque, _: SymbolTable) Expression.Error!Expression.Result {
        const self: *BooleanLiteral = @ptrCast(@alignCast(this_ptr));
        return .{ .boolean = self.val };
    }

    pub fn evaluateAlloc(_: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        return evaluate(this_ptr, symbol_table);
    }

    pub fn expr(self: *BooleanLiteral) Expression {
        return .{
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
            return ParseError.UnexpectedToken;
        }
        return ParseError.EOF;
    }

    pub fn evaluate(this_ptr: *anyopaque, _: SymbolTable) Expression.Error!Expression.Result {
        const self: *DamageTypeLiteral = @ptrCast(@alignCast(this_ptr));
        return .{ .damage_type = self.val };
    }

    pub fn evaluateAlloc(_: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        return evaluate(this_ptr, symbol_table);
    }

    pub fn expr(self: *DamageTypeLiteral) Expression {
        return .{
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
                return .{ .val = d };
            }
            return ParseError.UnexpectedToken;
        }
        return ParseError.EOF;
    }

    pub fn evaluate(this_ptr: *anyopaque, _: SymbolTable) Expression.Error!Expression.Result {
        const self: *DiceLiteral = @ptrCast(@alignCast(this_ptr));
        return .{ .dice = self.val };
    }

    pub fn evaluateAlloc(_: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        return evaluate(this_ptr, symbol_table);
    }

    pub fn expr(self: *DiceLiteral) Expression {
        return .{
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

pub const ParensthesizedExpression = struct {
    inner: Expression,

    pub fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        const self: *ParensthesizedExpression = @ptrCast(@alignCast(this_ptr));
        return self.inner.evaluate(symbol_table);
    }

    pub fn evaluateAlloc(allocator: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        const self: *ParensthesizedExpression = @ptrCast(@alignCast(this_ptr));
        return self.inner.evaluate(allocator, symbol_table);
    }

    pub fn expr(self: *ParensthesizedExpression) Expression {
        return Expression {
            .ptr = self,
            .requires_alloc = self.inner.requires_alloc,
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

    fn evaluateInternal(self: UnaryExpression, result: Expression.Result) Expression.Error!Expression.Result {
        switch (result) {
            Expression.Result.boolean => |x| {
                if (self.op.expectSymbolEquals("~")) {
                    return !x;
                } else |err| {
                    return err;
                }
                return Expression.Error.OperandTypeNotSupported;
            },
            Expression.Result.integer => |x| {
                if (self.op.expectSymbolEquals("-")) {
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

    pub fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        const self: *AdditiveExpression = @ptrCast(@alignCast(this_ptr));

        const lh_result: Expression.Result = try self.lhs.evaluate(symbol_table);
        const rh_result: Expression.Result = try self.rhs.evaluate(symbol_table);

        return evaluateInternal(lh_result, rh_result, self.op);
    }

    pub fn evaluateAlloc(allocator: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        const self: *AdditiveExpression = @ptrCast(@alignCast(this_ptr));

        const lh_result: Expression.Result = try self.lhs.evaluateAlloc(allocator, symbol_table);
        const rh_result: Expression.Result = try self.rhs.evaluateAlloc(allocator, symbol_table);

        return evaluateInternal(lh_result, rh_result, self.op);
    }

    fn evaluateInternal(lhs: Expression.Result, rhs: Expression.Result, operator: Token) Expression.Error!Expression.Result {
        switch (lhs) {
            Expression.Result.integer => |lh_int| {
                // rhs can only be an integer in this case
                const rh_int: i32 = try rhs.expectType(i32) catch { return Expression.Error.OperandTypeMismatch; };
                try operator.expectSymbolEqualsOneOf(&[_][]const u8 { "+", "-" });
                if (operator.stringEquals("+")) {
                    return .{ .integer = lh_int + rh_int };
                }
                else {
                    return .{ .integer = lh_int - rh_int };
                }
            },
            Expression.Result.list => |lh_list| {
                try operator.expectSymbolEqualsOneOf(&[_][]const u8 { "+", "-", "+!" });
                if (rhs.isList()) |rh_list| {
                    var new_list: Expression.ListResult = undefined;
                    if (operator.stringEquals("+")) {
                        new_list = try lh_list.append(rh_list);
                    } else if (operator.stringEquals("+!")) {
                        new_list = try lh_list.appendUnique(rh_list);
                    } else {
                        new_list = try lh_list.remove(rh_list);
                    }
                    // cleanup both sides
                    lh_list.deinit();
                    rh_list.deinit();

                    return .{ .list = new_list };
                } else {
                    var new_list: Expression.ListResult = undefined;
                    if (operator.stringEquals("+")) {
                        new_list = try lh_list.appendOne(rhs);
                    } else if (operator.stringEquals("+!")) {
                        new_list = try lh_list.appendOneUnique(rhs);
                    } else {
                        new_list = try lh_list.removeOne(rhs);
                    }
                    // cleanup original list
                    lh_list.deinit();

                    return .{ .list = new_list };
                }
            },
            else => return Expression.Error.OperandTypeNotSupported
        }
    }

    pub fn expr(self: *AdditiveExpression) Expression {
        return Expression {
            .ptr = self,
            .requires_alloc = self.lhs.requires_alloc or self.rhs.requires_alloc,
            .evaluateFn = &evaluate,
            .evaluateAllocFn = &evaluateAlloc
        };
    }
};

pub const FactorExpression = struct {
    lhs: Expression,
    rhs: Expression,
    op: Token,

    pub fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        const self: *FactorExpression = @ptrCast(@alignCast(this_ptr));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "*", "/" });

        const lh_result: Expression.Result = try self.lhs.evaluate(symbol_table);
        const rh_result: Expression.Result = try self.rhs.evaluate(symbol_table);

        return evaluateInternal(lh_result, rh_result, self.op);
    }

    pub fn evaluateAlloc(allocator: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        const self: *AdditiveExpression = @ptrCast(@alignCast(this_ptr));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "*", "/" });

        const lh_result: Expression.Result = try self.lhs.evaluateAlloc(allocator, symbol_table);
        const rh_result: Expression.Result = try self.rhs.evaluateAlloc(allocator, symbol_table);

        return evaluateInternal(lh_result, rh_result, self.op);
    }

    fn evaluateInternal(lhs: Expression.Result, rhs: Expression.Result, operator: Token) Expression.Error!Expression.Result {
        const lh_int: i32 = try lhs.expectType(i32) catch { return Expression.Error.OperandTypeNotSupported; };
        const rh_int: i32 = try rhs.expectType(i32) catch { return Expression.Error.OperandTypeNotSupported; };

        if (operator.stringEquals("*")) {
            return .{ .integer = lh_int * rh_int };
        } else {
            return .{ .integer = lh_int / rh_int };
        }
    }

    pub fn expr(self: *FactorExpression) Expression {
        return .{
            .ptr = self,
            .requires_alloc = self.lhs.requires_alloc or self.rhs.requires_alloc,
            .evaluateFn = &evaluate,
            .evaluateAllocFn = &evaluateAlloc
        };
    }
};

pub const ComparisonExpression = struct {
    lhs: Expression,
    rhs: Expression,
    op: Token,

    pub fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        const self: *ComparisonExpression = @ptrCast(@alignCast(this_ptr));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "<", "<=", ">=", ">" });

        const lh_result: Expression.Result = try self.lhs.evaluate(symbol_table);
        const rh_result: Expression.Result = try self.rhs.evaluate(symbol_table);

        return evaluateInternal(lh_result, rh_result, self.op);
    }

    pub fn evaluateAlloc(allocator: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        const self: *ComparisonExpression = @ptrCast(@alignCast(this_ptr));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "<", "<=", ">=", ">" });

        const lh_result: Expression.Result = try self.lhs.evaluateAlloc(allocator, symbol_table);
        const rh_result: Expression.Result = try self.rhs.evaluateAlloc(allocator, symbol_table);

        return evaluateInternal(lh_result, rh_result, self.op);
    }

    fn evaluateInternal(lhs: Expression.Result, rhs: Expression.Result, operator: Token) Expression.Error!Expression.Result {
        const lh_int: i32 = try lhs.expectType(i32) catch { return Expression.Error.OperandTypeNotSupported; };
        const rh_int: i32 = try rhs.expectType(i32) catch { return Expression.Error.OperandTypeNotSupported; };

        if (operator.stringEquals("<")) {
            return .{ .boolean = lh_int < rh_int };
        } else if (operator.stringEquals("<=")) {
            return .{ .boolean = lh_int <= rh_int };
        } else if (operator.stringEquals(">=")) {
            return .{ .boolean = lh_int >= rh_int };
        } else {
            return .{ .boolean = lh_int > rh_int };
        }
    }

    pub fn expr(self: *ComparisonExpression) Expression {
        return .{
            .ptr = self,
            .requires_alloc = self.lhs.requires_alloc or self.rhs.requires_alloc,
            .evaluateFn = &evaluate,
            .evaluateAllocFn = &evaluateAlloc
        };
    }
};

pub const EqualityExpression = struct {
    lhs: Expression,
    rhs: Expression,
    op: Token,

    pub fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        const self: *EqualityExpression = @ptrCast(@alignCast(this_ptr));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "==", "~=" });

        const lh_result: Expression.Result = try self.lhs.evaluate(symbol_table);
        const rh_result: Expression.Result = try self.rhs.evaluate(symbol_table);

        return evaluateInternal(lh_result, rh_result, self.op);
    }

    pub fn evaluateAlloc(allocator: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        const self: *EqualityExpression = @ptrCast(@alignCast(this_ptr));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "==", "~=" });

        const lh_result: Expression.Result = try self.lhs.evaluateAlloc(allocator, symbol_table);
        const rh_result: Expression.Result = try self.rhs.evaluateAlloc(allocator, symbol_table);

        return evaluateInternal(lh_result, rh_result, self.op);
    }

    fn evaluateInternal(lhs: Expression.Result, rhs: Expression.Result, operator: Token) Expression.Error!Expression.Result {
        switch (lhs) {
            Expression.Result.integer => |lh_int| {
                const rh_int: i32 = try rhs.expectType(i32) catch { return Expression.Error.OperandTypeNotSupported; };
                if (operator.stringEquals("==")) {
                    return .{ .boolean = lh_int == rh_int };
                } else {
                    return .{ .boolean = lh_int != rh_int };
                }
            },
            Expression.Result.boolean => |lh_bool| {
                const rh_bool: bool = try rhs.expectType(bool) catch { return Expression.Error.OperandTypeNotSupported; };
                if (operator.stringEquals("==")) {
                    return .{ .boolean = lh_bool == rh_bool };
                } else {
                    return .{ .boolean = lh_bool != rh_bool };
                }
            },
            else => return Expression.Error.OperandTypeNotSupported
        }
    }

    pub fn expr(self: *EqualityExpression) Expression {
        return .{
            .ptr = self,
            .requires_alloc = self.lhs.requires_alloc or self.rhs.requires_alloc,
            .evaluateFn = &evaluate,
            .evaluateAllocFn = &evaluateAlloc
        };
    }
};

pub const BooleanExpression = struct {
    lhs: Expression,
    rhs: Expression,
    op: Token,

    pub fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        const self: *BooleanExpression = @ptrCast(@alignCast(this_ptr));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "+", "|", "^" });

        const lh_result: Expression.Result = try self.lhs.evaluate(symbol_table);
        const rh_result: Expression.Result = try self.rhs.evaluate(symbol_table);

        return evaluateInternal(lh_result, rh_result, self.op);
    }

    pub fn evaluateAlloc(allocator: Allocator, this_ptr: *anyopaque, symbol_table: SymbolTable) Expression.Error!Expression.Result {
        const self: *BooleanExpression = @ptrCast(@alignCast(this_ptr));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "+", "|", "^" });

        const lh_result: Expression.Result = try self.lhs.evaluateAlloc(allocator, symbol_table);
        const rh_result: Expression.Result = try self.rhs.evaluateAlloc(allocator, symbol_table);

        return evaluateInternal(lh_result, rh_result, self.op);
    }

    fn evaluateInternal(lhs: Expression.Result, rhs: Expression.Result, operator: Token) Expression.Error!Expression.Result {
        const lh_bool: bool = try lhs.expectType(bool) catch { return Expression.Error.OperandTypeNotSupported; };
        const rh_bool: bool = try rhs.expectType(bool) catch { return Expression.Error.OperandTypeNotSupported; };
        if (operator.stringEquals("+")) {
            return .{ .boolean = lh_bool and rh_bool };
        } else if (operator.stringEquals("|")) {
            return .{ .boolean = lh_bool or rh_bool };
        } else {
            return .{ .boolean = (!lh_bool and rh_bool) or (lh_bool and !rh_bool) };
        }
    }

    pub fn expr(self: *BooleanExpression) Expression {
        return .{
            .ptr = self,
            .requires_alloc = self.lhs.requires_alloc or self.rhs.requires_alloc,
            .evaluateFn = &evaluate,
            .evaluateAllocFn = &evaluateAlloc
        };
    }
};
