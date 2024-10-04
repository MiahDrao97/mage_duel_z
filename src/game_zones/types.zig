const std = @import("std");
const util = @import("util");
const Random = std.Random;

pub const DamageType  = enum {
    Fire,
    Lightning,
    Force,
    Divine,
    Acid,
    Necrotic,
    Ice,
    Psychic,

    pub fn try_from(str: []const u8) ?DamageType {
        if (std.mem.eql(u8, str, "fire")) {
            return .Fire;
        } else if (std.mem.eql(u8, str, "lightning")) {
            return .Lightning;
        } else if (std.mem.eql(u8, str, "force")) {
            return .Force;
        } else if (std.mem.eql(u8, str, "divine")) {
            return .Divine;
        } else if (std.mem.eql(u8, str, "acid")) {
            return .Acid;
        } else if (std.mem.eql(u8, str, "necrotic")) {
            return .Necrotic;
        } else if (std.mem.eql(u8, str, "ice")) {
            return .Ice;
        } else if (std.mem.eql(u8, str, "psychic")) {
            return .Psychic;
        }
        return null;
    }
};

pub const DamageTransaction = struct {
    damage_type: DamageType,
    modifier: i32 = 0,
    dice: ?Dice = null,
    repetitions: u16 = 1
};

pub const Dice = struct {
    sides: u8,
    rand: Random,

    /// Creates a Dice, where `sides` must be greater than 0 or it returns
    /// `error.OutOfRange`.
    pub fn new(sides: u8) error{OutOfRange}!Dice {
        if (sides < 1) {
            return error.OutOfRange;
        }
        return Dice {
            .sides = sides,
            .rand = std.crypto.random
        };
    }

    pub fn roll(self: Dice) u8 {
        return self.rand.intRangeAtMost(u8, 1, self.sides);
    }
};

pub const CardType = union(enum) {
    crystal: void,
    spell: SpellType,
    tactic: void,
    role: void,
    sludge: void,
};

pub const SpellType = enum {
    rush,
    attack,
    utility,
    teleport,
    summon
};

pub const CardCost = struct {
    // [ opal|ruby|obsidian + opal + 3 ] = [ 145, 1, 255, 255, 255, 0 ... ]
    components: [16]u8 = [_]u8 { 0 } ** 16,

    const ctx = struct {
        pub fn comparer(a: u8, b: u8) util.ComparerResult {
            if (a > b) {
               return .greater_than;
            } else if (a < b) {
                return .less_than;
            }
            return .equal_to;
        }
    };

    pub fn add(self: *CardCost, components: []u8) error{NoMoreComponentSlots}!void {
        if (self.cursor()) |idx| {
            if (components.len + idx > 15) {
                return error.NoMoreComponentSlots;
            }
            @memcpy(self.components[idx..(idx + components.len)], components);
        } else {
            return error.NoMoreComponentSlots;
        }
    }

    pub fn cursor(self: *CardCost) ?usize {
        util.sort(u8, &self.components, 0, 15, &ctx.comparer, .desc);
        for (self.components, 0..) |c, i| {
            if (c == 0) {
                return i;
            }
        }
        return null;
    }

    // would return [ 255, 255, 255, 145, 1 ]
    pub fn cost(self: *CardCost) []u8 {
        if (self.cursor()) |idx| {
            if (idx == 0) {
                return &[_]u8 {};
            }
            return self.components[0..idx];
        }
        return &self.components;
    }
};

pub const Crystal = enum(u8) {
    /// none
    none = 0,
    /// divine
    opal = 1,
    /// force
    sapphire = 2,
    /// ice
    amethyst = 4,
    /// psychic
    geode = 8,
    /// fire
    ruby = 16,
    /// lightning
    topaz = 32,
    /// acid
    emerald = 64,
    /// necrotic
    obsidian = 128,
    /// any
    any = 255,

    pub fn try_parse(str: []const u8) ?Crystal {
        if (std.mem.eql(u8, str, @tagName(.opal))) {
            return .opal;
        } else if (std.mem.eql(u8, str, @tagName(.sapphire))) {
            return .sapphire;
        } else if (std.mem.eql(u8, str, @tagName(.amethyst))) {
            return .amethyst;
        } else if (std.mem.eql(u8, str, @tagName(.geode))) {
            return .geode;
        } else if (std.mem.eql(u8, str, @tagName(.ruby))) {
            return .ruby;
        } else if (std.mem.eql(u8, str, @tagName(.topaz))) {
            return .topaz;
        } else if (std.mem.eql(u8, str, @tagName(.emerald))) {
            return .emerald;
        } else if (std.mem.eql(u8, str, @tagName(.obsidian))) {
            return .obsidian;
        } else if (std.mem.eql(u8, str, @tagName(.any))) {
            return .any;
        }
        return null;
    }
};

