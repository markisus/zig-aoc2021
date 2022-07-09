const std = @import("std");

const AmphiRoom = struct {
    const Self = @This();
    hallway: [11]u8 = .{' '} ** 11,
    rooms: [4][2]u8 = .{.{' '} ** 2} ** 4,

    pub fn print(self: *const Self) void {
        // std.debug.print("  ", .{});
        for (self.hallway) |apod| {
            std.debug.print("[{c}]", .{apod});
        }

        std.debug.print("\n", .{});

        var row: u8 = 0;
        while (row < 2) : (row += 1) {
            std.debug.print("      ", .{});
            for (self.rooms) |room| {
                std.debug.print("[{c}]", .{room[row]});
                std.debug.print("   ", .{});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn roomEql(room0: [2]u8, room1: [2]u8) bool {
        const result = std.mem.eql(u8, room0[0..], room1[0..]);
        // std.debug.print("room0 {c} == room1 {c} is {d}\n", .{ room0, room1, result });
        return result;
    }

    pub fn moveCost(apod: u8) u32 {
        return switch (apod) {
            'A' => 1,
            'B' => 10,
            'C' => 100,
            'D' => 1000,
            else => unreachable,
        };
    }

    pub fn getApodHome(apod: u8) u8 {
        const home_idx: u8 = switch (apod) {
            'A' => 0,
            'B' => 1,
            'C' => 2,
            'D' => 3,
            else => 4,
        };
        return home_idx;
    }

    pub fn moveHome(self: *Self, hall_idx: u8) void {
        const apod = self.hallway[hall_idx];
        self.hallway[hall_idx] = ' ';
        const apod_home = getApodHome(apod);
        if (self.rooms[apod_home][1] == ' ') {
            self.rooms[apod_home][1] = apod;
        } else {
            self.rooms[apod_home][0] = apod;
        }
    }

    pub fn homingCost(self: *const Self, hall_idx: u8) ?u32 {
        const debug = false;
        if (debug) std.debug.print("Computing homingCost {d}\n", .{hall_idx});
        const apod = self.hallway[hall_idx];
        const home_idx: u8 = getApodHome(apod);
        if (home_idx >= self.rooms.len) return null;

        if (debug) std.debug.print("apod {c}, home {d}\n", .{ apod, home_idx });
        const allowed_room0: [2]u8 = .{ ' ', apod };
        const allowed_room1: [2]u8 = .{ ' ', ' ' };
        const home_room = self.rooms[home_idx];

        var idx: u8 = 0; // the idx in the home
        if (roomEql(home_room, allowed_room0)) {
            idx = 0;
        } else if (roomEql(home_room, allowed_room1)) {
            idx = 1;
        } else {
            if (debug) std.debug.print("room not allowed {c}\n", .{home_room});
            return null;
        }

        if (debug) std.debug.print("home allowed!\n", .{});

        const home_x = 2 + 2 * home_idx;
        const min_x = @minimum(home_x, hall_idx);
        const max_x = @maximum(home_x, hall_idx);

        // check for blockers
        var blocker_idx = min_x;
        while (blocker_idx <= max_x) : (blocker_idx += 1) {
            if (blocker_idx == hall_idx) continue; // self is not a blocker
            if (debug) std.debug.print("Searching for blocker at {d}\n", .{blocker_idx});
            if (self.hallway[blocker_idx] != ' ') return null;
        }

        const delta_x = max_x - min_x;
        const num_moves = delta_x + idx + 1;
        return num_moves * moveCost(apod);
    }

    pub fn moveHallway(self: *Self, room_idx: u8, hall_idx: u8) void {
        const apod_idx: u8 = if (self.rooms[room_idx][0] == ' ') 1 else 0;
        const apod = self.rooms[room_idx][apod_idx];
        self.hallway[hall_idx] = apod;
        self.rooms[room_idx][apod_idx] = ' ';
    }

    pub fn hallwayCost(self: *const Self, room_idx: u8, hall_idx: u8) ?u32 {
        const debug = false;
        if (debug) std.debug.print("computing hallwayCost\n", .{});

        // handle banned squares
        switch (hall_idx) {
            2 => return null,
            4 => return null,
            6 => return null,
            8 => return null,
            else => {},
        }

        // get the apod that needs to move
        const apod_idx: u8 = if (self.rooms[room_idx][0] == ' ') 1 else 0;
        const apod: u8 = self.rooms[room_idx][apod_idx];
        if (apod == ' ') return null;

        if (getApodHome(apod) == room_idx) {
            // apod is already home
            if (apod_idx == 1) return null; // this room is partially solved, it's stupid to move
            if (apod_idx == 0 and self.rooms[room_idx][1] == apod) return null; // the room is solved already, it's stupid to move
        }

        const home_x = 2 + 2 * room_idx;
        const min_x = @minimum(home_x, hall_idx);
        const max_x = @maximum(home_x, hall_idx);

        if (debug) std.debug.print("apod {c}\n", .{apod});

        // check for blockers
        var blocker_idx = min_x;
        while (blocker_idx <= max_x) : (blocker_idx += 1) {
            if (debug) std.debug.print("checking for blocker at {d}\n", .{blocker_idx});
            if (self.hallway[blocker_idx] != ' ') return null;
        }

        const delta_x = max_x - min_x;
        const num_moves = delta_x + apod_idx + 1;
        return num_moves * moveCost(apod);
    }

    pub fn isSolved(self: *const Self) bool {
        if (!roomEql(self.rooms[0], .{ 'A', 'A' })) return false;
        if (!roomEql(self.rooms[1], .{ 'B', 'B' })) return false;
        if (!roomEql(self.rooms[2], .{ 'C', 'C' })) return false;
        if (!roomEql(self.rooms[3], .{ 'D', 'D' })) return false;
        return true;
    }
};

pub fn AmphiRoom2(comptime room_size: u8) type {
    return struct {
        const Self = @This();
        const RoomSize = room_size;
        hallway: [11]u8 = .{' '} ** 11,
        rooms: [4][RoomSize]u8 = .{.{' '} ** room_size} ** 4,

        pub fn print(self: *const Self) void {
            // std.debug.print("  ", .{});
            for (self.hallway) |apod| {
                std.debug.print("[{c}]", .{apod});
            }

            std.debug.print("\n", .{});

            var row: u8 = 0;
            while (row < RoomSize) : (row += 1) {
                std.debug.print("      ", .{});
                for (self.rooms) |room| {
                    std.debug.print("[{c}]", .{room[row]});
                    std.debug.print("   ", .{});
                }
                std.debug.print("\n", .{});
            }
        }

        pub fn roomEql(room0: [RoomSize]u8, room1: [RoomSize]u8) bool {
            const result = std.mem.eql(u8, room0[0..], room1[0..]);
            // std.debug.print("room0 {c} == room1 {c} is {d}\n", .{ room0, room1, result });
            return result;
        }

        pub fn moveCost(apod: u8) u32 {
            return switch (apod) {
                'A' => 1,
                'B' => 10,
                'C' => 100,
                'D' => 1000,
                else => unreachable,
            };
        }

        pub fn getApodHome(apod: u8) u8 {
            const home_idx: u8 = switch (apod) {
                'A' => 0,
                'B' => 1,
                'C' => 2,
                'D' => 3,
                else => 4,
            };
            return home_idx;
        }

        pub fn moveHome(self: *Self, hall_idx: u8) void {
            const apod = self.hallway[hall_idx];
            self.hallway[hall_idx] = ' ';
            const apod_home = getApodHome(apod);

            var islot: i8 = RoomSize - 1;
            while (islot >= 0) : (islot -= 1) {
                const slot = @intCast(u8, islot);
                if (self.rooms[apod_home][slot] == ' ') {
                    self.rooms[apod_home][slot] = apod;
                    return;
                }
            }
        }

        pub fn homingCost(self: *const Self, hall_idx: u8) ?u32 {
            const debug = false;
            if (debug) std.debug.print("Computing homingCost {d}\n", .{hall_idx});
            const apod = self.hallway[hall_idx];
            const home_idx: u8 = getApodHome(apod);
            if (home_idx >= self.rooms.len) return null;

            if (debug) std.debug.print("apod {c}, home {d}\n", .{ apod, home_idx });

            var slot: u8 = 0;
            var last_slot_empty: u8 = 0;
            while (slot < RoomSize) : (slot += 1) {
                var resident = &self.rooms[home_idx][slot];
                if (resident.* == ' ') {
                    last_slot_empty = slot;
                } else if (resident.* != apod) {
                    return null; // non-home apods are in the room so cannot enter
                }
            }

            const home_x = 2 + 2 * home_idx;
            const min_x = @minimum(home_x, hall_idx);
            const max_x = @maximum(home_x, hall_idx);

            // check for blockers
            var blocker_idx = min_x;
            while (blocker_idx <= max_x) : (blocker_idx += 1) {
                if (blocker_idx == hall_idx) continue; // self is not a blocker
                if (debug) std.debug.print("Searching for blocker at {d}\n", .{blocker_idx});
                if (self.hallway[blocker_idx] != ' ') return null;
            }

            const delta_x = max_x - min_x;
            const num_moves = delta_x + last_slot_empty + 1;
            return num_moves * moveCost(apod);
        }

        pub fn moveHallway(self: *Self, room_idx: u8, hall_idx: u8) void {
            var apod_idx: u8 = 0;
            while (apod_idx < RoomSize) : (apod_idx += 1) {
                if (self.rooms[room_idx][apod_idx] != ' ') break;
            }
            const apod = self.rooms[room_idx][apod_idx];
            self.hallway[hall_idx] = apod;
            self.rooms[room_idx][apod_idx] = ' ';
        }

        pub fn hallwayCost(self: *const Self, room_idx: u8, hall_idx: u8) ?u32 {
            const debug = false;
            if (debug) std.debug.print("computing hallwayCost\n", .{});

            // handle banned squares
            switch (hall_idx) {
                2 => return null,
                4 => return null,
                6 => return null,
                8 => return null,
                else => {},
            }

            // get the apod that needs to move
            var apod_idx: u8 = 0;
            while (apod_idx < RoomSize) : (apod_idx += 1) {
                if (self.rooms[room_idx][apod_idx] != ' ') break;
            }
            if (apod_idx >= RoomSize) return null;
            const apod: u8 = self.rooms[room_idx][apod_idx];

            if (getApodHome(apod) == room_idx) {
                // apod is already home
                // it's stupid to move unless there is an apod trapped behind it that can't get out
                var trapped_idx = apod_idx + 1;
                while (trapped_idx < RoomSize) : (trapped_idx += 1) {
                    if (self.rooms[room_idx][trapped_idx] != apod) break;
                }
                if (trapped_idx >= RoomSize) return null;
            }

            const home_x = 2 + 2 * room_idx;
            const min_x = @minimum(home_x, hall_idx);
            const max_x = @maximum(home_x, hall_idx);

            if (debug) std.debug.print("apod {c}\n", .{apod});

            // check for blockers
            var blocker_idx = min_x;
            while (blocker_idx <= max_x) : (blocker_idx += 1) {
                if (debug) std.debug.print("checking for blocker at {d}\n", .{blocker_idx});
                if (self.hallway[blocker_idx] != ' ') return null;
            }

            const delta_x = max_x - min_x;
            const num_moves = delta_x + apod_idx + 1;
            return num_moves * moveCost(apod);
        }

        pub fn getFinalApod(room_idx: u8) u8 {
            if (room_idx == 0) return 'A';
            if (room_idx == 1) return 'B';
            if (room_idx == 2) return 'C';
            if (room_idx == 3) return 'D';
            unreachable;
        }

        pub fn isSolved(self: *const Self) bool {
            var room_idx: u8 = 0;
            while (room_idx < self.rooms.len) : (room_idx += 1) {
                var slot: u8 = 0;
                while (slot < RoomSize) : (slot += 1) {
                    if (self.rooms[room_idx][slot] != getFinalApod(room_idx)) return false;
                }
            }
            return true;
        }
    };
}

pub fn Solver(comptime room_size: u8) type {
    return struct {
        const Memo = std.AutoHashMap(AmphiRoom2(room_size), u64);
        pub fn solve(room: AmphiRoom2(room_size), memo: *Memo) !u64 {
            var cost_ceil: u64 = std.math.maxInt(u64);
            return try solve_impl(room, memo, 0, &cost_ceil);
        }
        pub fn solve_impl(room: AmphiRoom2(room_size), memo: *Memo, cost_so_far: u64, cost_ceil: *u64) !u64 {
            const debug = true;
            if (debug) {
                // std.debug.print("Solve...\n", .{});
                // room.print();
            }

            // base case: cost ceiling violated
            if (cost_so_far > cost_ceil.*) return std.math.maxInt(u64); // bail

            // base case: solved room
            if (room.isSolved()) {
                // lower the global cost ceiling, if possible
                cost_ceil.* = @minimum(cost_ceil.*, cost_so_far);
                return 0;
            }

            // base case: memozied
            if (memo.get(room)) |count| return count;

            // general case:
            // make every possible move

            // put into memoizer to mark this state
            // as being explored. subsequent stack calls
            // will bail out
            try memo.put(room, std.math.maxInt(u64));

            // var best_homing_hall_idx: u8 = 0;
            // var best_homing_home_idx: u8 = 0; // 0 or 1
            var best_homing_cost: u64 = std.math.maxInt(u64);

            // if (debug) std.debug.print("Checking homing moves\n", .{});

            // make all possible homing moves
            for (room.hallway) |apod, _hall_idx| {
                const hall_idx = @intCast(u8, _hall_idx);
                if (apod != ' ') {
                    if (room.homingCost(hall_idx)) |hcost| {
                        var next_room = room;
                        next_room.moveHome(hall_idx);
                        const next_cost = solve_impl(next_room, memo, cost_so_far + hcost, cost_ceil) catch unreachable;
                        if (next_cost == std.math.maxInt(u64)) continue;
                        const cost = hcost + next_cost;
                        if (cost < best_homing_cost) {
                            best_homing_cost = cost;
                            // best_homing_hall_idx = hall_idx;
                            // best_homing_home_idx = idx;
                        }
                    }
                }
            }

            if (best_homing_cost != std.math.maxInt(u64)) {
                // if there is a homing move, there is a
                // greedy solution where a homing move
                // happens next
                try memo.put(room, best_homing_cost);
                if (debug) room.print();
                std.debug.print("Solved with cost {d}\n", .{best_homing_cost});
                return best_homing_cost;
            }

            // if (debug) std.debug.print("Checking hallway moves\n", .{});

            // make all possible hallway moves
            // var best_hallway_hall_idx: u8 = 0;
            // var best_hallway_room_idx: u8 = 0;
            var best_hallway_cost: u64 = std.math.maxInt(u64);
            {
                var room_idx: u8 = 0;
                while (room_idx < room.rooms.len) : (room_idx += 1) {
                    var hallway_idx: u8 = 0;
                    while (hallway_idx < room.hallway.len) : (hallway_idx += 1) {
                        if (room.hallwayCost(room_idx, hallway_idx)) |hcost| {
                            var next_room = room;
                            next_room.moveHallway(room_idx, hallway_idx);
                            const next_cost = solve_impl(next_room, memo, cost_so_far + hcost, cost_ceil) catch unreachable;
                            if (next_cost == std.math.maxInt(u64)) continue;
                            const cost = hcost + next_cost;
                            if (cost < best_hallway_cost) {
                                best_hallway_cost = cost;
                            }
                        }
                    }
                }
            }

            const mincost = @minimum(best_hallway_cost, best_homing_cost);

            if (debug and mincost != std.math.maxInt(u64)) {
                room.print();
                std.debug.print("Solved with cost {d}\n", .{mincost});
            }

            try memo.put(room, mincost);
            return mincost;
        }
    };
}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) unreachable;

    // part 1
    if (true) {
        var room: AmphiRoom2(2) = .{};
        const debug = false;
        if (debug) {
            room.rooms[0] = .{ 'A', 'B' };
            room.rooms[1] = .{ 'B', 'A' };
            room.rooms[2] = .{ 'C', 'C' };
            room.rooms[3] = .{ 'D', 'D' };
        } else {
            room.rooms[0] = .{ 'B', 'D' };
            room.rooms[1] = .{ 'B', 'A' };
            room.rooms[2] = .{ 'C', 'A' };
            room.rooms[3] = .{ 'D', 'C' };
        }

        const Solver2 = Solver(2);
        var memo = Solver2.Memo.init(gpa.allocator());
        defer memo.deinit();
        const mincost = Solver2.solve(room, &memo);
        std.debug.print("mincost {d}\n", .{mincost});
    }

    // part 2
    {
        var room: AmphiRoom2(4) = .{};
        room.rooms[0] = .{ 'B', 'D', 'D', 'D' };
        room.rooms[1] = .{ 'B', 'C', 'B', 'A' };
        room.rooms[2] = .{ 'C', 'B', 'A', 'A' };
        room.rooms[3] = .{ 'D', 'A', 'C', 'C' };

        const Solver4 = Solver(4);
        var memo = Solver4.Memo.init(gpa.allocator());
        defer memo.deinit();
        const mincost = Solver4.solve(room, &memo);
        std.debug.print("mincost {d}\n", .{mincost});
    }

    // okay now what do we do
    // ...
    // kill the

}
