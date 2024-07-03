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

    pub fn from(str: []const u8) error{ParseDamageTypeError}!DamageType {
        if (std.mem.eql(u8, str, "fire")) {
            return DamageType.Fire;
        } else if (std.mem.eql(u8, str, "lightning")) {
            return DamageType.Lightning;
        } else if (std.mem.eql(u8, str, "force")) {
            return DamageType.Force;
        } else if (std.mem.eql(u8, str, "divine")) {
            return DamageType.Divine;
        } else if (std.mem.eql(u8, str, "acid")) {
            return DamageType.Acid;
        } else if (std.mem.eql(u8, str, "necrotic")) {
            return DamageType.Necrotic;
        } else if (std.mem.eql(u8, str, "ice")) {
            return DamageType.Ice;
        } else if (std.mem.eql(u8, str, "psychic")) {
            return DamageType.Psychic;
        }
        return error.ParseDamageTypeError;
    }
};

pub const DamageTransaction = struct {
    damage_type: DamageType,
    amount: u16,
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
