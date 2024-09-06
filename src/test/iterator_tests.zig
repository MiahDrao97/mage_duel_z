const Iterator = @import("util").Iterator;
const std = @import("std");
const testing = std.testing;

fn numToStr(num: u8) ![]u8 {
    return try std.fmt.allocPrint(testing.allocator, "{d}", .{ num });
}

test {
    var nums: [3]u8 = [_]u8 { 1, 2, 3 };
    var iter = try Iterator(u8).from(testing.allocator, &nums);
    defer iter.deinit();

    for (0..2) |i| {
        try testing.expect(iter.next().? == i + 1);
    }
}
test {
    var nums: [3]u8 = [_]u8 { 1, 2, 3 };
    var iter = try Iterator(u8).from(testing.allocator, &nums);
    var iter2 = try iter.select(anyerror![]u8, &numToStr);
    defer iter2.deinit();

    try testing.expect(iter2.len() == 3);

    for (0..2) |i| {
        var buf: [1]u8 = undefined;
        const expected: []u8 = try std.fmt.bufPrint(&buf, "{d}", .{i + 1});

        const actual: []u8 = try iter2.next().?;
        defer testing.allocator.free(actual);

        try testing.expect(std.mem.eql(u8, actual, expected));
    }
}
