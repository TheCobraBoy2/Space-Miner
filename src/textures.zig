const std = @import("std");
const rl = @import("raylib");

var textures: ?std.ArrayList(rl.Texture2D) = null;
var images: ?std.ArrayList(rl.Image) = null;

fn ensureTextures() !void {
    if (textures == null) {
        textures = try std.ArrayList(rl.Texture2D)
            .initCapacity(std.heap.page_allocator, 0);
    }
}

fn ensureImages() !void {
    if (images == null) {
        images = try std.ArrayList(rl.Image)
            .initCapacity(std.heap.page_allocator, 0);
    }
}

pub fn loadTexture(path: [:0]const u8) !rl.Texture2D {
    try ensureTextures();
    const tex = try rl.loadTexture(path);
    try textures.?.append(tex);
    return tex;
}

pub fn loadImage(path: [:0]const u8) !rl.Image {
    try ensureImages();
    const img = try rl.loadImage(path);
    try images.?.append(img);
    return img;
}

pub fn unloadImage(img: rl.Image) void {
    if (images) |*list| {
        var i: usize = 0;
        while (i < list.items.len) : (i += 1) {
            if (list.items[i] == img) {
                const removed = list.swapRemove(img);
                rl.unloadImage(removed);
                return;
            }
        }
    }
}

pub fn unloadTexture(tex: rl.Texture2D) void {
    if (textures) |*list| {
        var i: usize = 0;
        while (i < list.items.len) : (i += 1) {
            if (list.items[i] == tex) {
                const removed = list.swapRemove(tex);
                rl.unloadTexture(removed);
                return;
            }
        }
    }
}

pub fn unloadTextures() void {
    if (textures) |*list| {
        for (list.items) |tex| {
            rl.unloadTexture(tex);
        }
        list.deinit(std.heap.page_allocator);
    }
}

pub fn unloadImages() void {
    if (images) |*list| {
        for (list.items) |img| {
            rl.unloadImage(img);
        }
        list.deinit(std.heap.page_allocator);
    }
}

pub fn unloadAll() void {
    unloadImages();
    unloadTextures();
}

