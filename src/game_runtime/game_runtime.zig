const std = @import("std");
const parsing = @import("parsing");
const game_zones = @import("game_zones");

const CardType = game_zones.types.CardType;
const CardCost = game_zones.types.CardCost;
const Label = parsing.Label;
const Zone = game_zones.Zone;
const CardDef = parsing.CardDef;
const SymbolTable = parsing.SymbolTable;
const Symbol = parsing.Symbol;
const Scope = parsing.Scope;
const ExpressionResult = parsing.ExpressionResult;
const Allocator = std.mem.Allocator;

/// Intermediate representation of a card when it exists in the deck/discard piles
pub const IntermediateCard = struct {
    id: u32,
    type: CardType,
    cost: CardCost,

    pub fn toScope(self: IntermediateCard, allocator: Allocator) Allocator.Error!*Scope {
        var scope: *Scope = try Scope.newObj(allocator, null); //we're only adding props, so no need for a pointer
        errdefer scope.deinit();

        try scope.putValue("id", .{
            .integer = .{
                .value = @bitCast(self.id)
            }
        });

        const card_type: Label = switch (self.type) {
            .role => .{ .role },
            .tactic => .{ .tactic },
            .crystal => .{ .crystal },
            .sludge => .{ .sludge },
            .spell => |s| {
                switch (s) {
                    .attack => .{ .attack },
                    .summon => .{ .summon },
                    .utility => .{ .utility },
                    .teleport => .{ .teleport },
                    .rush => .{ .rush }
                }
            }
        };
        try scope.putValue("type", .{ .label = card_type });

        const is_spell: bool = switch(self.type) {
            .spell => true,
            else => false
        };
        try scope.putValue("isSpell", .{ .boolean = is_spell });

        return scope;
    }
};

pub const Card = struct {
    id:                 *const u32,
    name:               []const u8,
    text:               []const u8,
    script:             []const u8,
    type:               CardType,
    allocator:          Allocator,

    pub fn init(
        allocator: Allocator,
        id: u32,
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

    pub fn getCard(_: CardFactory, _: u32) !Card {
        return error.NotImplemented;
    }
};

pub const Player = struct {
    order_axis: i5 = 0,
    moral_axis: i5 = 0,
    hp: u16,
    card_factory: CardFactory,
    zones: Zones,
    allocator: Allocator,

    const Self = @This();

    const Zones = struct {
        hand: Zone(CardDef, 5),
        prepared_zone: Zone(CardDef, 5),

        pub fn isValid(_: Zone(CardDef), _: CardDef) bool {
            return true;
        }
    };

    fn implHeal(impl: ?*anyopaque, args: []ExpressionResult) !ExpressionResult {
        if (args.len != 1) {
            return error.InvalidArgumentCount;
        }
        const int: i32 = try args[0].expectType(i32);
        if (int < 0) {
            return error.ArgumentOutOfRange;
        }

        std.debug.assert(impl != null);
        const self: *Self = @ptrCast(@alignCast(impl));

        self.hp +|= int;
        return .void;
    }

    fn implTakeDamage(impl: ?*anyopaque, args: []ExpressionResult) !ExpressionResult {
        if (args.len < 1 or args.len > 2) {
            return error.InvalidArgumentCount;
        }
        const int: i32 = try args[0].expectType(i32);
        if (int < 0) {
            return error.ArgumentOutOfRange;
        }

        std.debug.assert(impl != null);
        const self: *Self = @ptrCast(@alignCast(impl));

        self.hp -|= int;
        return .void;
    }

    fn implAddMoralPoints(impl: ?*anyopaque, args: []ExpressionResult) !ExpressionResult {
        if (args.len != 1) {
            return error.InvalidArgumentCount;
        }
        const int: i32 = try args[0].expectType(i32);
        if (int < 0) {
            return error.ArgumentOutOfRange;
        }

        std.debug.assert(impl != null);
        const self: *Self = @ptrCast(@alignCast(impl));

        self.moral_axis +|= int;
        return .void;
    }

    fn implAddOrderPoints(impl: ?*anyopaque, args: []ExpressionResult) !ExpressionResult {
        if (args.len != 1) {
            return error.InvalidArgumentCount;
        }
        const int: i32 = try args[0].expectType(i32);
        if (int < 0) {
            return error.ArgumentOutOfRange;
        }

        std.debug.assert(impl != null);
        const self: *Self = @ptrCast(@alignCast(impl));

        self.order_axis +|= int;
        return .void;
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
                    const card: Card = try self.card_factory.getCard(@bitCast(id));

                    try self.zones.prepared_zone.add(card);
                    return .void;
                }
                return error.SymbolNotFound;
            },
            else => return error.InvalidArgument
        }
    }

    pub fn draw(self: *Self, card: CardDef) !void {
        try self.zones.hand.add(card);
    }

    pub fn handleCapacity(self: *Self, card: Card) !Card {
        // TODO: figure this out (we'll need the player interface to make a choice)
        const removed: Card = try self.zones.hand.removeAtIndex(0);
        // TODO: figure out how to handle bad input (or better yet, don't even allow that to happen (or better yet, don't even allow that to happen (or better yet, don't even allow that to happen (or better yet, don't even allow that to happen (or better yet, don't even allow that to happen (or better yet, don't even allow that to happen (or better yet, don't even allow that to happen (or better yet, don't even allow that to happen (or better yet, don't even allow that to happen)))))))))
        self.draw(card) catch unreachable;
        return removed;
    }

    pub fn toScope(self: *Self) !*Scope {
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
        try as_scope.putFunc("heal", &implHeal);
        try as_scope.putFunc("takeDamage", &implTakeDamage);

        return as_scope;
    }
};
