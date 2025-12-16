// ------------------------------
// ---        Imports         ---
// ------------------------------
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

// ------------------------------
// ---       Constants        ---
// ------------------------------
const window_scale = 2;
const window_size = Vector2.init(640 * window_scale, 480 * window_scale);
const window_title = "Space Miner";
const window_color = rl.Color.black;

pub fn main() !void {
    defer Textures.unloadAll();
    defer Sounds.unloadAll();

    rl.initWindow(window_size.x, window_size.y, window_title);
    rl.initAudioDevice();
    defer rl.closeWindow();
    defer rl.closeAudioDevice();

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(window_color);
    }
}
