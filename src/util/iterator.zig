pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        i: usize = 0,
        inner: []const T,

        /// Create a new instance of `Iterator(T)`.
        /// It does not own this slice, so the caller must free it.
        pub fn from(slice: []const T) Self {
            return Self {
                .inner = slice
            };
        }

        /// Return next element or null if iteration is over.
        pub fn next(self: *Self) ?T {
            if (self.i >= self.inner.len) {
                return null;
            }
            
            const item: T = self.inner[self.i];
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
    };
}