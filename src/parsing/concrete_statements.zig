const std = @import("std");

const imports = struct {
    usingnamespace @import("util");
    usingnamespace @import("game_zones");
    usingnamespace @import("expression.zig");
    usingnamespace @import("concrete_expressions.zig");
    usingnamespace @import("Statement.zig");
    usingnamespace @import("tokens.zig");
};

const Statement = imports.Statement;
const Expression = imports.Expression;
const SymbolTable = imports.SymbolTable;
const Symbol = imports.Symbol;
const Result = imports.Result;
const Error = imports.Error;
const FunctionDef = imports.FunctionDef;
const DiceResult = imports.DiceResult;
const DamageType = imports.types.DamageType;
const DamageTransaction = imports.types.DamageTransaction;
const Dice = imports.types.Dice;
const IntegerLiteral = imports.IntegerLiteral;
const TargetExpression = imports.TargetExpression;
const WhenExpression = imports.WhenExpression;
const Allocator = std.mem.Allocator;
const Token = imports.Token;

pub const FunctionCall = struct {
    name: Token,
    args: []Expression,
    allocator: Allocator,

    pub fn new(allocator: Allocator, name: Token, args: []Expression) !FunctionCall {
        try name.expectMatches(@tagName(Token.identifier));
        return .{
            .name = try name.clone(),
            .args = args,
            .allocator = allocator
        };
    }

    pub fn deinit(self: *FunctionCall) void {
        self.name.deinit();
        Expression.deinitAll(self.args);
        self.allocator.free(self.args);
        self.* = undefined;
    }

    fn execute(this_ptr: *anyopaque, symbol_table: SymbolTable) !void {
        const self: *FunctionCall = @ptrCast(@alignCast(this_ptr));
        const function_def: FunctionDef = symbol_table.getSymbol(self.name) orelse return error.FunctionDefinitionNotFound;

        const args_list: []Result = symbol_table.allocator.alloc(Result, self.args.len);
        defer symbol_table.allocator.free(args_list);
        
        for (self.args, 0..) |arg, i| {
            args_list[i] = try arg.evaluate(symbol_table);
        }

        _ = try function_def(args_list);
    }

    fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Error!Result {
        const self: *FunctionCall = @ptrCast(@alignCast(this_ptr));
        const function_def: FunctionDef = symbol_table.getSymbol(self.name) orelse return error.FunctionDefinitionNotFound;

        const args_list: []Result = symbol_table.allocator.alloc(Result, self.args.len);
        defer symbol_table.allocator.free(args_list);
        
        for (self.args, 0..) |arg, i| {
            args_list[i] = try arg.evaluate(symbol_table);
        }

        return function_def(args_list) catch |err| {
            std.log.err("Caught error while executing '{s}(...)': {any}-->\n{any}", .{
                self.name,
                err,
                @errorReturnTrace().?
            });
            return Error.FunctionInvocationFailed;
        };
    }

    fn deinitFn(this_ptr: *anyopaque) void {
        const self: *FunctionCall = @ptrCast(@alignCast(this_ptr));
        self.deinit();
    }

    pub fn expr(self: *FunctionCall) Expression {
        return .{
            .ptr = self,
            .evaluateFn = &evaluate,
            .deinitFn = &deinitFn
        };
    }

    pub fn stmt(self: *FunctionCall) Statement {
        return .{
            .ptr = self,
            .executeFn = &execute
        };
    }
};

pub const DamageStatement = struct {
    damage_transaction_expr: Expression,
    target_expr: Expression,

    fn execute(this_ptr: *anyopaque, symbol_table: SymbolTable) !void {
        const self: *DamageStatement = @ptrCast(@alignCast(this_ptr));

        const damage_transaction_eval: Result = try self.damage_transaction_expr.evaluate(symbol_table);
        _ = try damage_transaction_eval.expectType(DamageTransaction);

        const target_eval: Result = try self.target_expr.evaluate(symbol_table);
        const target: Symbol = try target_eval.expectType(Symbol);

        switch (target) {
            Symbol.complex_object => |o| {
                if (o.getSymbol("takeDamage")) |take_damage_symb| {
                    switch (take_damage_symb) {
                        Symbol.function => |f| {
                            // should be a void function
                            _ = try f(&[_] Result { damage_transaction_eval });
                        },
                        else => return error.FunctionNotFound
                    }
                } else {
                    return error.FunctionNotFound;
                }
            },
            else => return error.InvalidTarget
        }
    }

    fn deinitFn(this_ptr: *anyopaque) void {
        const self: *DamageStatement = @ptrCast(@alignCast(this_ptr));
        self.deinit();
    }

    pub fn deinit(self: *DamageStatement) void {
        self.damage_transaction_expr.deinit();
        self.target_expr.deinit();
        self.* = undefined;
    }

    pub fn stmt(self: *DamageStatement) Statement {
        return .{
            .ptr = self,
            .executeFn = &execute,
            .deinitFn = &deinitFn
        };
    }
};

pub const IfStatement = struct {
    condition: Expression,
    true_statements: []Statement,
    else_statements: []Statement,
    allocator: Allocator,

    pub fn init(
        allocator: Allocator,
        condition: Expression,
        true_statements: []Statement,
        else_statements: []Statement
    ) IfStatement {
        return .{
            .condition = condition,
            .true_statements = true_statements,
            .else_statements = else_statements,
            .allocator = allocator
        };
    }

    pub fn deinit(self: *IfStatement) void {
        self.condition.deinit();
        Statement.deinitAll(self.true_statements);
        Statement.deinitAll(self.else_statements);
        self.allocator.free(self.true_statements);
        self.allocator.free(self.else_statements);

        self.* = undefined;
    }

    fn execute(this_ptr: *anyopaque, symbol_table: SymbolTable) !void {
        const self: *IfStatement = @ptrCast(@alignCast(this_ptr));

        const condition_eval: Result = try self.condition.evaluate(symbol_table);
        const condition: bool = try condition_eval.expectType(bool);

        if (condition) {
            for (self.true_statements) |true_stmt| {
                try symbol_table.newScope();
                defer symbol_table.endScope();

                try true_stmt.execute(symbol_table);
            }
        } else {
            for (self.else_statements) |else_stmt| {
                try symbol_table.newScope();
                defer symbol_table.endScope();

                try else_stmt.execute(symbol_table);
            }
        }
    }

    fn deinitFn(this_ptr: *anyopaque) void {
        const self: *IfStatement = @ptrCast(@alignCast(this_ptr));
        self.deinit();
    }

    pub fn stmt(self: *IfStatement) Statement {
        return .{
            .ptr = self,
            .executeFn = &execute,
            .deinitFn = &deinitFn
        };
    }
};

pub const ForLoop = struct {
    identifier: Token,
    range: Expression,
    statements: []Statement,
    allocator: Allocator,

    pub fn new(
        allocator: Allocator,
        identifier: Token,
        range: Expression,
        statements: []Statement
    ) !ForLoop {
        try identifier.expectMatches(@tagName(Token.identifier));
        return .{
            .idententifier = try identifier.clone(),
            .range = range,
            .statements = statements,
            .allocator = allocator
        };
    }

    pub fn deinit(self: *ForLoop) void {
        self.identifier.deinit();
        self.range.deinit();
        Statement.deinitAll(self.statements);
        self.allocator.free(self.statements);

        self.* = undefined;
    }

    fn execute(this_ptr: *anyopaque, symbol_table: SymbolTable) !void {
        const self: *ForLoop = @ptrCast(@alignCast(this_ptr));
        
        const range_eval: Result = try self.range.evaluate(symbol_table);
        switch (range_eval) {
            Result.list => |list| {
                try self.executeList(list.items, symbol_table);
            },
            Result.integer => |i| {
                if (i.value < 0) {
                    return error.RangeCannotBeNegative;
                }
                try self.executeRange(i, symbol_table);
            },
            else => return error.InvalidRangeExpression
        }
    }

    fn executeList(self: ForLoop, items: []Result, symbol_table: SymbolTable) !void {
        for (items) |item| {
            try symbol_table.newScope();
            defer symbol_table.endScope();

            try symbol_table.putValue(self.identifier.toString().?, item);
            for (self.statements) |inner_stmt| {
                try inner_stmt.execute(symbol_table);
            }
        }
    }

    fn executeRange(self: ForLoop, range: i32, symbol_table: SymbolTable) !void {
        std.debug.assert(range >= 0);

        for (0..range) |i| {
            try symbol_table.newScope();
            defer symbol_table.endScope();

            try symbol_table.putValue(self.identifier, Result { .integer = i });
            for (self.statements) |inner_stmt| {
                try inner_stmt.execute(symbol_table);
            }
        }
    }

    fn deinitFn(this_ptr: *anyopaque) void {
        const self: *ForLoop = @ptrCast(@alignCast(this_ptr));
        self.deinit();
    }

    pub fn stmt(self: *ForLoop) Statement {
        return .{
            .ptr = self,
            .executeFn = &execute,
            .deinitFn = &deinitFn
        };
    }
};

pub const ActionDefinitionStatement = struct {
    pub const ActionCostExpr = union(enum) {
        flat: IntegerLiteral,
        dynamic: TargetExpression
    };

    action_cost: ActionCostExpr,
    condition: ?WhenExpression,
    statements: []Statement,
    allocator: Allocator,

    /// Init's a new instance of `ActionDefinitionStatement`.
    /// `statements` is presumably allocated by `allocator`.
    /// That memory is owned by this structure.
    pub fn init(
        allocator: Allocator,
        statements: []Statement,
        action_cost: ActionCostExpr,
        condition: ?WhenExpression
    ) ActionDefinitionStatement {
        return .{
            .action_cost = action_cost,
            .condition = condition,
            .statements = statements,
            .allocator = allocator
        };
    }

    pub fn deinit(self: *ActionDefinitionStatement) void {
        for (self.statements) |inner_stmt| {
            inner_stmt.deinit();
        }
        self.allocator.free(self.statements);
        self.* = undefined;
    }

    fn execute(this_ptr: *anyopaque, symbol_table: SymbolTable) !void {
        const self: *ActionDefinitionStatement = @ptrCast(@alignCast(this_ptr));
        // operating under the guise that the action cost has been paid
        for (self.statements) |inner_stmt| {
            try inner_stmt.execute(symbol_table);
        }
    }

    fn deinitFn(this_ptr: *anyopaque) void {
        const self: *ActionDefinitionStatement = @ptrCast(@alignCast(this_ptr));
        self.deinit();
    }

    pub fn evaluateCondition(self: ActionDefinitionStatement, symbol_table: SymbolTable) Error!Result {
        if (self.condition) |condition| {
            return try condition.expr().evaluate(symbol_table);
        }
        return .{ .boolean = true };
    }

    pub fn evaluateActionCost(self: ActionDefinitionStatement, symbol_table: SymbolTable) Error!Result {
        switch (self.action_cost) {
            inline else => |x| {
                const action_cost_eval: Result = try x.evaluate(symbol_table);
                const cost: i32 = try action_cost_eval.expectType(i32);

                if (cost < 0) {
                    return Error.MustBePositiveInteger;
                }
                return cost;
            }
        }
    }

    pub fn stmt(self: *ActionDefinitionStatement) Statement {
        return .{
            .ptr = self,
            .executeFn = &execute,
            .deinitFn = &deinitFn
        };
    }
};

pub const AssignmentStatement = struct {
    identifier: Token,
    value: Expression,

    /// Init's a new instance of `AssignmentStatement`.
    /// `identifier` was presumably allocated by `allocator`.
    /// This structure owns that memory.
    pub fn new(identifier: Token, value: Expression) !AssignmentStatement {
        try identifier.expectMatches(@tagName(Token.identifier));
        return .{
            .idententifier = try identifier.clone(),
            .value = value
        };
    }

    pub fn deinit(self: *AssignmentStatement) void {
        self.identifier.deinit();
        self.value.deinit();
        self.* = undefined;
    }

    fn execute(this_ptr: *anyopaque, symbol_table: SymbolTable) !void {
        const self: *AssignmentStatement = @ptrCast(@alignCast(this_ptr));

        const evaluated = try self.value.evaluate(symbol_table);
        try symbol_table.putValue(self.identifier, evaluated);
    }

    fn deinitFn(this_ptr: *anyopaque) void {
        const self: *AssignmentStatement = @ptrCast(@alignCast(this_ptr));
        self.deinit();
    }

    pub fn stmt(self: *AssignmentStatement) Statement {
        return .{
            .ptr = self,
            .executeFn = &execute,
            .deinitFn = &deinitFn
        };
    }
};

// for now, skipping function defs
