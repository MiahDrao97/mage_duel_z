const std = @import("std");
const tokens = @import("tokens.zig");

const Allocator = std.mem.Allocator;

pub const Tokenizer = @import("Tokenizer.zig");
pub const TokenizerError = Tokenizer.TokenizerError;
pub const expression = @import("expression.zig");
pub const Expression = expression.Expression;
pub const ExpressionResult = expression.Result;
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
    actions: []ActionDefinitionStatement,
    allocator: Allocator,

    pub fn init(allocator: Allocator, labels: []Label, actions: []ActionDefinitionStatement) CardDef {
        return .{
            .labels = labels,
            .actions = actions,
            .allocator = allocator
        };
    }

    pub fn deinit(self: *CardDef) void {
        self.allocator.free(self.labels);
        self.allocator.free(self.actions);
        self.* = undefined;
    }
};
