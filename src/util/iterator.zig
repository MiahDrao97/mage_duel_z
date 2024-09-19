const std = @import("std");
const Allocator = std.mem.Allocator;

/// Generic iterator interface for type `T`.
/// Use `from()` or `fromSliceOwned()` to create an instance from a slice.
pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        ptr:                *anyopaque,
        v_table:            *const VTable,
        allocator:          Allocator,

        pub const VTable = struct {
            next_fn:            *const fn (*anyopaque) ?T,
            set_index_fn:       *const fn (*anyopaque, usize) void,
            reset_fn:           *const fn (*anyopaque) void,
            scroll_fn:          *const fn (*anyopaque, isize) void,
            has_indexing_fn:    *const fn (*anyopaque) bool,
            clone_fn:           *const fn (*anyopaque) Allocator.Error!Iterator(T),
            get_len_fn:         *const fn (*anyopaque) usize,
            deinit_fn:          *const fn (*anyopaque) void,
        };

        var empty_instance: ?EmptyIterator = null;

        /// Return next element or null if iteration is over.
        pub fn next(self: Self) ?T {
            return self.v_table.next_fn(self.ptr);
        }

        /// Set the index to any place
        pub fn setIndex(self: Self, index: usize) void {
            self.v_table.set_index_fn(self.ptr, index);
        }

        /// Reset the iterator to its first element.
        pub fn reset(self: Self) void {
            self.v_table.reset_fn(self.ptr);
        }

        /// Scroll forward or backward x.
        pub fn scroll(self: Self, amount: isize) void {
            self.v_table.scroll_fn(self.ptr, amount);
        }

        /// Determine if this iterator can use `scroll()` or `setIndex()`.
        /// 
        /// Indexing is only available when this iterator returns the same number of elements as its `len()`.
        /// When the returned set of elements varies from the original length (like filtered down from `where()` or increased with `concat()`),
        /// this is no longer possible.
        pub fn hasIndexing(self: Self) bool {
            return self.v_table.has_indexing_fn(self.ptr);
        }

        /// Produces a clone of `Iterator(T)` (note that it is not reset).
        pub fn clone(self: Self) Allocator.Error!Iterator(T) {
            return try self.v_table.clone_fn(self.ptr);
        }

        /// Produces a clone of `Iterator(T)` that is reset.
        pub fn cloneReset(self: Self) Allocator.Error!Iterator(T) {
            var c = try self.clone();
            c.reset();
            return c;
        }

        /// Get the length of the iterator.
        /// 
        /// If `hasIndexing()` is true, then the `Iterator(T)` is expected to return this many items.
        /// Otherwise, `len()` represents a maximum length that the `Iterator(T)` can return.
        pub fn len(self: Self) usize {
            return self.v_table.get_len_fn(self.ptr);
        }

        /// Free the underlying pointer and other owned memory.
        pub fn deinit(self: Self) void {
            self.v_table.deinit_fn(self.ptr);
        }

        const EmptyIterator = struct {
            allocator: Allocator,

            const InnerSelf = @This();

            fn implNext(_: *anyopaque) ?T { return null; }

            fn implSetIndex(_: *anyopaque, _: usize) void { }

            fn implReset(_: *anyopaque) void { }

            fn implScroll(_: *anyopaque, _: isize) void { }

            fn implHasIndexing(_: *anyopaque) bool { return false; }

            fn implClone(impl: *anyopaque) Allocator.Error!Self {
                const self: *InnerSelf = @ptrCast(@alignCast(impl));
                return self.iter();
            }

            fn implLen(_: *anyopaque) usize { return 0; }

            fn implDeinit(_: *anyopaque) void { }

            pub fn iter(impl_ptr: *InnerSelf) Self {
                return Self {
                    .ptr = impl_ptr,
                    .allocator = impl_ptr.allocator,
                    .v_table = &.{
                        .next_fn = &implNext,
                        .reset_fn = &implReset,
                        .set_index_fn = &implSetIndex,
                        .scroll_fn = &implScroll,
                        .has_indexing_fn = &implHasIndexing,
                        .clone_fn = &implClone,
                        .get_len_fn = &implLen,
                        .deinit_fn = &implDeinit
                    }
                };
            }
        };

        const SliceIterator = struct {
            i: usize = 0,
            inner: []const T,
            owns_slice: bool = false,
            on_deinit: ?*const fn ([]T) void = null,
            allocator: Allocator,

            const InnerSelf = @This();

            fn implNext(impl: *anyopaque) ?T {
                const self: *InnerSelf = @ptrCast(@alignCast(impl));
                if (self.i >= self.inner.len) {
                    return null;
                }
                
                const item: T = self.inner[ @bitCast(self.i) ];
                self.i += 1;

                return item;
            }

            fn implSetIndex(impl: *anyopaque, index: usize) void {
                const self: *InnerSelf = @ptrCast(@alignCast(impl));
                self.i = index;
            }

            fn implReset(impl: *anyopaque) void {
                implSetIndex(impl, 0);
            }

            fn implScroll(impl: *anyopaque, amount: isize) void {
                const self: *InnerSelf = @ptrCast(@alignCast(impl));
                var temp: isize = @bitCast(self.i);
                temp += amount;
                if (temp <= 0) {
                    self.i = 0;
                } else {
                    self.i = @bitCast(temp);
                }
            }

            fn implHasIndexing(_: *anyopaque) bool { return true; }

            fn implClone(impl: *anyopaque) Allocator.Error!Self {
                const self: *InnerSelf = @ptrCast(@alignCast(impl));
                const ptr_cpy: *InnerSelf = try self.allocator.create(InnerSelf);
                ptr_cpy.* = self.*;

                return .{
                    .ptr = ptr_cpy,
                    .allocator = self.allocator,
                    .v_table = &.{
                        .next_fn = &implNext,
                        .reset_fn = &implReset,
                        .set_index_fn = &implSetIndex,
                        .scroll_fn = &implScroll,
                        .has_indexing_fn = &implHasIndexing,
                        .clone_fn = &implClone,
                        .get_len_fn = &implLen,
                        .deinit_fn = &implDeinit
                    },
                };
            }

            fn implLen(impl: *anyopaque) usize {
                const self: *InnerSelf = @ptrCast(@alignCast(impl));
                return self.inner.len;
            }

            fn implDeinit(impl: *anyopaque) void {
                const self: *InnerSelf = @ptrCast(@alignCast(impl));
                if (self.owns_slice) {
                    if (self.on_deinit) |on_deinit_fn| {
                        // const-cast here since the deinit function can't possibly take in a []const T slice
                        on_deinit_fn(@constCast(self.inner));
                    }
                    self.allocator.free(self.inner);
                }
                self.allocator.destroy(self);
            }

            pub fn iter(impl_ptr: *InnerSelf) Self {
                return Self {
                    .ptr = impl_ptr,
                    .allocator = impl_ptr.allocator,
                    .v_table = &.{
                        .next_fn = &implNext,
                        .reset_fn = &implReset,
                        .set_index_fn = &implSetIndex,
                        .scroll_fn = &implScroll,
                        .has_indexing_fn = &implHasIndexing,
                        .clone_fn = &implClone,
                        .get_len_fn = &implLen,
                        .deinit_fn = &implDeinit
                    }
                };
            }
        };

        /// Empty iterator with no elements.
        /// 
        /// Note that this empty instance is a singleton.
        /// `clone()` will not actually create a new instance, but just returns this one.
        /// There's no need to `deinit(), and calling that function will have no effect.
        pub fn empty(allocator: Allocator) Self {
            if (empty_instance != null) {
                return empty_instance.?.iter();
            }

            empty_instance = .{ .allocator = allocator };
            return empty_instance.?.iter();
        }

        /// The resulting iterator does not own `slice`.
        /// Allocator is used to allocate a pointer to the impementation of `Iterator(T)`.
        pub fn from(allocator: Allocator, slice: []const T) Allocator.Error!Self {
            const iter_ptr: *SliceIterator = try allocator.create(SliceIterator);
            iter_ptr.* = .{
                .inner = slice,
                .allocator = allocator
            };

            return iter_ptr.iter();
        }

        /// The resulting iterator owns `slice`.
        /// Optionally pass in a function to be called when this iterator is de-initialized (namely, deinit the elements within the slice).
        pub fn fromSliceOwned(
            allocator: Allocator,
            slice: []const T,
            on_deinit: ?*const fn ([]T) void
        ) Allocator.Error!Self {
            const iter_ptr: *SliceIterator = try allocator.create(SliceIterator);
            iter_ptr.* = .{
                .inner = slice,
                .owns_slice = true,
                .on_deinit = on_deinit,
                .allocator = allocator
            };

            return iter_ptr.iter();
        }

        /// Transforms this iterator into `Iterator(TOther)`, using the function passed in `selector`.
        /// 
        /// This new `Iterator(TOther)` owns `prev_iter`, so you only need to call `deinit()` on this one.
        pub fn select(
            prev_iter: Self,
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

                fn implHasIndexing(impl: *anyopaque) bool {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    return self.inner_iter.hasIndexing();
                }

                fn implClone(impl: *anyopaque) Allocator.Error!Iterator(TOther) {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    const c_inner: Self = try self.inner_iter.clone();
                    var c = InnerSelf {
                        .inner_iter = c_inner,
                        .select_fn = self.select_fn,
                        .allocator = self.allocator
                    };

                    return c.iter();
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
                        .v_table = &.{
                            .next_fn = &implNext,
                            .reset_fn = &implReset,
                            .set_index_fn = &implSetIndex,
                            .scroll_fn = &implScroll,
                            .has_indexing_fn = &implHasIndexing,
                            .clone_fn = &implClone,
                            .get_len_fn = &implLen,
                            .deinit_fn = &implDeinit
                        }
                    };
                }
            };
            const iter_ptr: *SelectIterator = try prev_iter.allocator.create(SelectIterator);
            iter_ptr.* = .{
                .allocator = prev_iter.allocator,
                .select_fn = selector,
                .inner_iter = prev_iter
            };

            return iter_ptr.iter();
        }

        /// Filters the iteration of `prev_iter`.
        /// `next()` returns the next element that fulfills the condition on the passed-in `filter` or `null` if no more elements are present or fulfill the condition.
        /// 
        /// ### Note
        /// `setIndex()` and `scroll()` have no effect since all indexing is lost after calling `where()`.
        /// `len()` returns the length of the inner iterator, but that does not guarantee that this new iterator will return that many elements.
        /// However, it can serve to give a max length in a buffer scenario.
        /// The inner iterator can always be reset with `reset()`.
        /// 
        /// This new `Iterator(T)` owns `prev_iter`, so you only need to call `deinit()` on this one.
        pub fn where(prev_iter: Self, filter: *const fn (T) bool) Allocator.Error!Self {
            const WhereIterator = struct {
                const InnerSelf = @This();

                filter: *const fn (T) bool,
                inner_iter: Self,
                allocator: Allocator,

                fn implNext(impl: *anyopaque) ?T {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    while (self.inner_iter.next()) |x| {
                        if (self.filter(x)) {
                            return x;
                        }
                    }
                    return null;
                }

                fn implSetIndex(_: *anyopaque, _: usize) void { }

                fn implReset(impl: *anyopaque) void {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    self.inner_iter.reset();
                }

                fn implScroll(_: *anyopaque, _: isize) void { }
                
                fn implHasIndexing(_: *anyopaque) bool { return false; }

                fn implClone(impl: *anyopaque) Allocator.Error!Self {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    const ptr_cpy: *InnerSelf = try self.allocator.create(InnerSelf);
                    ptr_cpy.* = self.*;

                    return Self {
                        .ptr = ptr_cpy,
                        .allocator = self.allocator,
                        .v_table = &.{
                            .next_fn = &implNext,
                            .reset_fn = &implReset,
                            .set_index_fn = &implSetIndex,
                            .scroll_fn = &implScroll,
                            .has_indexing_fn = &implHasIndexing,
                            .clone_fn = &implClone,
                            .get_len_fn = &implLen,
                            .deinit_fn = &implDeinit
                        },
                    };
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

                pub fn iter(impl_ptr: *InnerSelf) Self {
                    return Self {
                        .ptr = impl_ptr,
                        .allocator = impl_ptr.allocator,
                        .v_table = &.{
                            .next_fn = &implNext,
                            .reset_fn = &implReset,
                            .set_index_fn = &implSetIndex,
                            .scroll_fn = &implScroll,
                            .has_indexing_fn = &implHasIndexing,
                            .clone_fn = &implClone,
                            .get_len_fn = &implLen,
                            .deinit_fn = &implDeinit
                        },
                    };
                }
            };
            const iter_ptr: *WhereIterator = try prev_iter.allocator.create(WhereIterator);
            iter_ptr.* = .{
                .allocator = prev_iter.allocator,
                .filter = filter,
                .inner_iter = prev_iter
            };

            return iter_ptr.iter();
        }

        /// Enumerates into `buf`, starting at `self`'s current `next()` call.
        /// For the full enumeration, you may need to call `reset()`.
        /// Note that `self` may need to be deallocated via calling `deinit()` or reset for later enumeration.
        /// 
        /// Returns a slice containing the full enumeration.
        pub fn enumerateToBuffer(self: Self, buf: []T) error{NoSpaceLeft}![]T {
            if (buf.len < self.len()) {
                return error.NoSpaceLeft;
            }

            var i: usize = 0;
            while (self.next()) |x| {
                buf[i] = x;
                i += 1;
            }
            return buf[0..i];
        }

        /// Enumerates into a new slice.
        /// Note this does not reset `self` but rather starts at the current offset, so you may want to call `reset()` beforehand.
        /// Note that `self` may need to be deallocated via calling `deinit()` or reset again for later enumeration.
        /// 
        /// Caller owns the resulting slice.
        pub fn toOwnedSlice(self: Self) Allocator.Error![]T {
            var buf: []T = try self.allocator.alloc(T, self.len());

            var i: usize = 0;
            while (self.next()) |x| {
                buf[i] = x;
                i += 1;
            }

            // just the right size: return our buffer
            if (i == self.len()) {
                return buf;
            }

            defer self.allocator.free(buf);

            // pair buf down to final slice
            const final: []T = try self.allocator.alloc(T, i);
            @memcpy(final, buf[0..i]);

            return final;
        }

        /// Enumerates through `iter`, storing the results in a fresh `Iterator(T)`.
        /// `iter` is then destroyed.
        /// 
        /// This new iterator owns the results.
        /// If de-allocation is required for the individual elements when calling `deinit()` on this new `Iterator(T)`,
        /// pass in a function to be called for `on_deinit`.
        /// 
        /// ### Purpose
        /// Use this method when you need an `Iterator(T)` with indexing, but the indexing on `iter` was lost due to calling methods like `where()` or `concat()`.
        /// Apart from that specific scenario, avoid calling this method since reindexing costs time and memory.
        /// If enumeration results are required, see if it can be done by converting the results to a slice, like `enumerateToBuffer()` or `toOwnedSlice()`.
        pub fn rebuild(iter: Self, on_deinit: ?*const fn ([]T) void) Allocator.Error!Self {
            const slice: []T = try iter.toOwnedSlice();
            errdefer iter.allocator.free(slice);

            const new_iter: Self = try fromSliceOwned(iter.allocator, slice, on_deinit);

            iter.deinit();
            return new_iter;
        }

        /// Concat two iterators, `a` and `b` into a new `Iterator(T)`.
        /// It will iterate through `a`'s elements first, and then `b`'s.
        /// 
        /// ### Note
        /// `setIndex()` and `scroll()` have no effect since all indexing is lost after calling `concat()`.
        /// `len()` returns the combined lengths of `a` and `b`.
        /// On calling `reset()`, both `a` and `b` reset, and we'll resume enumerating from the beginning of `a`.
        /// 
        /// This new `Iterator(T)` owns `a` and `b`, so there's no need to call `deinit()` on either of them.
        pub fn concat(a: Self, b: Self) Allocator.Error!Self {
            const ConcatIterator = struct {
                const InnerSelf = @This();

                iter_a: Self,
                iter_b: Self,
                allocator: Allocator,

                fn implNext(impl: *anyopaque) ?T {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    if (self.iter_a.next()) |x| {
                        return x;
                    } else if (self.iter_b.next()) |y| {
                        return y;
                    }
                    return null;
                }

                fn implSetIndex(_: *anyopaque, _: usize) void { }
                
                fn implHasIndexing(_: *anyopaque) bool { return false; }

                fn implReset(impl: *anyopaque) void {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    self.iter_a.reset();
                    self.iter_b.reset();
                }

                fn implScroll(_: *anyopaque, _: isize) void { }

                fn implClone(impl: *anyopaque) Allocator.Error!Self {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    const ptr_cpy: *InnerSelf = try self.allocator.create(InnerSelf);
                    ptr_cpy.* = self.*;

                    return Self {
                        .ptr = ptr_cpy,
                        .allocator = self.allocator,
                        .v_table = &.{
                            .next_fn = &implNext,
                            .reset_fn = &implReset,
                            .set_index_fn = &implSetIndex,
                            .scroll_fn = &implScroll,
                            .has_indexing_fn = &implHasIndexing,
                            .clone_fn = &implClone,
                            .get_len_fn = &implLen,
                            .deinit_fn = &implDeinit
                        },
                    };
                }

                fn implLen(impl: *anyopaque) usize {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    return self.iter_a.len() + self.iter_b.len();
                }

                fn implDeinit(impl: *anyopaque) void {
                    const self: *InnerSelf = @ptrCast(@alignCast(impl));
                    self.iter_a.deinit();
                    self.iter_b.deinit();
                    self.allocator.destroy(self);
                }

                pub fn iter(impl_ptr: *InnerSelf) Self {
                    return Self {
                        .ptr = impl_ptr,
                        .allocator = impl_ptr.allocator,
                        .v_table = &.{
                            .next_fn = &implNext,
                            .reset_fn = &implReset,
                            .set_index_fn = &implSetIndex,
                            .scroll_fn = &implScroll,
                            .has_indexing_fn = &implHasIndexing,
                            .clone_fn = &implClone,
                            .get_len_fn = &implLen,
                            .deinit_fn = &implDeinit
                        },
                    };
                }
            };
            const iter_ptr: *ConcatIterator = try a.allocator.create(ConcatIterator);
            iter_ptr.* = .{
                .allocator = a.allocator,
                .iter_a = a,
                .iter_b = b
            };

            return iter_ptr.iter();
        }
    };
}
