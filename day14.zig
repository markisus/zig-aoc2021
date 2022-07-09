const std = @import("std");

const ParseError = error{
    MalformedRule,
};

pub fn pairToInt(char1: u8, char2: u8) u16 {
    return @intCast(u16, (char1 - 'A')) * 26 + (char2 - 'A');
}

pub fn getChar2(pair: u16) u8 {
    return @truncate(u8, (pair % 26)) + 'A';
}

pub fn getChar1(pair: u16) u8 {
    return @truncate(u8, (pair / 26)) + 'A';
}

pub fn printPair(pair: u16) void {
    const char1 = getChar1(pair);
    const char2 = getChar2(pair);
    std.debug.print("({c}{c})", .{ char1, char2 });
}

pub fn addPair(pair: u16, num_times: u64, dst: *std.AutoHashMap(u16, u64)) !void {
    // transfer the result pair to destination
    var gop = try dst.getOrPut(pair);
    if (gop.found_existing) {
        gop.value_ptr.* += num_times;
    } else {
        gop.value_ptr.* = num_times;
    }
}

pub fn runAnalysis(max_steps: u32, rules: *std.AutoHashMap(u16, u8), poly1: *std.AutoHashMap(u16, u64), poly2: *std.AutoHashMap(u16, u64), first_char: u8, last_char: u8) !void {
    var debug = false;

    var src = poly1;
    var dst = poly2;

    var step: u32 = 0;
    while (step < max_steps) : (step += 1) {
        var it = src.iterator();
        if (debug) {
            std.debug.print("step======\n", .{});
        }
        while (it.next()) |kv| {
            const src_pair = kv.key_ptr.*;
            const num_srcs = kv.value_ptr.*;
            if (debug and true) {
                printPair(src_pair);
                std.debug.print(" {d}\n", .{num_srcs});
            }
            if (rules.get(src_pair)) |result_char| {
                const src1 = getChar1(src_pair);
                const src2 = getChar2(src_pair);
                const pair1 = pairToInt(src1, result_char);
                const pair2 = pairToInt(result_char, src2);

                if (debug and true) {
                    std.debug.print("Results in pairs ", .{});
                    printPair(pair1);
                    printPair(pair2);
                    std.debug.print("\n", .{});
                }

                try addPair(pair1, num_srcs, dst);
                try addPair(pair2, num_srcs, dst);
            } else {
                if (debug and true) {
                    std.debug.print("Results in pair ", .{});
                    printPair(src_pair);
                    std.debug.print("\n", .{});
                }
                try addPair(src_pair, num_srcs, dst);
            }
        }

        var tmp = dst;
        dst = src;
        src = tmp;
        dst.clearAndFree();
    }

    // std.debug.print("Building counts\n", .{});
    // break pair into singles and count
    // every letter in sequence is double counted
    // except for first and last character
    var counts: [26]u64 = .{0} ** 26;
    var it = src.iterator();
    while (it.next()) |kvp| {
        const pair = kvp.key_ptr.*;
        const pair_cnt = kvp.value_ptr.*;

        if (debug) {
            std.debug.print("Seeing pair ", .{});
            printPair(pair);
            std.debug.print(" count={d}\n", .{pair_cnt});
        }

        const char1 = getChar1(pair);
        const char2 = getChar2(pair);
        counts[char1 - 'A'] += pair_cnt;
        counts[char2 - 'A'] += pair_cnt;

        if (debug) {
            std.debug.print("Count updated\n", .{});
            std.debug.print("{c}=>{d}\n", .{ @truncate(u8, char1), counts[char1 - 'A'] });
            std.debug.print("{c}=>{d}\n", .{ @truncate(u8, char2), counts[char2 - 'A'] });
        }
    }
    counts[first_char - 'A'] += 1;
    counts[last_char - 'A'] += 1;
    // std.debug.print("First char, last char, count updated\n", .{});
    // std.debug.print("{c}=>{d}\n", .{ @truncate(u8, first_char), counts[first_char - 'A'] });
    // std.debug.print("{c}=>{d}\n", .{ @truncate(u8, last_char), counts[last_char - 'A'] });

    for (counts) |*count, idx| {
        _ = idx;
        std.debug.assert(count.* % 2 == 0);
        count.* /= 2;
    }

    var most: u8 = 0;
    var most_count: u64 = 0;
    var least: u8 = 0;
    var least_count: u64 = std.math.maxInt(u64);
    for (counts) |cnt, idx| {
        if (cnt == 0) continue; // not all letters appear as "elements"
        const char = @truncate(u8, idx) + 'A';

        if (cnt > most_count) {
            most = char;
            most_count = cnt;
        }

        if (cnt < least_count) {
            least = char;
            least_count = cnt;
        }
    }

    std.debug.print("most={c},{d}\tleast={c},{d}\tdiff={d}\n", .{ most, most_count, least, least_count, most_count - least_count });
}

pub fn main() !void {
    const filename = "day14.txt";
    var file = try std.fs.cwd().openFile(filename, .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) unreachable;

    var rules1 = std.AutoHashMap(u16, u8).init(gpa.allocator());
    defer rules1.deinit();

    var m1 = std.AutoHashMap(u16, u64).init(gpa.allocator());
    defer m1.deinit();
    var m2 = std.AutoHashMap(u16, u64).init(gpa.allocator());
    defer m2.deinit();

    var buf: [256]u8 = undefined;
    var first_line = true;
    var first_char: u8 = undefined;
    var last_char: u8 = undefined;
    while (try file.reader().readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        if (first_line) {
            first_line = false;
            var idx: u32 = 0;
            while (idx + 1 < line.len) : (idx += 1) {
                try addPair(pairToInt(line[idx], line[idx + 1]), 1, &m1);
            }
            std.debug.assert(line.len >= 2);
            first_char = line[0];
            last_char = line[line.len - 1];
            continue;
        } else if (line.len == 0) {
            continue;
        }
        var tokens = std.mem.tokenize(u8, line, " ->");
        var rule_head = tokens.next() orelse return ParseError.MalformedRule;
        var rule_tail = tokens.next() orelse return ParseError.MalformedRule;
        try rules1.put(pairToInt(rule_head[0], rule_head[1]), rule_tail[0]);
    }

    try runAnalysis(10, &rules1, &m1, &m2, first_char, last_char);
    try runAnalysis(30, &rules1, &m1, &m2, first_char, last_char); // run 30 more times for a total of 40
}
