pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        i: isize = 0,
        inner: []const T,

        /// Create a new instance of `Iterator(T)`.
        /// It does not own this slice, so the caller must free it.
        pub fn from(slice: []const T) Self {
            return .{ .inner = slice };
        }

        /// Return next element or null if iteration is over.
        pub fn next(self: *Self) ?T {
            if (self.i < 0 or self.i >= self.inner.len) {
                return null;
            }
            
            const item: T = self.inner[@bitCast(self.i)];
            self.i += 1;

            return item;
        }

        /// Set the index to any place
        pub fn setIndexTo(self: *Self, index: usize) void {
            self.i = index;
        }

        /// Set the index back to 0.
        pub fn reset(self: *Self) void {
            self.setIndexTo(0);
        }

        /// Scroll forward or backward x
        pub fn scroll(self: *Self, amount: isize) void {
            self.i += amount;
        }
    };
}