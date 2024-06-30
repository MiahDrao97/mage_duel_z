const std = @import("std");
const parsing = @import("parsing");
const Result = parsing.Expression.Result;

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
