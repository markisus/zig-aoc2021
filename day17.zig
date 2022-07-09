const std = @import("std");

pub fn isInTarget(x_min: i64, x_max: i64, y_min: i64, y_max: i64, x: i64, y: i64) bool {
    return (x_min <= x) and (x <= x_max) and (y_min <= y) and (y <= y_max);
}

// only for when yvel0 is positive
pub fn doesHitTarget0(x_min: i64, x_max: i64, y_min: i64, y_max: i64, xvel0: i64, yvel0: i64) bool {
    // shortcut: start off when we cross the horizontal axis
    const num_steps_to_cross_horizontal = yvel0 * 2 + 1;

    var y: i64 = 0;
    var yvel: i64 = -(yvel0 + 1);

    // solve for the initial x value @ num_steps_to_cross_horizontal
    // const x_terminal = @divExact(xvel0 * (xvel0 + 1), 2); // xvel0 = 5, then x_terminal = 5+4+3+2+1 = 5*(5+1)/2
    const num_steps_to_terminal_x = xvel0; // the step at which x reaches its maximum value

    // case: terminal velocity is reached before horizontal crossing
    // if num_steps_to_cross_horizontal = 10
    //    num_steps_to_terminal_x = 3
    // then x reaches terminal velocity before the crossing
    //    x = xvel0 + (xvel0-1) + (xvel0-2) = 3*xvel0 - 3*(3-1)/2
    //    xvel = 0
    //
    // case: terminal velocity is not reached before horizontal corssing
    // if num_steps_to_cross_horizontal = 3
    //    num_steps_to_terminal_x = 4
    // then x reaches terminal velocity before the crossing
    //    x = xvel0 + (xvel0-1) + (xvel0-2) = 3*xvel0 - 3*(3-1)/2
    //    xvel = xvel0 - 3

    const relevant_x_steps = @minimum(num_steps_to_cross_horizontal, num_steps_to_terminal_x);
    var x = relevant_x_steps * xvel0 - @divExact(relevant_x_steps * (relevant_x_steps - 1), 2);
    var xvel = xvel0 - relevant_x_steps;
    if (xvel < 0) xvel = 0;

    while (x <= x_max and y >= y_min) {
        x += xvel;
        y += yvel;

        yvel -= 1;
        xvel -= 1;
        if (xvel < 0) xvel = 0;

        // std.debug.print("[v {d}, {d}] ", .{ xvel, yvel });

        if (isInTarget(x_min, x_max, y_min, y_max, x, y)) return true;
    }

    return false;
}

// only for when yvel0 is positive
pub fn doesHitTarget1(x_min: i64, x_max: i64, y_min: i64, y_max: i64, xvel0: i64, yvel0: i64) bool {
    // shortcut: start off when we cross the horizontal axis
    const num_steps_to_cross_horizontal = yvel0 * 2 + 1;

    var y: i64 = 0;
    var yvel: i64 = -(yvel0 + 1);

    // solve for the initial x value @ num_steps_to_cross_horizontal
    // const x_terminal = @divExact(xvel0 * (xvel0 + 1), 2); // xvel0 = 5, then x_terminal = 5+4+3+2+1 = 5*(5+1)/2
    const num_steps_to_terminal_x = xvel0; // the step at which x reaches its maximum value

    // case: terminal velocity is reached before horizontal crossing
    // if num_steps_to_cross_horizontal = 10
    //    num_steps_to_terminal_x = 3
    // then x reaches terminal velocity before the crossing
    //    x = xvel0 + (xvel0-1) + (xvel0-2) = 3*xvel0 - 3*(3-1)/2
    //    xvel = 0
    //
    // case: terminal velocity is not reached before horizontal corssing
    // if num_steps_to_cross_horizontal = 3
    //    num_steps_to_terminal_x = 4
    // then x reaches terminal velocity before the crossing
    //    x = xvel0 + (xvel0-1) + (xvel0-2) = 3*xvel0 - 3*(3-1)/2
    //    xvel = xvel0 - 3

    const relevant_x_steps = @minimum(num_steps_to_cross_horizontal, num_steps_to_terminal_x);
    var x = relevant_x_steps * xvel0 - @divExact(relevant_x_steps * (relevant_x_steps - 1), 2);
    var xvel = xvel0 - relevant_x_steps;
    if (xvel < 0) xvel = 0;

    while (x <= x_max and y >= y_min) {
        x += xvel;
        y += yvel;

        yvel -= 1;
        xvel -= 1;
        if (xvel < 0) xvel = 0;

        // std.debug.print("[v {d}, {d}] ", .{ xvel, yvel });

        if (isInTarget(x_min, x_max, y_min, y_max, x, y)) return true;
    }

    return false;
}

pub fn yvel0ToMaxHeight(yvel0: i64) i64 {
    // convert yvel0 to maximum
    // if yvel0 = 5, then the max is attained at 5+4+3+2+1 = 5*(5+1)/2
    return @divExact(yvel0 * (yvel0 + 1), 2);
}

// return the yvel0 that gives the max height, s.t the target is hit
pub fn solve0(x_min: i64, x_max: i64, y_min: i64, y_max: i64) i64 {
    std.debug.assert(y_min < 0);
    std.debug.assert(y_max < 0);

    std.debug.assert(x_min > 0);
    std.debug.assert(x_max > 0);

    // if y_min = -50 then yvel_ub = 50 (not inclusive),
    // because suppose we launch at yvel = 50, then when we cross
    // the horizontal axis again, yvel = -51 and will totally skip
    // over the target region
    const yvel_ub: i64 = -y_min;

    // if x_max = 50, then launching at 51 will completely
    // skip over the target in the first step, so x_max + 1
    // an easy upper bound (not inclusive)
    const xvel_ub: i64 = x_max + 1;
    const xvel_lb = getXvelLb(x_min);

    var yvel0: i64 = yvel_ub - 1;

    while (yvel0 > 0) : (yvel0 -= 1) {
        var xvel0: i64 = xvel_ub - 1;
        while (xvel0 >= xvel_lb) : (xvel0 -= 1) {
            if (doesHitTarget0(x_min, x_max, y_min, y_max, xvel0, yvel0)) {
                // convert yvel0 to maximum
                // if yvel0 = 5, then the max is attained at 5+4+3+2+1 = 5*(5+1)/2
                return yvel0;
            }
        }
    }

    return 0;
}

pub fn getXvelLb(x_min: i64) i64 {
    // if x_min = 50, then launching at velocity whose
    // terminal x value is less than 50 will miss.
    // eg if xvel0 = 5, then x_terminal = 5+4+3+2+1 = 5*(5+1)/2 = 15
    // we need to solve x_min <= xt
    //                  x_min <= xv0*(xv0+1)/2
    var xvel_lb: i64 = 1;
    while (@divExact(xvel_lb * (xvel_lb + 1), 2) < x_min) : (xvel_lb += 1) {}
    return xvel_lb;
}

// return the number of solutions that hit the target
pub fn solve1(x_min: i64, x_max: i64, y_min: i64, y_max: i64, max_yvel0: i64) u64 {
    std.debug.assert(y_min < 0);
    std.debug.assert(y_max < 0);

    std.debug.assert(x_min > 0);
    std.debug.assert(x_max > 0);

    var num_slns: u64 = 0;

    // if x_max = 50, then launching at 51 will completely
    // skip over the target in the first step, so x_max + 1
    // an easy upper bound (not inclusive)
    const xvel_ub: i64 = x_max + 1;
    const xvel_lb = getXvelLb(x_min);

    const yvel_lb = y_min - 1;
    var yvel0: i64 = max_yvel0;

    while (yvel0 >= yvel_lb) : (yvel0 -= 1) {
        var xvel0: i64 = xvel_ub - 1;
        while (xvel0 >= xvel_lb) : (xvel0 -= 1) {
            if (yvel0 > 0) {
                if (doesHitTarget0(x_min, x_max, y_min, y_max, xvel0, yvel0)) {
                    num_slns += 1;
                }
            } else {
                if (doesHitTarget1(x_min, x_max, y_min, y_max, xvel0, yvel0)) {
                    num_slns += 1;
                }
            }
        }
    }

    return num_slns;
}

pub fn main() !void {
    // const max_yvel0 = solve0(20, 30, -10, -5); // test
    const max_yvel0 = solve0(150, 171, -129, -70); // part1
    std.debug.print("best yvel0 {d}, max height {d}\n", .{ max_yvel0, yvel0ToMaxHeight(max_yvel0) });

    // const sln1 = solve1(20, 30, -10, -5, max_yvel0); // test
    const sln1 = solve1(150, 171, -129, -70, max_yvel0); // part2
    std.debug.print("sln1 {d}\n", .{sln1});
}
