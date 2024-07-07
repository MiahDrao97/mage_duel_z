pub const tokenizer_tests = @import("tokenizer_tests.zig");
pub const scratch_tests = @import("scratch_tests.zig");
pub const symbol_table_tests = @import("symbol_table_tests.zig");

// this just adds an additional test to the others
test {
    @import("std").testing.refAllDecls(@This());
}
