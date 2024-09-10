const std = @import("std");
const tokens = @import("tokens.zig");

const Allocator = std.mem.Allocator;

pub const Tokenizer = @import("Tokenizer.zig");
pub const Parser = @import("Parser.zig");
pub const TokenizerError = Tokenizer.TokenizerError;
pub const expression = @import("expression.zig");
pub const Expression = expression.Expression;
pub const ExpressionResult = expression.Result;
pub const DiceResult = expression.DiceResult;
pub const IntResult = expression.IntResult;
pub const ListResult = expression.ListResult;
pub const ExpressionErr = expression.Error;
pub const concrete_expressions = @import("concrete_expressions.zig");
pub const Token = tokens.Token;
pub const StringToken = tokens.StringToken;
pub const NumericToken = tokens.NumericToken;
pub const BooleanToken = tokens.BooleanToken;
pub const DamageTypeToken = tokens.DamageTypeToken;
pub const DiceToken = tokens.DiceToken;
pub const SymbolTable = expression.SymbolTable;
pub const Symbol = expression.Symbol;
pub const Scope = expression.Scope;
pub const FunctionDef = expression.FunctionDef;
pub const Statement = @import("Statement.zig");
pub const concrete_statements = @import("concrete_statements.zig");
pub const ActionDefinitionStatement = concrete_statements.ActionDefinitionStatement;
pub const Label = expression.Label;

pub const CardDef = struct {
    labels: []Label,
    actions: []const *ActionDefinitionStatement,
    allocator: Allocator,

    const Error = Allocator.Error || error{InvalidCardDef};

    pub fn new(
        allocator: Allocator,
        labels: []Label,
        actions: []const *ActionDefinitionStatement
    ) Allocator.Error!*CardDef {
        const ptr: *CardDef = try allocator.create(CardDef);
        ptr.* = .{
            .labels = labels,
            .actions = actions,
            .allocator = allocator
        };

        return ptr;
    }

    pub fn getRank(self: CardDef) ?u8 {
        for (self.labels) |label| {
            switch (label) {
                Label.rank => |r| return r,
                else => { }
            }
        }
        return null;
    }

    pub fn getAccuracy(self: CardDef) ?u8 {
        for (self.labels) |label| {
            switch (label) {
                Label.accuracy => |r| return r,
                else => { }
            }
        }
        return null;
    }

    pub fn isAttack(self: CardDef) bool {
        for (self.labels) |label| {
            switch (label) {
                Label.attack => return true,
                else => { }
            }
        }
        return false;
    }

    pub fn isMonster(self: CardDef) bool {
        for (self.labels) |label| {
            switch (label) {
                Label.monster => return true,
                else => { }
            }
        }
        return false;
    }

    pub fn isOneTimeUse(self: CardDef) bool {
        for (self.labels) |label| {
            switch (label) {
                Label.one_time_use => return true,
                else => { }
            }
        }
        return false;
    }

    pub fn deinit(self: *CardDef) void {
        for (self.actions) |action| {
            action.deinit();
        }
        self.allocator.free(self.labels);
        self.allocator.free(self.actions);
        self.allocator.destroy(self);
    }

    fn implGetActionCost(impl: ?*anyopaque, args: []ExpressionResult) !ExpressionResult {
        if (args.len != 1) {
            std.log.err("Expected 1 argument, but received {d}.", .{ args.len });
            return error.ArgumentCountMismatch;
        }

        const index: IntResult = args[0].expectType(IntResult) catch {
            std.log.err("Expected arg 0 to be an integer.", .{});
            return error.ArgumentTypeMismatch;
        };

        std.debug.assert(impl != null);
        const self: *CardDef = @ptrCast(@alignCast(impl.?));

        std.debug.assert(self.actions.len > 0);
        if (index.value < 0 or index.value >= self.actions.len) {
            std.log.err("Arg 0 is out of range (was '{}') => Values allowed to range from 0 to {d}.", .{
                index.value,
                self.actions.len - 1
            });
            return error.ArgumentOutOfRange;
        }
        
        const action_def: *const ActionDefinitionStatement = self.actions[ @intCast(index.value) ];
        switch (action_def.action_cost) {
            ActionDefinitionStatement.ActionCostExpr.flat => |f| {
                return .{
                    .integer = .{
                        .value = @intCast(f.val)
                    }
                };
            },
            ActionDefinitionStatement.ActionCostExpr.dynamic => |d| {
                var empty_sym_table: SymbolTable = try SymbolTable.new(self.allocator);
                defer empty_sym_table.deinit();

                const result: ExpressionResult = try d.amount.evaluate(&empty_sym_table);
                var int_result: IntResult = result.as(IntResult) orelse {
                    std.log.err("Invalid amount expression on dynamic action cost expression.", .{});
                    return error.InvalidDynamicAmountExpr;
                };
                // it's dynamic, so this implicitly costs "up to" x actions
                int_result.up_to = true;
                return ExpressionResult { .integer = int_result };
            }
        }
    }

    /// Converts this `CardDef` to a `Scope`.
    /// Resulting scope must be freed by caller.
    pub fn toOwnedScope(self: *CardDef) Error!*Scope {
        const scope: *Scope = try Scope.newObj(self.allocator, self);
        errdefer scope.deinit();

        if (self.getRank()) |rank| {
            try scope.putValue("rank", .{
                .label = .{
                    .rank = rank
                }
            });
        } else {
            std.log.err("Cannot convert this card to a scope: Missing rank label.", .{});
            return Error.InvalidCardDef;
        }

        if (self.isAttack()) {
            if (self.getAccuracy()) |acc| {
                try scope.putValue("accuracy", .{
                    .label = .{
                        .accuracy = acc
                    }
                });
            } else {
                // for now, we're ignore AOE
                std.log.err("Cannot convert this card to a scope: Attack is missing accuracy.", .{});
                return Error.InvalidCardDef;
            }
            try scope.putValue("isAttack", .{ .boolean = true });
        }

        if (!self.isMonster()) {
            try scope.putFunc("getActionCost", &implGetActionCost);
        } else {
            try scope.putValue("isMonster", .{ .boolean = true });
            // TODO: Monster-related functions
        }
        
        return scope;
    }
};
