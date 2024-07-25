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

    fn evaluate(this_ptr: *anyopaque, _: SymbolTable) Error!Result {
        const self: *IntegerLiteral = @ptrCast(@alignCast(this_ptr));
        return .{ .integer = self.val };
    }

    pub fn expr(self: *IntegerLiteral) Expression {
        return .{
            .ptr = self,
            .evaluateFn = &evaluate
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

    fn evaluate(this_ptr: *anyopaque, _: SymbolTable) Error!Result {
        const self: *BooleanLiteral = @ptrCast(@alignCast(this_ptr));
        return .{ .boolean = self.val };
    }

    pub fn expr(self: *BooleanLiteral) Expression {
        return .{
            .ptr = self,
            .evaluateFn = &evaluate
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

    fn evaluate(this_ptr: *anyopaque, _: SymbolTable) Error!Result {
        const self: *DamageTypeLiteral = @ptrCast(@alignCast(this_ptr));
        return .{ .damage_type = self.val };
    }

    pub fn expr(self: *DamageTypeLiteral) Expression {
        return .{
            .ptr = self,
            .evaluateFn = &evaluate
        };
    }
};

pub const DiceLiteral = struct {
    count: u16 = 1,
    val: Dice,

    pub fn from(iter: TokenIterator) ParseError!DiceLiteral {
        if (iter.next()) |token| {
            if (token.getDiceValue()) |d| {
                return .{ .val = d };
            } else if (token.getNumericValue()) |n| {
                // case with multiple dice, like 2d4
                if (iter.next()) |next_token| {
                    if (next_token.getDiceValue()) |d| {
                        return .{ .count = n, .val = d };
                    }
                    return ParseError.UnexpectedToken;
                }
                return ParseError.EOF;
            }
            return ParseError.UnexpectedToken;
        }
        return ParseError.EOF;
    }

    fn evaluate(this_ptr: *anyopaque, _: SymbolTable) Error!Result {
        const self: *DiceLiteral = @ptrCast(@alignCast(this_ptr));
        return .{
            .dice = .{
                .count = self.count,
                .dice = self.val
            }
        };
    }

    pub fn expr(self: *DiceLiteral) Expression {
        return .{
            .ptr = self,
            .evaluateFn = &evaluate
        };
    }
};

pub const DamageExpression = struct {
    amount_expr: Expression,
    damage_type_expr: Expression,

    fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Error!Result {
        const self: *DamageExpression = @ptrCast(@alignCast(this_ptr));

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

    pub fn expr(self: *DamageExpression) Expression {
        return .{
            .ptr = self,
            .evaluateFn = &evaluate
        };
    }
};

/// No `from` function is defined because this literal holds a slice of expressions,
/// and we can't parse other expressions in this scope.
pub const ListLiteral = struct {
    vals: []Expression,

    fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Error!Result {
        const self: *ListLiteral = @ptrCast(@alignCast(this_ptr));
        const evaluated: []Result = try symbol_table.allocator.alloc(Result);

        // since we require the allocator here, we're gonna assume each item needs one too
        for (0..self.vals.len) |i| {
            evaluated[i] = try self.vals[i].evaluate(symbol_table);
        }

        return .{ .list = try ListResult.from(symbol_table.allocator, evaluated) };
    }

    pub fn expr(self: *ListLiteral) Expression {
        return Expression {
            .ptr = self,
            .evaluateFn = &evaluate
        };
    }
};

pub const LabelLiteral = struct {
    label: Label,

    pub fn from(iter: TokenIterator) ParseError!LabelLiteral {
        _ = try iter.require("#");
        const label_token: Token = try iter.requireType(&[_][]const u8 { @tagName(Token.identifier) });
        var label: Label = undefined;

        if (iter.peek()) |next_tok| {
            // #accuracy = 2
            // #rank = s
            if (next_tok.symbolEquals("=")) {
                // consume because we already have the next token
                _ = iter.next();
                next_tok = try iter.requireType(&[_][]const u8 { @tagName(Token.identifier), @tagName(Token.numeric) });
                label = try Label.from(label_token.toString().?, next_tok.toString());
                return .{ .label = label };
            }
        }

        label = try Label.from(label_token.toString().?, null);
        return .{ .label = label };
    }

    fn evaluate(this_ptr: *anyopaque, _: SymbolTable) Error!Result {
        const self: *LabelLiteral = @ptrCast(@alignCast(this_ptr));
        return .{ .label = self.label };
    }

    pub fn expr(self: *LabelLiteral) Expression {
        return Expression {
            .ptr = self,
            .evaluateFn = &evaluate
        };
    }
};

pub const Identifier = struct {
    name: []const u8,
    allocator: Allocator,

    pub fn from(allocator: Allocator, iter: TokenIterator) ParseError!Identifier {
        const identifier_token: Token = try iter.requireType(&[_][]const u8 { @tagName(Token.identifier) });
        const str: []const u8 = identifier_token.toString().?;

        var name_cpy: []u8 = try allocator.alloc(u8, str.len);
        _ = &name_cpy;
        @memcpy(name_cpy, str);

        return .{
            .name = name_cpy,
            .allocator = allocator
        };
    }

    fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Error!Result {
        const self: *Identifier = @ptrCast(@alignCast(this_ptr));

        if (symbol_table.getSymbol(self.name)) |value| {
            return .{ .identifier = value };
        }
        return Error.UndefinedIdentifier;
    }

    fn deinitFn(this_ptr: *anyopaque) void {
        var self: *Identifier = @ptrCast(@alignCast(this_ptr));
        self.deinit();
    }

    pub fn deinit(self: *Identifier) void {
        self.allocator.free(self.name);
        self.* = undefined;
    }

    pub fn expr(self: *Identifier) Expression {
        return Expression {
            .ptr = self,
            .evaluateFn = &evaluate,
            .deinitFn = &deinitFn
        };
    }
};

pub const ParensthesizedExpression = struct {
    inner: Expression,

    fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Error!Result {
        const self: *ParensthesizedExpression = @ptrCast(@alignCast(this_ptr));
        return self.inner.evaluate(symbol_table);
    }

    pub fn expr(self: *ParensthesizedExpression) Expression {
        return Expression {
            .ptr = self,
            .evaluateFn = &evaluate
        };
    }
};

pub const UnaryExpression = struct {
    rhs: Expression,
    op: Token,

    fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Error!Result {
        const self: *UnaryExpression = @ptrCast(@alignCast(this_ptr));

        const rh_result: Result = try self.rhs.evaluate(symbol_table);
        switch (rh_result) {
            Result.boolean => |x| {
                if (self.op.expectSymbolEquals("~")) {
                    return !x;
                } else |err| {
                    return err;
                }
                return Error.OperandTypeNotSupported;
            },
            Result.integer => |x| {
                if (self.op.expectSymbolEquals("-")) {
                    return -x;
                } else |err| {
                    return err;
                }
                return Error.OperandTypeNotSupported;
            },
            else => return Error.OperandTypeNotSupported
        }
    }

    pub fn expr(self: *UnaryExpression) Expression {
        return Expression {
            .ptr = self,
            .evaluateFn = &evaluate
        };
    }
};

pub const AdditiveExpression = struct {
    lhs: Expression,
    rhs: Expression,
    op: Token,

    fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Error!Result {
        const self: *AdditiveExpression = @ptrCast(@alignCast(this_ptr));

        const lh_result: Result = try self.lhs.evaluate(symbol_table);
        const rh_result: Result = try self.rhs.evaluate(symbol_table);

        switch (lh_result) {
            Result.integer => |lh_int| {
                // rhs can only be an integer in this case
                const rh_int: i32 = try rh_result.expectType(i32) catch { return Error.OperandTypeMismatch; };
                try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "+", "-" });
                if (self.op.stringEquals("+")) {
                    return .{ .integer = lh_int + rh_int };
                }
                else {
                    return .{ .integer = lh_int - rh_int };
                }
            },
            Result.list => |lh_list| {
                try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "+", "-", "+!" });
                if (rh_result.isList()) |rh_list| {
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
            Result.dice => |*lh_dice| {
                try self.op.expectStringEqualsOneOf(&[_][]const u8 { "+", "-" });
                const rh_int: i32 = try rh_result.expectType(i32);

                lh_dice.*.modifier += rh_int;
                return .{ .dice = lh_dice };
            },
            else => return Error.OperandTypeNotSupported
        }
    }

    pub fn expr(self: *AdditiveExpression) Expression {
        return Expression {
            .ptr = self,
            .evaluateFn = &evaluate
        };
    }
};

pub const FactorExpression = struct {
    lhs: Expression,
    rhs: Expression,
    op: Token,

    fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Error!Result {
        const self: *FactorExpression = @ptrCast(@alignCast(this_ptr));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "*", "/" });

        const lh_result: Result = try self.lhs.evaluate(symbol_table);
        const rh_result: Result = try self.rhs.evaluate(symbol_table);

        const lh_int: i32 = try lh_result.expectType(i32) catch { return Error.OperandTypeNotSupported; };
        const rh_int: i32 = try rh_result.expectType(i32) catch { return Error.OperandTypeNotSupported; };

        if (self.op.stringEquals("*")) {
            return .{ .integer = lh_int * rh_int };
        } else {
            return .{ .integer = lh_int / rh_int };
        }
    }

    pub fn expr(self: *FactorExpression) Expression {
        return .{
            .ptr = self,
            .evaluateFn = &evaluate
        };
    }
};

pub const ComparisonExpression = struct {
    lhs: Expression,
    rhs: Expression,
    op: Token,

    fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Error!Result {
        const self: *ComparisonExpression = @ptrCast(@alignCast(this_ptr));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "<", "<=", ">=", ">" });

        const lh_result: Result = try self.lhs.evaluate(symbol_table);
        const rh_result: Result = try self.rhs.evaluate(symbol_table);

        const lh_int: i32 = try lh_result.expectType(i32) catch { return Error.OperandTypeNotSupported; };
        const rh_int: i32 = try rh_result.expectType(i32) catch { return Error.OperandTypeNotSupported; };

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

    pub fn expr(self: *ComparisonExpression) Expression {
        return .{
            .ptr = self,
            .evaluateFn = &evaluate,
        };
    }
};

pub const EqualityExpression = struct {
    lhs: Expression,
    rhs: Expression,
    op: Token,

    fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Error!Result {
        const self: *EqualityExpression = @ptrCast(@alignCast(this_ptr));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "==", "~=" });

        const lh_result: Result = try self.lhs.evaluate(symbol_table);
        const rh_result: Result = try self.rhs.evaluate(symbol_table);

        switch (lh_result) {
            Result.integer => |lh_int| {
                const rh_int: i32 = try rh_result.expectType(i32) catch { return Error.OperandTypeNotSupported; };
                if (self.op.stringEquals("==")) {
                    return .{ .boolean = lh_int == rh_int };
                } else {
                    return .{ .boolean = lh_int != rh_int };
                }
            },
            Result.boolean => |lh_bool| {
                const rh_bool: bool = try rh_result.expectType(bool) catch { return Error.OperandTypeNotSupported; };
                if (self.op.stringEquals("==")) {
                    return .{ .boolean = lh_bool == rh_bool };
                } else {
                    return .{ .boolean = lh_bool != rh_bool };
                }
            },
            else => return Error.OperandTypeNotSupported
        }
    }

    pub fn expr(self: *EqualityExpression) Expression {
        return .{
            .ptr = self,
            .evaluateFn = &evaluate
        };
    }
};

pub const BooleanExpression = struct {
    lhs: Expression,
    rhs: Expression,
    op: Token,

    fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Error!Result {
        const self: *BooleanExpression = @ptrCast(@alignCast(this_ptr));

        try self.op.expectSymbolEqualsOneOf(&[_][]const u8 { "+", "|", "^" });

        const lh_result: Result = try self.lhs.evaluate(symbol_table);
        const rh_result: Result = try self.rhs.evaluate(symbol_table);

        const lh_bool: bool = try lh_result.expectType(bool) catch { return Error.OperandTypeNotSupported; };
        const rh_bool: bool = try rh_result.expectType(bool) catch { return Error.OperandTypeNotSupported; };
        if (self.op.stringEquals("+")) {
            return .{ .boolean = lh_bool and rh_bool };
        } else if (self.op.stringEquals("|")) {
            return .{ .boolean = lh_bool or rh_bool };
        } else {
            return .{ .boolean = (!lh_bool and rh_bool) or (lh_bool and !rh_bool) };
        }
    }

    pub fn expr(self: *BooleanExpression) Expression {
        return .{
            .ptr = self,
            .evaluateFn = &evaluate
        };
    }
};

/// Ex.
/// `target(1 in from Monster)`
pub const TargetExpression = struct {
    amount: Expression,
    pool: Expression,

    fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Error!Result {
        const self: *TargetExpression = @ptrCast(@alignCast(this_ptr));

        const eval_amount: Result = try self.amount.evaluate(symbol_table);
        const eval_pool: Result = try self.pool.evaluate(symbol_table);

        const eval_int: i32 = try eval_amount.expectType(i32);
        if (eval_int < 1) {
            return Error.MustBeGreaterThanZero;
        }

        const eval_list: ListResult = try eval_pool.expectType(ListResult);
        // TODO: determine if up-to operator was used (^)
        if (symbol_table.getPlayerChoice(@bitCast(eval_int), eval_list.items, false)) |choice| {
            return choice;
        } else |err| {
            switch (err) {
                error.NotImplemented => std.builtin.panic("This is not yet implemented"),
                else => return err
            }
        }
    }

    pub fn expr(self: *TargetExpression) Expression {
        return Expression {
            .ptr = self,
            .evaluateFn = &evaluate
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
    
    fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Error!Result {
        const self: *AccessorExpression = @ptrCast(@alignCast(this_ptr));

        // we need at least one '.' for this to be a full accessor chain
        if (self.accessor_chain < 2) {
            return Error.InvalidAccessorChain;
        }

        var current_symbol: Symbol = undefined;
        var previous_node_name: []const u8 = undefined;
        for (self.accessor_chain, 0..) |member, i| {
            if (i == 0) {
                const root: Result = try member.expr().evaluate(symbol_table);
                current_symbol = root.expectType(Symbol);
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

    fn deinitFn(this_ptr: *anyopaque) void {
        var self: *AccessorExpression = @ptrCast(@alignCast(this_ptr));
        self.deinit();
    }

    pub fn deinit(self: *AccessorExpression) void {
        for (self.accessor_chain) |link| {
            switch (link) {
                inline else => |x| x.deinit()
            }
        }
        self.* = undefined;
    }

    pub fn expr(self: *AccessorExpression) Expression {
        return .{
            .ptr = self,
            .evaluateFn = &evaluate
        };
    }
};

pub const WhenExpression = struct {
    condition: Expression,

    fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Error!Result {
        const self: *WhenExpression = @ptrCast(@alignCast(this_ptr));

        const condition_eval: Result = try self.condition.evaluate(symbol_table);
        const condition: bool = try condition_eval.expectType(bool);

        return .{ .boolean = condition };
    }

    pub fn expr(self: *WhenExpression) Expression {
        return .{
            .ptr = self,
            .evaluateFn = &evaluate
        };
    }
};
