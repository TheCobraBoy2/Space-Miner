// -------------------------------
// ---         Imports         ---
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
            .Large => window_scale * 3.0,
            .Medium => window_scale * 1.4,
            .Small => window_scale * 0.8,
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
};

const Asteroid = struct {
    pos: Vector2,
    rot: f32 = 0.0,
    seed: u64,
    size: AsteroidSize,
};

// ------------------------------
// ---       Game State       ---
// ------------------------------
const GameState = struct {
    now: f32 = 0.0,
    delta: f32 = 0.0,
    player: Player,
    asteroids: ArrayList(Asteroid),

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
    const n = random.intRangeLessThan(i32, 8, 15);
    for (0..@intCast(n)) |i| {
        var radius = 0.3 + (0.2 * random.float(f32));
        if (random.float(f32) < 0.2) {
            radius -= 0.2;
        }
        const angle: f32 = (@as(f32, @floatFromInt(i)) * (Math.tau / @as(f32, @floatFromInt(n)))) + (Math.pi * 0.125) * random.float(f32);
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
    const c = count orelse 5;
    for (0..c) |_| {
        const size = AsteroidSize.Large;
        try state.asteroids.append(
            allocator,
            .{
                .pos = Vector2.init(
                    rand.float(f32) * window_size.x,
                    rand.float(f32) * window_size.y,
                ),
                .rot = 0.0,
                .seed = rand.int(u64),
                .size = size,
            },
        );
    }
}

// ------------------------------
// ---    Constant Methods    ---
// ------------------------------
fn update() void {
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

    ship.vel = ship.vel.scale(1.0 - global_drag);
    ship.pos = ship.pos.add(ship.vel);
    wrapPos(&ship.*.pos, null);
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
    };
    defer state.asteroids.deinit(allocator);

    try respawnAsteroids(null);

    // Application loop
    while (!rl.windowShouldClose()) {
        state.delta = rl.getFrameTime();
        state.now += state.delta;
        update();

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(window_color);

        try render();
    }
}
