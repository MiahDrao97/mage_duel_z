const std = @import("std");
const tokens = @import("tokens.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Tokenizer = @import("tokenizer.zig");
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
pub const Label = expression.Label;

pub const CardDef = struct {
    labels: []Label,
    statements: []Statement,
};

pub fn parseTokens(allocator: Allocator, to_parse: []Token) !CardDef {
    var statements = try ArrayList(Statement).initCapacity(allocator, to_parse.len);
    errdefer statements.deinit();

    var labels = ArrayList(Label).init(allocator);
    errdefer labels.deinit();
}
