const std = @import("std");
const Iterator = @import("util").Iterator;
const Allocator = std.mem.Allocator;

pub const types = @import("types.zig");

pub fn Deck(comptime T: type) type {
    return struct {
        const Self = @This();

        elements: Iterator(T),

        /// Assumed that this deck owns `elements`. To free, call `deinit()`.
        pub fn init(elements: Iterator(T)) error{NonIndexingIterator}!Self {
            if (!elements.hasIndexing()) {
                return error.NonIndexingIterator;
            }
            return Self { .elements = elements };
        }

        pub fn deinit(self: *Self) void {
            self.elements.deinit();
            self.* = undefined;
        }

        pub fn draw(self: Self) ?T {
            return self.elements.next();
        }

        pub fn drawMany(self: Self, allocator: Allocator, amt: usize) Allocator.Error![]T {
            const items: []T = try allocator.alloc(T, amt);

            var i: usize = 0;
            while (self.draw()) |x| {
                items[i] = x;
                i += 1;

                if (i == amt) {
                    return items;
                }
            }

            // if break out of the while loop, we ran out of cards
            defer allocator.free(items);

            const final: []T = try allocator.alloc(T, i);
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

        pub fn peekMany(self: Self, allocator: Allocator, amt: usize) []T {
            const items: []T = try allocator.alloc(T, amt);

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
                allocator.free(items);
                self.elements.scroll(-1 * i);
            }

            const final: []T = try allocator.alloc(T, i);
            @memcpy(final, items[0..i]);

            return final;
        }
    };
}
