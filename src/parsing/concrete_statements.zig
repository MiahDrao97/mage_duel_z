const std = @import("std");

const imports = struct {
    usingnamespace @import("tokens.zig");
    usingnamespace @import("util");
    usingnamespace @import("game_zones");
    usingnamespace @import("expression.zig");
    usingnamespace @import("Statement.zig");
};

const Statement = imports.Statement;
const Expression = imports.Expression;
const SymbolTable = imports.SymbolTable;
const Symbol = imports.Symbol;
const Result = imports.Result;
const Error = imports.Error;
const FunctionDef = imports.FunctionDef;

const FunctionCall = struct {
    name: []const u8,
    args: []Expression,

    pub fn execute(this_ptr: *anyopaque, symbol_table: SymbolTable) !void {
        const self: *FunctionCall = @ptrCast(@alignCast(this_ptr));
        
        const function_def: FunctionDef = symbol_table.getSymbol(self.name) orelse return error.FunctionDefinitionNotFound;

        const args_list: []Result = symbol_table.allocator.alloc(Result, self.args.len);
        defer symbol_table.allocator.free(args_list);
        
        for (self.args, 0..) |arg, i| {
            args_list[i] = try arg.evaluate(symbol_table);
        }

        try function_def(args_list);
    }

    pub fn evaluate(this_ptr: *anyopaque, symbol_table: SymbolTable) Error!Result {
        const self: *FunctionCall = @ptrCast(@alignCast(this_ptr));
        const function_def: FunctionDef = symbol_table.getSymbol(self.name) orelse return error.FunctionDefinitionNotFound;

        const args_list: []Result = symbol_table.allocator.alloc(Result, self.args.len);
        defer symbol_table.allocator.free(args_list);
        
        for (self.args, 0..) |arg, i| {
            args_list[i] = try arg.evaluate(symbol_table);
        }

        return function_def(args_list) catch |err| {
            std.log.err("Caught error while executing '{s}(...)': {any}-->\n{s}", .{
                self.name,
                err,
                @errorReturnTrace() orelse "[Stack trace unavailable]"
            });
            return Error.FailedFunctionInvocation;
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
