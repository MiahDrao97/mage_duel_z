const std = @import("std");
const parsing = @import("parsing");
const Result = parsing.ExpressionResult;

fn errFunc() !void {
    return error.Test;
}

fn some_string_non_const() []u8 {
    return @constCast("blarf");
}

fn some_string() *const [5]u8 {
    return "blarf";
}

fn some_string_const_slice() []const u8 {
    return "blarf";
}

fn some_arr(comptime T: type, size: comptime_int, values: T) [size]T {
    return [_]T { values } ** size;
}

fn ContainsArray(comptime T: type, capacity: comptime_int) type {
    return struct {
        elements: [capacity]?T = [_]?T { null } ** capacity,
    };
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
test "some string experiment" {
    const str1 = some_string();
    try std.testing.expectEqualStrings("blarf", str1);

    const str2 = some_string_const_slice();
    try std.testing.expectEqualStrings("blarf", str2);

    const str3 = some_string_non_const();
    try std.testing.expectEqualStrings("blarf", str3);
}
test "array experiment" {
    const arr = some_arr(u8, 8, 0);
    try std.testing.expectEqualSlices(u8, &[_]u8 { 0, 0, 0, 0, 0, 0, 0, 0 }, &arr);

    const arr_struct: ContainsArray(u8, 4) = .{};
    try std.testing.expectEqualSlices(?u8, &[_]?u8 { null, null, null, null }, &arr_struct.elements);
}
