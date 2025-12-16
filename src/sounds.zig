const std = @import("std");
const rl = @import("raylib");

var sounds: ?std.ArrayList(rl.Sound) = null;

fn ensureSounds() !void {
    if (sounds == null) {
        sounds = try std.ArrayList(rl.Sound)
            .initCapacity(std.heap.page_allocator, 0);
    }
}

pub fn loadSound(path: [:0]const u8) !rl.Sound {
    try ensureSounds();
    const sou = try rl.loadSound(path);
    try sounds.?.append(std.heap.page_allocator, sou);
    return sou;
}

pub fn unloadSound(sound: rl.Sound) !void {
    if (sounds) |*list| {
        var i: usize = 0;
        while (i < list.items.len) : (i += 1) {
            if (list.items[i] == sound) {
                const removed = list.swapRemove(i);
                rl.unloadSound(removed);
                return;
            }
        }
    }
}

pub fn unloadSounds() void {
    if (sounds) |*list| {
        for (list.items) |sou| {
            rl.unloadSound(sou);
        }
        list.deinit(std.heap.page_allocator);
    }
}

pub fn unloadAll() void {
    unloadSounds();
}
