const std = @import("std");

const imports = struct {
    usingnamespace @import("tokens.zig");
    usingnamespace @import("util");
    usingnamespace @import("game_zones");
};

const DamageType = imports.types.DamageType;
const Dice = imports.types.Dice;
const DamageTransaction = imports.types.DamageTransaction;
const StringHashMap = std.StringHashMap;
const Allocator = std.mem.Allocator;
const TokenIterator = imports.TokenIterator;

pub const Result = union(enum) {
    integer: i32,
    boolean: bool,
    damage_type: DamageType,
    damage_transaction: DamageTransaction,
    dice: struct { count: u16, dice: Dice },
    list: ListResult,
    label: Label,
    identifier: Symbol,
    // TODO: add player, cards, decks, etc.

    pub fn as(self: Result, comptime T: type) ?T {
        switch (self) {
            inline else => |x| {
                if (@TypeOf(x) == T) {
                    return x;
                }
            }
        }
        return null;
    }

    pub fn expectType(self: Result, comptime T: type) Error!T {
        return self.as(T) orelse Error.UnexpectedType;
    }

    pub fn isList(self: Result) ?ListResult {
        return self.as(ListResult);
    }
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

        const new_list: ListResult = try from(self.allocator, new_results);
        
        return new_list;
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

        const hash_set = std.AutoArrayHashMap(Result, void).init(self.allocator);
        defer hash_set.deinit();

        // copy the items
        for (self.items) |item| {
            hash_set.put(item, void);
        }
        for (other.items) |item| {
            hash_set.put(item, void);
        }

        const combined_items: []Result = hash_set.keys();
        // copy the keys (before we nuke the above hash set)
        var copied_items: []Result = try self.allocator.alloc(Result, combined_items.len);
        _ = &copied_items;
        errdefer self.allocator.free(copied_items);
        @memcpy(copied_items, combined_items);

        return try ListResult.from(self.allocator, copied_items);
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

        const new_list: ListResult = try from(self.allocator, new_results);
        return new_list;
    }

    /// Creates a new `ListResult` with `item` at the end, ensuring each element is unique.
    /// Be sure to destroy the original `ListResult` afterward.
    pub fn appendOneUnique(self: ListResult, new: Result) Error!ListResult {
        if (self.component_type != null and !std.mem.eql(u8, self.component_type.?, @tagName(new))) {
            return Error.ElementTypesVary;
        }

        const hash_set = std.AutoArrayHashMap(Result, void).init(self.allocator);
        defer hash_set.deinit();

        // copy the items
        for (self.items) |item| {
            hash_set.put(item, void);
        }
        hash_set.put(new, void);

        const combined_items: []Result = hash_set.keys();
        // copy the keys (before we nuke the above hash set)
        var copied_items: []Result = try self.allocator.alloc(Result, combined_items.len);
        _ = &copied_items;
        errdefer self.allocator.free(copied_items);
        @memcpy(copied_items, combined_items);

        return try ListResult.from(self.allocator, copied_items);
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

        const hash_set = std.AutoArrayHashMap(Result, void).init(self.allocator);
        defer hash_set.deinit();

        // copy the items from self
        for (self.items) |item| {
            hash_set.put(item, void);
        }
        // remove the items from other
        for (other.items) |item| {
            hash_set.remove(item, void);
        }

        const combined_items: []Result = hash_set.keys();
        // copy the keys (before we nuke the above hash set)
        var copied_items: []Result = try self.allocator.alloc(Result, combined_items.len);
        _ = &copied_items;
        errdefer self.allocator.free(copied_items);
        @memcpy(copied_items, combined_items);

        return try ListResult.from(self.allocator, copied_items);
    }

    /// Creates a new `ListResult` with `to_remove` removed from `self`.
    /// Be sure to destroy the original `ListResult` afterward.
    /// As a side effect, the new `ListResult` will only contain unique items, even if nothing is removed.
    pub fn removeOne(self: ListResult, to_remove: Result) Error!ListResult {
        if (self.component_type != null and !std.mem.eql(u8, self.component_type.?, @tagName(to_remove))) {
            return Error.ElementTypesVary;
        }

        const hash_set = std.AutoHashMap(Result, void).init(self.allocator);
        defer hash_set.deinit();

        // copy the items from self
        for (self.items) |item| {
            hash_set.put(item, void);
        }
        // remove the items from other
        hash_set.remove(to_remove);

        const combined_items: []Result = hash_set.keys();
        // copy the keys (before we nuke the above hash set)
        var copied_items: []Result = try self.allocator.alloc(Result, combined_items.len);
        _ = &copied_items;
        errdefer self.allocator.free(copied_items);
        @memcpy(copied_items, combined_items);

        return try ListResult.from(self.allocator, copied_items);
    }

    pub fn deinit(self: *ListResult) void {
        self.allocator.free(self.items);
        self.* = undefined;
    }
};

/// Allowed labels on cards.
/// Labels are annotations that give cards attributes.
pub const Label = enum {
    one_time_use,
    attack,
    s_rank,
    a_rank,
    b_rank,
    c_rank,

    pub fn from(label: []const u8) ?Label {
        if (std.mem.eql(u8, @tagName(Label.one_time_use), label)) {
            return Label.one_time_use;
        } else if (std.mem.eql(u8, @tagName(Label.attack), label)) {
            return Label.attack;
        } else if (std.mem.eql(u8, @tagName(Label.s_rank), label)) {
            return Label.s_rank;
        } else if (std.mem.eql(u8, @tagName(Label.a_rank), label)) {
            return Label.a_rank;
        } else if (std.mem.eql(u8, @tagName(Label.b_rank), label)) {
            return Label.b_rank;
        } else if (std.mem.eql(u8, @tagName(Label.c_rank), label)) {
            return Label.c_rank;
        }
        return null;
    }
};

pub const FunctionDef = *const fn (*anyopaque) anyerror!Result;

pub const Symbol = union(enum) {
    value: *Result,
    function: FunctionDef,
    complex_object: *Scope,
};

pub const Scope = struct {
    outer: ?*Scope,
    allocator: Allocator,
    symbols: StringHashMap(Symbol),

    pub fn new(allocator: Allocator, outer: ?*Scope) Allocator.Error!*Scope {
        const ptr: *Scope = try allocator.create(Scope);
        ptr.* = .{
            .symbols = StringHashMap(Symbol).init(allocator),
            .allocator = allocator,
            .outer = outer
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

    pub fn getSymbol(self: Scope, name: []const u8) ?Symbol {
        return self.symbols.get(name);
    }

    pub fn putSymbol(self: *Scope, name: []const u8, symbol: Symbol) Allocator.Error!void {
        try self.symbols.put(name, symbol);
    }

    pub fn deinit(self: *Scope) void {
        self.symbols.deinit();
        self.allocator.destroy(self);
    }

    /// Recursively destroys all outer scopes as well as this one.
    /// Should only be used when the symbol table `deinit`'s or else unepxected behavior will occur.
    pub fn deinitAllScopes(self: *Scope) void {
        if (self.outer) |outer| {
            outer.deinitAllScopes();
        }
        self.deinit();
    }
};

pub const SymbolTable = struct {
    allocator: Allocator,
    current_scope: *Scope,

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

    pub fn putSymbol(self: SymbolTable, name: []const u8, value: Symbol) Allocator.Error!void {
        switch (value) {
            Symbol.complex_object => |s| {
                s.outer = self.current_scope;
            },
            else => { }
        }
        try self.current_scope.putSymbol(name, value);
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
        _ = &self;
        _ = &amount;
        _ = &pool;
        _ = &exact;
        return error.NotImplemented;
    }

    pub fn deinit(self: *SymbolTable) void {
        self.current_scope.deinitAllScopes();
        self.* = undefined;
    }
};

const InnerError = error {
    AllocatorRequired,
    InvalidLabel,
    UndefinedIdentifier,
    OperandTypeNotSupported,
    OperandTypeMismatch,
    UnexpectedType,
    ElementTypesVary,
    MustBeGreaterThanZero
};

pub const Error = InnerError || Allocator.Error;

pub const Expression = struct {
    ptr: *anyopaque,
    requires_alloc: bool,
    evaluateFn: *const fn (*anyopaque, SymbolTable) Error!Result,
    evaluateAllocFn: *const fn (Allocator, *anyopaque, SymbolTable) Error!Result,

    pub fn evaluate(self: Expression, symbol_table: SymbolTable) Error!Result {
        if (self.requires_alloc) {
            return Error.AllocatorRequired;
        }
        return self.evaluateFn(self.ptr, symbol_table);
    }

    pub fn evaluateAlloc(self: Expression, allocator: Allocator, symbol_table: SymbolTable) Error!Result {
        return self.evaluateAllocFn(allocator, self.ptr, symbol_table);
    }

/// Simply returns `AllocatorRequired` error.
    /// Used for the various expressions that need an allocator but also must implement `evaluteFn`.
    pub fn errRequireAlloc(_: *anyopaque, _: SymbolTable) Error!Result {
       return Error.AllocatorRequired;
    }
};
