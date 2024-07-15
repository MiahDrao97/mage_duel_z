const std = @import("std");

const imports = struct {
    usingnamespace @import("tokens.zig");
    usingnamespace @import("expression.zig");
    usingnamespace @import("concrete_expressions.zig");
    usingnamespace @import("Statement.zig");
    usingnamespace @import("concrete_statements.zig");
    usingnamespace @import("parsing.zig");
};

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Token = imports.Token;
const Expression = imports.Expression;
const Statement = imports.Statement;
const TokenIterator = imports.TokenIterator;
const LabelLiteral = imports.LabelLiteral;
const IntegerLiteral = imports.IntegerLiteral;
const TargetExpression = imports.TargetExpression;
const WhenExpression = imports.WhenExpression;
const IfStatement = imports.IfStatement;
const ForLoop = imports.ForLoop;
const CardDef = imports.CardDef;
const ActionDefinitionStatement = imports.ActionDefinitionStatement;
const Label = imports.Label;

pub const Parser = @This();

allocator: Allocator,

/// This structure does not own the memory produced by `parseTokens`.
/// Thus, no `deinit()` method is defined.
pub fn init(allocator: Allocator) Parser {
    return .{ .allocator = allocator };
}

pub fn parseTokens(self: Parser, to_parse: []Token) !CardDef {
    var actions = try ArrayList(ActionDefinitionStatement).initCapacity(self.allocator, to_parse.len);
    errdefer actions.deinit();

    var labels = ArrayList(Label).init(self.allocator);
    errdefer labels.deinit();

    const iter: TokenIterator = try TokenIterator.from(self.allocator, to_parse);

    // topmost level
    while (iter.peek()) |next| {
        if (next.stringEquals("#")) {
            // parse label
            const label_expr: LabelLiteral = try LabelLiteral.from(iter);
            try labels.append(label_expr.label);
        } else if (next.stringEquals("[")) {
            const statement: ActionDefinitionStatement = try self.parseActionDefinitionStatement(iter);
            try actions.append(statement);
        } else {
            std.log.err("Unable to parse label or action definition statement with token: '{s}'",
                .{ next.toString() orelse @tagName(next) });
            return error.UnexpectedToken;
        }
    }
}

fn parseActionDefinitionStatement(self: Parser, iter: TokenIterator) !ActionDefinitionStatement {
    var statements = ArrayList(Statement).init(self.allocator);
    errdefer statements.deinit();

    _ = try iter.require("[");
    const actionCost: ActionDefinitionStatement.ActionCostExpr = try parseActionCostExpr(iter);
    _ = try iter.require("]");

    const whenExpr: ?WhenExpression = try parseWhenExpression(iter);

    _ = try iter.require("{");
    while (iter.peek()) |next| {
        if (next.stringEquals("}")) {
            break;
        }
        try statements.append(try parseStatement(iter));
    }
    _ = try iter.require("}");

    const statements_slice: []Statement = try statements.toOwnedSlice();
    return ActionDefinitionStatement.init(self.allocator, statements_slice, actionCost, whenExpr);
}

fn parseActionCostExpr(iter: TokenIterator) !ActionDefinitionStatement.ActionCostExpr {
    if (IntegerLiteral.from(iter)) |int| {
        // this is the most common case
        return .{ .flat = int };
    } else |_| {
        return .{ .dynamic = try parseTargetExpression(iter) };
    }
}

fn parseWhenExpression(iter: TokenIterator) !?WhenExpression {
    if (iter.peek()) |next| {
        if (next.stringEquals("when")) {
            _ = try iter.require("when");
            _ = try iter.require("(");

            const expr: Expression = try parseExpression(iter);
            _ = try iter.require(")");

            return WhenExpression { .condition = expr };
        }
    }
    return null;
}

fn parseStatement(self: Parser, iter: TokenIterator) !Statement {
    while (iter.peek()) |next| {
        if (next.stringEquals("if")) {
            const if_statement: IfStatement = try self.parseIfStatement(iter);
            return if_statement.stmt();
        } else if (next.stringEquals("for")) {

        } else {
            // damage statement, assignment statement
        }
    }
    return error.NotImplemented;
}

fn parseIfStatement(self: Parser, iter: TokenIterator) !IfStatement {
    _ = try iter.require("if");
    _ = try iter.require("(");
    const condition: Expression = try parseExpression(iter);
    _ = try iter.require(")");
    _ = try iter.require("{");

    var true_statements = ArrayList(Statement).init(self.allocator);
    errdefer {
        Statement.deinitAll(true_statements.items);
        true_statements.deinit();
    }
    var else_statements = ArrayList(Statement).init(self.allocator);
    errdefer {
        Statement.deinitAll(else_statements.items);
        else_statements.deinit();
    }

    var block_terminated: bool = false;
    while (iter.peek()) |next| {
        if (next.stringEquals("}")) {
            _ = try iter.require("}");
            block_terminated = true;
            break;
        }
        try true_statements.append(try self.parseStatement(iter));
    }

    if (!block_terminated) {
        return error.UnterminatedStatementBlock;
    }

    if (iter.peek()) |next| {
        if (next.stringEquals("else")) {
            block_terminated = false;
            _ = try iter.require("else");
            _ = try iter.require("{");

            while (iter.peek()) |else_next| {
                if (else_next.stringEquals("}")) {
                    _ = try iter.require("}");
                    block_terminated = true;
                    break;
                }
                try else_statements.append(try self.parseStatement(iter));
            }
        }
    }

    if (!block_terminated) {
        return error.UnterminatedStatementBlock;
    }

    const true_statements_slice: []Statement = try true_statements.toOwnedSlice();
    const else_statements_slice: []Statement = try else_statements.toOwnedSlice();

    return IfStatement.init(self.allocator, condition, true_statements_slice, else_statements_slice);
}

fn parseExpression(iter: TokenIterator) !Expression {
    _ = &iter;
    return error.NotImplemented;
}

fn parseTargetExpression(iter: TokenIterator) !TargetExpression {
    // target(1 from [ 1 | 2 ])

    _ = try iter.require("target");
    _ = try iter.require("(");
    const amount: Expression = try parseExpression(iter);

    _ = try iter.require("from");
    const pool: Expression = try parseExpression(iter);

    _ = try iter.require(")");

    return TargetExpression {
        .amount = amount,
        .pool = pool
    };
}
