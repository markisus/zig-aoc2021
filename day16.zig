const std = @import("std");

const MsgHeader = struct { version: u3, ttype: u3 };
const Type0Op = struct { subpackets_length: u15 };
const Type1Op = struct { num_subpackets: u11 };
const Content = union(enum) { type0: Type0Op, type1: Type1Op, literal: u64 };

const PacketContext = struct {
    return_bits_processed: bool = false,
    child_bits_processed: u15 = 0,
    self_bits_processed: u15 = 0,
    subpackets_processed: u11 = 0,
    header: ?MsgHeader = null,
    content: Content = Content{ .literal = 0 },
    result: u64 = 0,
};

pub fn barrayToU16(bits: []u1) u16 {
    std.debug.assert(bits.len <= 16);
    var v: u16 = 0;
    for (bits) |b| {
        v = v << 1;
        v += b;
    }
    return v;
}

const BitsMsg = struct {
    const Self = @This();

    bits: [64]u1 = .{0} ** (64),
    write_idx: u8 = 0,
    read_idx: u8 = 0,

    pub fn ingestHex(self: *Self, char: u8) !void {
        const u: u4 = switch (char) {
            '0' => 0b0000,
            '1' => 0b0001,
            '2' => 0b0010,
            '3' => 0b0011,
            '4' => 0b0100,
            '5' => 0b0101,
            '6' => 0b0110,
            '7' => 0b0111,
            '8' => 0b1000,
            '9' => 0b1001,
            'A' => 0b1010,
            'B' => 0b1011,
            'C' => 0b1100,
            'D' => 0b1101,
            'E' => 0b1110,
            'F' => 0b1111,
            else => {
                std.debug.print("Got {c}({d})\n", .{ char, char });
                unreachable;
            },
        };
        self.ingestU4(u) catch {
            // retry after making as much space
            // as possible
            self.clearProcessedBits();
            try self.ingestU4(u);
        };
    }

    pub fn ingest(self: *Self, msg: []const u8) !void {
        for (msg) |hex| {
            self.ingestHex(hex);
        }
    }

    pub fn ingestU4(self: *Self, u: u4) !void {
        if (self.bitsWriteable() < 4) {
            return error.IndexOutOfBounds;
        }

        var i: u8 = 0;
        while (i < 4) : (i += 1) {
            const bit_high = (u >> 3 - @truncate(u2, i)) % 2;
            self.bits[self.write_idx] = @truncate(u1, bit_high);
            self.write_idx += 1;
        }
    }

    pub fn printSlice(s: []u1) void {
        for (s) |b| {
            std.debug.print("{d}", .{b});
        }
    }

    pub fn clearProcessedBits(self: *Self) void {
        const shift_amt = self.read_idx;
        // std.debug.print("Shifting by {d}\n", .{self.read_idx});
        var idx: u8 = 0;
        while (idx + shift_amt < self.bits.len) : (idx += 1) {
            self.bits[idx] = self.bits[idx + shift_amt];
        }
        self.write_idx -= self.read_idx;
        self.read_idx = 0;
    }

    pub fn bitsUnconsumed(self: *const Self) u8 {
        return (self.write_idx - self.read_idx);
    }

    pub fn bitsWriteable(self: *const Self) u8 {
        return (@truncate(u8, self.bits.len) - self.write_idx);
    }

    pub fn readBits(self: *Self, num_bits: u8) !u16 {
        if (self.read_idx + num_bits > self.bits.len) {
            return error.EndOfStream;
        }
        std.debug.assert(num_bits <= 16);
        const result: u16 = barrayToU16(self.bits[self.read_idx .. self.read_idx + num_bits]);
        self.read_idx += num_bits;
        return result;
    }

    pub fn consumeHeader(self: *Self, bits_processed: *u15) MsgHeader {
        // std.debug.print("\tConsuming header from...\n\t", .{});
        // BitsMsg.printSlice(self.bits[self.read_idx .. self.read_idx + 6]);

        const version = self.readBits(3) catch unreachable;
        const ttype = self.readBits(3) catch unreachable;
        bits_processed.* += 6;

        const result = MsgHeader{
            .version = @truncate(u3, version),
            .ttype = @truncate(u3, ttype),
        };

        // std.debug.print("returning {s}\n", .{result});
        return result;
    }

    pub fn unconsumedSlice(self: *Self) []u1 {
        return self.bits[self.read_idx..self.write_idx];
    }

    pub fn consumeLiteralChunk(self: *Self, literal: *u64, bits_processed: *u15) bool {
        const keep_going = self.readBits(1) catch unreachable;
        const chunk = self.readBits(4) catch unreachable;
        bits_processed.* += 5;

        literal.* = literal.* << 4;
        literal.* += chunk;
        return keep_going == 1;
    }

    pub fn consumeOp(self: *Self, bits_processed: *u15) Content {
        const length_type = @truncate(u1, self.readBits(1) catch unreachable);
        bits_processed.* += 1;
        switch (length_type) {
            0 => {
                const subpackets_len = self.readBits(15) catch unreachable;
                bits_processed.* += 15;
                // const result = Type0Op{ .subpackets_length = @truncate(u15, subpackets_len) };

                return Content{ .type0 = Type0Op{ .subpackets_length = @truncate(u15, subpackets_len) } };

                // return Content{ .type0 = result };
            },
            1 => {
                const num_subpackets = self.readBits(11) catch unreachable;
                bits_processed.* += 11;
                // const result = Type1Op{ .num_subpackets = @truncate(u11, num_subpackets) };
                return Content{ .type1 = Type1Op{ .num_subpackets = @truncate(u11, num_subpackets) } };

                // return Content{ .type1 = result };
            },
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) unreachable;

    var context_stack = std.ArrayList(PacketContext).init(gpa.allocator());
    defer context_stack.deinit();
    try context_stack.append(PacketContext{});

    var bits = BitsMsg{};
    // bits.ingest(msg[0..]);
    // bits.print();
    // std.debug.print("\nv{d}", .{bits.version()});

    const filename = "day16.txt";
    var file = try std.fs.cwd().openFile(filename, .{});
    var file_finished = false;

    var version_sum: u64 = 0;

    const debug = false;

    const SUM_TTYPE: u3 = 0;
    const PROD_TTYPE: u3 = 1;
    const MIN_TTYPE: u3 = 2;
    const MAX_TTYPE: u3 = 3;
    const GT_TTYPE: u3 = 5;
    const LT_TTYPE: u3 = 6;
    const EQ_TTYPE: u3 = 7;

    var final_result: u64 = 0;

    while (true) {
        // make sure that there are always
        // min(16, remaining bits left in file) bits
        // available to read from the stream

        if (bits.bitsWriteable() < 16) {
            bits.clearProcessedBits();

            // the buffer now has the maximum possible
            // blank space for writing. if there is still
            // not much writeable space, the whole buffer
            // is being taken up by unread bits.
        }

        // top-up the buffer
        while (!file_finished and (bits.bitsWriteable() >= 4)) {
            const hex = file.reader().readByte() catch {
                file_finished = true;
                break;
            };
            if (hex == '\n') {
                file_finished = true;
                break; // file accidentally ends with newline
            }
            bits.ingestHex(hex) catch unreachable;
        }

        if (!file_finished) {
            std.debug.assert(bits.bitsUnconsumed() >= 16);
        }

        if (debug) {
            std.debug.print("After pumping, bitsUnconsumed {d}\n", .{bits.bitsUnconsumed()});
            BitsMsg.printSlice(bits.unconsumedSlice());
            std.debug.print("\n", .{});
        }

        if (context_stack.items.len == 0) {
            if (debug) {
                std.debug.print("Done processing!\n", .{});
            }
            std.debug.assert(file_finished);
            if (bits.bitsUnconsumed() < 6) {
                std.debug.assert(file_finished);
                var all_zeros = true;
                for (bits.unconsumedSlice()) |b| {
                    all_zeros = all_zeros and (b == 0);
                }
                std.debug.assert(all_zeros);
            }
            break;
        }

        var ctx = &context_stack.items[context_stack.items.len - 1];

        if (ctx.header) |*header| {
            if (header.ttype == 4) {
                if (debug) std.debug.print("Handling literal, tracking bits? {s}\n", .{ctx.return_bits_processed});

                std.debug.assert(bits.bitsUnconsumed() >= 4);

                if (!bits.consumeLiteralChunk(&ctx.content.literal, &ctx.self_bits_processed)) {
                    // literal is done
                    if (debug) std.debug.print("Literal {d}\n", .{ctx.content.literal});
                    ctx.result = ctx.content.literal;

                    var need_pop_ctx = true;
                    while (need_pop_ctx) {
                        // transfer current state up the stack
                        const popped_ctx = context_stack.pop(); // == ctx

                        if (context_stack.items.len == 0) {
                            // the entire message was a literal
                            if (debug) std.debug.print("Entire message was parsed!\n", .{});
                            final_result = popped_ctx.result;

                            break;
                        } else {
                            // this is a subpacket of a bigger message
                            if (debug) std.debug.print("Returning to parent message!\n", .{});
                            var back_ctx = &context_stack.items[context_stack.items.len - 1];
                            back_ctx.subpackets_processed += 1;
                            if (popped_ctx.return_bits_processed) {
                                back_ctx.child_bits_processed += popped_ctx.child_bits_processed + popped_ctx.self_bits_processed;
                            }
                            if (debug) std.debug.print("{s}\n", .{back_ctx});

                            switch (back_ctx.content) {
                                .literal => {
                                    // literals cannot have subpacket
                                    unreachable;
                                },
                                .type0 => |t| {
                                    need_pop_ctx = t.subpackets_length == back_ctx.child_bits_processed;
                                },
                                .type1 => |*t| {
                                    need_pop_ctx = t.num_subpackets == back_ctx.subpackets_processed;
                                },
                            }

                            // accumulate result into parent
                            switch (back_ctx.header.?.ttype) {
                                SUM_TTYPE => {
                                    back_ctx.result += popped_ctx.result;
                                },
                                PROD_TTYPE => {
                                    back_ctx.result *= popped_ctx.result;
                                },
                                MIN_TTYPE => {
                                    back_ctx.result = @minimum(back_ctx.result, popped_ctx.result);
                                },
                                MAX_TTYPE => {
                                    back_ctx.result = @maximum(back_ctx.result, popped_ctx.result);
                                },
                                EQ_TTYPE => {
                                    if (!need_pop_ctx) {
                                        back_ctx.result = popped_ctx.result;
                                    } else if (back_ctx.result == popped_ctx.result) {
                                        back_ctx.result = 1;
                                    } else {
                                        back_ctx.result = 0;
                                    }
                                },
                                LT_TTYPE => {
                                    if (!need_pop_ctx) {
                                        back_ctx.result = popped_ctx.result;
                                    } else if (back_ctx.result < popped_ctx.result) {
                                        back_ctx.result = 1;
                                    } else {
                                        back_ctx.result = 0;
                                    }
                                },
                                GT_TTYPE => {
                                    if (!need_pop_ctx) {
                                        back_ctx.result = popped_ctx.result;
                                    } else if (back_ctx.result > popped_ctx.result) {
                                        back_ctx.result = 1;
                                    } else {
                                        back_ctx.result = 0;
                                    }
                                },
                                else => |t| {
                                    std.debug.print("Unhandled ttype {d}\n", .{t});
                                    unreachable;
                                },
                            }

                            if (!need_pop_ctx) {
                                // the parent message is expecting more subpackets
                                if (debug) std.debug.print("Parent expects more children\n", .{});
                                try context_stack.append(PacketContext{ .return_bits_processed = popped_ctx.return_bits_processed });
                            } else {}
                        }
                    }
                } else {
                    if (debug) std.debug.print("Consumed literal chunk, literal is now {d}\n", .{ctx.content.literal});
                }
            } else {
                if (debug) std.debug.print("Handling op\n", .{});
                ctx.content = bits.consumeOp(&ctx.self_bits_processed);
                switch (ctx.header.?.ttype) {
                    PROD_TTYPE => {
                        ctx.result = 1;
                    },
                    MIN_TTYPE => {
                        ctx.result = std.math.maxInt(u64);
                    },
                    MAX_TTYPE => {
                        ctx.result = 0;
                    },
                    else => {
                        ctx.result = 0;
                    },
                }

                if (debug) std.debug.print("Updated context to {s}\n", .{ctx});

                // prepare a context for the sub-packet
                const new_context = PacketContext{ .return_bits_processed = ((ctx.content == Content.type0) or ctx.return_bits_processed) };
                if (debug) std.debug.print("Pushing context {s}\n", .{new_context});
                try context_stack.append(new_context);
            }
        } else {
            if (debug) std.debug.print("Handling new packet\n", .{});
            ctx.header = bits.consumeHeader(&ctx.self_bits_processed);
            version_sum += ctx.header.?.version;
            if (debug) std.debug.print("Ingested header {s}\n", .{ctx.header});
        }
    }

    std.debug.print("version sum {d}\n", .{version_sum});
    std.debug.print("final result {d}\n", .{final_result});
}
