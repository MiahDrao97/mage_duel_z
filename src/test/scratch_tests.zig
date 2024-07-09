const std = @import("std");
const parsing = @import("parsing");
const Result = parsing.ExpressionResult;

fn errFunc() !void {
    return error.Test;
}

test "type equal" {
    const type_1 = u8;
    const type_2 = u8;

    try std.testing.expectEqual(type_1, type_2);
}
test "expect result" {
    const result: Result = .{ .boolean = true };
    const cast_result: bool = try result.expectType(bool);

    try std.testing.expect(cast_result);
}
test "stack trace experiment" {
    errFunc() catch {
        const stack_trace: ?*std.builtin.StackTrace = @errorReturnTrace();
        try std.testing.expect(stack_trace != null);
        // std.debug.print("Err: {any}", .{ stack_trace.? });
    };
}
