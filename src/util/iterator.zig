const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        ptr:            *anyopaque,
        allocator:      Allocator,
        next_fn:        *const fn (*anyopaque) ?T,
        set_index_fn:   *const fn (*anyopaque, usize) void,
        reset_fn:       *const fn (*anyopaque) void,
        scroll_fn:      *const fn (*anyopaque, isize) void,
        get_len_fn:     *const fn (*anyopaque) usize,
        deinit_fn:      *const fn (*anyopaque) void,

        /// Return next element or null if iteration is over.
        pub fn next(self: Self) ?T {
            return self.next_fn(self.ptr);
        }

        /// Set the index to any place
        pub fn setIndex(self: Self, index: usize) void {
            self.set_index_fn(self.ptr, index);
        }

        /// Set the index back to 0.
        pub fn reset(self: Self) void {
            self.reset_fn(self.ptr);
        }

        /// Scroll forward or backward x
        pub fn scroll(self: Self, amount: isize) void {
            self.scroll_fn(self.ptr, amount);
        }

        /// Get the length of the iterator
        pub fn len(self: Self) usize {
            return self.get_len_fn(self.ptr);
        }

        /// Free the underlying pointer
        pub fn deinit(self: *Self) void {
            self.deinit_fn(self.ptr);
            self.* = undefined;
        }

        /// The resulting iterator does not own `slice`.
        /// Allocator is used to allocate a pointer to the impementation of `Iterator(T)`.
        pub fn from(allocator: Allocator, slice: []const T) Allocator.Error!Self {
            const SliceIterator = struct {
                i: isize = 0,
                inner: []const T,
                allocator: Allocator,

                const InnerSelf = @This();

                fn implNext(impl: *anyopaque) ?T {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    if (self.i < 0 or self.i >= self.inner.len) {
                        return null;
                    }
                    
                    const item: T = self.inner[ @bitCast(self.i) ];
                    self.i += 1;

                    return item;
                }

                fn implSetIndex(impl: *anyopaque, index: usize) void {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    self.i = @bitCast(index);
                }

                fn implReset(impl: *anyopaque) void {
                    implSetIndex(impl, 0);
                }

                fn implScroll(impl: *anyopaque, amount: isize) void {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    self.i += amount;
                    if (self.i < 0) {
                        self.i = 0;
                    }
                }

                fn implLen(impl: *anyopaque) usize {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    return self.inner.len;
                }

                fn implDeinit(impl: *anyopaque) void {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    self.allocator.destroy(self);
                }

                pub fn iter(impl_ptr: *InnerSelf) Self {
                    return Self {
                        .ptr = impl_ptr,
                        .allocator = impl_ptr.allocator,
                        .next_fn = &implNext,
                        .reset_fn = &implReset,
                        .set_index_fn = &implSetIndex,
                        .scroll_fn = &implScroll,
                        .get_len_fn = &implLen,
                        .deinit_fn = &implDeinit
                    };
                }
            };
            const iter_ptr: *SliceIterator = try allocator.create(SliceIterator);

            iter_ptr.* = .{
                .inner = slice,
                .allocator = allocator
            };

            return iter_ptr.iter();
        }

        /// Transforms the result from `other_iter` into `TOther` on `next()`.
        /// This new `Iterator(TOther)` owns `other_iter`, so you only need to call `deinit()` on this one.
        pub fn select(
            other_iter: Self,
            comptime TOther: type,
            selector: *const fn (T) TOther
        ) Allocator.Error!Iterator(TOther) {
            const SelectIterator = struct {
                const InnerSelf = @This();

                select_fn: *const fn (T) TOther,
                inner_iter: Self,
                allocator: Allocator,

                fn implNext(impl: *anyopaque) ?TOther {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    if (self.inner_iter.next()) |x| {
                        return self.select_fn(x);
                    }
                    return null;
                }

                fn implSetIndex(impl: *anyopaque, index: usize) void {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    return self.inner_iter.setIndex(index);
                }

                fn implReset(impl: *anyopaque) void {
                    implSetIndex(impl, 0);
                }

                fn implScroll(impl: *anyopaque, amount: isize) void {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    self.inner_iter.scroll(amount);
                }

                fn implLen(impl: *anyopaque) usize {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    return self.inner_iter.len();
                }

                fn implDeinit(impl: *anyopaque) void {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    self.inner_iter.deinit();
                    self.allocator.destroy(self);
                }

                pub fn iter(impl_ptr: *InnerSelf) Iterator(TOther) {
                    return Iterator(TOther) {
                        .ptr = impl_ptr,
                        .allocator = impl_ptr.allocator,
                        .next_fn = &implNext,
                        .reset_fn = &implReset,
                        .set_index_fn = &implSetIndex,
                        .scroll_fn = &implScroll,
                        .get_len_fn = &implLen,
                        .deinit_fn = &implDeinit
                    };
                }
            };
            const iter_ptr: *SelectIterator = try other_iter.allocator.create(SelectIterator);

            iter_ptr.* = .{
                .allocator = other_iter.allocator,
                .select_fn = selector,
                .inner_iter = other_iter
            };

            return iter_ptr.iter();
        }
    };
}
