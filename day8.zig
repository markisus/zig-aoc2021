const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;

pub fn numBitsHigh(bits: u7) u8 {
    var bits_edit = bits;
    var total: u8 = 0;
    while (bits_edit != 0) : (bits_edit = bits_edit >> 1) {
        total += bits_edit % 2;
    }
    return total;
}

pub fn letterToBitIdx(letter: u8) u3 {
    const result: u3 = @intCast(u3, letter - 'a');
    assert(result < 7);
    return result;
}

pub fn lettersToBits(letters: []const u8) u7 {
    var result: u7 = 0;
    for (letters) |letter| {
        result |= @as(u7, 1) << letterToBitIdx(letter);
    }
    return result;
}

pub fn main() !void {
    const unique_lens = comptime [_]u8{ 2, 3, 4, 7 };

    var file = try std.fs.cwd().openFile("day8.txt", .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader()).reader();
    var buf: [512]u8 = undefined;

    var num_unique_tokens: u64 = 0;
    var decoded_sum: u64 = 0;
    var unsolved_patterns: [10]u7 = undefined;

    while (try reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        var before_pipe: []const u8 = undefined;
        var after_pipe: []const u8 = undefined;
        var split = std.mem.tokenize(u8, line, "|");
        before_pipe = split.next().?;
        after_pipe = split.next().?;

        var before_pipe_items = std.mem.tokenize(u8, before_pipe, " ");
        var pattern_idx: u8 = 0;
        while (pattern_idx < 10) : (pattern_idx += 1) {
            unsolved_patterns[pattern_idx] = lettersToBits(before_pipe_items.next().?);
        }

        // Here are the source bit patterns
        //
        //   a  b  c  d  e  f  g
        //  [1, 1, 1, 1, 1, 1, 1] abcdefg   x₈ -
        //  [1, 1, 1, 1, _, 1, 1] abcdfg    x₉ -
        //  [1, 1, 1, _, 1, 1, 1] abcefg    x₀ -
        //  [1, 1, _, 1, 1, 1, 1] abdefg    x₆ -
        //  [1, 1, _, 1, _, 1, 1] abdfg     x₅ -
        //  [1, _, 1, 1, 1, _, 1] acdeg     x₂
        //  [1, _, 1, 1, _, 1, 1] acdfg     x₃
        //  [1, _, 1, _, _, 1, _] acf       x₇ -
        //  [_, 1, 1, 1, _, 1, _] bcdf      x₄ -
        //  [_, _, 1, _, _, 1, _] cf        x₁ -
        //
        // These get scrambled. But scrambling leaves the
        // number of bits high invariant.

        var scramble_map: [10]u7 = .{0} ** 10;
        var scramble_map_set: [10]bool = .{false} ** 10;

        // First pass, figure out 1, 4, and 7 based on
        // number of bits high.
        for (unsolved_patterns) |*pattern, idx| {
            const num_elements = numBitsHigh(pattern.*);
            switch (num_elements) {
                //  [_, _, 1, _, _, 1, _] cf        x₁
                2 => {
                    scramble_map[1] = pattern.*;
                    pattern.* = 0;
                    scramble_map_set[idx] = true;
                },
                //  [_, 1, 1, 1, _, 1, _] bcdf      x₄
                4 => {
                    scramble_map[4] = pattern.*;
                    pattern.* = 0;
                    scramble_map_set[idx] = true;
                },
                //  [1, _, 1, _, _, 1, _] acf       x₇
                3 => {
                    scramble_map[7] = pattern.*;
                    pattern.* = 0;
                    scramble_map_set[idx] = true;
                },
                //  [1, 1, 1, 1, 1, 1, 1] abcdefg   x₈
                7 => {
                    scramble_map[8] = pattern.*;
                    pattern.* = 0;
                    scramble_map_set[idx] = true;
                },
                else => {},
            }
        }

        // now we can find scramble_map[9]
        //  [1, 1, 1, 1, _, 1, 1] abcdfg    x₉
        const not_eg: u7 = scramble_map[7] | scramble_map[4];
        for (unsolved_patterns) |*pattern| {
            if (pattern.* == 0) continue; // already solved
            if (numBitsHigh(pattern.*) != 6) continue; // pattern 9 has six high bits
            if (numBitsHigh(not_eg & pattern.*) != 5) continue; // should only kill g, since e does not exist in pattern 9

            // found pattern 9
            scramble_map[9] = pattern.*;
            pattern.* = 0;
            break;
        }

        // we can use a similar technique to find scramble_map[6]
        //  [1, 1, _, 1, 1, 1, 1] abdefg    x₆
        const not_cf = ~scramble_map[1];
        for (unsolved_patterns) |*pattern| {
            if (pattern.* == 0) continue; // already solved
            if (numBitsHigh(pattern.*) != 6) continue; // pattern 6 has six high bits
            if (numBitsHigh(not_cf & pattern.*) != 5) continue; // should only kill f, since c does not exist in pattern 6

            // found pattern 6
            scramble_map[6] = pattern.*;
            pattern.* = 0;
            break;
        }

        // find pattern zero
        //  [1, 1, 1, _, 1, 1, 1] abcefg    x₀
        const not_bd = ~(scramble_map[4] - scramble_map[1]);
        // print("not_bd {b:0>7}\n", .{not_bd});
        for (unsolved_patterns) |*pattern| {
            if (pattern.* == 0) continue; // already solved
            if (numBitsHigh(pattern.*) != 6) continue; // pattern 0 has six high bits
            if (numBitsHigh(not_bd & pattern.*) != 5) continue; // should only kill b, since d does not exist

            // found pattern 0
            scramble_map[0] = pattern.*;
            pattern.* = 0;
            break;
        }

        // manufacture pattern 5
        scramble_map[5] = scramble_map[8] & scramble_map[6] & scramble_map[9];
        for (unsolved_patterns) |*pattern| {
            if (pattern.* == scramble_map[5]) {
                pattern.* = 0;
            }
        }

        // only pattern 2 and 3 remain. They can be distinguished by
        // their e position.
        const not_e = scramble_map[9];
        for (unsolved_patterns) |*pattern| {
            if (pattern.* == 0) continue;
            if (numBitsHigh(not_e & pattern.*) == numBitsHigh(pattern.*)) {
                scramble_map[3] = pattern.*;
                pattern.* = 0;
            } else {
                scramble_map[2] = pattern.*;
                pattern.* = 0;
            }
        }

        // tokenize the after_pipe
        var decoded_digits: [10]u8 = undefined;
        var num_digits: u8 = 0;
        var after_pipe_items = std.mem.tokenize(u8, after_pipe, " ");
        while (after_pipe_items.next()) |item| : (num_digits += 1) {
            const bits = lettersToBits(item);

            // search the scramble map to decode the bits
            for (scramble_map) |pattern, idx| {
                if (bits == pattern) {
                    decoded_digits[num_digits] = @intCast(u8, idx);
                    break;
                }
            }

            inline for (unique_lens) |unique_len| {
                if (item.len == unique_len) {
                    num_unique_tokens += 1;
                    break;
                }
            }
        }

        // decode the digits
        var decoded: u64 = 0;
        var power: u64 = 1;
        var digit_idx: u8 = 0;
        while (digit_idx < num_digits) : (digit_idx += 1) {
            const current_digit = decoded_digits[num_digits - digit_idx - 1];
            decoded += current_digit * power;
            power *= 10;
        }

        decoded_sum += decoded;
    }

    print("num uniques {d}\n", .{num_unique_tokens});
    print("sum of decoded {d}\n", .{decoded_sum});
}
