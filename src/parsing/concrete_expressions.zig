const std = @import("std");

const imports = struct {
    usingnamespace @import("tokens.zig");
    usingnamespace @import("util");
    usingnamespace @import("game_zones");
    usingnamespace @import("expression.zig");
    usingnamespace @import("concrete_statements.zig");
};

const Allocator = std.mem.Allocator;
const Expression = imports.Expression;
const Result = imports.Result;
const Error = imports.Error;
const ListResult = imports.ListResult;
const DiceResult = imports.DiceResult;
const IntResult = imports.IntResult;
const Label = imports.Label;
const Token = imports.Token;
const TokenIterator = imports.TokenIterator;
const SymbolTable = imports.SymbolTable;
const Symbol = imports.Symbol;
const DamageType = imports.types.DamageType;
const Dice = imports.types.Dice;
const ParseTokenError = imports.ParseTokenError;
const FunctionCall = imports.FunctionCall;

const InnerError = error {
    UnexpectedToken
};

pub const ParseError = InnerError || imports.ParseTokenError || imports.Error;

pub const IntegerLiteral = struct {
    val: u16,
    allocator: Allocator,

    pub fn from(allocator: Allocator, iter: TokenIterator) ParseError!*IntegerLiteral {
        if (iter.next()) |token| {
            if (token.getNumericValue()) |n| {
                const ptr: *IntegerLiteral = try allocator.create(IntegerLiteral);
                ptr.* = .{
                    .val = n,
                    .allocator = allocator
                };
                return ptr;
            }
            iter.internal_iter.scroll(-1);
            return ParseError.UnexpectedToken;
        }
        return ParseError.EOF;
    }

    fn implEvaluate(impl: *anyopaque, _: *SymbolTable) Error!Result {
        const self: *IntegerLiteral = @ptrCast(@alignCast(impl));
        return .{
            .integer = .{
                .value = @intCast(self.val)
            }
        };
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *IntegerLiteral = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn expr(self: *IntegerLiteral) Expression {
        return .{
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }

    pub fn deinit(self: *IntegerLiteral) void {
        self.allocator.destroy(self);
    }
};

pub const BooleanLiteral = struct {
    val: bool,
    allocator: Allocator,

    pub fn from(allocator: Allocator, iter: TokenIterator) ParseError!*BooleanLiteral {
        if (iter.next()) |token| {
            if (token.getBoolValue()) |b| {
                const ptr: *BooleanLiteral = try allocator.create(BooleanLiteral);
                ptr.* = .{
                    .val = b,
                    .allocator = allocator
                };
                return ptr;
            }
            iter.internal_iter.scroll(-1);
            return ParseError.UnexpectedToken;
        }
        return ParseError.EOF;
    }

    fn implEvaluate(impl: *anyopaque, _: *SymbolTable) Error!Result {
        const self: *BooleanLiteral = @ptrCast(@alignCast(impl));
        return .{ .boolean = self.val };
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *BooleanLiteral = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn expr(self: *BooleanLiteral) Expression {
        return .{
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }

    pub fn deinit(self: *BooleanLiteral) void {
        self.allocator.destroy(self);
    }
};

pub const DamageTypeLiteral = struct {
    val: DamageType,
    allocator: Allocator,

    pub fn from(allocator: Allocator, iter: TokenIterator) ParseError!*DamageTypeLiteral {
        if (iter.next()) |token| {
            if (token.getDamageTypeValue()) |d| {
                const ptr: *DamageTypeLiteral = try allocator.create(DamageTypeLiteral);
                ptr.* = .{
                    .val = d,
                    .allocator = allocator
                };
                return ptr;
            }
            iter.internal_iter.scroll(-1);
            return ParseError.UnexpectedToken;
        }
        return ParseError.EOF;
    }

    fn implEvaluate(impl: *anyopaque, _: *SymbolTable) Error!Result {
        const self: *DamageTypeLiteral = @ptrCast(@alignCast(impl));
        return .{ .damage_type = self.val };
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *DamageTypeLiteral = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn expr(self: *DamageTypeLiteral) Expression {
        return .{
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }

    pub fn deinit(self: *DamageTypeLiteral) void {
        self.allocator.destroy(self);
    }
};

pub const DiceLiteral = struct {
    count: u16 = 1,
    val: Dice,
    allocator: Allocator,

    pub fn from(allocator: Allocator, iter: TokenIterator) ParseError!*DiceLiteral {
        if (iter.next()) |token| {
            if (token.getDiceValue()) |d| {
                const ptr: *DiceLiteral = try allocator.create(DiceLiteral);
                ptr.* = .{
                    .val = d,
                    .allocator = allocator,
                };
                return ptr;
            } else if (token.getNumericValue()) |n| {
                // case with multiple dice, like 2d4
                if (iter.next()) |next_token| {
                    if (next_token.getDiceValue()) |d| {
                        const ptr: *DiceLiteral = try allocator.create(DiceLiteral);
                        ptr.* = .{
                            .count = n,
                            .val = d,
                            .allocator = allocator
                        };
                        return ptr;
                    }
                    // scroll back 2 tokens
                    iter.internal_iter.scroll(-2);
                    return ParseError.UnexpectedToken;
                }
                // scroll back 1 token
                iter.internal_iter.scroll(-1);
                return ParseError.EOF;
            }
            // scroll back 1 token
            iter.internal_iter.scroll(-1);
            return ParseError.UnexpectedToken;
        }
        return ParseError.EOF;
    }

    fn implEvaluate(impl: *anyopaque, _: *SymbolTable) Error!Result {
        const self: *DiceLiteral = @ptrCast(@alignCast(impl));
        return .{
            .dice = .{
                .count = self.count,
                .dice = self.val
            }
        };
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *DiceLiteral = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn expr(self: *DiceLiteral) Expression {
        return .{
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }

    pub fn deinit(self: *DiceLiteral) void {
        self.allocator.destroy(self);
    }
};

pub const DamageExpression = struct {
    amount_expr: Expression,
    damage_type_expr: Expression,
    allocator: Allocator,

    pub fn new(
        allocator: Allocator,
        amount_expr: Expression,
        damage_type_expr: Expression
    ) Allocator.Error!*DamageExpression {
        const ptr: *DamageExpression = try allocator.create(DamageExpression);
        ptr.* = .{
            .amount_expr = amount_expr,
            .damage_type_expr = damage_type_expr,
            .allocator = allocator
        };
        return ptr;
    }

    fn implEvaluate(impl: *anyopaque, symbol_table: *SymbolTable) Error!Result {
        const self: *DamageExpression = @ptrCast(@alignCast(impl));

        const damage_type_eval: Result = try self.damage_type_expr.evaluate(symbol_table);
        const damage_type: DamageType = try damage_type_eval.expectType(DamageType);

        const amount_eval: Result = try self.amount_expr.evaluate(symbol_table);
        if (amount_eval.as(i32)) |amount| {
            return .{
                .damage_transaction = .{
                    // can never deal negative damage
                    .modifier = if (amount < 0) 0 else amount,
                    .damage_type = damage_type
                }
            };
        } else if (amount_eval.as(DiceResult)) |dice| {
            return .{
                .damage_transaction = .{
                    .dice = dice.dice,
                    .repetitions = dice.count,
                    .modifier = dice.modifier,
                    .damage_type = damage_type
                }
            };
        }
        return Error.InvalidInnerExpression;
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *DamageExpression = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn deinit(self: *DamageExpression) void {
        self.amount_expr.deinit();
        self.damage_type_expr.deinit();
        self.allocator.destroy(self);
    }

    pub fn expr(self: *DamageExpression) Expression {
        return .{
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }
};

/// No `from` function is defined because this literal holds a slice of expressions,
/// and we can't parse other expressions in this scope.
pub const ListLiteral = struct {
    vals: []Expression,
    allocator: Allocator,

    pub fn new(allocator: Allocator, items: []Expression) Allocator.Error!*ListLiteral {
        const ptr: *ListLiteral = try allocator.create(ListLiteral);
        ptr.* = .{
            .vals = items,
            .allocator = allocator
        };
        return ptr;
    }

    fn implEvaluate(impl: *anyopaque, symbol_table: *SymbolTable) Error!Result {
        const self: *ListLiteral = @ptrCast(@alignCast(impl));
        const evaluated: []Result = try symbol_table.allocator.alloc(Result);

        // since we require the allocator here, we're gonna assume each item needs one too
        for (0..self.vals.len) |i| {
            evaluated[i] = try self.vals[i].evaluate(symbol_table);
        }

        return .{
            .list = try ListResult.from(symbol_table.allocator, evaluated)
        };
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *ListLiteral = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn deinit(self: *ListLiteral) void {
        Expression.deinitAllAndFree(self.allocator, self.vals);
        self.allocator.destroy(self);
    }

    pub fn expr(self: *ListLiteral) Expression {
        return Expression {
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }
};

pub const LabelLiteral = struct {
    label: Label,
    allocator: Allocator,

    pub fn from(allocator: Allocator, iter: TokenIterator) ParseError!*LabelLiteral {
        _ = iter.require("#") catch |err| {
            iter.internal_iter.scroll(-1);
            return err;
        };
        const label_token: Token = try iter.requireType(&[_][]const u8 { @tagName(Token.identifier) });
        var label: Label = undefined;

        if (iter.peek()) |next_tok| {
            // #accuracy = 2
            // #rank = s
            if (next_tok.symbolEquals("=")) {
                // consume because we already have the next token
                _ = iter.next();
                const rhs: Token = try iter.requireType(&[_][]const u8 { @tagName(Token.identifier), @tagName(Token.numeric) });
                label = try Label.from(label_token.toString().?, rhs.toString());

                const ptr: *LabelLiteral = try allocator.create(LabelLiteral);
                ptr.* = .{
                    .label = label,
                    .allocator = allocator
                };
                return ptr;
            }
        }

        label = try Label.from(label_token.toString().?, null);
        const ptr: *LabelLiteral = try allocator.create(LabelLiteral);
        ptr.* = .{
            .label = label,
            .allocator = allocator
        };
        return ptr;
    }

    fn implEvaluate(impl: *anyopaque, _: *SymbolTable) Error!Result {
        const self: *LabelLiteral = @ptrCast(@alignCast(impl));
        return .{ .label = self.label };
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *LabelLiteral = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn expr(self: *LabelLiteral) Expression {
        return Expression {
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }

    pub fn deinit(self: *LabelLiteral) void {
        self.allocator.destroy(self);
    }
};

pub const Identifier = struct {
    name: Token,
    allocator: Allocator,

    pub fn from(allocator: Allocator, iter: TokenIterator) ParseError!*Identifier {
        const identifier_token: Token = try iter.requireType(&[_][]const u8 { @tagName(Token.identifier) });
        
        const ptr: *Identifier = try allocator.create(Identifier);
        errdefer allocator.destroy(ptr);

        ptr.* = .{
            .name = try identifier_token.clone(),
            .allocator = allocator
        };
        return ptr;
    }

    fn implEvaluate(impl: *anyopaque, symbol_table: *SymbolTable) Error!Result {
        const self: *Identifier = @ptrCast(@alignCast(impl));

        if (symbol_table.getSymbol(self.name.toString().?)) |value| {
            return .{ .identifier = value };
        }
        return Error.UndefinedIdentifier;
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *Identifier = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn deinit(self: *Identifier) void {
        self.name.deinit();
        self.allocator.destroy(self);
    }

    pub fn expr(self: *Identifier) Expression {
        return Expression {
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }
};

pub const ParensthesizedExpression = struct {
    inner: Expression,

    pub fn deinit(self: ParensthesizedExpression) void {
        self.inner.deinit();
    }

    pub fn expr(self: ParensthesizedExpression) Expression {
        return self.inner;
    }
};

pub const UnaryExpression = struct {
    rhs: Expression,
    op: Token,
    allocator: Allocator,

    pub fn new(allocator: Allocator, rhs: Expression, op: Token) Error!*UnaryExpression {
        const ptr: *UnaryExpression = try allocator.create(UnaryExpression);
        errdefer allocator.destroy(ptr);

        ptr.* = .{
            .rhs = rhs,
            .op = try op.clone(),
            .allocator = allocator
        };
        return ptr;
    }

    fn implEvaluate(impl: *anyopaque, symbol_table: *SymbolTable) Error!Result {
        const self: *UnaryExpression = @ptrCast(@alignCast(impl));

        const rh_result: Result = try self.rhs.evaluate(symbol_table);
        switch (rh_result) {
            Result.boolean => |x| {
                if (self.op.expectSymbolEquals("~")) {
                    return .{ .boolean = !x };
                } else |err| {
                    return err;
                }
                return Error.OperandTypeNotSupported;
            },
            Result.integer => |x| {
                if (self.op.symbolEquals("-")) {
                    return .{
                        .integer = .{
                            .value = -x.value
                        }
                    };
                } else if (self.op.symbolEquals("^")) {
                    return .{
                        .integer = .{
                            .value = x.value,
                            .up_to = true
                        }
                    };
                }
                return Error.OperandTypeNotSupported;
            },
            else => return Error.OperandTypeNotSupported
        }
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *UnaryExpression = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn deinit(self: *UnaryExpression) void {
        self.rhs.deinit();
        self.op.deinit();
        self.allocator.destroy(self);
    }

    pub fn expr(self: *UnaryExpression) Expression {
        return Expression {
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }
};

pub const AdditiveExpression = struct {
    lhs: Expression,
    rhs: Expression,
    op: Token,
    allocator: Allocator,

    pub fn new(
        allocator: Allocator,
        lhs: Expression,
        rhs: Expression,
        op: Token
    ) Error!*AdditiveExpression {
        const ptr: *AdditiveExpression = try allocator.create(AdditiveExpression);
        errdefer allocator.destroy(ptr);

        ptr.* = .{
            .lhs = lhs,
            .rhs = rhs,
            .op = try op.clone(),
            .allocator = allocator
        };
        return ptr;
    }

    fn implEvaluate(impl: *anyopaque, symbol_table: *SymbolTable) Error!Result {
        const self: *AdditiveExpression = @ptrCast(@alignCast(impl));

        const lh_result: Result = try self.lhs.evaluate(symbol_table);
        const rh_result: Result = try self.rhs.evaluate(symbol_table);

        switch (lh_result) {
            Result.integer => |lh_int| {
                // rhs can only be an integer in this case
                const rh_int: i32 = rh_result.expectType(i32) catch { return Error.OperandTypeMismatch; };
                try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "+", "-" });
                if (self.op.stringEquals("+")) {
                    return .{
                        .integer = .{
                            .value = lh_int.value + rh_int
                        }
                    };
                } else {
                    return .{
                        .integer = .{
                            .value = lh_int.value - rh_int
                        }    
                    };
                }
            },
            Result.list => |lh_list| {
                try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "+", "-", "+!" });
                if (rh_result.as(ListResult)) |rh_list| {
                    var new_list: ListResult = undefined;
                    if (self.op.stringEquals("+")) {
                        new_list = try lh_list.append(rh_list);
                    } else if (self.op.stringEquals("+!")) {
                        new_list = try lh_list.appendUnique(rh_list);
                    } else {
                        new_list = try lh_list.remove(rh_list);
                    }
                    return .{ .list = new_list };
                } else {
                    var new_list: ListResult = undefined;
                    if (self.op.stringEquals("+")) {
                        new_list = try lh_list.appendOne(rh_result);
                    } else if (self.op.stringEquals("+!")) {
                        new_list = try lh_list.appendOneUnique(rh_result);
                    } else {
                        new_list = try lh_list.removeOne(rh_result);
                    }
                    return .{ .list = new_list };
                }
            },
            Result.dice => |lh_dice| {
                try self.op.expectStringEqualsOneOf(&[_][]const u8 { "+", "-" });
                const rh_int: i32 = try rh_result.expectType(i32);

                var dice_result: DiceResult = .{
                    .dice = lh_dice.dice,
                    .count = lh_dice.count,
                    .modifier = lh_dice.modifier
                };

                if (self.op.symbolEquals("+")) {
                    dice_result.modifier += rh_int;
                } else {
                    dice_result.modifier -= rh_int;
                }

                return .{ .dice = dice_result };
            },
            else => return Error.OperandTypeNotSupported
        }
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *AdditiveExpression = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn deinit(self: *AdditiveExpression) void {
        self.lhs.deinit();
        self.rhs.deinit();
        self.op.deinit();
        self.allocator.destroy(self);
    }

    pub fn expr(self: *AdditiveExpression) Expression {
        return Expression {
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }
};

pub const FactorExpression = struct {
    lhs: Expression,
    rhs: Expression,
    op: Token,
    allocator: Allocator,

    pub fn new(
        allocator: Allocator,
        lhs: Expression,
        rhs: Expression,
        op: Token
    ) Error!*FactorExpression {
        const ptr: *FactorExpression = try allocator.create(FactorExpression);
        errdefer allocator.destroy(ptr);

        ptr.* = .{
            .lhs = lhs,
            .rhs = rhs,
            .op = try op.clone(),
            .allocator = allocator
        };
        return ptr;
    }

    fn implEvaluate(impl: *anyopaque, symbol_table: *SymbolTable) Error!Result {
        const self: *FactorExpression = @ptrCast(@alignCast(impl));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "*", "/" });

        const lh_result: Result = try self.lhs.evaluate(symbol_table);
        const rh_result: Result = try self.rhs.evaluate(symbol_table);

        const lh_int: i32 = lh_result.expectType(i32) catch { return Error.OperandTypeNotSupported; };
        const rh_int: i32 = rh_result.expectType(i32) catch { return Error.OperandTypeNotSupported; };

        if (self.op.stringEquals("*")) {
            return .{
                .integer = .{
                    .value = lh_int * rh_int
                }
            };
        } else {
            return .{
                .integer = .{
                    .value = @divTrunc(lh_int, rh_int)
                }
            };
        }
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *FactorExpression = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn deinit(self: *FactorExpression) void {
        self.lhs.deinit();
        self.rhs.deinit();
        self.op.deinit();
        self.allocator.destroy(self);
    }

    pub fn expr(self: *FactorExpression) Expression {
        return .{
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }
};

pub const ComparisonExpression = struct {
    lhs: Expression,
    rhs: Expression,
    op: Token,
    allocator: Allocator,

    pub fn new(
        allocator: Allocator,
        lhs: Expression,
        rhs: Expression,
        op: Token
    ) Error!*ComparisonExpression {
        const ptr: *ComparisonExpression = try allocator.create(ComparisonExpression);
        errdefer allocator.destroy(ptr);

        ptr.* = .{
            .lhs = lhs,
            .rhs = rhs,
            .op = try op.clone(),
            .allocator = allocator
        };
        return ptr;
    }

    fn implEvaluate(impl: *anyopaque, symbol_table: *SymbolTable) Error!Result {
        const self: *ComparisonExpression = @ptrCast(@alignCast(impl));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "<", "<=", ">=", ">" });

        const lh_result: Result = try self.lhs.evaluate(symbol_table);
        const rh_result: Result = try self.rhs.evaluate(symbol_table);

        const lh_int: i32 = lh_result.expectType(i32) catch { return Error.OperandTypeNotSupported; };
        const rh_int: i32 = rh_result.expectType(i32) catch { return Error.OperandTypeNotSupported; };

        if (self.op.stringEquals("<")) {
            return .{ .boolean = lh_int < rh_int };
        } else if (self.op.stringEquals("<=")) {
            return .{ .boolean = lh_int <= rh_int };
        } else if (self.op.stringEquals(">=")) {
            return .{ .boolean = lh_int >= rh_int };
        } else {
            return .{ .boolean = lh_int > rh_int };
        }
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *ComparisonExpression = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn deinit(self: *ComparisonExpression) void {
        self.lhs.deinit();
        self.rhs.deinit();
        self.op.deinit();
        self.allocator.destroy(self);
    }

    pub fn expr(self: *ComparisonExpression) Expression {
        return .{
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }
};

pub const EqualityExpression = struct {
    lhs: Expression,
    rhs: Expression,
    op: Token,
    allocator: Allocator,

    pub fn new(
        allocator: Allocator,
        lhs: Expression,
        rhs: Expression,
        op: Token
    ) Error!*EqualityExpression {
        const ptr: *EqualityExpression = try allocator.create(EqualityExpression);
        errdefer allocator.destroy(ptr);

        ptr.* = .{
            .lhs = lhs,
            .rhs = rhs,
            .op = try op.clone(),
            .allocator = allocator
        };
        return ptr;
    }

    fn implEvaluate(impl: *anyopaque, symbol_table: *SymbolTable) Error!Result {
        const self: *EqualityExpression = @ptrCast(@alignCast(impl));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "==", "~=" });

        const lh_result: Result = try self.lhs.evaluate(symbol_table);
        const rh_result: Result = try self.rhs.evaluate(symbol_table);

        switch (lh_result) {
            Result.integer => |lh_int| {
                const rh_int: i32 = rh_result.expectType(i32) catch { return Error.OperandTypeMismatch; };
                if (self.op.stringEquals("==")) {
                    return .{ .boolean = lh_int.value == rh_int };
                } else {
                    return .{ .boolean = lh_int.value != rh_int };
                }
            },
            Result.boolean => |lh_bool| {
                const rh_bool: bool = rh_result.expectType(bool) catch { return Error.OperandTypeMismatch; };
                if (self.op.stringEquals("==")) {
                    return .{ .boolean = lh_bool == rh_bool };
                } else {
                    return .{ .boolean = lh_bool != rh_bool };
                }
            },
            Result.label => |lh_label| {
                const rh_label: Label = rh_result.expectType(Label) catch {return Error.OperandTypeMismatch; };
                if (self.op.stringEquals("==")) {
                    return .{ .boolean = lh_label.equals(rh_label) };
                } else {
                    return .{ .boolean = !lh_label.equals(rh_label) };
                }
            },
            else => return Error.OperandTypeNotSupported
        }
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *EqualityExpression = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn deinit(self: *EqualityExpression) void {
        self.lhs.deinit();
        self.rhs.deinit();
        self.op.deinit();
        self.allocator.destroy(self);
    }

    pub fn expr(self: *EqualityExpression) Expression {
        return .{
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }
};

pub const BooleanExpression = struct {
    lhs: Expression,
    rhs: Expression,
    op: Token,
    allocator: Allocator,

    pub fn new(
        allocator: Allocator,
        lhs: Expression,
        rhs: Expression,
        op: Token
    ) Error!*BooleanExpression {
        const ptr: *BooleanExpression = try allocator.create(BooleanExpression);
        errdefer allocator.destroy(ptr);

        ptr.* = .{
            .lhs = lhs,
            .rhs = rhs,
            .op = try op.clone(),
            .allocator = allocator
        };
        return ptr;
    }

    fn implEvaluate(impl: *anyopaque, symbol_table: *SymbolTable) Error!Result {
        const self: *BooleanExpression = @ptrCast(@alignCast(impl));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "+", "|", "^" });

        const lh_result: Result = try self.lhs.evaluate(symbol_table);
        const rh_result: Result = try self.rhs.evaluate(symbol_table);

        const lh_bool: bool = lh_result.expectType(bool) catch { return Error.OperandTypeNotSupported; };
        const rh_bool: bool = rh_result.expectType(bool) catch { return Error.OperandTypeNotSupported; };
        if (self.op.stringEquals("+")) {
            return .{ .boolean = lh_bool and rh_bool };
        } else if (self.op.stringEquals("|")) {
            return .{ .boolean = lh_bool or rh_bool };
        } else {
            return .{ .boolean = (!lh_bool and rh_bool) or (lh_bool and !rh_bool) };
        }
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *BooleanExpression = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn deinit(self: *BooleanExpression) void {
        self.lhs.deinit();
        self.rhs.deinit();
        self.op.deinit();
        self.allocator.destroy(self);
    }

    pub fn expr(self: *BooleanExpression) Expression {
        return .{
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }
};

/// Ex.
/// `target(1 from Monster)` or
/// `target(1 from [1 | 2])`
pub const TargetExpression = struct {
    amount: Expression,
    pool: Expression,
    allocator: Allocator,

    pub fn new(
        allocator: Allocator,
        amount: Expression,
        pool: Expression
    ) Allocator.Error!*TargetExpression {
        const ptr: *TargetExpression = try allocator.create(TargetExpression);
        ptr.* = .{
            .amount = amount,
            .pool = pool,
            .allocator = allocator
        };
        return ptr;
    }

    fn implEvaluate(impl: *anyopaque, symbol_table: *SymbolTable) Error!Result {
        const self: *TargetExpression = @ptrCast(@alignCast(impl));

        const eval_amount: Result = try self.amount.evaluate(symbol_table);
        const eval_pool: Result = try self.pool.evaluate(symbol_table);

        const eval_int: IntResult = try eval_amount.expectType(IntResult);
        if (eval_int.value < 1) {
            return Error.MustBeGreaterThanZero;
        }

        const eval_list: ListResult = try eval_pool.expectType(ListResult);
        if (symbol_table.getPlayerChoice(@intCast(eval_int.value), eval_list.items, !eval_int.up_to)) |choice| {
            return choice;
        } else |err| {
            switch (err) {
                error.NotImplemented => std.debug.panic("This is not yet implemented", .{}),
                else => {
                    std.log.err("Could not get player choice: {s}\n{?}", .{ @errorName(err), @errorReturnTrace() });
                    return Error.PlayerChoiceFailed;
                }
            }
        }
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *TargetExpression = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn deinit(self: *TargetExpression) void {
        self.amount.deinit();
        self.pool.deinit();
        self.allocator.destroy(self);
    }

    pub fn expr(self: *TargetExpression) Expression {
        return Expression {
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }
};

pub const AccessorExpression = struct {
    pub const Link = union(enum) {
        function_call: FunctionCall,
        idententifier: Identifier,

        pub fn getName(self: Link) []const u8 {
            switch (self) {
                inline else => |x| return x.name
            }
        }

        pub fn expr(self: Link) Expression {
            switch (self) {
                inline else => |x| return x.expr()
            }
        }
    };

    accessor_chain: []Link,
    allocator: Allocator,

    pub fn new(allocator: Allocator, accessor_chain: []Link) Allocator.Error!*AccessorExpression {
        const ptr: *AccessorExpression = try allocator.create(AccessorExpression);
        ptr.* = .{
            .accessor_chain = accessor_chain,
            .allocator = allocator
        };
        return ptr;
    }
    
    fn implEvaluate(impl: *anyopaque, symbol_table: *SymbolTable) Error!Result {
        const self: *AccessorExpression = @ptrCast(@alignCast(impl));

        // we need at least one '.' for this to be a full accessor chain
        if (self.accessor_chain.len < 2) {
            return Error.InvalidAccessorChain;
        }

        var current_symbol: Symbol = undefined;
        var previous_node_name: []const u8 = undefined;
        for (self.accessor_chain, 0..) |member, i| {
            if (i == 0) {
                const root: Result = try member.expr().evaluate(symbol_table);
                current_symbol = try root.expectType(Symbol);
                previous_node_name = member.getName();
                continue;
            }

            std.debug.assert(i > 0);
            switch(current_symbol) {
                Symbol.complex_object => |o| {
                    if (i < self.accessor_chain.len - 1) {
                        current_symbol = o.getSymbol(member.name) orelse {
                            std.log.err("Member '{s}' was not found on {s}.", .{ member.name, previous_node_name });
                            return Error.UndefinedIdentifier;
                        };
                    } else {
                        return .{ .identifier = o.* };
                    }
                },
                Symbol.function => |_| {
                    if (i < self.accessor_chain.len - 1) {
                        // function args are stored on the member, so just evaluate
                        current_symbol = try member.expr().evaluate();
                    } else {
                        // can't return a function
                        return Error.HigherOrderFunctionsNotSupported;
                    }
                },
                Symbol.value => |x| {
                    if (i < self.accessor_chain.len - 1) {
                        return Error.PrematureAccessorTerminus;
                    }
                    return x.*;
                }
            }
        }
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *AccessorExpression = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn deinit(self: *AccessorExpression) void {
        for (self.accessor_chain) |link| {
            switch (link) {
                inline else => |x| x.deinit()
            }
        }
        self.allocator.free(self.accessor_chain);
        self.allocator.destroy(self);
    }

    pub fn expr(self: *AccessorExpression) Expression {
        return .{
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }
};

pub const WhenExpression = struct {
    condition: Expression,
    allocator: Allocator,

    pub fn new(allocator: Allocator, condition: Expression) Allocator.Error!*WhenExpression {
        const ptr: *WhenExpression = try allocator.create(WhenExpression);
        ptr.* = .{
            .condition = condition,
            .allocator = allocator,
        };
        return ptr;
    }

    fn implEvaluate(impl: *anyopaque, symbol_table: *SymbolTable) Error!Result {
        const self: *WhenExpression = @ptrCast(@alignCast(impl));

        const condition_eval: Result = try self.condition.evaluate(symbol_table);
        const condition: bool = try condition_eval.expectType(bool);

        return .{ .boolean = condition };
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *WhenExpression = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn deinit(self: *WhenExpression) void {
        self.condition.deinit();
        self.allocator.destroy(self);
    }

    pub fn expr(self: *WhenExpression) Expression {
        return .{
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }
};
