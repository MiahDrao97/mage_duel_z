const std = @import("std");
const util = @import("util");

pub fn main() !void {
    try std.io.getStdOut().writer().print("Hello, world", .{});
}
