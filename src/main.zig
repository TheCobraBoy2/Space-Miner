// -------------------------------
// ---         Imports         ---
// -------------------------------
const std = @import("std");
const Space_Miner = @import("Space_Miner");
const BoundedArray = @import("bounded_array").BoundedArray;
const rl = @import("raylib");
const rg = @import("raygui");

const Textures = @import("textures.zig");
const Sounds = @import("sounds.zig");

// ------------------------------
// ---        Mappings        ---
// ------------------------------
const Vector2 = rl.Vector2;
const Math = std.math;

// -------------------------------
// ---        Constants        ---
// -------------------------------
const window_scale = 2;
const window_size = Vector2.init(640 * window_scale, 480 * window_scale);
const window_title = "Space Miner";
const window_color = rl.Color.black;
const target_fps = 60;
const window_exit_key = rl.KeyboardKey.f9;
var allocator: std.mem.Allocator = undefined;

// ------------------------------
// ---       Game State       ---
// ------------------------------
const GameState = struct {};
var state: GameState = undefined;

// -------------------------------
// ---         Methods         ---
// -------------------------------

fn drawSum() void {}

fn fmt(
    buf: []u8,
    comptime str: []const u8,
    args: anytype,
) ![:0]const u8 {
    const written = try std.fmt.bufPrint(buf[0 .. buf.len - 1], str, args);

    buf[written.len] = 0;

    return buf[0..written.len :0];
}

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

// ------------------------------
// ---    Constant Methods    ---
// ------------------------------
fn update() void {}

fn render() void {
    var frame_arena = std.heap.ArenaAllocator.init(allocator);
    defer frame_arena.deinit();
    const A = frame_arena.allocator();
    _ = A;

    rl.drawText("Hello this is raylib in zig", 10, 10, 20, .white);
}

// ------------------------------
// ---          Main          ---
// ------------------------------
pub fn main() !void {
    // create our allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

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
    state = .{};

    // Application loop
    while (!rl.windowShouldClose()) {
        update();

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(window_color);

        render();
    }
}
