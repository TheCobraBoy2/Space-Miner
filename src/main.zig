// -------------------------------
const std = @import("std");
const Space_Miner = @import("Space_Miner");
const BoundedArray = @import("BoundedArray").BoundedArray;
const rl = @import("raylib");
const rg = @import("raygui");

const Textures = @import("textures.zig");
const Sounds = @import("sounds.zig");

// ------------------------------
// ---        Mappings        ---
// ------------------------------
const Vector2 = rl.Vector2;
const Math = std.math;
const Rand = std.Random;
const ArrayList = std.ArrayList;

// -------------------------------
// ---        Constants        ---
// -------------------------------
const window_scale = 2.0;
const window_size = Vector2.init(640 * window_scale, 480 * window_scale);
const window_title = "Space Miner";
const window_color = rl.Color.black;
const target_fps = 60;
const window_exit_key = rl.KeyboardKey.f9;
const global_thickness = 2.0;
const global_default_color: rl.Color = .white;
const default_rot_speed = 1.0;
const global_drag = 0.05 * (window_scale / 1.75);
const default_speed = 15.0 * window_scale;

var allocator: std.mem.Allocator = undefined;
var rand: std.Random = undefined;

// -------------------------------
// ---          Enums          ---
// -------------------------------
const AsteroidSize = enum {
    Large,
    Medium,
    Small,

    fn scale(self: @This()) f32 {
        return switch (self) {
            .Large => 38.0 * 3.0,
            .Medium => 38.0 * 1.4,
            .Small => 38.0 * 0.8,
        };
    }
};

// -------------------------------
// ---         Structs         ---
// -------------------------------
const Ship = struct {
    pos: Vector2,
    vel: Vector2,
    rot: f32 = 0.0,
    energy: f32 = 10.0,
    max_energy: f32 = 10.0,
    max_laser_length: f32 = 0.5,
    laser_length: f32 = 0.0,
    laser_speed: f32 = 0.05,

    fn isThrusting(self: @This()) bool {
        _ = self;
        return rl.isKeyDown(.w);
    }

    fn isMining(self: @This()) bool {
        return self.energy > 0 and rl.isKeyDown(.space);
    }

    fn drawLaser(self: @This()) bool {
        return self.energy > 0 and self.laser_length > 0.0;
    }
};

const Player = struct {
    ship: Ship,
    mining_rate: f32 = 0.0,
};

const Asteroid = struct {
    pos: Vector2,
    rot: f32 = 0.0,
    seed: u64,
    size: AsteroidSize,
    points_amount: u32,
};

const Spark = struct {
    pos: Vector2,
    vel: Vector2,
    life: f32,
    max_life: f32,
};

// ------------------------------
// ---       Game State       ---
// ------------------------------
const GameState = struct {
    now: f32 = 0.0,
    delta: f32 = 0.0,
    player: Player,
    asteroids: ArrayList(Asteroid),
    sparks: ArrayList(Spark),

    // Returns a pointer to the player's ship
    fn p_ship_p(self: *@This()) *Ship {
        return &self.player.ship;
    }

    // Returns the player's ship
    fn p_ship(self: @This()) Ship {
        return self.player.ship;
    }
};
var state: GameState = undefined;

// -------------------------------
// ---         Methods         ---
// -------------------------------

// Buffer format
fn fmt(
    buf: []u8,
    comptime str: []const u8,
    args: anytype,
) ![:0]const u8 {
    const written = try std.fmt.bufPrint(buf[0 .. buf.len - 1], str, args);

    buf[written.len] = 0;

    return buf[0..written.len :0];
}

// Alocated format
fn aFmt(
    alloc: std.mem.Allocator,
    comptime str: []const u8,
    args: anytype,
) ![:0]const u8 {
    const s = try std.fmt.allocPrint(alloc, str, args);

    const buf = try allocator.realloc(s, s.len + 1);
    buf[s.len] = 0;

    return buf[0..s.len :0];
}

// requires a path from workspace_root/assets
fn assetPath(buf: []u8, path: []const u8) ![:0]const u8 {
    return fmt(buf, "assets/{s}", .{path});
}

fn transformToPoint(
    origin: Vector2,
    scale: f32,
    rot: f32,
    point: Vector2,
) Vector2 {
    return point.rotate(rot).scale(scale).add(origin);
}

fn drawLines(
    origin: Vector2,
    scale: f32,
    rot: f32,
    points: []const Vector2,
    thickness: ?f32,
    color: ?rl.Color,
) void {
    const t = thickness orelse global_thickness;
    const c = color orelse global_default_color;
    for (0..points.len) |i| {
        rl.drawLineEx(
            transformToPoint(origin, scale, rot, points[i]),
            transformToPoint(origin, scale, rot, points[(i + 1) % points.len]),
            t,
            c,
        );
    }
}

fn drawShip(ship: Ship) void {
    drawLines(
        ship.pos,
        16 * window_scale,
        ship.rot,
        &[_]Vector2{
            Vector2.init(0.0, 0.5),
            Vector2.init(0.4, -0.5),
            Vector2.init(0.2, -0.4),
            Vector2.init(-0.2, -0.4),
            Vector2.init(-0.4, -0.5),
        },
        null,
        null,
    );
    if (ship.isThrusting() and @mod(@as(i32, @intFromFloat(state.now * 20)), 2) == 0) {
        drawLines(
            ship.pos,
            16.0 * window_scale,
            ship.rot,
            &[_]Vector2{
                Vector2.init(0.3, -0.4),
                Vector2.init(0.0, -0.95),
                Vector2.init(-0.3, -0.4),
            },
            null,
            null,
        );
    }
    if (ship.drawLaser()) {
        const ship_radius = 8.0 * window_scale;

        const LASER_SCALE = 20.0;
        const laser_len = ship.laser_length * LASER_SCALE * window_scale;
        const laser_w = 2.0 * window_scale;

        const forward = Vector2.init(
            -@sin(ship.rot),
            @cos(ship.rot),
        );

        const base = ship.pos.add(forward.scale(ship_radius));

        const rect = rl.Rectangle{
            .x = base.x,
            .y = base.y,
            .width = laser_w,
            .height = laser_len,
        };

        const origin = rl.Vector2{
            .x = laser_w / 2,
            .y = 0,
        };

        rl.drawRectanglePro(
            rect,
            origin,
            std.math.radiansToDegrees(ship.rot),
            .red,
        );
    }
}

fn wrapPos(pos: *Vector2, container: ?Vector2) void {
    const cont = container orelse window_size;
    pos.x = @mod(pos.x, cont.x);
    pos.y = @mod(pos.y, cont.y);
}

fn drawAsteroid(asteroid: Asteroid) !void {
    var prng = Rand.Xoshiro256.init(asteroid.seed);
    var random = prng.random();
    var points = try BoundedArray(Vector2, 16).init(0);
    for (0..@intCast(asteroid.points_amount)) |i| {
        var radius = 0.3 + (0.2 * random.float(f32));
        if (random.float(f32) < 0.2) {
            radius -= 0.2;
        }
        const angle: f32 = (@as(f32, @floatFromInt(i)) * (Math.tau / @as(f32, @floatFromInt(asteroid.points_amount)))) + (Math.pi * 0.125) * random.float(f32);
        try points.append(
            Vector2.init(Math.cos(angle), Math.sin(angle)).scale(radius),
        );
    }

    drawLines(
        asteroid.pos,
        asteroid.size.scale(),
        asteroid.rot,
        points.slice(),
        null,
        null,
    );
}

fn respawnAsteroids(count: ?usize) !void {
    const c = count orelse 7;

    for (0..c) |_| {
        const size = AsteroidSize.Large;

        // Approximate asteroid radius in screen space
        const radius = size.scale();

        // Spawn only in the right 3/4 of the screen
        const min_x = window_size.x * 0.25 + radius;
        const max_x = window_size.x - radius;

        const min_y = radius;
        const max_y = window_size.y - radius;

        try state.asteroids.append(
            allocator,
            .{
                .pos = Vector2.init(
                    min_x + rand.float(f32) * (max_x - min_x),
                    min_y + rand.float(f32) * (max_y - min_y),
                ),
                .rot = 0.0,
                .seed = rand.int(u64),
                .size = size,
                .points_amount = rand.intRangeLessThan(u32, 8, 15),
            },
        );
    }
}

fn getLaserEnd(ship: Ship) Vector2 {
    const ship_radius = 8.0 * window_scale;
    const LASER_SCALE = 20.0;

    const forward = Vector2.init(
        -@sin(ship.rot),
        @cos(ship.rot),
    );

    const base = ship.pos.add(forward.scale(ship_radius));

    const laser_len = ship.laser_length * LASER_SCALE * window_scale;

    const laser_end = base.add(forward.scale(laser_len));
    return laser_end;
}

fn pointInCircle(p: Vector2, center: Vector2, radius: f32) bool {
    const dx = p.x - center.x;
    const dy = p.y - center.y;
    return (dx * dx + dy * dy) <= (radius * radius);
}

fn generateAsteroidPoints(
    seed: u64,
    count: usize,
    alloc: std.mem.Allocator,
) ![]Vector2 {
    var prng = Rand.Xoshiro256.init(seed);
    var random = prng.random();

    var points = try alloc.alloc(Vector2, count);

    for (0..count) |i| {
        var radius = 0.3 + (0.2 * random.float(f32));
        if (random.float(f32) < 0.2) {
            radius -= 0.2;
        }

        const angle =
            (@as(f32, @floatFromInt(i)) * (Math.tau / @as(f32, @floatFromInt(count)))) + (Math.pi * 0.125) * random.float(f32);

        points[i] = Vector2
            .init(Math.cos(angle), Math.sin(angle))
            .scale(radius);
    }

    return points;
}

fn sampleLaserPoints(
    ship: Ship,
    samples_len: usize,
    samples_width: usize,
    alloc: std.mem.Allocator,
) ![]Vector2 {
    const ship_radius = 8.0 * window_scale;
    const LASER_SCALE = 20.0;

    const forward = Vector2.init(-@sin(ship.rot), @cos(ship.rot));
    const right = Vector2.init(forward.y, -forward.x);

    const base = ship.pos.add(forward.scale(ship_radius));
    const laser_len = ship.laser_length * LASER_SCALE * window_scale;
    const laser_w = 2.0 * window_scale;

    const total = samples_len * samples_width;
    var pts = try alloc.alloc(Vector2, total);

    var idx: usize = 0;
    for (0..samples_len) |i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(samples_len - 1));
        const along = base.add(forward.scale(laser_len * t));

        for (0..samples_width) |j| {
            const w =
                (@as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(samples_width - 1)) - 0.5) * laser_w;

            pts[idx] = along.add(right.scale(w));
            idx += 1;
        }
    }

    return pts;
}

fn asteroidWorldPolygon(
    a: Asteroid,
    alloc: std.mem.Allocator,
) ![]Vector2 {
    const count = a.points_amount; // must match draw range (8–15 ok if fixed)

    const local = try generateAsteroidPoints(a.seed, count, alloc);
    defer alloc.free(local);

    var world = try alloc.alloc(Vector2, count);

    for (0..count) |i| {
        world[i] = transformToPoint(
            a.pos,
            a.size.scale(),
            a.rot,
            local[i],
        );
    }

    return world;
}

fn pointInPolygon(p: Vector2, poly: []const Vector2) bool {
    var inside = false;
    var j = poly.len - 1;

    for (0..poly.len) |i| {
        const pi = poly[i];
        const pj = poly[j];

        const intersect =
            ((pi.y > p.y) != (pj.y > p.y)) and
            (p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x);

        if (intersect) inside = !inside;
        j = i;
    }

    return inside;
}

fn laserIntersectsPolygon(
    ship: Ship,
    poly: []const Vector2,
) bool {
    const ship_radius = 8.0 * window_scale;
    const LASER_SCALE = 20.0;

    const laser_len = ship.laser_length * LASER_SCALE * window_scale;
    if (laser_len <= 0.0) return false;

    const laser_w = 2.0 * window_scale;

    const forward = Vector2.init(
        -@sin(ship.rot),
        @cos(ship.rot),
    );

    // perpendicular for width sampling
    const right = Vector2.init(
        forward.y,
        -forward.x,
    );

    const base = ship.pos.add(forward.scale(ship_radius));

    // how fine the sampling is
    const length_steps: usize = 12;
    const width_steps: usize = 3;

    for (0..length_steps) |i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(length_steps - 1));
        const center = base.add(forward.scale(laser_len * t));

        for (0..width_steps) |w| {
            const wt =
                (@as(f32, @floatFromInt(w)) / @as(f32, @floatFromInt(width_steps - 1))) - 0.5;

            const sample = center.add(
                right.scale(wt * laser_w),
            );

            if (pointInPolygon(sample, poly)) {
                return true;
            }
        }
    }

    return false;
}

fn spawnSpark(pos: Vector2, vel: Vector2) !void {
    try state.sparks.append(allocator, .{
        .pos = pos,
        .vel = vel,
        .life = 0.15,
        .max_life = 0.15,
    });
}

// ------------------------------
// ---    Constant Methods    ---
// ------------------------------
fn update() !void {
    var ship = state.p_ship_p();

    if (rl.isKeyDown(.a)) {
        ship.rot -= state.delta * Math.tau * default_rot_speed;
    }
    if (rl.isKeyDown(.d)) {
        ship.rot += state.delta * Math.tau * default_rot_speed;
    }
    if (rl.isKeyDown(.w)) {
        const dirAngle = ship.rot + (Math.pi * 0.5);
        const shipDir = Vector2.init(
            Math.cos(dirAngle),
            Math.sin(dirAngle),
        );

        ship.vel = ship.vel.add(shipDir.scale(state.delta * default_speed));
    }
    if (ship.isMining() and ship.laser_length <= ship.max_laser_length) {
        if (ship.laser_length + ship.laser_speed >= ship.max_laser_length) {
            ship.laser_length = ship.max_laser_length;
        } else {
            ship.laser_length += ship.laser_speed;
        }
    } else {
        if (ship.laser_length <= 0.0) {
            if (ship.laser_length <= 0.0 or ship.energy <= 0.0) {
                ship.laser_length = 0.0;
            }
        } else {
            ship.laser_length -= ship.laser_speed;
        }
    }

    if (ship.drawLaser()) {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const A = arena.allocator();

        const samples = try sampleLaserPoints(ship.*, 10, 4, A);

        var hit_count: usize = 0;
        const max_hits = samples.len;

        for (state.asteroids.items) |a| {
            const poly = try asteroidWorldPolygon(a, A);

            for (samples) |p| {
                if (pointInPolygon(p, poly)) {
                    hit_count += 1;

                    if (@mod(@as(i32, @intFromFloat(state.now * 60)), 30) == 0) {
                        const outward = p.subtract(a.pos).normalize();
                        const jitter = Vector2.init(
                            rand.float(f32) - 0.5,
                            rand.float(f32) - 0.5,
                        ).scale(40.0);

                        const vel = outward.scale(120.0).add(jitter);

                        try spawnSpark(p, vel);
                    }
                }
            }
        }

        const rate =
            @as(f32, @floatFromInt(hit_count)) /
            @as(f32, @floatFromInt(max_hits));

        state.player.mining_rate =
            @floatCast(@min(1.0, rate));
    } else {
        state.player.mining_rate = 0.0;
    }

    ship.vel = ship.vel.scale(1.0 - global_drag);
    ship.pos = ship.pos.add(ship.vel);
    wrapPos(&ship.*.pos, null);

    var i: usize = 0;
    while (i < state.sparks.items.len) {
        var s = &state.sparks.items[i];
        s.life -= state.delta;
        s.pos = s.pos.add(s.vel.scale(state.delta));
        s.vel = s.vel.scale(0.85); // damping

        if (s.life <= 0.0) {
            _ = state.sparks.swapRemove(i);
        } else {
            i += 1;
        }
    }
}

fn render() !void {
    var frame_arena = std.heap.ArenaAllocator.init(allocator);
    defer frame_arena.deinit();
    const A = frame_arena.allocator();
    _ = A;

    drawShip(state.p_ship());

    for (state.asteroids.items) |a| {
        try drawAsteroid(a);
    }

    for (state.sparks.items) |s| {
        const t = s.life / s.max_life; // 1 → 0
        const r = 2.0 * t;

        rl.drawCircleV(s.pos, r + 1.0, .orange);
        rl.drawCircleV(s.pos, r, .yellow);
    }
}

// ------------------------------
// ---          Main          ---
// ------------------------------
pub fn main() !void {
    // create our allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var rng = Rand.Xoshiro256.init(@bitCast(std.time.timestamp()));
    rand = rng.random();

    allocator = gpa.allocator();

    defer Textures.unloadAll();
    defer Sounds.unloadAll();

    rl.initWindow(window_size.x, window_size.y, window_title);
    rl.initAudioDevice();
    defer rl.closeWindow();
    defer rl.closeAudioDevice();

    rl.setExitKey(window_exit_key);
    rl.setTargetFPS(target_fps);
    //var a_buf: [256]u8 = undefined; // buffer for assetPaths
    //_ = a_buf;

    //const texture = try Textures.loadTexture(try assetPath(&a_buf, "texturefile.png"));
    // Initialization of the game state
    state = .{
        .player = .{
            .ship = .{
                .pos = window_size.scale(0.5),
                .vel = Vector2.init(0.0, 0.0),
            },
        },
        .asteroids = try ArrayList(Asteroid).initCapacity(allocator, 0),
        .sparks = try ArrayList(Spark).initCapacity(allocator, 0),
    };
    defer state.asteroids.deinit(allocator);
    defer state.sparks.deinit(allocator);

    try respawnAsteroids(null);

    // Application loop
    while (!rl.windowShouldClose()) {
        state.delta = rl.getFrameTime();
        state.now += state.delta;
        try update();

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(window_color);

        try render();
    }
}

