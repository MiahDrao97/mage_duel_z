const std = @import("std");
const util = @import("util");
const Iterator = util.Iterator;
const ComparerResult = util.ComparerResult;
const Allocator = std.mem.Allocator;
const Random = std.Random;

pub const types = @import("types.zig");

pub fn Deck(comptime T: type) type {
    return struct {
        const Self = @This();

        elements: Iterator(T),
        on_deinit: ?*const fn (T) void,

        /// Assumed that this deck owns `elements`. To free, call `deinit()`.
        pub fn init(elements: Iterator(T), on_deinit: ?*const fn (T) void) error{NonIndexingIterator}!Self {
            if (!elements.hasIndexing()) {
                return error.NonIndexingIterator;
            }
            return Self {
                .elements = elements,
                .on_deinit = on_deinit
            };
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

            // if we break out of the while loop, we ran out of cards
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

            // if we break out of the while loop, we ran out of cards
            defer {
                allocator.free(items);
                self.elements.scroll(-1 * i);
            }

            const final: []T = try allocator.alloc(T, i);
            @memcpy(final, items[0..i]);

            return final;
        }

        pub fn shuffle(self: *Self) Allocator.Error!void {
            const local_ctx = struct {
                const rando: Random = std.crypto.random;

                pub fn shuffle_comparer(_: T, _: T) ComparerResult {
                    if (rando.boolean()) {
                        return .greater_than;
                    }
                    return .less_than;
                }
            };

            const shuffle_iter = try self.elements.orderBy(&local_ctx.shuffle_comparer, .asc, self.on_deinit);
            self.elements = shuffle_iter;
        }

        pub fn addToTop(self: *Self, to_add: Iterator(T)) Allocator.Error!void {
            var combined: Iterator(T) = try to_add.concat(self.elements);
            // deinit on error will destroy `to_add` as well, we only wanna destroy the new pointer.
            errdefer combined.allocator.destroy(combined.ptr);

            self.elements = try combined.rebuild(self.on_deinit);
        }

        pub fn addToBottom(self: *Self, to_add: Iterator(T)) Allocator.Error!void {
            var combined: Iterator(T) = try self.elements.concat(to_add);
            // deinit on error will destroy `to_add` as well, we only wanna destroy the new pointer.
            errdefer combined.allocator.destroy(combined.ptr);

            self.elements = try combined.rebuild(self.on_deinit);
        }
    };
}
