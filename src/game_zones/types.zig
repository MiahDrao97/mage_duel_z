const std = @import("std");
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
    // [ opal|fire|obsidian + opal + 7 ]
    components: [9]CostComponent = [_]CostComponent { .none } ** 9,

    pub fn cost(self: *CardCost) []CostComponent {
        for (self.components, 0..) |c, i| {
            switch (c) {
                .none => {
                    if (i == 0) {
                        return &[_]CostComponent {};
                    }
                    return self.components[0..i];
                },
                else => { }
            }
        }
        return &self.components;
    }
};

pub const Crystal = enum(u8) {
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
        }
        return null;
    }
};

pub const CostComponent = union(enum) {
    /// any crystal type
    any: u8,
    /// specific crystal type (with hyrbids, because we're treating crystals as flags via bitwise operations)
    specific: u8,
    /// basically a slug to fill in the array
    none: void,

    pub fn includes(self: CostComponent, crystal: Crystal) bool {
        switch (self) {
            .specific => |c| {
                return c & @intFromEnum(crystal) == @intFromEnum(crystal);
            },
            .any => return true,
            .none => return false,
        }
    }
};
