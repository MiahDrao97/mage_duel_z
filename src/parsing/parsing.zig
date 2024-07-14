const std = @import("std");
const tokens = @import("tokens.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const TokenIterator = tokens.TokenIterator;

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
pub const concrete_statements = @import("concrete_statements.zig");
pub const ActionDefinitionStatement = concrete_statements.ActionDefinitionStatement;
pub const Label = expression.Label;

const LabelLiteral = concrete_expressions.LabelLiteral;

pub const CardDef = struct {
    labels: []Label,
    actions: []ActionDefinitionStatement,
};

pub fn parseTokens(allocator: Allocator, to_parse: []Token) !CardDef {
    var actions = try ArrayList(ActionDefinitionStatement).initCapacity(allocator, to_parse.len);
    errdefer actions.deinit();

    var labels = ArrayList(Label).init(allocator);
    errdefer labels.deinit();

    const iter: TokenIterator = try TokenIterator.from(allocator, to_parse);

    // topmost level
    while (iter.peek()) |next| {
        if (next.stringEquals("#")) {
            // parse label
            const label_expr: LabelLiteral = try LabelLiteral.from(iter);
            try labels.append(label_expr.label);
        } else if (next.stringEquals("[")) {
            const statement: ActionDefinitionStatement = try parseActionDefinitionStatement(allocator, iter);
            try actions.append(statement);
        } else {
            std.log.err("Unable to parse label or action definition statement with token: '{s}'",
                .{ next.toString() orelse @tagName(next) });
            return error.UnexpectedToken;
        }
    }
}

fn parseActionDefinitionStatement(allocator: Allocator, iter: TokenIterator) !ActionDefinitionStatement {
    var statements = ArrayList(Statement).init(allocator);
    errdefer statements.deinit();

    _ = try iter.require("[");
    const actionCost: ActionDefinitionStatement.ActionCostExpr = try parseExpression(iter);
    
    _ = try iter.require("]");
    _ = try iter.require("{");

    while (iter.peek()) |next| {
        if (next.stringEquals("}")) {
            break;
        }
        try statements.append(try parseStatement(iter));
    }

    _ = try iter.require("}");

    const statements_slice: []Statement = try statements.toOwnedSlice();
    return ActionDefinitionStatement.init(allocator, statements_slice, actionCost);
}

fn parseActionCostExpr(iter: TokenIterator) !ActionDefinitionStatement.ActionCostExpr {
    _ = &iter;
    return error.NotImplemented;
}

fn parseStatement(iter: TokenIterator) !Expression {
    _ = &iter;
    return error.NotImplemented;
}

fn parseExpression(iter: TokenIterator) !Expression {
    _ = &iter;
    return error.NotImplemented;
}
