const std = @import("std");

const BingoBoard = struct {
    numbers: [5][5]u8,
    matches: [5][5]bool,
    turns_taken: u32,
    won_flag: bool,
    last_update: u8,

    pub fn init(self: *BingoBoard) void {
        var r: u8 = 0;
        while (r < 5) : (r += 1) {
            var c: u8 = 0;
            while (c < 5) : (c += 1) {
                self.matches[r][c] = false;
            }
        }
        self.turns_taken = 0;
        self.won_flag = false;
    }

    pub fn print(self: *const BingoBoard) void {
        var r: u8 = 0;
        while (r < 5) : (r += 1) {
            var c: u8 = 0;
            while (c < 5) : (c += 1) {
                if (self.matches[r][c]) {
                    std.debug.print("[{d: >3}] ", .{self.numbers[r][c]});
                } else {
                    std.debug.print(" {d: >3}  ", .{self.numbers[r][c]});
                }
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn _did_row_win(self: *BingoBoard, row: u8) bool {
        var c: u8 = 0;
        while (c < 5) : (c += 1) {
            if (!self.matches[row][c]) {
                return false;
            }
        }
        return true;
    }
    pub fn _did_col_win(self: *BingoBoard, col: u8) bool {
        var r: u8 = 0;
        while (r < 5) : (r += 1) {
            if (!self.matches[r][col]) {
                return false;
            }
        }
        return true;
    }

    pub fn _did_win(self: *BingoBoard) bool {
        var r: u8 = 0;
        while (r < 5) : (r += 1) {
            if (self._did_row_win(r)) return true;
        }

        var c: u8 = 0;
        while (c < 5) : (c += 1) {
            if (self._did_col_win(c)) return true;
        }

        return false;
    }

    pub fn update(self: *BingoBoard, number: u8) void {
        if (self.won_flag) {
            // do not allow more updates
            return;
        }

        self.last_update = number;
        self.turns_taken += 1;
        var r: u8 = 0;
        while (r < 5) : (r += 1) {
            var c: u8 = 0;
            while (c < 5) : (c += 1) {
                if (self.numbers[r][c] == number) {
                    self.matches[r][c] = true;
                }
            }
        }

        if (self._did_win()) {
            self.won_flag = true;
        }
    }

    pub fn final_score(self: *BingoBoard) u32 {
        var sum_unmarked: u32 = 0;
        var r: u8 = 0;
        while (r < 5) : (r += 1) {
            var c: u8 = 0;
            while (c < 5) : (c += 1) {
                if (!self.matches[r][c]) {
                    sum_unmarked += self.numbers[r][c];
                }
            }
        }
        return sum_unmarked * self.last_update;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const leaks = gpa.deinit();
        if (leaks) {
            std.debug.print("Leaks!", .{});
        }
    }

    var moves_buf: [100]u8 = undefined;
    var num_moves: u32 = 0;

    var boards = std.ArrayList(BingoBoard).init(allocator);
    defer boards.deinit();

    var file = try std.fs.cwd().openFile("day4.txt", .{});
    defer file.close();

    var file_reader = std.io.bufferedReader(file.reader()).reader();
    var buf: [1024]u8 = undefined;

    if (try file_reader.readUntilDelimiterOrEof(buf[0..], '\n')) |first_line| {
        var tokens = std.mem.tokenize(u8, first_line, ",");
        while (tokens.next()) |token| {
            moves_buf[num_moves] = try std.fmt.parseInt(u8, token, 10);
            num_moves += 1;
        }
    }

    const moves = moves_buf[0..num_moves];

    // load board
    var board_row: u8 = 0;
    var board: *BingoBoard = undefined;
    while (try file_reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        if (line.len == 0) {
            board_row = 0;
        } else {
            if (board_row == 0) {
                board = try boards.addOne();
            }

            // add this row to the board
            var col: u8 = 0;
            var tokens = std.mem.tokenize(u8, line, " ");
            while (tokens.next()) |token| : (col += 1) {
                // std.debug.print("token {s}\n", .{token});
                const entry = try std.fmt.parseInt(u8, token, 10);
                board.*.numbers[board_row][col] = entry;
            }
            board_row += 1;
        }
        // std.debug.print("{s}\n", .{line});
    }

    {
        // part1
        var best_board: u32 = 0;
        var win_steps: u32 = std.math.maxInt(u32);
        var board_idx: u32 = 0;
        for (boards.items) |*b| {
            b.*.init();
            for (moves) |move| {
                b.*.update(move);
                if (b.*.turns_taken > win_steps) {
                    // this board can't win
                    break;
                }
                if (b.*.won_flag) {
                    // this board won
                    win_steps = b.*.turns_taken;
                    best_board = board_idx;
                    break;
                }
            }
            board_idx += 1;
        }

        var answer = boards.items[best_board].final_score();
        std.debug.print("part1 answer {}\n", .{answer});
    }

    {
        // part2
        var worst_board: u32 = 0;
        var worst_steps: u32 = 0;
        var board_idx: u32 = 0;
        for (boards.items) |*b| {
            b.*.init();
            for (moves) |move| {
                b.*.update(move);
                if (b.*.won_flag) {
                    // std.debug.print("a board won with {d} moves\n", .{b.*.turns_taken});
                    if (b.*.turns_taken > worst_steps) {
                        worst_steps = b.*.turns_taken;
                        worst_board = board_idx;
                        // std.debug.print("new worst board with {d} moves, last move {d}\n", .{ worst_steps, b.*.last_update });
                        // b.*.print();
                    }
                    break;
                }
            }
            board_idx += 1;
        }

        var answer = boards.items[worst_board].final_score();
        std.debug.print("part2 answer {}\n", .{answer});
    }
}
