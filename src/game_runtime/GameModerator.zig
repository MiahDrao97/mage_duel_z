const std = @import("std");
const parsing = @import("parsing");
const game_zones = @import("game_zones");
const game_runtime = @import("game_runtime.zig");

const Scope = parsing.Scope;
const ExpressionResult = parsing.ExpressionResult;
const Symbol = parsing.Symbol;
const Player = game_runtime.Player;
const Deck = game_zones.Deck;
const Zone = game_zones.Zone;
const CardFactory = game_runtime.CardFactory;
const Card = game_runtime.Card;
const Allocator = std.mem.Allocator;

pub const GameModerator = @This();

card_factory:               CardFactory,
players:                    []Player,
spell_deck:                 Deck(u32),
monster_deck:               Deck(u32),
monster_zone:               Zone(Card),
active_player_idx:          usize = 0,
allocator:                  Allocator,

fn implDraw(impl: ?*anyopaque, args: []ExpressionResult) !ExpressionResult {
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
                const self: *GameModerator = @ptrCast(@alignCast(impl));
                const card: Card = try self.card_factory.getCard(@intCast(id));
                self.activePlayer().draw(card) catch |err| {
                    self.handleFailToDraw(self.activePlayer(), card, err);
                };
                return .void;
            }
            return error.SymbolNotFound;
        },
        else => return error.InvalidArgument
    }
}

fn implYou(impl: ?*anyopaque, _: []ExpressionResult) !ExpressionResult {
    std.debug.assert(impl != null);
    const self: *GameModerator = @ptrCast(@alignCast(impl));

    return .{
        .symbol = .{
            .complex_object = try self.activePlayer().toScope()
        }
    };
}

fn handleFailToDraw(_: GameModerator, player: Player, card: Card, err: anyerror) void {
    switch (err) {
        error.AtCapacity => {
            // TODO: put this in the discard pile
            _ = try player.handleCapacity(card);
        },
        error.InvalidElement => {

        },
        else => unreachable
    }
}

pub fn addGlobalFunctions(self: *GameModerator, scope: *Scope) !void {
    scope.obj_ptr = self;
    try scope.putFunc("draw", &implDraw);
    try scope.putFunc("You", &implYou);
}

pub fn activePlayer(self: GameModerator) Player {
    return self.players[ self.active_player_idx ];
}

pub fn endTurn(self: *GameModerator) void {
    if (self.active_player_idx >= self.players.len) {
        self.active_player_idx = 0;
    }
    self.active_player_idx += 1;
}

pub fn deinit(self: *GameModerator) void {
    self.allocator.free(self.players);
    self.* = undefined;
}
