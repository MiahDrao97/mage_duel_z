const std = @import("std");

const imports = struct {
    usingnamespace @import("util");
    usingnamespace @import("game_zones");
    usingnamespace @import("expression.zig");
    usingnamespace @import("concrete_expressions.zig");
    usingnamespace @import("Statement.zig");
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
const Dice = imports.types.Dice;
const IntegerLiteral = imports.IntegerLiteral;
const TargetExpression = imports.TargetExpression;

pub const FunctionCall = struct {
    name: []const u8,
    args: []Expression,

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

    pub fn expr(self: *FunctionCall) Expression {
        return .{
            .ptr = self,
            .evaluateFn = &evaluate
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
    amount_expr: Expression,
    damage_type_expr: Expression,
    target_expr: Expression,

    fn execute(this_ptr: *anyopaque, symbol_table: SymbolTable) !void {
        const self: *DamageStatement = @ptrCast(@alignCast(this_ptr));

        const amount_eval: Result = try self.amount_expr.evaluate(symbol_table);
        _ = try amount_eval.expectType(DiceResult);

        const damage_type_eval: Result = try self.damage_type_expr.evaluate(symbol_table);
        _ = try damage_type_eval.expectType(DamageType);

        const target_eval: Result = try self.target_expr.evaluate(symbol_table);
        const target: Symbol = try target_eval.expectType(Symbol);

        switch (target) {
            Symbol.complex_object => |o| {
                if (o.getSymbol("takeDamage")) |take_damage_symb| {
                    switch (take_damage_symb) {
                        Symbol.function => |f| {
                            // should be a void function
                            _ = try f(&[_] Result { amount_eval, damage_type_eval });
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

    pub fn stmt(self: *DamageStatement) Statement {
        return .{
            .ptr = self,
            .executeFn = &execute
        };
    }
};

pub const IfStatement = struct {
    condition: Expression,
    true_statements: []Statement,
    else_statements: []Statement,

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

    pub fn stmt(self: *IfStatement) Statement {
        return .{
            .ptr = self,
            .executeFn = &execute
        };
    }
};

pub const ForLoop = struct {
    identifier: []const u8,
    range: Expression,
    statements: []Statement,

    fn execute(this_ptr: *anyopaque, symbol_table: SymbolTable) !void {
        const self: *ForLoop = @ptrCast(@alignCast(this_ptr));
        
        const range_eval: Result = try self.range.evaluate(symbol_table);
        switch (range_eval) {
            Result.list => |list| {
                try self.executeList(list.items, symbol_table);
            },
            Result.integer => |i| {
                if (i < 0) {
                    return error.RangeCannotBeNegative;
                }
                try self.executeRange(i, symbol_table);
            },
            else => return error.InvalidRangeExpression
        }
    }

    fn executeList(self: ForLoop, items: []Result, symbol_table: SymbolTable) !void {
        for (items) |*item| {
            try symbol_table.newScope();
            defer symbol_table.endScope();

            try symbol_table.putSymbol(self.identifier, .{ .value = item });
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

            try symbol_table.putSymbol(self.identifier, .{
                .value = &Result {
                    .integer = i
                }
            });
            for (self.statements) |inner_stmt| {
                try inner_stmt.execute(symbol_table);
            }
        }
    }

    pub fn stmt(self: *ForLoop) Statement {
        return .{
            .ptr = self,
            .executeFn = &execute
        };
    }
};

pub const ActionDefinitionStatement = struct {
    pub const ActionCostExpr = union(enum) {
        flat: IntegerLiteral,
        dynamic: TargetExpression
    };

    action_cost: ActionCostExpr,
    statements: []Statement,

    fn execute(this_ptr: *anyopaque, symbol_table: SymbolTable) !void {
        const self: *ActionDefinitionStatement = @ptrCast(@alignCast(this_ptr));

        // operating under the guise that the action cost has been paid
        for (self.statements) |inner_stmt| {
            try inner_stmt.execute(symbol_table);
        }
    }

    pub fn evaluateActionCost(self: ActionDefinitionStatement, symbol_table: SymbolTable) Error!Result {
        switch (self.action_cost) {
            inline else => |x| return try x.evaluate(symbol_table)
        }
    }

    pub fn stmt(self: *ActionDefinitionStatement) Statement {
        return .{
            .ptr = self,
            .executeFn = &execute
        };
    }
};

// for now, skipping function defs
