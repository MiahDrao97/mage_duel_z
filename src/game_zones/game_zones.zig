const std = @import("std");
const Iterator = @import("util").Iterator;
const Allocator = std.mem.Allocator;

pub const types = @import("types.zig");

pub fn Deck(comptime T: type) type {
    return struct {
        const Self = @This();

        elements:       Iterator(T),
        allocator:      Allocator,

        pub fn draw(self: Self) ?T {
            return self.elements.next();
        }

        pub fn drawMany(self: Self, amt: usize) Allocator.Error![]T {
            const items: []T = try self.allocator.alloc(T, amt);

            var i: usize = 0;
            while (self.draw()) |x| {
                items[i] = x;
                i += 1;

                if (i == amt) {
                    return items;
                }
            }

            // if break out of the while loop, we ran out of cards
            defer self.allocator.free(items);

            const final: []T = try self.allocator.alloc(T, i);
            @memcpy(final, items[0..i]);

            return final;
        }

        pub fn peek(self: Self) ?T {
            if (self.elements.next()) |x| {
                self.elements.scroll(-1);
                return x;
            }
            return null;
        }

        pub fn peekMany(self: Self, amt: usize) []T {
            const items: []T = try self.allocator.alloc(T, amt);

            var i: usize = 0;
            while (self.elements.next()) |x| {
                items[i] = x;
                i += 1;

                if (i == amt) {
                    self.elements.scroll(-1 * amt);
                    return items;
                }
            }

            // if break out of the while loop, we ran out of cards
            defer {
                self.allocator.free(items);
                self.elements.scroll(-1 * i);
            }

            const final: []T = try self.allocator.alloc(T, i);
            @memcpy(final, items[0..i]);

            return final;
        }
    };
}
