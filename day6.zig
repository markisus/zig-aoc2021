const std = @import("std");

pub fn main() !void {
    const test_mode: bool = false;
    const data_file = if (test_mode) "day6_test.txt" else "day6.txt";
    var file = try std.fs.cwd().openFile(data_file, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var buf: [1024]u8 = undefined;

    var fishes: [9]u64 = .{0} ** 9;
    const line = try in_stream.readUntilDelimiterOrEof(buf[0..], '\n');
    var tokens = std.mem.tokenize(u8, line.?, ",");
    while (tokens.next()) |token| {
        const time = try std.fmt.parseInt(u8, token, 10);
        // std.debug.print("time {d}\n", .{time});
        fishes[time] += 1;
    }

    const num_days = 256;
    var curr_day: u16 = 0;
    var fishes_next: [9]u64 = .{0} ** 9;
    while (curr_day < num_days) : (curr_day += 1) {
        // shift all fishes to the left (except 0)
        var fish_timer: u8 = 1;
        while (fish_timer < 9) : (fish_timer += 1) {
            fishes_next[fish_timer - 1] = fishes[fish_timer];
        }
        // all the ones with zero go to timer 6
        fishes_next[6] += fishes[0];
        // they also spawn fishes with timer 8
        fishes_next[8] = fishes[0];

        // swap fishes and fishes_next
        var tmp = fishes_next;
        fishes_next = fishes;
        fishes = tmp;
    }

    var total: u64 = 0;
    for (fishes) |fish| {
        total += fish;
    }

    std.debug.print("total {d}\n", .{total});
}
