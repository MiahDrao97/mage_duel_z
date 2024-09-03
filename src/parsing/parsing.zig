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
    actions: []*ActionDefinitionStatement,
    allocator: Allocator,

    const Error = Allocator.Error || error.InvalidCardDef;

    pub fn init(allocator: Allocator, labels: []Label, actions: []*ActionDefinitionStatement) CardDef {
        return .{
            .labels = labels,
            .actions = actions,
            .allocator = allocator
        };
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
        self.* = undefined;
    }

    pub fn toScope(self: CardDef, current_scope: *Scope) Error!*Scope {
        const scope: *Scope = try current_scope.pushNew();
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
        }

        // TODO: the rest of these:
        // - getActionCost(1)
        return scope;
    }
};
