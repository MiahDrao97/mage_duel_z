const std = @import("std");
const parsing = @import("parsing");
const game_zones = @import("game_zones");

const CardType = game_zones.types.CardType;
const Zone = game_zones.Zone;
const CardDef = parsing.CardDef;
const SymbolTable = parsing.SymbolTable;
const Symbol = parsing.Symbol;
const Scope = parsing.Scope;
const ExpressionResult = parsing.ExpressionResult;
const Allocator = std.mem.Allocator;

pub const Card = struct {
    id:                 *const u64,
    name:               []const u8,
    text:               []const u8,
    script:             []const u8,
    type:               CardType,
    allocator:          Allocator,

    pub fn init(
        allocator: Allocator,
        id: u64,
        name: []const u8,
        text: []const u8,
        script: []const u8,
        card_type: CardType
    ) Card {
        return .{
            .id = &id,
            .name = name,
            .text = text,
            .script = script,
            .type = card_type,
            .allocator = allocator
        };
    }

    pub fn deinit(self: *Card) void {
        self.allocator.free(self.name);
        self.allocator.free(self.text);
        self.allocator.free(self.script);
        self.* = undefined;
    }
};

pub const CardFactory = struct {
    allocator: Allocator,

    pub fn getCard(_: u64) !Card {
        return error.NotImplemented;
    }
};

pub const Player = struct {
    order_axis: i5 = 0,
    moral_axis: i5 = 0,
    card_factory: CardFactory,
    zones: Zones,
    allocator: Allocator,

    const Self = @This();
    const Zones = struct {
        hand: Zone(CardDef),
        prepared_zone: Zone(CardDef),

        pub fn isValid(_: Zone(CardDef), _: CardDef) bool {
            return true;
        }
    };

    fn implAddMoralPoints(impl: ?*anyopaque, args: []ExpressionResult) !ExpressionResult {
        if (args.len != 1) {
            return error.InvalidArgumentCount;
        }
        const int: i32 = try args[0].expectType(i32);

        std.debug.assert(impl != null);
        const self: *Self = @ptrCast(@alignCast(impl));

        self.moral_axis +|= int;
        return .{ .void };
    }

    fn implAddOrderPoints(impl: ?*anyopaque, args: []ExpressionResult) !ExpressionResult {
        if (args.len != 1) {
            return error.InvalidArgumentCount;
        }
        const int: i32 = try args[0].expectType(i32);

        std.debug.assert(impl != null);
        const self: *Self = @ptrCast(@alignCast(impl));

        self.order_axis +|= int;
        return .{ .void };
    }

    fn implPrepareCard(impl: ?*anyopaque, args: []ExpressionResult) !ExpressionResult {
        if (args.len != 1) {
            return error.InvalidArgumentCount;
        }
        const card_sym: Symbol = try args[0].expectType(Symbol);
        switch (card_sym) {
            .complex_object => |o| {
                if (o.getSymbol("id")) |id_sym| {
                    const id: i32 = try (
                        try id_sym.unwrapValue()
                    ).expectType(i32);

                    std.debug.assert(impl != null);
                    const self: *Self = @ptrCast(@alignCast(impl));
                    const card: Card = try self.card_factory.getCard(@intCast(id));
                    
                    try self.zones.prepared_zone.add(card);
                    return .{ .void };
                }
                return error.SymbolNotFound;
            },
            else => return error.InvalidArgument
        }
    }

    pub fn toScope(self: *Self) Allocator.Error!*Scope {
        var as_scope: *Scope = try Scope.newObj(self.allocator, self);
        errdefer as_scope.deinit();

        try as_scope.putValue("moralScore", .{
            .integer = .{
                .value = self.moral_axis
            }
        });
        try as_scope.putValue("orderScore", .{
            .integer = .{
                .value = self.order_axis
            }
        });
        try as_scope.putFunc("addMoralPoints", &implAddMoralPoints);
        try as_scope.putFunc("addOrderPoints", &implAddOrderPoints);
        
        return as_scope;
    }
};
