const std = @import("std");
const print = std.debug.print;

pub fn Stack(comptime T: type) type {
    return struct {
        const Self = @This();
        data: [512]T = undefined,
        len: u16 = 0,

        pub fn push(self: *Self, char: T) void {
            self.data[self.len] = char;
            self.len += 1;
        }

        pub fn peek(self: *Self) ?T {
            if (self.len == 0) {
                return null;
            }
            return self.data[self.len - 1];
        }

        pub fn pop(self: *Self) void {
            self.len -= 1;
        }

        pub fn range(self: *Self) []T {
            return self.data[0..self.len];
        }
    };
}

pub fn isOpen(char: u8) bool {
    return switch (char) {
        '(' => true,
        '[' => true,
        '<' => true,
        '{' => true,
        else => false,
    };
}

pub fn getOpener(char: u8) u8 {
    return switch (char) {
        ')' => '(',
        ']' => '[',
        '>' => '<',
        '}' => '{',
        else => unreachable,
    };
}

pub fn getScore(char: u8) u64 {
    return switch (char) {
        ')' => 3,
        ']' => 57,
        '}' => 1197,
        '>' => 25137,
        else => unreachable,
    };
}

pub fn getCompletionScore(char: u8) u64 {
    return switch (char) {
        '(' => 1,
        '[' => 2,
        '{' => 3,
        '<' => 4,
        else => unreachable,
    };
}

pub fn main() !void {
    var file = try std.fs.cwd().openFile("day10.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader()).reader();
    var buf: [512]u8 = undefined;
    var score: u64 = 0;
    var completion_scores: Stack(u64) = .{};
    while (try reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        if (line.len == 0) {
            continue;
        }

        var stack: Stack(u8) = .{};
        var illegal: ?u8 = null;

        for (line) |char| {
            if (isOpen(char)) {
                stack.push(char);
            } else {
                const open = stack.peek() orelse ' ';
                if (open != getOpener(char)) {
                    illegal = char;
                    break;
                } else {
                    stack.pop();
                }
            }
        }

        if (illegal != null) {
            print("illegal {c}\n", .{illegal.?});
            score += getScore(illegal.?);
        } else {
            print("ok\n", .{});
            if (stack.len != 0) {
                // print("completing {d}", .{completion_scores.len});
                // for (stack.range()) |c| {
                //     print("{c} ", .{c});
                // }
                // print("\n", .{});
                var completion_score: u64 = 0;
                while (stack.len != 0) : (stack.pop()) {
                    completion_score *= 5;
                    completion_score += getCompletionScore(stack.peek().?);
                }
                completion_scores.push(completion_score);
            }
        }
    }

    print("score {d}\n", .{score});

    std.sort.sort(u64, completion_scores.range(), {}, comptime std.sort.asc(u64));
    const middle: u16 = (completion_scores.len / 2);
    print("cscore {d} ========\n", .{completion_scores.data[middle]});
    // for (completion_scores.range()) |cscore, idx| {
    //     print("{d}: {d}\n", .{ idx, cscore });
    // }
}
