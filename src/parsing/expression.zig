const std = @import("std");

const imports = struct {
    usingnamespace @import("tokens.zig");
    usingnamespace @import("util");
    usingnamespace @import("game_zones");
};

const DamageType = imports.types.DamageType;
const Dice = imports.types.Dice;
const DamageTransaction = imports.types.DamageTransaction;
const CardType = imports.types.CardType;
const StringHashMap = std.StringHashMap;
const Allocator = std.mem.Allocator;
const TokenIterator = imports.TokenIterator;
const ParseTokenError = imports.ParseTokenError;
const Wyhash = std.hash.Wyhash;

pub const Result = union(enum) {
    integer: IntResult,
    boolean: bool,
    damage_type: DamageType,
    damage_transaction: DamageTransaction,
    dice: DiceResult,
    list: ListResult,
    label: Label,
    identifier: Symbol,
    crystal: u8,
    err: []const u8,
    void: void,

    pub fn as(self: Result, comptime T: type) ?T {
        switch (self) {
            .integer => |i| {
                if (T == i32) {
                    return i.value;
                } else if (T == IntResult) {
                    return i;
                }
            },
            .err => return null,
            inline else => |x| {
                if (@TypeOf(x) == T) {
                    return x;
                }
            }
        }
        return null;
    }

    pub fn expectType(self: Result, comptime T: type) Error!T {
        if (self.hasError()) |err| {
            std.log.err("Result has error: '{s}'", .{ err });
            return Error.HasError;
        }
        return self.as(T) orelse Error.UnexpectedType;
    }

    pub fn hasError(self: Result) ?[]const u8 {
        switch (self) {
            .err => |e| return e,
            else => return null
        }
    }

    const Context = struct {
        pub fn hash(_: Context, k: Result) u32 {
            var hash_result: u64 = 0;
            var result_type: u8 = 0;
            switch (k) {
                .void, .err => hash_result = 0,
                .integer => |int| {
                    result_type = 1;
                    const bytes: [@sizeOf(i32)]u8 = std.mem.toBytes(int.value);
                    const hash_size: comptime_int = @sizeOf(i32) + 1;
                    var to_hash: [hash_size]u8 = undefined;
                    to_hash[0] = result_type;
                    for (1..@intCast(hash_size)) |i| {
                        to_hash[i] = bytes[i - 1];
                    }
                    hash_result = Wyhash.hash(0, &to_hash);
                },
                .boolean => |boolean| {
                    result_type = 2;
                    const bytes: [@sizeOf(bool)]u8 = std.mem.toBytes(boolean);
                    const hash_size: comptime_int = @sizeOf(bool) + 1;
                    var to_hash: [hash_size]u8 = undefined;
                    to_hash[0] = result_type;
                    for (1..@intCast(hash_size)) |i| {
                        to_hash[i] = bytes[i - 1];
                    }
                    hash_result = Wyhash.hash(0, &to_hash);
                },
                .damage_type => |damage_type| {
                    result_type = 3;
                    const bytes: [@sizeOf(DamageType)]u8 = std.mem.toBytes(damage_type);
                    const hash_size: comptime_int = @sizeOf(DamageType) + 1;
                    var to_hash: [hash_size]u8 = undefined;
                    to_hash[0] = result_type;
                    for (1..@intCast(hash_size)) |i| {
                        to_hash[i] = bytes[i - 1];
                    }
                    hash_result = Wyhash.hash(0, &to_hash);
                },
                .damage_transaction => |damage_transaction| {
                    result_type = 4;
                    const bytes: [@sizeOf(DamageTransaction)]u8 = std.mem.toBytes(damage_transaction);
                    const hash_size: comptime_int = @sizeOf(DamageTransaction) + 1;
                    var to_hash: [hash_size]u8 = undefined;
                    to_hash[0] = result_type;
                    for (1..@intCast(hash_size)) |i| {
                        to_hash[i] = bytes[i - 1];
                    }
                    hash_result = Wyhash.hash(0, &to_hash);
                },
                .dice => |dice| {
                    result_type = 5;
                    const bytes: [@sizeOf(DiceResult)]u8 = std.mem.toBytes(dice);
                    const hash_size: comptime_int = @sizeOf(DiceResult) + 1;
                    var to_hash: [hash_size]u8 = undefined;
                    to_hash[0] = result_type;
                    for (1..@intCast(hash_size)) |i| {
                        to_hash[i] = bytes[i - 1];
                    }
                    hash_result = Wyhash.hash(0, &to_hash);
                },
                .label => |label| {
                    result_type = 6;
                    const bytes: [@sizeOf(Label)]u8 = std.mem.toBytes(label);
                    const hash_size: comptime_int = @sizeOf(Label) + 1;
                    var to_hash: [hash_size]u8 = undefined;
                    to_hash[0] = result_type;
                    for (1..@intCast(hash_size)) |i| {
                        to_hash[i] = bytes[i - 1];
                    }
                    hash_result = Wyhash.hash(0, &to_hash);
                },
                .identifier => |identifier| {
                    result_type = 6;
                    var ptr: usize = undefined;
                    switch (identifier) {
                        .value => |v| ptr = @intFromPtr(v),
                        .function => |f| ptr = @intFromPtr(f),
                        .complex_object => |o| ptr = @intFromPtr(o)
                    }
                    const bytes: [@sizeOf(usize)]u8 = std.mem.toBytes(ptr);
                    const hash_size: comptime_int = @sizeOf(usize) + 1;
                    var to_hash: [hash_size]u8 = undefined;
                    to_hash[0] = result_type;
                    for (1..@intCast(hash_size)) |i| {
                        to_hash[i] = bytes[i - 1];
                    }
                    hash_result = Wyhash.hash(0, &to_hash);
                },
                .crystal => |c| {
                    result_type = 7;
                    const bytes: [@sizeOf(u8)]u8 = std.mem.toBytes(c);
                    const hash_size: comptime_int = @sizeOf(u8) + 1;
                    var to_hash: [hash_size]u8 = undefined;
                    to_hash[0] = result_type;
                    for (1..@intCast(hash_size)) |i| {
                        to_hash[i] = bytes[i - 1];
                    }
                    hash_result = Wyhash.hash(0, &to_hash);
                },
                .list => |list| {
                    result_type = 9;
                    // TODO: do we wanna hash each item?
                    // Right now, we're not evaluating the contents...
                    const ptr: usize = @intFromPtr(list.items.ptr);
                    const bytes: [@sizeOf(usize)]u8 = std.mem.toBytes(ptr);
                    const hash_size: comptime_int = @sizeOf(usize) + 1;
                    var to_hash: [hash_size]u8 = undefined;
                    to_hash[0] = result_type;
                    for (1..@intCast(hash_size)) |i| {
                        to_hash[i] = bytes[i - 1];
                    }
                    hash_result = Wyhash.hash(0, &to_hash);
                }
            }
            return @truncate(hash_result);
        }

        pub fn eql(self: Context, a: Result, b: Result, _: usize) bool {
            return self.hash(a) == self.hash(b);
        }
    };
};

pub const ResultHashSet = std.ArrayHashMap(Result, void, Result.Context, false);

pub const DiceResult = struct {
    count: u16,
    dice: Dice,
    modifier: i32 = 0,
};

pub const IntResult = struct {
    value: i32,
    up_to: bool = false,
};

pub const ListResult = struct {
    items: []Result,
    /// The tag name of the contained elements. Will be null if the list is empty.
    component_type: ?[]const u8,
    allocator: Allocator,

    /// Initialize a `ListResult` with elements and the allocator that allocated them.
    pub fn from(allocator: Allocator, elements: []Result) Error!ListResult {
        if (elements.len == 0) {
            return .{
                .items = elements,
                .component_type = null,
                .allocator = allocator
            };
        }

        const component_type: []const u8 = @tagName(elements[0]);
        for (elements) |e| {
            if (!std.mem.eql(u8, @tagName(e), component_type)) {
                return Error.ElementTypesVary;
            }
        }
        return .{
            .items = elements,
            .component_type = component_type,
            .allocator = allocator
        };
    }

    /// Takes two `ListResult`'s, combining their items.
    /// This results in a new `ListResult`, so be sure to destroy the other two.
    pub fn append(self: ListResult, other: ListResult) Error!ListResult {
        if (self.component_type != null
            and other.component_type != null
            and !std.mem.eql(u8, self.component_type.?, other.component_type.?)
        ) {
            return Error.ElementTypesVary;
        }

        const new_results: []Result = try self.allocator.alloc(Result, self.items.len + other.items.len);
        errdefer self.allocator.free(new_results);

        // copy everything
        var i: usize = 0;
        for (self.items) |item| {
            new_results[i] = item;
            i += 1;
        }
        for (other.items) |item| {
            new_results[i] = item;
            i += 1;
        }

        return try from(self.allocator, new_results);
    }

    /// Takes two `ListResult`'s, combining their items, but only items not already contained in `self`.
    /// This results in a new `ListResult`, so be sure to destroy the other two.
    pub fn appendUnique(self: ListResult, other: ListResult) Error!ListResult {
        if (self.component_type != null
            and other.component_type != null
            and !std.mem.eql(u8, self.component_type.?, other.component_type.?)
        ) {
            return Error.ElementTypesVary;
        }

        var hash_set = ResultHashSet.init(self.allocator);
        defer hash_set.deinit();

        // copy the items
        for (self.items) |item| {
            try hash_set.put(item, {});
        }
        for (other.items) |item| {
            try hash_set.put(item, {});
        }

        const combined_items: []Result = hash_set.keys();
        // copy the keys (before we nuke the above hash set)
        const copied_items: []Result = try self.allocator.alloc(Result, combined_items.len);
        errdefer self.allocator.free(copied_items);
        @memcpy(copied_items, combined_items);

        return try from(self.allocator, copied_items);
    }

    /// Creates a new `ListResult` with `item` at the end.
    /// Be sure to destroy the original `ListResult` afterward.
    pub fn appendOne(self: ListResult, new: Result) Error!ListResult {
        if (self.component_type != null and !std.mem.eql(u8, self.component_type.?, @tagName(new))) {
            return Error.ElementTypesVary;
        }

        const new_results: []Result = try self.allocator.alloc(Result, self.items.len + 1);
        errdefer self.allocator.free(new_results);

        // copy everything
        var i: usize = 0;
        for (self.items) |item| {
            new_results[i] = item;
            i += 1;
        }
        new_results[i] = new;

        return try from(self.allocator, new_results);
    }

    /// Creates a new `ListResult` with `item` at the end, ensuring each element is unique.
    /// Be sure to destroy the original `ListResult` afterward.
    pub fn appendOneUnique(self: ListResult, new: Result) Error!ListResult {
        if (self.component_type != null and !std.mem.eql(u8, self.component_type.?, @tagName(new))) {
            return Error.ElementTypesVary;
        }

        var hash_set = ResultHashSet.init(self.allocator);
        defer hash_set.deinit();

        // copy the items
        for (self.items) |item| {
            try hash_set.put(item, {});
        }
        try hash_set.put(new, {});

        const combined_items: []Result = hash_set.keys();
        // copy the keys (before we nuke the above hash set)
        const copied_items: []Result = try self.allocator.alloc(Result, combined_items.len);
        errdefer self.allocator.free(copied_items);
        @memcpy(copied_items, combined_items);

        return try from(self.allocator, copied_items);
    }

    /// Creates a new `ListResult` with items in `other` removed from `self`.
    /// Be sure to destroy the original `ListResult`'s afterward.
    /// As a side effect, the new `ListResult` will only contain unique items, even if nothing is removed.
    pub fn remove(self: ListResult, other: ListResult) Error!ListResult {
        if (self.component_type != null
            and other.component_type != null
            and !std.mem.eql(u8, self.component_type.?, other.component_type.?)
        ) {
            return Error.ElementTypesVary;
        }

        var hash_set = ResultHashSet.init(self.allocator);
        defer hash_set.deinit();

        // copy the items from self
        for (self.items) |item| {
            try hash_set.put(item, {});
        }
        // remove the items from other
        for (other.items) |item| {
            _ = hash_set.orderedRemove(item);
        }

        const combined_items: []Result = hash_set.keys();
        // copy the keys (before we nuke the above hash set)
        const copied_items: []Result = try self.allocator.alloc(Result, combined_items.len);
        errdefer self.allocator.free(copied_items);
        @memcpy(copied_items, combined_items);

        return try from(self.allocator, copied_items);
    }

    /// Creates a new `ListResult` with `to_remove` removed from `self`.
    /// Be sure to destroy the original `ListResult` afterward.
    /// As a side effect, the new `ListResult` will only contain unique items, even if nothing is removed.
    pub fn removeOne(self: ListResult, to_remove: Result) Error!ListResult {
        if (self.component_type != null and !std.mem.eql(u8, self.component_type.?, @tagName(to_remove))) {
            return Error.ElementTypesVary;
        }

        var hash_set = ResultHashSet.init(self.allocator);
        defer hash_set.deinit();

        // copy the items from self
        for (self.items) |item| {
            try hash_set.put(item, {});
        }
        // remove the items from other
        _ = hash_set.orderedRemove(to_remove);

        const keys: []Result = hash_set.keys();
        // copy the keys (before we nuke the above hash set)
        const copied_items: []Result = try self.allocator.alloc(Result, keys.len);
        errdefer self.allocator.free(copied_items);
        @memcpy(copied_items, keys);

        return try from(self.allocator, copied_items);
    }

    pub fn deinit(self: *ListResult) void {
        self.allocator.free(self.items);
        self.* = undefined;
    }
};

/// Allowed labels on cards.
/// Labels are annotations that give cards attributes.
pub const Label = union(enum) {
    one_time_use: void,
    attack: void,
    attack_attr: u8,
    monster: void,
    rank: u8,
    accuracy: u8,
    teleport: void,
    rush: void,
    summon: void,
    utility: void,
    tactic: void,
    crystal: void,
    role: void,
    sludge: void,
    // TODO: AOE

    const rank_values: []const u8 = "abcs";
    const attack_attr_values: []const u8 = "psmc";

    pub fn from(label: []const u8, value: ?[]const u8) Error!Label {
        if (std.mem.eql(u8, @tagName(Label.one_time_use), label)) {
            return Label.one_time_use;
        } else if (std.mem.eql(u8, @tagName(Label.attack), label)) {
            return Label.attack;
        } else if (std.mem.eql(u8, @tagName(Label.attack_attr), label)) {
            if (value) |val| {
                if (val.len == 1) {
                    if (std.mem.indexOf(u8, attack_attr_values, &[_]u8 { std.ascii.toLower(val[0]) })) |i| {
                        return .{ .attack_attr = rank_values[i] };
                    }
                    return Error.InvalidLabelValue;
                }
            }
            return Error.LabelRequiresValue;
        } else if (std.mem.eql(u8, @tagName(Label.rank), label)) {
            if (value) |val| {
                // expecting a single character
                if (val.len == 1) {
                    if (std.mem.indexOf(u8, rank_values, &[_]u8 { std.ascii.toLower(val[0]) })) |i| {
                        return .{ .rank = rank_values[i] };
                    }   
                }
                return Error.InvalidLabelValue;
            }
            return Error.LabelRequiresValue;
        } else if (std.mem.eql(u8, @tagName(Label.accuracy), label)) {
            if (value) |val| {
                const accuracy: u8 = std.fmt.parseUnsigned(u8, val, 10) catch {
                    std.log.err("Unable to parse unsigned 8-bit integer from '{s}' while parsing the value of the accuracy label.", .{ val });
                    return Error.InvalidLabelValue;
                };
                if (accuracy > 20) {
                    std.log.err("Accuracy cannot exceed 20. Was {d}.", .{ accuracy });
                    return Error.InvalidLabelValue;
                }
                return .{ .accuracy = accuracy };
            }
        }
        return Error.InvalidLabel;
    }

    pub fn asByte(self: Label) ?u8 {
        switch (self) {
            .rank, .accuracy => |x| return x,
            inline else => return null
        }
    }

    pub fn equals(a: Label, b: Label) bool {
        if (std.mem.eql(u8, @tagName(a), @tagName(b))) {
            return a.asByte() == b.asByte();
        }
        return false;
    }
};

pub const FunctionDef = *const fn (?*anyopaque, []Result) anyerror!Result;

pub const Symbol = union(enum) {
    value: *Result,
    function: FunctionDef,
    complex_object: *Scope,

    pub fn unwrapValue(self: Symbol) error{UnwrapError}!Result {
        switch (self) {
            .value => |v| return v.*,
            else => return error.UnwrapError
        }
    }

    pub fn unwrapFunction(self: Symbol) error{UnwrapError}!FunctionDef {
        switch (self) {
            .function => |f| return f,
            else => return error.UnwrapError
        }
    }

    pub fn unwrapObj(self: Symbol) error{UnwrapError}!*Scope {
        switch (self) {
            .complex_object => |o| return o,
            else => return error.UnwrapError
        }
    }
};

pub const Scope = struct {
    outer: ?*Scope = null,
    allocator: Allocator,
    symbols: StringHashMap(Symbol),
    obj_ptr: ?*anyopaque = null,

    pub fn new(allocator: Allocator, outer: ?*Scope) Allocator.Error!*Scope {
        const ptr: *Scope = try allocator.create(Scope);
        ptr.* = .{
            .symbols = StringHashMap(Symbol).init(allocator),
            .allocator = allocator,
            .outer = outer
        };
        return ptr;
    }

    pub fn newObj(allocator: Allocator, obj_ptr: *anyopaque) Allocator.Error!*Scope {
        const ptr: *Scope =  try allocator.create(Scope);
        ptr.* = .{
            .symbols = StringHashMap(Symbol).init(allocator),
            .allocator = allocator,
            .obj_ptr = obj_ptr
        };
        return ptr;
    }

    pub fn pushNew(self: *Scope) Allocator.Error!*Scope {
        return Scope.new(self.allocator, self);
    }

    pub fn pop(self: *Scope) error{NoOuterScope}!*Scope {
        if (self.outer) |next_scope| {
            self.deinit();
            return next_scope;
        }
        return error.NoOuterScope;
    }

    pub fn putValue(self: *Scope, name: []const u8, value: Result) Allocator.Error!void {
        // copy name
        const name_cpy: []u8 = try self.allocator.alloc(u8, name.len);
        errdefer self.allocator.free(name_cpy);
        @memcpy(name_cpy, name);

        // create value ptr
        const value_ptr: *Result = try self.allocator.create(Result);
        errdefer self.allocator.destroy(value_ptr);
        value_ptr.* = value;

        try self.symbols.put(name_cpy, Symbol { .value = value_ptr });
    }

    pub fn putFunc(self: *Scope, name: []const u8, func: FunctionDef) Allocator.Error!void {
        // copy name
        const name_cpy: []u8 = try self.allocator.alloc(u8, name.len);
        errdefer self.allocator.free(name_cpy);
        @memcpy(name_cpy, name);

        try self.symbols.put(name_cpy, Symbol { .function = func });
    }

    pub fn putObj(self: *Scope, name: []const u8, obj: *Scope) Allocator.Error!void {
        // copy name
        const name_cpy: []u8 = try self.allocator.alloc(u8, name.len);
        errdefer self.allocator.free(name_cpy);
        @memcpy(name_cpy, name);

        // create value ptr
        try self.symbols.put(name_cpy, Symbol { .complex_object = obj });
    }

    pub fn getSymbol(self: Scope, name: []const u8) ?Symbol {
        return self.symbols.get(name);
    }

    pub fn deinit(self: *Scope) void {
        var iter = self.symbols.iterator();
        while (iter.next()) |kvp| {
            self.allocator.free(kvp.key_ptr.*);
            switch (kvp.value_ptr.*) {
                .value => |v| self.allocator.destroy(v),
                .complex_object => |o| o.deinit(),
                // function def's are comptime pointers, so no need to destroy anything here
                else => { }
            }
        }
        self.symbols.deinit();
        self.allocator.destroy(self);
    }
};

pub const SymbolTable = struct {
    allocator: Allocator,
    current_scope: *Scope,
    player_interface: ?PlayerInterface = null,

    pub fn new(allocator: Allocator) Allocator.Error!SymbolTable {
        return .{
            .allocator = allocator,
            .current_scope = try Scope.new(allocator, null)
        };
    }

    pub fn getSymbol(self: SymbolTable, name: []const u8) ?Symbol {
        var current: ?*Scope = self.current_scope;
        while (current) |scope| {
            if (scope.getSymbol(name)) |val| {
                return val;
            }
            current = scope.outer;
        }
        return null;
    }

    pub fn putValue(self: SymbolTable, name: []const u8, value: Result) Allocator.Error!void {
        try self.current_scope.putValue(name, value);
    }

    pub fn putFunc(self: SymbolTable, name: []const u8, func: FunctionDef) Allocator.Error!void {
        try self.current_scope.putFunc(name, func);
    }

    pub fn putObj(self: SymbolTable, name: []const u8, obj: *Scope) Allocator.Error!void {
        // just in case this wasn't already set
        obj.*.outer = self.current_scope;
        try self.current_scope.putObj(name, obj);
    }

    pub fn newScope(self: *SymbolTable) Allocator.Error!void {
        self.current_scope = try self.current_scope.pushNew();
    }

    /// If there are no inner scopes, this function will have no effect.
    pub fn endScope(self: *SymbolTable) void {
        if (self.current_scope.pop()) |outer| {
            self.current_scope = outer;
        } else |_| { }
    }

    pub fn getPlayerChoice(self: SymbolTable, amount: u16, pool: []const Result, exact: bool) !Result {
        if (self.player_interface) |p| {
            return try p.getPlayerChoice(amount, pool, exact);
        }
        return error.NotImplemented;
    }

    pub fn deinit(self: *SymbolTable) void {
        var current: ?*Scope = self.current_scope;
        while (current) |scope| {
            // assign next before we kill current
            current = scope.outer;
            scope.deinit();
        }
        self.* = undefined;
    }
};

const InnerError = error {
    InvalidLabel,
    InvalidLabelValue,
    LabelRequiresValue,
    UndefinedIdentifier,
    OperandTypeNotSupported,
    OperandTypeMismatch,
    UnexpectedType,
    ElementTypesVary,
    MustBeGreaterThanZero,
    MustBePositiveInteger,
    InvalidAccessorChain,
    PrematureAccessorTerminus,
    FunctionDefinitionNotFound,
    FunctionInvocationFailed,
    HigherOrderFunctionsNotSupported,
    InvalidInnerExpression,
    UnexpectedToken,
    PlayerChoiceFailed,
    HasError
};

pub const Error = InnerError || ParseTokenError || Allocator.Error;

pub const PlayerInterface = struct {
    ptr: *anyopaque,
    get_player_choice: *const fn (*anyopaque, u16, []const Result, bool) anyerror!Result,

    pub fn getPlayerChoice(self: PlayerInterface, amount: u16, pool: []const Result, exact: bool) !Result {
        return try self.get_player_choice(self.ptr, amount, pool, exact);
    }
};

pub const Expression = struct {
    ptr: *anyopaque,
    evaluate_fn: *const fn (*anyopaque, *SymbolTable) Error!Result,
    deinit_fn: *const fn (*anyopaque) void,

    pub fn evaluate(self: Expression, symbol_table: *SymbolTable) Error!Result {
        return self.evaluate_fn(self.ptr, symbol_table);
    }

    pub fn deinit(self: Expression) void {
        self.deinit_fn(self.ptr);
    }
    
    pub fn deinitAll(expressions: []Expression) void {
        for (expressions) |expr| {
            expr.deinit();
        }
    }

    pub fn deinitAllAndFree(allocator: Allocator, expressions: []Expression) void {
        deinitAll(expressions);
        allocator.free(expressions);
    }
};
