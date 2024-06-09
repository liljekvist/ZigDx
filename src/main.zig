const std = @import("std");
const glfw = @import("zglfw");

pub fn main() !u8 {
    std.debug.print("Starting application", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    //const allocator = gpa.allocator();

    try glfw.init();
    defer glfw.terminate();

    glfw.windowHintTyped(.client_api, .no_api);
    const glfw_window = try glfw.Window.create(1600, 1200, "test", null);
    defer glfw_window.destroy();
    while (!glfw_window.shouldClose()) {
        glfw.pollEvents();
    }


    return 0;
}
