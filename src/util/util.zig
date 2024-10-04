const std = @import("std");
const iterator = @import("iterator.zig");

pub const Iterator = iterator.Iterator;
pub const ComparerResult = iterator.ComparerResult;
pub const Ordering = iterator.Ordering;

pub fn isWhiteSpace(char: u8) bool {
    return switch(char) {
        inline 0...' ' => true,
        else => false
    };
}

pub fn isNumeric(char: u8) bool {
    return switch (char) {
        inline '0'...'9' => true,
        else => false
    };
}

pub fn isAlpha(char: u8) bool {
     return switch (char) {
        inline 'a'...'z' => true,
        inline 'A'...'Z' => true,
        else => false
    };
}

pub fn isAlphaNumeric(char: u8) bool {
    return switch (char) {
        inline 'a'...'z' => true,
        inline 'A'...'Z' => true,
        inline '0'...'9' => true,
        else => false
    };
}

pub fn containerHasSlice(comptime T: type, container: []const []const T, slice: []const T) bool {
    for (container) |item| {
        if (std.mem.eql(T, item, slice)) {
            return true;
        }
    }
    return false;
}

fn partition(
    comptime T: type,
    slice: []T,
    left: usize,
    right: usize,
    comparer: *const fn (T, T) ComparerResult,
    ordering: Ordering
) usize {
    // i must be an isize because it's allowed to -1 at the beginning
    var i: isize = @as(isize, @bitCast(left)) - 1;

    const pivot: T = slice[right];
    std.log.debug("Left = {d}. Pivot at index[{d}]: {any}", .{ left, right, pivot });
    for (left..right) |j| {
        std.log.debug("Index[{d}]: Comparing {any} to pivot {any}", .{ j, slice[j], pivot });
        switch (ordering) {
            .asc => {
                switch(comparer(pivot, slice[j])) {
                    .greater_than => {
                        i += 1;
                        swap(T, slice, @bitCast(i), j);
                    },
                    else => { }
                }
            },
            .desc => {
                switch(comparer(pivot, slice[j])) {
                    .less_than => {
                        i += 1;
                        swap(T, slice, @bitCast(i), j);
                    },
                    else => { }
                }
            }
        }
    }
    swap(T, slice, @bitCast(i + 1), right);
    return @bitCast(i + 1);
}

fn swap(comptime T: type, slice: []T, left: usize, right: usize) void {
    if (left >= slice.len) {
        std.log.debug("Left-hand index exceeds slice side.", .{});
        return;
    }
    if (left == right) {
        std.log.debug("Indexes are equal. No swap operation taking place.", .{});
        return;
    }
    std.log.debug("Slice snapshot: [{any}] =>", .{ slice });
    const temp: T = slice[left];

    slice[left] = slice[right];
    slice[right] = temp;

    std.log.debug("                [{any}]", .{ slice });
}

pub fn sort(
    comptime T: type,
    slice: []T,
    left: usize,
    right: usize,
    comparer: *const fn (T, T) ComparerResult,
    ordering: Ordering
) void {
    if (right <= left) {
        return;
    }
    const partition_point: usize = partition(T, slice, left, right, comparer, ordering);
    sort(T, slice, left, partition_point -| 1, comparer, ordering);
    sort(T, slice, partition_point + 1, right, comparer, ordering);
}