const std = @import("std");

const Hasher = struct {
    const Self = @This();

    md5: std.crypto.hash.Md5 = std.crypto.hash.Md5.init(.{}),

    pub fn addBytes(self: *Self, bytes: []const u8) void {
        // std.debug.print("hashBytes with bytes {c}\n", .{bytes});
        self.md5.update(bytes);
        // var hash_out: u128 = undefined;
        // self.md5.final(hashToByteArray(&hash_out));
        // return hash_out;
    }

    pub fn addTs(self: *Self, comptime T: type, ts: []const T) void {
        var slice: []const u8 = undefined;
        slice.len = ts.len * @sizeOf(T);
        slice.ptr = @intToPtr([*]u8, @ptrToInt(ts.ptr));
        self.addBytes(slice);
    }

    pub fn addT(self: *Self, comptime T: type, t: T) void {
        var slice: []const u8 = undefined;
        slice.len = @sizeOf(T);
        slice.ptr = @intToPtr([*]u8, @ptrToInt(&t));
        self.addBytes(slice);
    }

    pub fn get(self: *Self) u128 {
        var hash_out: u128 = undefined;
        self.md5.final(hashToByteArray(&hash_out));
        return hash_out;
    }
};

pub fn hashToByteArray(hash: *u128) *[16]u8 {
    return @ptrCast(*[16]u8, hash);
}

pub fn abs16(x: i16) u16 {
    const absx = std.math.absInt(x) catch unreachable;
    return @intCast(u16, absx);
}

pub fn absPt(xyz: [3]i16) [3]u16 {
    return .{ abs16(xyz[0]), abs16(xyz[1]), abs16(xyz[2]) };
}

pub fn l1Pt(xyz: [3]i16) u16 {
    const abs_xyz = absPt(xyz);
    return @maximum(@maximum(abs_xyz[0], abs_xyz[1]), abs_xyz[2]);
}

pub fn manhattanDist(p0: [3]i16, p1: [3]i16) u16 {
    const delta = absPt(subPts(p0, p1));
    return delta[0] + delta[1] + delta[2];
}

pub fn ptsEq(p1: [3]i16, p2: [3]i16) bool {
    return std.mem.eql(i16, p1[0..], p2[0..]);
}

pub fn subPts(p1: [3]i16, p2: [3]i16) [3]i16 {
    var result: [3]i16 = undefined;
    for (result) |*el, i| {
        el.* = p1[i] - p2[i];
    }
    return result;
}

pub fn ptToI32(p: [3]i16) [3]i32 {
    var result: [3]i32 = undefined;
    for (result) |*el, i| {
        el.* = p[i];
    }
    return result;
}
pub fn ptToI16(p: [3]i32) [3]i16 {
    var result: [3]i16 = undefined;
    for (result) |*el, i| {
        el.* = @truncate(i16, p[i]);
    }
    return result;
}

pub fn addPtsT(comptime T: type, p1: [3]T, p2: [3]T) [3]T {
    var result: [3]T = undefined;
    for (result) |*el, i| {
        el.* = p1[i] + p2[i];
    }
    return result;
}

pub fn mulPtsT(comptime T: type, k: T, p: [3]T) [3]T {
    var result: [3]T = undefined;
    for (result) |*el, i| {
        el.* = k * p[i];
    }
    return result;
}
pub fn subPtsT(comptime T: type, p1: [3]T, p2: [3]T) [3]T {
    var result: [3]T = undefined;
    for (result) |*el, i| {
        el.* = p1[i] - p2[i];
    }
    return result;
}

pub fn addPts(p1: [3]i16, p2: [3]i16) [3]i16 {
    return addPtsT(i16, p1, p2);
}

const RegionDescriptor = struct {
    const Self = @This();
    const NeighborhoodSize = 150;

    allocator: std.mem.Allocator,
    hashes: std.ArrayList(u128),
    points: std.ArrayList([3]i16),

    pub fn init(allocator: std.mem.Allocator) Self {
        var self: Self = undefined;
        self.allocator = allocator;
        self.hashes = std.ArrayList(u128).init(allocator);
        self.points = std.ArrayList([3]i16).init(allocator);
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.points.deinit();
        self.hashes.deinit();
    }

    pub fn clear(self: *Self) void {
        self.points.clearRetainingCapacity();
        self.hashes.clearRetainingCapacity();
    }

    pub fn makeInvariantPoint(xyz: [3]i16) [3]u16 {
        var x = abs16(xyz[0]);
        var y = abs16(xyz[1]);
        var z = abs16(xyz[2]);

        // sorting the coordinates
        if (y < x) {
            const t = x;
            x = y;
            y = t;
        }
        if (z < x) {
            const t = x;
            x = z;
            z = t;
        }
        // x is now the min
        // fix y and z
        if (y > z) {
            const t = y;
            y = z;
            z = t;
        }
        const invariantPoint: [3]u16 = .{ x, y, z };
        return invariantPoint;
    }

    pub fn ingest(self: *Self, xyz: [3]i16) !void {
        var x = abs16(xyz[0]);
        var y = abs16(xyz[1]);
        var z = abs16(xyz[2]);

        // if out of neighborhood, do nothing
        if (x >= NeighborhoodSize) return;
        if (y >= NeighborhoodSize) return;
        if (z >= NeighborhoodSize) return;

        try self.points.append(xyz);
        // try self.pt_hashes.append(hashPoint(xyz));
    }

    pub fn generate(self: *Self) !u128 {
        var hasher = Hasher{};

        hasher.addT(usize, self.points.items.len);

        var total: [3]i16 = .{ 0, 0, 0 };
        for (self.points.items) |pt| {
            total = addPtsT(i16, pt, total);
        }

        const invariantTotal = makeInvariantPoint(total);
        hasher.addT([3]u16, invariantTotal);

        // the total vector defines a canonical direction where
        // we can take projection
        const total32 = ptToI32(total);

        self.hashes.clearRetainingCapacity();
        for (self.points.items) |pt16| {
            var inner_hasher = Hasher{};

            // n = vector towards centroid
            //   = (total / k)  where k is ||total||
            //
            // pt|| + ptT = pt
            // (pt.n)*n + ptT =  pt
            // ptT = pt - pt.n*n
            //
            // let K = k^2
            // K ptT = K pt - (pt. k n)* k n
            // K ptT = K pt - (pt. total) * total

            var K: i32 = 0;
            for (total32) |el| {
                K += el * el;
            }

            const pt = ptToI32(pt16);
            const Kpt = mulPtsT(i32, K, pt);
            const pt_dot_total = pt[0] * total[0] + pt[1] * total[1] + pt[2] * total[2];

            inner_hasher.addT(i32, pt_dot_total); // ingest this since it's rotation invariant

            const par = mulPtsT(i32, pt_dot_total, total32);
            const perp = ptToI16(subPtsT(i32, Kpt, par));
            const perpInvariant = makeInvariantPoint(perp);

            inner_hasher.addT([3]u16, perpInvariant);

            try self.hashes.append(inner_hasher.get());
        }

        // sort to make the list permutation invariant
        std.sort.sort(u128, self.hashes.items, {}, comptime std.sort.asc(u128));
        for (self.hashes.items) |hash| {
            hasher.addT(u128, hash);
        }

        return hasher.get();
    }
};

const Scan = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    points: std.ArrayList([3]i16),
    // descriptor_lists: std.ArrayList(Node),
    descriptor_lookup: std.AutoHashMap(u128, u16), // lookup into points array
    pt_set: std.AutoHashMap([3]i16, u16), // lookup into points array

    pub fn init(allocator: std.mem.Allocator) Self {
        var self: Self = undefined;
        self.allocator = allocator;
        self.points = std.ArrayList([3]i16).init(allocator);
        self.descriptor_lookup = std.AutoHashMap(u128, u16).init(allocator);
        self.pt_set = std.AutoHashMap([3]i16, u16).init(allocator);
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.points.deinit();
        self.descriptor_lookup.deinit();
        self.pt_set.deinit();
    }

    // returns index in .points.items array where
    // the point resides
    pub fn addPoint(self: *Self, pt: [3]i16) !u16 {
        var gop = try self.pt_set.getOrPut(pt);
        if (!gop.found_existing) {
            try self.points.append(pt);
            gop.value_ptr.* = @truncate(u16, self.points.items.len - 1);
        }
        return gop.value_ptr.*;
    }

    pub fn merge(self: *Self, other: *Self, tx_self_other: Transform) !void {
        // first merge the points with descriptors
        // so that we can control the lookup
        var other_it = other.descriptor_lookup.iterator();
        while (other_it.next()) |kv| {
            const descriptor = kv.key_ptr.*;
            const other_point = other.points.items[kv.value_ptr.*];
            const point = applyTransform(tx_self_other, other_point);
            const self_idx = try self.addPoint(point);
            try self.descriptor_lookup.put(descriptor, self_idx);
        }

        // now add the rest of the points
        for (other.points.items) |other_point| {
            const point = applyTransform(tx_self_other, other_point);
            _ = try self.addPoint(point);
        }
    }

    pub fn makeDescriptors(self: *Self, descriptor: *RegionDescriptor) !void {
        // std.debug.print("Adding descriptors\n", .{});
        for (self.points.items) |center, i| {
            // too close to boundary for accurate region descriptor
            const l1 = l1Pt(center);
            if (l1 > 1000 - RegionDescriptor.NeighborhoodSize) {
                // std.debug.print("skip l1 {d}, center {d},{d},{d}\n", .{ l1, center[0], center[1], center[2] });
                continue;
            }

            descriptor.clear();
            for (self.points.items) |other| {
                const delta = subPts(other, center);
                try descriptor.ingest(delta);
            }
            const d = try descriptor.generate();
            try self.descriptor_lookup.put(d, @truncate(u16, i));
        }
        // std.debug.print("Added {d} descriptors\n", .{self.descriptor_lookup.count()});
    }
};

pub fn getCorrespondences(base: *Scan, other: *Scan) CorrespondenceTable {
    var ctable = CorrespondenceTable{};
    var it = base.descriptor_lookup.iterator();
    while (it.next()) |kv0| {
        const s0 = kv0.value_ptr.*;
        if (other.descriptor_lookup.get(kv0.key_ptr.*)) |s1| {
            ctable.add(base.points.items[s0], other.points.items[s1]) catch break;
        }
    }
    return ctable;
}

const X = 1;
const Y = 2;
const Z = 3;

pub fn genRotations() [24][3]i8 {

    // equivalence classes of
    // orientation preserving rotations
    // based on the permutation of axes
    // zig fmt: off
    const base_rotations: [6][3]i8 = .{
        .{  X, Y, Z },
        .{ -X, Z, Y },
        .{  Y, Z, X },
        .{ -Y, X, Z },
        .{  Z, X, Y },
        .{ -Z, Y, X }
    };
    // zig fmt: on

    var rotations: [24][3]i8 = undefined;

    var i: u8 = 0;
    for (base_rotations) |base_rotation| {
        std.mem.copy(i8, rotations[i][0..], base_rotation[0..]);
        i += 1;

        // flip axes in all possible ways
        // by choosing two to flip (det remains same)
        var skip_flip_i: u8 = 0;
        while (skip_flip_i < 3) : (skip_flip_i += 1) {
            std.mem.copy(i8, rotations[i][0..], base_rotation[0..]);
            for (rotations[i]) |*axis, j| {
                if (skip_flip_i != j) axis.* *= -1;
            }
            i += 1;
        }
    }

    return rotations;
}

pub fn applyRotation(rot: [3]i8, pt: [3]i16) [3]i16 {
    var result: [3]i16 = undefined;
    for (rot) |axis, i| {
        if (axis < 0) {
            result[@intCast(u8, (-axis)) - 1] = -pt[i];
        } else {
            result[@intCast(u8, axis) - 1] = pt[i];
        }
    }
    return result;
}

const Transform = struct { rot: [3]i8, trans: [3]i16 };

pub fn applyTransform(transform: Transform, pt: [3]i16) [3]i16 {
    return addPts(applyRotation(transform.rot, pt), transform.trans);
}

const ROTATIONS = genRotations();

pub fn guessTransformImpl(base: [][3]i16, other: [][3]i16, align_idx: u8) ?Transform {
    for (ROTATIONS) |rotation| {
        var tx_base_other: Transform = undefined;
        tx_base_other.rot = rotation;

        // solve the first equation
        // base[0] = tx_base_other * other[0]
        {
            const b = base[align_idx];
            const o = other[align_idx];
            const ro = applyRotation(rotation, o);
            tx_base_other.trans = subPts(b, ro);
            const checkb = applyTransform(tx_base_other, o);
            std.debug.assert(ptsEq(checkb, b));
        }

        var penalties: i16 = 0;
        var transform_works = true;
        for (base) |b, i| {
            const o = other[i];
            if (!ptsEq(applyTransform(tx_base_other, o), b)) {
                penalties += 1;
            }
            if (penalties > base.len / 3) {
                // std.debug.print("\tPenalties {d}!\n", .{penalties});
                transform_works = false;
                break;
            }
        }

        if (transform_works) {
            // std.debug.print("Returning with penalties {d}\n", .{penalties});
            return tx_base_other;
        }
    }

    return null;
}

pub fn guessTransform(base: [][3]i16, other: [][3]i16) ?Transform {
    if (base.len == 0) return null;
    std.debug.assert(base.len == other.len);

    var idx: u8 = 0;
    while (idx < @minimum(base.len, 4)) : (idx += 1) {
        if (guessTransformImpl(base, other, idx)) |tx| return tx;
    }

    return null;
}

const CorrespondenceTable = struct {
    const MAX_MATCHES = 25;
    const Self = @This();

    base: [MAX_MATCHES][3]i16 = undefined,
    other: [MAX_MATCHES][3]i16 = undefined,
    num_matches: u8 = 0,

    pub fn add(self: *Self, basePt: [3]i16, otherPt: [3]i16) !void {
        if (self.num_matches == MAX_MATCHES) {
            return error.MaxMatchesReached;
        }
        self.base[self.num_matches] = basePt;
        self.other[self.num_matches] = otherPt;
        self.num_matches += 1;
    }

    pub fn clear(self: *Self) void {
        self.num_matches = 0;
    }

    pub fn basePoints(self: *Self) [][3]i16 {
        return self.base[0..self.num_matches];
    }

    pub fn otherPoints(self: *Self) [][3]i16 {
        return self.other[0..self.num_matches];
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) unreachable;

    var descriptor = RegionDescriptor.init(gpa.allocator());
    defer descriptor.deinit();

    var scans: [100]Scan = undefined;
    var num_scans: u8 = 0;
    defer {
        var i: u8 = 0;
        while (i < num_scans) : (i += 1) {
            scans[i].deinit();
        }
    }

    var file = try std.fs.cwd().openFile("day19.txt", .{});
    var buf: [512]u8 = undefined;
    while (try file.reader().readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        if (line.len == 0) continue;
        if (std.mem.eql(u8, line[0..3], "---")) {
            // compute the scan previous
            // std.debug.print("Ingesting scanner {d}\n", .{num_scans});
            scans[num_scans] = Scan.init(gpa.allocator());
            num_scans += 1;
            continue;
        }

        var tokens = std.mem.tokenize(u8, line, ",");
        var pt: [3]i16 = undefined;
        for (pt) |*el| {
            el.* = try std.fmt.parseInt(i16, tokens.next().?, 10);
        }
        _ = try scans[num_scans - 1].addPoint(pt);
    }

    // make descriptors for all maps
    {
        var sidx: u8 = 0;
        while (sidx < num_scans) : (sidx += 1) {
            try scans[sidx].makeDescriptors(&descriptor);
            if (scans[sidx].descriptor_lookup.count() == 0) {
                return error.NoDescriptors;
            }
        }
    }

    var global_map = Scan.init(gpa.allocator());
    defer global_map.deinit();
    try global_map.merge(&scans[0], Transform{ .rot = .{ X, Y, Z }, .trans = .{ 0, 0, 0 } });

    // idx => coordinate in the merged system
    var maps_merged = std.AutoHashMap(u8, [3]i16).init(gpa.allocator());
    defer maps_merged.deinit();
    try maps_merged.put(0, .{ 0, 0, 0 });

    while (maps_merged.count() != num_scans) {
        var sidx: u8 = 0;
        var merged_any = false;
        while (sidx < num_scans) : (sidx += 1) {
            if (maps_merged.contains(sidx)) continue; // already merged this map
            var matches = getCorrespondences(&global_map, &scans[sidx]);
            const overlap_thresh = 5;
            if (matches.num_matches >= overlap_thresh) {
                if (guessTransform(matches.basePoints(), matches.otherPoints())) |tx_base_other| {
                    try global_map.merge(&scans[sidx], tx_base_other);
                    try maps_merged.put(sidx, tx_base_other.trans);
                    merged_any = true;
                    break;
                }
            }
        }
        if (!merged_any) {
            std.debug.print("Could not grow the map\n", .{});
            return error.MapMergeFailed;
        }
    }

    std.debug.print("Num points = {d}\n", .{global_map.points.items.len});

    var biggest_mdist: u16 = 0;
    {
        var it0 = maps_merged.iterator();
        while (it0.next()) |kv0| {
            const p0 = kv0.value_ptr.*;
            var it1 = it0;
            while (it1.next()) |kv1| {
                const p1 = kv1.value_ptr.*;
                const mdist = manhattanDist(p1, p0);
                biggest_mdist = @maximum(mdist, biggest_mdist);
            }
        }
    }
    std.debug.print("biggest manhattan dist {d}\n", .{biggest_mdist});
}

test "t0" {
    // region1
    const p1: [3]i16 = .{ -1, 2, 3 };
    const p2: [3]i16 = .{ 30, -2, 1 };
    const p3: [3]i16 = .{ 3, -2, 5 };

    const rot: [3]i8 = .{ Y, -X, Z };
    const r1 = applyRotation(rot, p1);
    const r2 = applyRotation(rot, p2);
    const r3 = applyRotation(rot, p3);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) unreachable;

    var d1 = RegionDescriptor.init(gpa.allocator());
    defer d1.deinit();

    var d2 = RegionDescriptor.init(gpa.allocator());
    defer d2.deinit();

    try d1.ingest(p1);
    try d1.ingest(p2);
    try d1.ingest(p3);
    const d1_descriptor = try d1.generate();

    try d2.ingest(r1);
    try d2.ingest(r2);
    try d2.ingest(r3);
    const d2_descriptor = try d2.generate();

    try std.testing.expect(d1_descriptor == d2_descriptor);

    try d2.ingest(.{ 1, 1, 1 });
    const d2_descriptor_alt = try d2.generate();
    try std.testing.expect(d1_descriptor != d2_descriptor_alt);
}
