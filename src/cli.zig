const std = @import("std");
const time = std.time;

const PomodoroTimer = @import("./PomodoroTimer.zig");

pub fn run(allocator: std.mem.Allocator, timer: *PomodoroTimer, stdout: *std.Io.Writer) !void {
    timer.start();

    var buf: [16]u8 = undefined;
    var progress_bar = std.array_list.Managed(u8).init(allocator);
    defer progress_bar.deinit();

    while (true) {
        try stdout.print("\x1b[2J\x1b[H", .{}); // Clear screen

        const finished = timer.update();
        if (finished) {
            try stdout.print("Done!", .{});
            try stdout.flush();
            break;
        }

        progress_bar.clearRetainingCapacity();

        const progress: f16 = timer.getProgress();
        const filled: u16 = @intFromFloat(progress * 20);
        for (0..20) |i| {
            if (i < filled) {
                try progress_bar.appendSlice("━");
            } else {
                try progress_bar.appendSlice("░");
            }
        }

        const time_str = try timer.formatTime(&buf);
        const progress_str: u16 = @intFromFloat(progress * 100);

        try stdout.print("⏰ {s}\n", .{time_str});
        try stdout.print("{s} {d}%\n", .{ progress_bar.items, progress_str });
        try stdout.flush();

        std.Thread.sleep(1 * time.ns_per_s); // 1 Second
    }
}
