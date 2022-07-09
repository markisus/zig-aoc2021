const std = @import("std");

pub fn move(curr: u8, total: u16) u8 {
    // There are 10 locations
    // 1, 2, ..., 10
    //
    // remap to
    // 0, 1, ..., 9
    //
    // then make moves with modular arith
    // then map back to 1 ... 10

    std.debug.assert(1 <= curr and curr <= 10);
    std.debug.print("moving with {d} + {d}\n", .{ curr, total });
    const next = @intCast(u16, curr) + total;

    return @truncate(u8, next % 10 + 1);
}

pub fn rollDie(die: *u16) u16 {
    const result = 3 * die.* + 3;
    die.* += 3;
    return result;
}

const Player = struct {
    const Self = @This();

    position: u8,
    score: u16 = 0,

    pub fn move(self: *Self, roll: u16) void {
        // There are 10 locations
        // 1, 2, ..., 10
        // remap to
        // 0, 1, ..., 9
        // then make moves with modular arith
        // then map back to 1 ... 10
        std.debug.assert(1 <= self.position and self.position <= 10);
        self.position = @truncate(u8, (roll + (self.position - 1)) % 10 + 1);
        self.score += self.position;
    }
};

const RollTable = struct {
    const Self = @This();

    data: [10]u8,

    pub fn generate() RollTable {
        var self: Self = undefined;
        @memset(self.data[0..], 0, self.data.len);
        var d1: u8 = 1;
        while (d1 <= 3) : (d1 += 1) {
            var d2: u8 = 1;
            while (d2 <= 3) : (d2 += 1) {
                var d3: u8 = 1;
                while (d3 <= 3) : (d3 += 1) {
                    self.data[d1 + d2 + d3] += 1;
                }
            }
        }
        return self;
    }
};

const roll_table = RollTable.generate();

// brute force simulate dirac dice
pub fn bruteForce(p1_turn: bool, p1_score: u8, p1_position: u8, p2_score: u8, p2_position: u8) u64 {
    // std.debug.print("Eval bf({d},{d},{d},{d},{d})\n", .{ p1_turn, p1_score, p1_position, p2_score, p2_position });
    if (p1_score >= 21) return 1;
    if (p2_score >= 21) return 0;

    var count: u64 = 0;
    const score = if (p1_turn) p1_score else p2_score;
    const position = if (p1_turn) p1_position else p2_position;

    var roll: u8 = 3;
    while (roll <= 9) : (roll += 1) {
        const next_position = ((position + roll - 1) % 10) + 1;
        const next_score = score + next_position;
        const num_duplicate_universes = roll_table.data[roll]; // in how many universes we obtain this roll

        if (p1_turn) {
            count += num_duplicate_universes * bruteForce(!p1_turn, next_score, next_position, p2_score, p2_position);
        } else {
            count += num_duplicate_universes * bruteForce(!p1_turn, p1_score, p1_position, next_score, next_position);
        }
    }

    return count;
}

const WinTable = struct {
    const Self = @This();

    // [curr score][curr spot][num steps to take]
    // => # of winning paths
    wintable: [21][10][21]u64,

    // query the number of ways to win
    // using num_steps starting from
    // `position` with score `score`
    pub fn waysToWin(self: *Self, score: u8, position: u8, num_steps: u8) *u64 {
        return &self.wintable[score][position - 1][num_steps - 1];
    }

    // query the number of ways to not
    // win yet using num_steps starting from
    // `position` with score `score`
    pub fn waysToStay(self: *Self, score: u8, position: u8, num_steps: u8) u64 {
        if (num_steps == 0) return 1;

        var paths_already_won: u64 = 0;
        var steps: u8 = 1;
        while (steps <= num_steps) : (steps += 1) {
            // each path has already won in the previous step
            // will split 27 times to continue winning in the current step
            paths_already_won *= 27;
            paths_already_won += self.waysToWin(score, position, steps).*;
        }

        return (std.math.powi(u64, @as(u64, 27), num_steps) catch unreachable) - paths_already_won;
    }

    pub fn fill(self: *Self) void {
        @memset(@ptrCast([*]u8, &self.wintable[0]), 0, @bitSizeOf(@TypeOf(self.wintable)) / 8);

        // std.debug.print("{d}\n", .{roll_table.data});

        // fill out the data table for the ways to win with score 20
        {
            var position: u8 = 1;
            while (position <= 10) : (position += 1) {
                // any of the 27 die rolls will cause a win in 1 step
                // there are no other ways to win starting with score 20
                self.waysToWin(20, position, 1).* = 27;
            }
        }

        // fill out the rest of the table, walking backwards from
        // score = 19
        {
            var iscore: i8 = 19;
            while (iscore >= 0) : (iscore -= 1) {
                const score = @intCast(u8, iscore);
                var position: u8 = 1;
                while (position <= 10) : (position += 1) {
                    const dbg = false; // (position == 4) and (score == 19);
                    if (dbg) std.debug.print("Debug trigger!", .{});

                    var roll: u8 = 3;
                    while (roll <= 9) : (roll += 1) {
                        const next_position = ((position + roll - 1) % 10) + 1;
                        const next_score = score + next_position;
                        const num_duplicate_universes = roll_table.data[roll]; // in how many universes we obtain this roll

                        if (dbg) std.debug.print("roll {d}, next pos {d}, next score {d}\n", .{ roll, next_position, next_score });

                        // a way to win in 1 step?
                        if (next_score >= 21) {
                            self.waysToWin(score, position, 1).* += num_duplicate_universes;
                        }
                        // a way to win in 1 + num_additional_steps
                        else {
                            const max_additional_steps: i8 = 21 - @intCast(i8, next_score);
                            var num_additional_steps: u8 = 1;

                            while (num_additional_steps <= max_additional_steps) : (num_additional_steps += 1) {
                                self.waysToWin(score, position, num_additional_steps + 1).* +=
                                    num_duplicate_universes * self.waysToWin(next_score, next_position, num_additional_steps).*;
                            }
                        }
                    }

                    var steps: u8 = 1;
                    while (steps <= 21) : (steps += 1) {
                        const count = self.waysToWin(score, position, steps).*;
                        if (count == 0) continue;
                        if (dbg) std.debug.print("{d} ways to win starting on spot {d} in {d} steps, starting with {d} points\n", .{ count, position, steps, score });
                    }
                }
            }
        }
    }
};

pub fn main() void {
    var p1_start: u8 = 8;
    var p2_start: u8 = 7;

    const debug = false;
    if (debug) {
        // test input
        p1_start = 4;
        p2_start = 8;
    }

    var p1 = Player{ .position = p1_start };
    var p2 = Player{ .position = p2_start };

    var die: u16 = 1;
    var num_rolls: u32 = 0;

    while (p1.score < 1000 and p2.score < 1000) {
        p1.move(rollDie(&die));
        num_rolls += 3;
        if (p1.score < 1000) {
            p2.move(rollDie(&die));
            num_rolls += 3;
        }
    }

    const p1_won = p1.score >= 1000;
    const loser_score = switch (p1_won) {
        true => p2.score,
        false => p1.score,
    };

    std.debug.print("rolls: {d}, p1 :{d}, p2: {d}\n", .{ num_rolls, p1, p2 });
    std.debug.print("loser_score*num_rolls={d}\n", .{num_rolls * loser_score});

    var wintable: WinTable = undefined;
    wintable.fill();

    // var wc2: u64 = 0;
    // var steps: u8 = 1;
    // while (steps <= 21) : (steps += 1) {
    //     wc2 += wintable.waysToWin(0, p1_start, steps).*;
    // }

    // const wc = winCheck(0, p1_start);
    // std.debug.print("wc {d}, wc2 {d}\n", .{ wc, wc2 });

    if (true) {
        // part2

        // ways to win and lose for player 1
        var p1_ways_to_win: u64 = 0;
        var p2_ways_to_win: u64 = 0;
        const p1_start_score = 0;
        const p2_start_score = 0;

        // std.debug.print("brute force p1 {d}\n", .{bruteForce(true, p1_start_score, p1_start, p2_start_score, p2_start)});
        // std.debug.print("brute force p2 {d}\n", .{bruteForce(true, p1_start_score, p1_start, p2_start_score, p2_start)});

        var num_p1_steps: u8 = 1;
        while (num_p1_steps <= 21) : (num_p1_steps += 1) {
            // calculate # universes p1 wins after taking num_p1_steps
            {
                const num_p2_steps = num_p1_steps - 1;
                const count1 = wintable.waysToWin(p1_start_score, p1_start, num_p1_steps).*;
                if (count1 != 0) {
                    const count2 = wintable.waysToStay(p2_start_score, p2_start, num_p2_steps);
                    // std.debug.print(" waysToWin({d}, {d}, {d})={d}\n", .{ p1_start_score, p1_start, num_p1_steps, count1 });
                    // std.debug.print("waysToStay({d}, {d}, {d})={d}\n\n", .{ p2_start_score, p2_start, num_p2_steps, count2 });
                    p1_ways_to_win += count1 * count2;
                }
            }

            // calculate # universes p1 loses after taking num_p1_steps
            {
                const num_p2_steps = num_p1_steps;
                const count2 = wintable.waysToWin(p2_start_score, p2_start, num_p2_steps).*;
                if (count2 != 0) {
                    const count1 = wintable.waysToStay(p1_start_score, p1_start, num_p1_steps);
                    // std.debug.print(" waysToWin({d}, {d}, {d})={d}\n", .{ p2_start_score, p2_start, num_p2_steps, count2 });
                    // std.debug.print("waysToStay({d}, {d}, {d})={d}\n\n", .{ p1_start_score, p1_start, num_p1_steps, count1 });
                    p2_ways_to_win += count1 * count2;
                }
            }
        }

        std.debug.print("p1 ways to win {d}, p2 ways to win {d}\n", .{ p1_ways_to_win, p2_ways_to_win });
        std.debug.print("p1 wins more? {d}\n", .{p1_ways_to_win > p2_ways_to_win});
    }
}
