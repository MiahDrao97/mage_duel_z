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

pub fn parseTokens(self: Parser, to_parse: []Token) !*CardDef {
    var actions = try ArrayList(*ActionDefinitionStatement).initCapacity(self.allocator, to_parse.len);
    defer actions.deinit();
    errdefer {
        for (actions.items) |action| {
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
            const label_expr: *LabelLiteral = try LabelLiteral.from(self.allocator, iter);
            defer label_expr.deinit();

            try labels.append(label_expr.label);
        } else if (next.stringEquals("[")) {
            const statement: *ActionDefinitionStatement = try self.parseActionDefinitionStatement(iter);
            errdefer statement.deinit();
            
            try actions.append(statement);
        } else {
            std.log.err("Unable to parse label or action definition statement with token: '{s}'",
                .{ next.toString() orelse @tagName(next) });
            return error.UnexpectedToken;
        }
    }

    const labels_slice: []Label = try labels.toOwnedSlice();
    errdefer self.allocator.free(labels_slice);

    const actions_slice: []*ActionDefinitionStatement = try actions.toOwnedSlice();

    return try CardDef.new(self.allocator, labels_slice, actions_slice);
}

fn parseActionDefinitionStatement(self: Parser, iter: TokenIterator) !*ActionDefinitionStatement {
    var statements = ArrayList(Statement).init(self.allocator);
    errdefer {
        Statement.deinitAll(statements.items);
        statements.deinit();
    }

    _ = try iter.require("[");

    var actionCost: ActionDefinitionStatement.ActionCostExpr = try self.parseActionCostExpr(iter);
    errdefer actionCost.deinit();

    _ = try iter.require("]");

    const whenExpr: ?*WhenExpression = try self.parseWhenExpression(iter);
    errdefer {
        if (whenExpr) |w| {
            w.deinit();
        }
    }

    _ = try iter.require(":");
    _ = try iter.require("{");
    while (iter.peek()) |next| {
        if (next.stringEquals("}")) {
            break;
        }
        var stmt: Statement = try self.parseStatement(iter);
        errdefer stmt.deinit();

        try statements.append(stmt);
    }
    _ = try iter.require("}");

    const statements_slice: []Statement = try statements.toOwnedSlice();
    errdefer Statement.deinitAllAndFree(self.allocator, statements_slice);

    return try ActionDefinitionStatement.new(self.allocator, statements_slice, actionCost, whenExpr);
}

fn parseActionCostExpr(self: Parser, iter: TokenIterator) !ActionDefinitionStatement.ActionCostExpr {
    if (IntegerLiteral.from(self.allocator, iter)) |int| {
        // this is the most common case
        return .{ .flat = int };
    } else |_| {
        return .{ .dynamic = try self.parseTargetExpression(iter, false) };
    }
}

fn parseWhenExpression(self: Parser, iter: TokenIterator) !?*WhenExpression {
    if (iter.peek()) |next| {
        if (next.stringEquals("when")) {
            _ = try iter.require("when");
            _ = try iter.require("(");

            var expr: Expression = try self.parseExpression(iter);
            errdefer expr.deinit();

            _ = try iter.require(")");

            return try WhenExpression.new(self.allocator, expr);
        }
    }
    return null;
}

fn parseStatement(self: Parser, iter: TokenIterator) anyerror!Statement {
    if (iter.peek()) |next| {
        if (next.symbolEquals("if")) {
            const if_statement: *IfStatement = try self.parseIfStatement(iter);
            return if_statement.stmt();
        } else if (next.symbolEquals("for")) {
            const for_loop: *ForLoop = try self.parseForLoop(iter);
            return for_loop.stmt();
        } else {
            // damage statement, assignment statement, or function call
            return self.parseNonControlFlowStatment(iter);
        }
    }
    return error.EOF;
}

fn parseIfStatement(self: Parser, iter: TokenIterator) !*IfStatement {
    _ = try iter.require("if");
    _ = try iter.require("(");

    var condition: Expression = try self.parseExpression(iter);
    errdefer condition.deinit();

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
        var stmt: Statement = try self.parseStatement(iter);
        errdefer stmt.deinit();

        try true_statements.append(stmt);
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
                var stmt: Statement = try self.parseStatement(iter);
                errdefer stmt.deinit();

                try else_statements.append(stmt);
            }
        }
    }

    if (!block_terminated) {
        return error.UnterminatedStatementBlock;
    }

    const true_statements_slice: []Statement = try true_statements.toOwnedSlice();
    errdefer Statement.deinitAllAndFree(self.allocator, true_statements_slice);

    const else_statements_slice: []Statement = try else_statements.toOwnedSlice();
    errdefer Statement.deinitAllAndFree(self.allocator, else_statements_slice);

    return try IfStatement.new(
        self.allocator,
        condition,
        true_statements_slice,
        else_statements_slice);
}

fn parseForLoop(self: Parser, iter: TokenIterator) !*ForLoop {
    _ = try iter.require("for");
    _ = try iter.require("(");

    const identifier: Token = try iter.requireType(&[_][]const u8 { @tagName(Token.identifier) });
    _ = try iter.require("in");

    var range: Expression = try self.parseExpression(iter);
    errdefer range.deinit();

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
    errdefer Statement.deinitAllAndFree(self.allocator, statements_slice);

    return try ForLoop.new(
        self.allocator,
        identifier,
        range,
        statements_slice);
}

fn parseNonControlFlowStatment(self: Parser, iter: TokenIterator) !Statement {
    // assignment statment, damage statement, and function can all start with an identifier
    var dbg_tok: Token = iter.peek() orelse Token.eof;
    std.log.debug("Beginning to parse non-control flow statment with next token: '{s}'", .{ dbg_tok.toString() orelse "<EOF>" });
    if (Identifier.from(self.allocator, iter)) |identifier| {
        defer identifier.deinit();

        // it all comes down to the next token...
        const token: Token = try iter.requireOneOf(&[_][]const u8 { "(", "=>", "=" });

        if (token.stringEquals("(")) {
            std.log.debug("Parsing function call", .{});
            // parse function call
            var matched_paren: bool = false;
            var expressions = ArrayList(Expression).init(self.allocator);
            errdefer {
                Expression.deinitAll(expressions.items);
                expressions.deinit();
            }

            while (iter.peek()) |next| {
                if (next.stringEquals(")")) {
                    _ = try iter.require(")");
                    matched_paren = true;
                    break;
                }
                var expr: Expression = try self.parseExpression(iter);
                errdefer expr.deinit();

                try expressions.append(expr);
            }
            if (!matched_paren) {
                return error.UnmatchedParen;
            }
            _ = try iter.require(";");

            const args: []Expression = try expressions.toOwnedSlice();
            errdefer Expression.deinitAllAndFree(self.allocator, args);

            var fn_call: *FunctionCall = try FunctionCall.new(self.allocator, identifier.name, args);
            return fn_call.stmt();
        } else if (token.stringEquals("=>")) {
            std.log.debug("Parsing damage statement", .{});

            // damage statement
            var target: Expression = try self.parseExpression(iter);
            errdefer target.deinit();

            _ = try iter.require(";");

            // no allocator needed for this one
            const dmg: *DamageStatement = try DamageStatement.new(self.allocator, identifier.expr(), target);
            return dmg.stmt();
        } else if (token.stringEquals("=")) {
            std.log.debug("Parsing assignment statement", .{});

            var rhs: Expression = try self.parseExpression(iter);
            errdefer rhs.deinit();

            _ = try iter.require(";");

            const assignment: *AssignmentStatement = try AssignmentStatement.new(self.allocator, identifier.name, rhs);
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
    if (DiceLiteral.from(self.allocator, iter)) |dice| {
        var dmg_amount: Expression = dice.expr();
        errdefer dmg_amount.deinit();

        // has to be a damage statement
        if (iter.nextMatchesSymbol(&[_][]const u8 { "+", "-"})) |op| {
            // has to be an integer next
            const modifier: *IntegerLiteral = try IntegerLiteral.from(self.allocator, iter);
            errdefer modifier.deinit();

            const additive_expr: *AdditiveExpression = try AdditiveExpression.new(self.allocator, dice.expr(), modifier.expr(), op);
            dmg_amount = additive_expr.expr();
        }

        const damage_type: *DamageTypeLiteral = DamageTypeLiteral.from(self.allocator, iter) catch |err| {
            switch (err) {
                error.UnexpectedToken => {
                    const next_tok: Token = iter.peek() orelse Token.eof;
                    std.log.err("Cannot parse damage type from token '{s}'", .{ next_tok.toString() orelse "<EOF>" });
                },
                else => {
                    std.log.err("Unexpected error while parsing damage type: '{s}', {?}", .{ @errorName(err), @errorReturnTrace() });
                }
            }
            return err;
        };
        errdefer damage_type.deinit();

        _ = try iter.require("=>");

        var target: Expression = try self.parseExpression(iter);
        errdefer target.deinit();

        _ = try iter.require(";");

        const damage_expr: *DamageExpression = try DamageExpression.new(self.allocator, dmg_amount, damage_type.expr());
        errdefer damage_expr.deinit();

        const damage_stmt: *DamageStatement = try DamageStatement.new(self.allocator, damage_expr.expr(), target);
        return damage_stmt.stmt();
    } else |_| {
        // DiceLiteral.from() handles the scrolling since it's variable
    }
    if (IntegerLiteral.from(self.allocator, iter)) |int| {
        errdefer int.deinit();
        // has to be a damage statement
        const damage_type: *DamageTypeLiteral = try DamageTypeLiteral.from(self.allocator, iter);
        errdefer damage_type.deinit();

        _ = try iter.require("=>");

        var target: Expression = try self.parseExpression(iter);
        errdefer target.deinit();

        _ = try iter.require(";");

        const damage_expr: *DamageExpression = try DamageExpression.new(self.allocator, int.expr(), damage_type.expr());
        errdefer damage_expr.deinit();

        const damage_stmt: *DamageStatement = try DamageStatement.new(self.allocator, damage_expr.expr(), target);
        return damage_stmt.stmt();
    } else |_| {
        // handles the scrolling
    }

    const next_tok: Token = iter.peek() orelse Token.eof;
    std.log.err("Cannot parse statement beginning with token '{s}'", .{ next_tok.toString() orelse "<EOF>" });
    return error.UnexpectedToken;
}

fn parseExpression(self: Parser, iter: TokenIterator) anyerror!Expression {
    return self.parseEqualityExpression(iter);
}

fn parseEqualityExpression(self: Parser, iter: TokenIterator) !Expression {
    var lhs: Expression = try self.parseBooleanExpression(iter);
    errdefer lhs.deinit();

    if (iter.nextMatchesSymbol(&[_][]const u8 { "==", "!=" })) |sym| {
        var rhs: Expression = try self.parseBooleanExpression(iter);
        errdefer rhs.deinit();

        const equalityExpr: *EqualityExpression = try EqualityExpression.new(self.allocator, lhs, rhs, sym);
        return equalityExpr.expr();
    }
    return lhs;
}

fn parseBooleanExpression(self: Parser, iter: TokenIterator) !Expression {
    var lhs: Expression = try self.parseComparisonExpression(iter);
    errdefer lhs.deinit();

    if (iter.nextMatchesSymbol(&[_][]const u8 { "+", "|", "^" })) |sym| {
        var rhs: Expression = try self.parseComparisonExpression(iter);
        errdefer rhs.deinit();

        const booleanExpr: *BooleanExpression = try BooleanExpression.new(self.allocator, lhs, rhs, sym);
        return booleanExpr.expr();
    }
    return lhs;
}

fn parseComparisonExpression(self: Parser, iter: TokenIterator) !Expression {
    var lhs: Expression = try self.parseAdditiveExpression(iter);
    errdefer lhs.deinit();

    if (iter.nextMatchesSymbol(&[_][]const u8 { ">", ">=", "<=", "<" })) |sym| {
        var rhs: Expression = try self.parseAdditiveExpression(iter);
        errdefer rhs.deinit();

        const comparisonExpr: *ComparisonExpression = try ComparisonExpression.new(self.allocator, lhs, rhs, sym);
        return comparisonExpr.expr();
    }
    return lhs;
}

fn parseAdditiveExpression(self: Parser, iter: TokenIterator) !Expression {
    var lhs: Expression = try self.parseFactorExpression(iter);
    errdefer lhs.deinit();

    if (iter.nextMatchesSymbol(&[_][]const u8 { "+", "+!", "-" })) |sym| {
        var rhs: Expression = try self.parseFactorExpression(iter);
        errdefer rhs.deinit();

        const additiveExpr: *AdditiveExpression = try AdditiveExpression.new(self.allocator, lhs, rhs, sym);
        return additiveExpr.expr();
    }
    return lhs;
}

fn parseFactorExpression(self: Parser, iter: TokenIterator) !Expression {
    var lhs: Expression = try self.parseUnaryExpression(iter);
    errdefer lhs.deinit();

    if (iter.nextMatchesSymbol(&[_][]const u8 { "*", "/" })) |sym| {
        var rhs: Expression = try self.parseUnaryExpression(iter);
        errdefer rhs.deinit();

        const factorExpr: *FactorExpression = try FactorExpression.new(self.allocator, lhs, rhs, sym);
        return factorExpr.expr();
    }
    return lhs;
}

fn parseUnaryExpression(self: Parser, iter: TokenIterator) !Expression {
    if (iter.nextMatchesSymbol(&[_][]const u8 { "-", "~", "^" })) |sym| {
        var rhs: Expression = try self.parsePrimaryExpression(iter);
        errdefer rhs.deinit();

        const unaryExpr: *UnaryExpression = try UnaryExpression.new(self.allocator, rhs, sym);
        return unaryExpr.expr();
    }
    return self.parsePrimaryExpression(iter);
}

fn parsePrimaryExpression(self: Parser, iter: TokenIterator) anyerror!Expression {
    if (iter.nextMatchesSymbol(&[_][]const u8 { "target" })) |_| {
        const target_expr: *TargetExpression = try self.parseTargetExpression(iter, true);
        return target_expr.expr();
    } else if (iter.nextMatchesSymbol(&[_][]const u8 { "(" })) |_| {
        var expr: Expression = try self.parseExpression(iter);
        errdefer expr.deinit();

        _ = try iter.require(")");

        const paren_expr: ParenthesizedExpression = .{ .inner = expr };
        return paren_expr.expr();
    } else if (iter.nextMatchesSymbol(&[_][] const u8 { "[" })) |_| {
        var list: ArrayList(Expression) = ArrayList(Expression).init(self.allocator);
        defer list.deinit();
        errdefer Expression.deinitAll(list.items);

        var list_terminated: bool = false;
        var is_first_item: bool = true;
        while (iter.peek()) |next_tok| {
            if (next_tok.stringEquals("]")) {
                _ = iter.next();
                list_terminated = true;
                break;
            } else if (!is_first_item) {
                _ = try iter.require("|");
            }
            try list.append(try self.parsePrimaryExpression(iter));
            is_first_item = false;
        }

        if (!list_terminated) {
            return error.UnterminatedListLiteral;
        }

        const list_literal: *ListLiteral = try ListLiteral.new(self.allocator, try list.toOwnedSlice());
        return list_literal.expr();
    } else {
        // parse integer, boolean, damage type, dice, identifier, list literal
        // leaving damage expression out because it's a composite of integer/dice + damage type (see parsing damage statements)

        if (BooleanLiteral.from(self.allocator, iter)) |boolean| {
            return boolean.expr();
        } else |_| { }

        if (DiceLiteral.from(self.allocator, iter)) |dice| {
            return dice.expr();
        } else |_| { }

        if (DamageTypeLiteral.from(self.allocator, iter)) |damage_type| {
            return damage_type.expr();
        } else |_| { }

        if (IntegerLiteral.from(self.allocator, iter)) |int| {
            return int.expr();
        } else |_| { }

        if (LabelLiteral.from(self.allocator, iter)) |label| {
            return label.expr();
        } else |_| { }

        // TODO: Make this an accessor expression
        if (Identifier.from(self.allocator, iter)) |identifier| {
            return identifier.expr();
        } else |err| {
            switch (err) {
                error.OutOfMemory => {
                    std.log.err("Out of memory while trying to parse identifier.", .{});
                    return err;
                },
                else => {
                    iter.internal_iter.scroll(-1);
                }
            }
        }
    }
    const next_tok: Token = iter.peek() orelse Token.eof;
    std.log.err("Cannot parse expression beginning with token '{s}'", .{ next_tok.toString() orelse "<EOF>" });
    return error.UnexpectedToken;
}

fn parseTargetExpression(self: Parser, iter: TokenIterator, keyword_parsed: bool) anyerror!*TargetExpression {
    // target(1 from [ 1 | 2 ])

    if (!keyword_parsed) {
        _ = try iter.require("target");
    }
    _ = try iter.require("(");

    var amount: Expression = try self.parseExpression(iter);
    errdefer amount.deinit();

    _ = try iter.require("from");
    
    var pool: Expression = try self.parseExpression(iter);
    errdefer pool.deinit();

    _ = try iter.require(")");

    return try TargetExpression.new(self.allocator, amount, pool);
}
