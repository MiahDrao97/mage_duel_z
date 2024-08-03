const std = @import("std");

const imports = struct {
    usingnamespace @import("expression.zig");
    usingnamespace @import("concrete_expressions.zig");
    usingnamespace @import("Statement.zig");
    usingnamespace @import("concrete_statements.zig");
    usingnamespace @import("tokens.zig");
};

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Token = imports.Token;
const Expression = imports.Expression;
const Statement = imports.Statement;
const TokenIterator = imports.TokenIterator;
const LabelLiteral = imports.LabelLiteral;
const IntegerLiteral = imports.IntegerLiteral;
const BooleanLiteral = imports.BooleanLiteral;
const DamageTypeLiteral = imports.DamageTypeLiteral;
const DiceLiteral = imports.DiceLiteral;
const ListLiteral = imports.ListLiteral;
const DamageExpression = imports.DamageExpression;
const TargetExpression = imports.TargetExpression;
const WhenExpression = imports.WhenExpression;
const IfStatement = imports.IfStatement;
const ForLoop = imports.ForLoop;
const CardDef = @import("parsing.zig").CardDef;
const ActionDefinitionStatement = imports.ActionDefinitionStatement;
const Label = imports.Label;
const Identifier = imports.Identifier;
const FunctionCall = imports.FunctionCall;
const DamageStatement = imports.DamageStatement;
const AssignmentStatement = imports.AssignmentStatement;
const EqualityExpression = imports.EqualityExpression;
const BooleanExpression = imports.BooleanExpression;
const ComparisonExpression = imports.ComparisonExpression;
const FactorExpression = imports.FactorExpression;
const AdditiveExpression = imports.AdditiveExpression;
const UnaryExpression = imports.UnaryExpression;
const ParenthesizedExpression = imports.ParensthesizedExpression;

pub const Parser = @This();

allocator: Allocator,

/// This structure does not own the memory produced by `parseTokens`.
/// Thus, no `deinit()` method is defined.
pub fn init(allocator: Allocator) Parser {
    return .{ .allocator = allocator };
}

pub fn parseTokens(self: Parser, to_parse: []Token) !CardDef {
    var actions = try ArrayList(ActionDefinitionStatement).initCapacity(self.allocator, to_parse.len);
    defer actions.deinit();
    errdefer {
        for (actions.items) |*action| {
            action.deinit();
        }
    }

    var labels = ArrayList(Label).init(self.allocator);
    defer labels.deinit();

    var iter: TokenIterator = try TokenIterator.from(self.allocator, to_parse);
    defer iter.deinit();

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

    const labels_slice: []Label = try labels.toOwnedSlice();
    const actions_slice: []ActionDefinitionStatement = try actions.toOwnedSlice();

    return CardDef.init(self.allocator, labels_slice, actions_slice);
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
        try statements.append(try self.parseStatement(iter));
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

fn parseStatement(self: Parser, iter: TokenIterator) anyerror!Statement {
    while (iter.peek()) |next| {
        if (next.symbolEquals("if")) {
            var if_statement: IfStatement = try self.parseIfStatement(iter);
            return if_statement.stmt();
        } else if (next.symbolEquals("for")) {
            var for_loop: ForLoop = try self.parseForLoop(iter);
            return for_loop.stmt();
        } else {
            // damage statement, assignment statement, or function call
            return self.parseNonControlFlowStatment(iter);
        }
    }
    return error.EOF;
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

fn parseForLoop(self: Parser, iter: TokenIterator) !ForLoop {
    _ = try iter.require("for");
    _ = try iter.require("(");

    const identifier: Token = try iter.requireType(&[_][]const u8 { @tagName(Token.identifier) });
    _ = try iter.require("in");

    const range: Expression = try parseExpression(iter);
    _ = try iter.require(")");
    _ = try iter.require("{");

    var statements = ArrayList(Statement).init(self.allocator);
    errdefer {
        Statement.deinitAll(statements.items);
        statements.deinit();
    }

    var block_terminated: bool = false;
    while (iter.peek()) |next| {
        if (next.stringEquals("}")) {
            _ = try iter.require("}");
            block_terminated = true;
            break;
        }
        try statements.append(try self.parseStatement(iter));
    }
    if (!block_terminated) {
        return error.UnterminatedStatementBlock;
    }

    const statements_slice: []Statement = try statements.toOwnedSlice();
    return try ForLoop.new(
        self.allocator,
        identifier,
        range,
        statements_slice);
}

fn parseNonControlFlowStatment(self: Parser, iter: TokenIterator) !Statement {
    // assignment statment, damage statement, and function can all start with an identifier
    if (Identifier.from(iter)) |i| {
        var identifier: Identifier = i;
        // it all comes down to the next token...
        const token: Token = try iter.requireOneOf(&[_][]const u8 { "(", "=>", "=" });

        if (token.stringEquals("(")) {
            // parse function call
            var matchedParen: bool = false;
            var expressions = ArrayList(Expression).init(self.allocator);
            errdefer expressions.deinit();

            while (iter.peek()) |next| {
                if (next.stringEquals(")")) {
                    _ = try iter.require(")");
                    matchedParen = true;
                    break;
                }
                const expr: Expression = try parseExpression(iter);
                try expressions.append(expr);
            }
            if (!matchedParen) {
                return error.UnmatchedParen;
            }
            _ = try iter.require(";");

            const args: []Expression = try expressions.toOwnedSlice();
            var fnCall: FunctionCall = try FunctionCall.new(self.allocator, identifier.name, args);
            return fnCall.stmt();
        } else if (token.stringEquals("=>")) {
            // damage statement
            _ = try iter.require("=>");
            const target: Expression = try parseExpression(iter);
            _ = try iter.require(";");

            // no allocator needed for this one
            var dmg: DamageStatement = .{
                .damage_transaction_expr = identifier.expr(),
                .target_expr = target
            };
            return dmg.stmt();
        } else if (token.stringEquals("=")) {
            _ = try iter.require("=");
            const rhs: Expression = try parseExpression(iter);
            _ = try iter.require(";");

            var assignment: AssignmentStatement = try AssignmentStatement.new(identifier.name, rhs);
            return assignment.stmt();
        }
        unreachable;
    } else |err| {
        switch (err) {
            error.OutOfMemory => {
                std.log.err("Out of memory while trying to parse identifier.", .{});
                return err;
            },
            else => {
                // roll back 1 token (it wasn't an identifier)
                iter.internal_iter.scroll(-1);
            }
        }
    }
    if (IntegerLiteral.from(iter)) |i| {
        var int: IntegerLiteral = i;
        // has to be a damage statement
        var damage_type: DamageTypeLiteral = try DamageTypeLiteral.from(iter);
        _ = try iter.require("=>");
        const target: Expression = try parseExpression(iter);
        _ = try iter.require(";");

        var damage_expr: DamageExpression = .{
            .amount_expr = int.expr(),
            .damage_type_expr = damage_type.expr()
        };

        var damage_stmt: DamageStatement = .{
            .damage_transaction_expr = damage_expr.expr(),
            .target_expr = target
        };
        return damage_stmt.stmt();
    } else |_| {
        // roll back 1 token (it wasn't an integer literal)
        iter.internal_iter.scroll(-1);
    }
    if (DiceLiteral.from(iter)) |d| {
        var dice: DiceLiteral = d;
        // has to be a damage statement
        var damage_type: DamageTypeLiteral = try DamageTypeLiteral.from(iter);
        _ = try iter.require("=>");
        const target: Expression = try parseExpression(iter);
        _ = try iter.require(";");

        var damage_expr: DamageExpression = .{
            .amount_expr = dice.expr(),
            .damage_type_expr = damage_type.expr()
        };

        var damage_stmt: DamageStatement = .{
            .damage_transaction_expr = damage_expr.expr(),
            .target_expr = target
        };
        return damage_stmt.stmt();
    } else |_| {
        // roll back 1 token (it wasn't a dice literal)
        iter.internal_iter.scroll(-1);
    }

    const next_tok: Token = iter.peek() orelse Token.eof;
    std.log.err("Cannot parse statement beginning with token '{s}'", .{ next_tok.toString() orelse "<EOF>" });
    return error.UnexpectedToken;
}

fn parseExpression(iter: TokenIterator) anyerror!Expression {
    return parseEqualityExpression(iter);
}

fn parseEqualityExpression(iter: TokenIterator) !Expression {
    const lhs: Expression = try parseBooleanExpression(iter);
    if (iter.nextMatchesSymbol(&[_][]const u8 { "==", "!=" })) |sym| {
        const rhs: Expression = try parseBooleanExpression(iter);
        var equalityExpr: EqualityExpression = try EqualityExpression.new(lhs, rhs, sym);
        return equalityExpr.expr();
    }
    return lhs;
}

fn parseBooleanExpression(iter: TokenIterator) !Expression {
    const lhs: Expression = try parseComparisonExpression(iter);
    if (iter.nextMatchesSymbol(&[_][]const u8 { "+", "|", "^" })) |sym| {
        const rhs: Expression = try parseComparisonExpression(iter);
        var booleanExpr: BooleanExpression = try BooleanExpression.new(lhs, rhs, sym);
        return booleanExpr.expr();
    }
    return lhs;
}

fn parseComparisonExpression(iter: TokenIterator) !Expression {
    const lhs: Expression = try parseAdditiveExpression(iter);
    if (iter.nextMatchesSymbol(&[_][]const u8 { ">", ">=", "<=", "<" })) |sym| {
        const rhs: Expression = try parseAdditiveExpression(iter);
        var comparisonExpr: ComparisonExpression = try ComparisonExpression.new(lhs, rhs, sym);
        return comparisonExpr.expr();
    }
    return lhs;
}

fn parseAdditiveExpression(iter: TokenIterator) !Expression {
    const lhs: Expression = try parseFactorExpression(iter);
    if (iter.nextMatchesSymbol(&[_][]const u8 { "+", "+!", "-" })) |sym| {
        const rhs: Expression = try parseFactorExpression(iter);
        var additiveExpr: AdditiveExpression = try AdditiveExpression.new(lhs, rhs, sym);
        return additiveExpr.expr();
    }
    return lhs;
}

fn parseFactorExpression(iter: TokenIterator) !Expression {
    const lhs: Expression = try parseUnaryExpression(iter);
    if (iter.nextMatchesSymbol(&[_][]const u8 { "*", "/" })) |sym| {
        const rhs: Expression = try parseUnaryExpression(iter);
        var factorExpr: FactorExpression = try FactorExpression.new(lhs, rhs, sym);
        return factorExpr.expr();
    }
    return lhs;
}

fn parseUnaryExpression(iter: TokenIterator) !Expression {
    if (iter.nextMatchesSymbol(&[_][]const u8 { "-", "~", "^" })) |sym| {
        const rhs: Expression = try parsePrimaryExpression(iter);
        var unaryExpr: UnaryExpression = try UnaryExpression.new(rhs, sym);
        return unaryExpr.expr();
    }
    return parsePrimaryExpression(iter);
}

fn parsePrimaryExpression(iter: TokenIterator) !Expression {
    if (iter.nextMatchesSymbol(&[_][]const u8 { "target" })) |_| {
        var target_expr: TargetExpression = try parseTargetExpression(iter);
        return target_expr.expr();
    } else if (iter.nextMatchesSymbol(&[_][]const u8 { "(" })) |_| {
        const expr: Expression = try parseExpression(iter);
        _ = try iter.require(")");

        var paren_expr: ParenthesizedExpression = .{ .inner = expr };
        return paren_expr.expr();
    } else {
        // parse integer, boolean, damage type, dice, identifier, list literal
        // leaving damage expression out because it's a composite of integer/dice + damage type (see parsing damage statements)
        if (IntegerLiteral.from(iter)) |i| {
            var int: IntegerLiteral = i;
            return int.expr();
        } else |_| { }

        if (BooleanLiteral.from(iter)) |b| {
            var boolean: BooleanLiteral = b;
            return boolean.expr();
        } else |_| { }

        if (DiceLiteral.from(iter)) |d| {
            var dice: DiceLiteral = d;
            return dice.expr();
        } else |_| { }

        if (DamageTypeLiteral.from(iter)) |d| {
            var damage_type: DamageTypeLiteral = d;
            return damage_type.expr();
        } else |_| { }

        if (Identifier.from(iter)) |i| {
            var identifier: Identifier = i;
            return identifier.expr();
        } else |err| {
            switch (err) {
                error.OutOfMemory => {
                    std.log.err("Out of memory while trying to parse identifier.", .{});
                    return err;
                },
                else => { }
            }
        }
    }
    const next_tok: Token = iter.peek() orelse Token.eof;
    std.log.err("Cannot parse statement beginning with token '{s}'", .{ next_tok.toString() orelse "<EOF>" });
    return error.UnexpectedToken;
}

fn parseTargetExpression(iter: TokenIterator) anyerror!TargetExpression {
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
