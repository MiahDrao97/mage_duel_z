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
