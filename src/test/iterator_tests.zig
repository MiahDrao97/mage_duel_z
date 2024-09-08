const Iterator = @import("util").Iterator;
const std = @import("std");
const testing = std.testing;

fn numToStr(num: u8) ![]u8 {
    return try std.fmt.allocPrint(testing.allocator, "{d}", .{ num });
}

fn isEven(num: u8) bool {
    return num % 2 == 0;
}

test "from" {
    var nums: [3]u8 = [_]u8 { 1, 2, 3 };
    var iter = try Iterator(u8).from(testing.allocator, &nums);
    defer iter.deinit();

    var i: usize = 0;
    while (iter.next()) |x| {
        i += 1;
        try testing.expect(x == i);
    }

    try testing.expect(i == 3);
}
test "select" {
    var nums: [3]u8 = [_]u8 { 1, 2, 3 };
    var inner = try Iterator(u8).from(testing.allocator, &nums);
    var iter = try inner.select(anyerror![]u8, &numToStr);
    defer iter.deinit();

    try testing.expect(iter.len() == 3);

    var i: usize = 0;
    while (iter.next()) |x| {
        i += 1;
        var buf: [1]u8 = undefined;
        const expected: []u8 = try std.fmt.bufPrint(&buf, "{d}", .{i});

        const actual: []u8 = try x;
        defer testing.allocator.free(actual);

        try testing.expect(std.mem.eql(u8, actual, expected));
    }

    try testing.expect(i == 3);
}
test "cloneReset" {
    var nums: [3]u8 = [_]u8 { 1, 2, 3 };
    var iter = try Iterator(u8).from(testing.allocator, &nums);
    defer iter.deinit();

    try testing.expect(iter.next() == 1);

    var clone = try iter.cloneReset();
    defer clone.deinit();

    var i: usize = 0;
    while (clone.next()) |x| {
        i += 1;
        try testing.expect(x == i);
    }

    try testing.expect(iter.next() == 2);
}
test "where" {
    {
        var nums: [3]u8 = [_]u8 { 1, 2, 3 };
        var inner = try Iterator(u8).from(testing.allocator, &nums);
        var iter = try inner.where(&isEven);
        defer iter.deinit();

        try testing.expect(iter.len() == 3);

        var i: usize = 0;
        while (iter.next()) |x| {
            try testing.expect(x == 2);
            i += 1;
        }

        try testing.expect(i == 1);
    }
    {
        var odds: [3]u8 = [_]u8 { 1, 3, 5 };
        var inner = try Iterator(u8).from(testing.allocator, &odds);
        var iter = try inner.where(&isEven);
        defer iter.deinit();

        try testing.expect(iter.len() == 3);

        var i: usize = 0;
        while (iter.next()) |_| {
            // should not enter this block
            i += 1;
        }

        try testing.expect(i == 0);
    }
}
test "toOwnedSlice" {
    var nums: [3]u8 = [_]u8 { 1, 2, 3 };
    var inner = try Iterator(u8).from(testing.allocator, &nums);
    var iter = try inner.where(&isEven);
    defer iter.deinit();

    try testing.expect(iter.len() == 3);

    var i: usize = 0;
    while (iter.next()) |x| {
        try testing.expect(x == 2);
        i += 1;
    }

    try testing.expect(i == 1);

    iter.reset();
    const slice: []u8 = try iter.toOwnedSlice();
    defer testing.allocator.free(slice);

    try testing.expect(slice.len == 1);
    try testing.expect(slice[0] == 2);
}
test "empty" {
    var iter = Iterator(u8).empty(testing.allocator);

    try testing.expect(iter.len() == 0);
    try testing.expect(iter.next() == null);

    var next_iter = try iter.where(&isEven);
    defer next_iter.deinit(); // <= we do need to deinit() this one because we allocated a new pointer

    try testing.expect(next_iter.len() == 0);
    try testing.expect(next_iter.next() == null);

    var next_empty = Iterator(u8).empty(testing.allocator);

    try testing.expect(next_empty.len() == 0);
    try testing.expect(next_empty.next() == null);

    var next_empty_2 = try iter.cloneReset();

    try testing.expect(next_empty_2.len() == 0);
    try testing.expect(next_empty_2.next() == null);
}
test "concat" {
    {
        var nums1: [3]u8 = [_]u8 { 1, 2, 3 };
        var nums2: [3]u8 = [_]u8 { 4, 5, 6 };
        const a = try Iterator(u8).from(testing.allocator, &nums1);
        const b = try Iterator(u8).from(testing.allocator, &nums2);
        var iter = try a.concat(b);

        var new_iter: Iterator(u8) = undefined;
        {
            errdefer iter.deinit();

            try testing.expect(iter.len() == 6);

            var i: usize = 0;
            while (iter.next()) |x| {
                i += 1;
                try testing.expect(x == i);
            }

            try testing.expect(i == 6);

            iter.reset();

            new_iter = try iter.where(&isEven);
        }
        defer new_iter.deinit();

        try testing.expect(new_iter.len() == 6);
        try testing.expect(!new_iter.hasIndexing());

        var i: usize = 0;
        while (new_iter.next()) |x| {
            i += 1;
            // should only be the evens
            try testing.expect(x == (i * 2));
        }

        try testing.expect(i == 3);
    }
    {
        var empty = Iterator(u8).empty(testing.allocator);

        var nums: [3]u8 = [_]u8 { 1, 2, 3 };
        var other = try Iterator(u8).from(testing.allocator, &nums);
        
        var iter = empty.concat(other) catch |err| {
            other.deinit();
            return err;
        };
        defer iter.deinit();

        try testing.expect(iter.len() == 3);

        var i: usize = 0;
        while (iter.next()) |x| {
            i += 1;
            try testing.expect(x == i);
        }

        try testing.expect(i == 3);

        // need to reset before concating...
        iter.reset();
        // assign empty to it
        iter = try iter.concat(Iterator(u8).empty(testing.allocator));

        try testing.expect(iter.len() == 3);

        i = 0;
        while (iter.next()) |x| {
            i += 1;
            try testing.expect(x == i);
        }

        try testing.expect(i == 3);
    }
}