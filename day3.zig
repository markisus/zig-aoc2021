const std = @import("std");

pub fn getBitFromLeft(datum: u12, idx: u4) bool {
    return ((datum >> (11 - idx)) % 2) != 0;
}

pub fn setBitFromLeft(datum: u12, idx: u4, bit: bool) u12 {
    var delta: u12 = @as(u12, 1) << (11 - idx);
    if (bit) {
        return datum | delta;
    } else {
        return datum & (~delta);
    }
}

pub fn flipBitFromLeft(datum: u12, idx: u4) u12 {
    const bit = getBitFromLeft(datum, idx);
    return setBitFromLeft(datum, idx, !bit);
}

pub fn maskMatches(mask_len: u4, mask: u12, datum: u12) bool {
    if (mask_len == 0) {
        return true;
    }
    return (mask >> (12 - mask_len)) == (datum >> (12 - mask_len));
}

pub fn advanceMask(mask_len: u4, mask: u12, data: []u12, early_terminate: *bool) u12 {
    // std.debug.print("advanceMask begin, len {d} \n", .{mask_len});
    var votes: u32 = 0; // those data that matched the mask and voted for 1
    var num_voters: u32 = 0;
    var example_match: u12 = 0;
    for (data) |datum| {
        if (maskMatches(mask_len, mask, datum)) {
            example_match = datum;
            num_voters += 1;
            if (getBitFromLeft(datum, mask_len)) {
                votes += 1;
            }
        }
    }
    if (num_voters == 1) {
        // early terminate flag
        early_terminate.* = true;
        return example_match;
    }
    // std.debug.print("votes {d} / {d}\n", .{ votes, num_voters });
    if (votes * 2 >= num_voters) {
        // majority voted for 1
        return setBitFromLeft(mask, mask_len, true);
    } else {
        // majority voted for 0
        return setBitFromLeft(mask, mask_len, false);
    }
    // std.debug.print("advanceMask end\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const leaks = gpa.deinit();
        if (leaks) {
            std.debug.print("Leaks!", .{});
        }
    }

    var parsed_data = std.ArrayList(u12).init(allocator);
    defer parsed_data.deinit();

    var file = try std.fs.cwd().openFile("day3.txt", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var buf: [13]u8 = undefined;

    var votes: [12]u32 = .{0} ** 12;
    var num_lines: u32 = 0;
    while (try in_stream.readUntilDelimiterOrEof(buf[0..], '\n')) |line| : (num_lines += 1) {
        var data = try parsed_data.addOne();
        data.* = 0;

        var idx: u4 = 0;
        while (idx < 12) : (idx += 1) {
            switch (line[idx]) {
                '0' => {
                    // no-op
                },
                '1' => {
                    data.* = flipBitFromLeft(data.*, idx);
                },
                else => {
                    unreachable;
                },
            }
        }
    }

    for (parsed_data.items) |data| {
        comptime var i = 0;
        inline while (i < 12) : (i += 1) {
            const vote = data >> (11 - i) & 1;
            votes[i] += vote;
        }
    }

    var gamma: u12 = 0;
    for (votes) |vote, idx| {
        var is_one = vote > num_lines / 2;
        gamma = setBitFromLeft(gamma, @intCast(u4, idx), is_one);
    }

    var epsilon: u12 = ~gamma;

    std.debug.print("num_lines={d}, gamma={b:0>12}, eps={b:0>12}, \n", .{ num_lines, gamma, epsilon });
    std.debug.print("gamma={d}, eps={d} \n", .{ gamma, epsilon });

    var product: u64 = gamma;
    product *= epsilon;
    std.debug.print("product {d} \n", .{product});

    // part b
    var it: u4 = 0;
    var mask: u12 = 0;

    while (it < 12) : (it += 1) {
        var early_terminate: bool = false;
        mask = advanceMask(it, mask, parsed_data.items, &early_terminate);
        // std.debug.print("mask={b:0>12}, \n", .{mask});
        if (early_terminate) {
            break;
        }
    }

    const majority = mask;
    std.debug.print("mask for majority={b:0>12}, \n", .{majority});

    mask = 0;
    it = 0;
    while (it < 12) : (it += 1) {
        var early_terminate: bool = false;
        mask = advanceMask(it, mask, parsed_data.items, &early_terminate);

        if (early_terminate) {
            std.debug.print("early terminate\n", .{});
            break;
        }
        // for a minority vote, we flip the ith bit
        mask = flipBitFromLeft(mask, it);
        // std.debug.print("mask={b:0>12}, \n", .{mask});
    }
    const minority = mask;
    std.debug.print("mask for minority={b:0>12}, \n", .{minority});
    std.debug.print("product={d}, \n", .{@as(u32, minority) * @as(u32, majority)});
}
