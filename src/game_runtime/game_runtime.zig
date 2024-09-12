const std = @import("std");
const parsing = @import("parsing");

const CardDef = parsing.CardDef;
const SymbolTable = parsing.SymbolTable;
const Allocator = std.mem.Allocator;

pub const Card = struct {
    id:             *const u64,
    name:           []const u8,
    text:           []const u8,
    card_def:       *const CardDef,
    allocator:      Allocator,

    pub fn init(
        allocator: Allocator,
        id: u64,
        name: []const u8,
        text: []const u8,
        card_def: *const CardDef
    ) Card {
        return .{
            .id = &id,
            .name = name,
            .text = text,
            .card_def = card_def,
            .allocator = allocator
        };
    }

    pub fn deinit(self: *Card) void {
        self.allocator.free(self.name);
        self.allocator.free(self.text);
        self.allocator.destroy(self.card_def);
        self.* = undefined;
    }
};
