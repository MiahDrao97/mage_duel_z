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

    pub fn new(allocator: Allocator, name: Token, args: []Expression) !*FunctionCall {
        try name.expectMatches(@tagName(Token.identifier));
        const ptr: *FunctionCall = try allocator.create(FunctionCall);
        errdefer allocator.destroy(ptr);

        ptr.* = .{
            .name = try name.clone(),
            .args = args,
            .allocator = allocator
        };
        return ptr;
    }

    pub fn deinit(self: *FunctionCall) void {
        self.name.deinit();
        Expression.deinitAllAndFree(self.allocator, self.args);
        self.allocator.destroy(self);
    }

    fn implExecute(impl: *anyopaque, symbol_table: *SymbolTable) !void {
        const self: *FunctionCall = @ptrCast(@alignCast(impl));
        const func_symbol: Symbol = symbol_table.getSymbol(self.name.toString().?)
            orelse return error.FunctionDefinitionNotFound;

        const function_def: FunctionDef = func_symbol.unwrapFunction() catch {
            return error.UnexpectedSymbol;
        };

        const args_list: []Result = try symbol_table.allocator.alloc(Result, self.args.len);
        defer symbol_table.allocator.free(args_list);
        
        for (self.args, 0..) |arg, i| {
            args_list[i] = try arg.evaluate(symbol_table);
        }

        const member_ptr: ?*anyopaque = symbol_table.current_scope.obj_ptr;
        _ = try function_def(member_ptr, args_list);
    }

    fn implEvaluate(impl: *anyopaque, symbol_table: *SymbolTable) Error!Result {
        const self: *FunctionCall = @ptrCast(@alignCast(impl));
        const function_sym: Symbol = symbol_table.getSymbol(self.name)
            orelse return error.FunctionDefinitionNotFound;

        const function_def: FunctionDef = function_sym.unwrapFunction() catch {
            return error.FunctionDefinitionNotFound;
        };

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

    fn implDeinit(impl: *anyopaque) void {
        const self: *FunctionCall = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn expr(self: *FunctionCall) Expression {
        return .{
            .ptr = self,
            .evaluate_fn = &implEvaluate,
            .deinit_fn = &implDeinit
        };
    }

    pub fn stmt(self: *FunctionCall) Statement {
        return .{
            .ptr = self,
            .execute_fn = &implExecute,
            .deinit_fn = &implDeinit,
        };
    }
};

pub const DamageStatement = struct {
    damage_transaction_expr: Expression,
    target_expr: Expression,
    allocator: Allocator,

    pub fn new(
        allocator: Allocator,
        damage_transaction_expr: Expression,
        target_expr: Expression
    ) Allocator.Error!*DamageStatement {
        const ptr: *DamageStatement = try allocator.create(DamageStatement);
        ptr.* = .{
            .damage_transaction_expr = damage_transaction_expr,
            .target_expr = target_expr,
            .allocator = allocator
        };
        return ptr;
    }

    fn implExecute(impl: *anyopaque, symbol_table: *SymbolTable) !void {
        const self: *DamageStatement = @ptrCast(@alignCast(impl));

        const damage_transaction_eval: Result = try self.damage_transaction_expr.evaluate(symbol_table);
        _ = try damage_transaction_eval.expectType(DamageTransaction);

        const target_eval: Result = try self.target_expr.evaluate(symbol_table);
        const target: Symbol = try target_eval.expectType(Symbol);

        switch (target) {
            .complex_object => |o| {
                if (o.getSymbol("takeDamage")) |take_damage_symb| {
                    switch (take_damage_symb) {
                        .function => |f| {
                            var args: [1]Result = [_]Result { damage_transaction_eval };
                            // should be a void function 
                            _ = try f(o.obj_ptr, &args);
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

    fn implDeinit(impl: *anyopaque) void {
        const self: *DamageStatement = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn deinit(self: *DamageStatement) void {
        self.damage_transaction_expr.deinit();
        self.target_expr.deinit();
        self.allocator.destroy(self);
    }

    pub fn stmt(self: *DamageStatement) Statement {
        return .{
            .ptr = self,
            .execute_fn = &implExecute,
            .deinit_fn = &implDeinit
        };
    }
};

pub const IfStatement = struct {
    condition: Expression,
    true_statements: []Statement,
    else_statements: []Statement,
    allocator: Allocator,

    pub fn new(
        allocator: Allocator,
        condition: Expression,
        true_statements: []Statement,
        else_statements: []Statement
    ) Allocator.Error!*IfStatement {
        const ptr: *IfStatement = try allocator.create(IfStatement);
        ptr.* = .{
            .condition = condition,
            .true_statements = true_statements,
            .else_statements = else_statements,
            .allocator = allocator
        };
        return ptr;
    }

    pub fn deinit(self: *IfStatement) void {
        self.condition.deinit();
        Statement.deinitAllAndFree(self.allocator, self.true_statements);
        Statement.deinitAllAndFree(self.allocator, self.else_statements);
        self.allocator.destroy(self);
    }

    fn implExecute(impl: *anyopaque, symbol_table: *SymbolTable) !void {
        const self: *IfStatement = @ptrCast(@alignCast(impl));

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

    fn implDeinit(impl: *anyopaque) void {
        const self: *IfStatement = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn stmt(self: *IfStatement) Statement {
        return .{
            .ptr = self,
            .execute_fn = &implExecute,
            .deinit_fn = &implDeinit
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
    ) !*ForLoop {
        try identifier.expectMatches(@tagName(Token.identifier));
        const ptr: *ForLoop = try allocator.create(ForLoop);
        errdefer allocator.destroy(ptr);

        ptr.* = .{
            .identifier = try identifier.clone(),
            .range = range,
            .statements = statements,
            .allocator = allocator
        };
        return ptr;
    }

    pub fn deinit(self: *ForLoop) void {
        self.identifier.deinit();
        self.range.deinit();
        Statement.deinitAllAndFree(self.allocator, self.statements);
        self.allocator.destroy(self);
    }

    fn implExecute(impl: *anyopaque, symbol_table: *SymbolTable) !void {
        const self: *ForLoop = @ptrCast(@alignCast(impl));
        
        const range_eval: Result = try self.range.evaluate(symbol_table);
        switch (range_eval) {
            .list => |list| {
                try self.executeList(list.items, symbol_table);
            },
            .integer => |i| {
                if (i.value < 0) {
                    return error.RangeCannotBeNegative;
                }
                try self.executeRange(i.value, symbol_table);
            },
            else => return error.InvalidRangeExpression
        }
    }

    fn executeList(self: ForLoop, items: []Result, symbol_table: *SymbolTable) !void {
        for (items) |item| {
            try symbol_table.newScope();
            defer symbol_table.endScope();

            try symbol_table.putValue(self.identifier.toString().?, item);
            for (self.statements) |inner_stmt| {
                try inner_stmt.execute(symbol_table);
            }
        }
    }

    fn executeRange(self: ForLoop, range: i32, symbol_table: *SymbolTable) !void {
        std.debug.assert(range >= 0);

        for (0..@intCast(range)) |i| {
            try symbol_table.newScope();
            defer symbol_table.endScope();

            try symbol_table.putValue(self.identifier.toString().?, Result{
                .integer = .{
                    .value = @intCast(i)
                }
            });
            for (self.statements) |inner_stmt| {
                try inner_stmt.execute(symbol_table);
            }
        }
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *ForLoop = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn stmt(self: *ForLoop) Statement {
        return .{
            .ptr = self,
            .execute_fn = &implExecute,
            .deinit_fn = &implDeinit
        };
    }
};

pub const ActionDefinitionStatement = struct {
    pub const ActionCostExpr = union(enum) {
        flat: *IntegerLiteral,
        dynamic: *TargetExpression,

        pub fn deinit(self: ActionCostExpr) void {
            switch (self) {
                inline else => |x| x.deinit()
            }
        }
    };

    action_cost: ActionCostExpr,
    condition: ?*WhenExpression,
    statements: []Statement,
    allocator: Allocator,

    /// Init's a new instance of `ActionDefinitionStatement`.
    /// `statements` is presumably allocated by `allocator`.
    /// That memory is owned by this structure.
    pub fn new(
        allocator: Allocator,
        statements: []Statement,
        action_cost: ActionCostExpr,
        condition: ?*WhenExpression
    ) Allocator.Error!*ActionDefinitionStatement {
        const ptr: *ActionDefinitionStatement = try allocator.create(ActionDefinitionStatement);
        ptr.* = .{
            .action_cost = action_cost,
            .condition = condition,
            .statements = statements,
            .allocator = allocator
        };
        return ptr;
    }

    pub fn deinit(self: *const ActionDefinitionStatement) void {
        Statement.deinitAllAndFree(self.allocator, self.statements);
        self.action_cost.deinit();
        self.allocator.destroy(self);
    }

    fn implExecute(impl: *anyopaque, symbol_table: *SymbolTable) !void {
        const self: *ActionDefinitionStatement = @ptrCast(@alignCast(impl));
        // operating under the guise that the action cost has been paid
        for (self.statements) |inner_stmt| {
            try inner_stmt.execute(symbol_table);
        }
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *ActionDefinitionStatement = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn evaluateCondition(self: ActionDefinitionStatement, symbol_table: *SymbolTable) Error!Result {
        if (self.condition) |condition| {
            return try condition.expr().evaluate(symbol_table);
        }
        return .{ .boolean = true };
    }

    pub fn evaluateActionCost(self: ActionDefinitionStatement, symbol_table: *SymbolTable) Error!Result {
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
            .execute_fn = &implExecute,
            .deinit_fn = &implDeinit
        };
    }
};

pub const AssignmentStatement = struct {
    identifier: Token,
    value: Expression,
    allocator: Allocator,

    /// Init's a new instance of `AssignmentStatement`.
    /// `identifier` was presumably allocated by `allocator`.
    /// This structure owns that memory.
    pub fn new(
        allocator: Allocator,
        identifier: Token,
        value: Expression
    ) !*AssignmentStatement {
        try identifier.expectMatches(@tagName(Token.identifier));
        const ptr: *AssignmentStatement = try allocator.create(AssignmentStatement);
        errdefer allocator.destroy(ptr);

        ptr.* = .{
            .identifier = try identifier.clone(),
            .value = value,
            .allocator = allocator
        };
        return ptr;
    }

    pub fn deinit(self: *AssignmentStatement) void {
        self.identifier.deinit();
        self.value.deinit();
        self.allocator.destroy(self);
    }

    fn implExecute(impl: *anyopaque, symbol_table: *SymbolTable) !void {
        const self: *AssignmentStatement = @ptrCast(@alignCast(impl));

        const evaluated = try self.value.evaluate(symbol_table);
        try symbol_table.putValue(self.identifier.toString().?, evaluated);
    }

    fn implDeinit(impl: *anyopaque) void {
        const self: *AssignmentStatement = @ptrCast(@alignCast(impl));
        self.deinit();
    }

    pub fn stmt(self: *AssignmentStatement) Statement {
        return .{
            .ptr = self,
            .execute_fn = &implExecute,
            .deinit_fn = &implDeinit
        };
    }
};

// for now, skipping function defs
