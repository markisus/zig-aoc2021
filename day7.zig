const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const GPA = std.heap.GeneralPurposeAllocator(.{});
const CrabMap = std.AutoArrayHashMap(i64, i64); // location => count
const CrabBucket = struct { location: i64, count: i64, num_to_left: i64 };
const CrabArray = std.ArrayList(CrabBucket);

pub fn crabBucketLessThan(ctx: void, lhs: CrabBucket, rhs: CrabBucket) bool {
    _ = ctx;
    return lhs.location < rhs.location;
}

pub fn rstrip(buf: []u8) []u8 {
    if (buf.len == 0) return buf;
    if (buf[buf.len - 1] == '\n') return rstrip(buf[0 .. buf.len - 1]);
    return buf;
}

pub fn main() !void {
    // We seek to minimize this objective.
    // min_x of Σᵢ abs(pᵢ - x) where the norm is l1.
    //
    // Note that each term inside the sum, namely abs(pᵢ - x)
    // is a convex function of x.
    //
    // Therefore we may use subgradient descent to locate the minimum.
    // At some value x, if there are R to the right, L to the left and T
    // on top, then a subgradient is (L - R +- T).
    //
    // Furthermore, since the problem can be modelled as an LP, we know
    // the solution occurs at a particular crab position pᵢ.
    // The LP model is as follows.
    //
    // min_{x,cᵢ} of Σᵢ cᵢ
    // s.t.
    // 0 <= cᵢ
    // pᵢ - x <= cᵢ
    // x - pᵢ <= cᵢ

    var gpa: GPA = .{};
    var allocator = gpa.allocator();
    defer {
        assert(!gpa.deinit());
    }

    var crab_map = CrabMap.init(allocator);
    defer crab_map.deinit();

    var crab_array = CrabArray.init(allocator);
    defer crab_array.deinit();

    var file = try std.fs.cwd().openFile("day7.txt", .{});
    defer file.close();

    var file_reader = std.io.bufferedReader(file.reader()).reader();
    var crab_str_buf: [10]u8 = undefined;
    while (try file_reader.readUntilDelimiterOrEof(crab_str_buf[0..], ',')) |crab_str| {
        const crab = try std.fmt.parseInt(i64, rstrip(crab_str), 10);
        const gop = try crab_map.getOrPut(crab);
        if (gop.found_existing) {
            gop.value_ptr.* += 1;
        } else {
            gop.value_ptr.* = 1;
        }
    }

    var crab_map_it = crab_map.iterator();
    while (crab_map_it.next()) |entry| {
        var bucket = try crab_array.addOne();
        bucket.location = entry.key_ptr.*;
        bucket.count = entry.value_ptr.*;
    }

    // crab array
    std.sort.sort(CrabBucket, crab_array.items, {}, crabBucketLessThan);

    var global_num_to_left: i64 = 0;
    for (crab_array.items) |*bucket| {
        bucket.num_to_left = global_num_to_left;
        global_num_to_left += bucket.count;
    }

    // the number of crabs is the number
    // of crabs to the left after we run
    // off the end of the array
    const num_crabs = global_num_to_left;

    var best_location: i64 = undefined;
    for (crab_array.items) |bucket| {
        const num_to_right = num_crabs - bucket.num_to_left - bucket.count;
        const num_to_left = bucket.num_to_left;
        const num_here = bucket.count;
        assert(num_to_right + num_to_left + num_here == num_crabs); // check arithmetic

        const slope: i64 = num_to_left + num_here - num_to_right;
        if (0 <= slope) {
            best_location = bucket.location;
            break;
        }
    }

    var energy_usage: i64 = 0;
    for (crab_array.items) |bucket| {
        const energy: i64 =
            if (bucket.location < best_location)
            best_location - bucket.location
        else
            bucket.location - best_location;
        energy_usage += energy * bucket.count;
    }

    print("part 1: energy usage {d}\n", .{energy_usage});

    // For part 2, a move of d costs (1 + 2 + ... d) = d*(d+1)/2 = (d² + d)/2
    // This is still a convex cost function per crab, so the total optimization is still convex.
    // Scaling by a factor of two for simplicity, we can say a move costs d² + d = (x - p)² + |x-p|.
    //
    // The total objective, summing over all crabs, obtains an additional quadratic term.
    // n x² - 2 Σpᵢ x + Σpᵢ² whose slope is 2 nx - 2 Σpᵢ, where n is number of crabs.
    //
    // The optimal value is no longer guaranteed to occur at a particular crab bucket.
    // It's not even guaranteed to occur at an integral location. But we can easily round the
    // best solution to an integer, which should be the best integral solution.

    // calculate Σpᵢ which appears in the derivative
    var sum_locations: i64 = 0;
    for (crab_array.items) |bucket| {
        sum_locations += bucket.location * bucket.count;
    }

    // print("sum locations {d}\n", .{sum_locations});

    // Gradient descent again, with the new expression for derivative
    for (crab_array.items) |bucket| {
        const num_to_right = num_crabs - bucket.num_to_left - bucket.count;
        const num_to_left = bucket.num_to_left;
        const num_here = bucket.count;
        assert(num_to_right + num_to_left + num_here == num_crabs); // check arithmetic

        const slope_linterm: i64 = num_to_left - (num_to_right + num_here);
        const slope = slope_linterm + 2 * bucket.location * num_crabs - 2 * sum_locations; // quadratic term
        // print("slope at {d} = {d}\n", .{ bucket.location, slope });
        if (0 <= slope) {
            // We've hit or gone slightly past the optimal location.
            // Find where the slope = 0 between this bucket and the previous.
            // slope(x) = slope_linterm + 2 * (n x - sum_locations)
            // 0        = slope_linterm + 2 n x - 2*sum_locations)
            // -slope_linterm + 2*sum_locations     = 2x
            // (-slope_linterm + 2*sum_locations)/(2 n) = x
            best_location = @divTrunc(2 * sum_locations - slope_linterm, 2 * num_crabs);
            // This location may be off-by-one due to roundning, need to test best_location+1 as well.
        }
    }

    var energy_usages: [2]i64 = undefined;
    for (energy_usages) |*usage| {
        usage.* = 0;
        for (crab_array.items) |bucket| {
            const distance: i64 =
                if (bucket.location < best_location)
                best_location - bucket.location
            else
                bucket.location - best_location;
            const energy = @divExact(distance * (distance + 1), 2) * bucket.count;
            usage.* += energy;
        }
    }
    var energy_usage_min = std.math.min(energy_usages[0], energy_usages[1]);
    print("part 2: energy usage {d}\n", .{energy_usage_min});
}
