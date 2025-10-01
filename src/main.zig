const std = @import("std");
const time = std.time;
const heap = std.heap;
const process = std.process;

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    var chosen_minutes: i8 = 25;
    if (args.len > 1) {
        chosen_minutes = std.fmt.parseInt(i8, args[1], 10) catch 25;
    }
    var minutes: i8 = chosen_minutes;

    var seconds: i8 = 0;
    var seconds_buf: [2]u8 = undefined;
    var elapsed_seconds: f16 = 0;
    const total_seconds = chosen_minutes * time.s_per_min;

    var progress: i16 = 0;
    var progress_bar = std.array_list.Managed(u8).init(allocator);
    while (true) {
        try stdout.print("\x1b[2J\x1b[H", .{}); // Move up 2 lines, clear down

        if (minutes == 0 and seconds == 0) {
            try stdout.print("Done!", .{});
            try stdout.flush();
            break;
        }

        elapsed_seconds = @as(f16, @floatFromInt((minutes * time.s_per_min) + seconds));
        progress = @intFromFloat(100 - (100 * (elapsed_seconds / @as(f16, @floatFromInt(total_seconds)))));

        progress_bar.clearRetainingCapacity();

        const filled: i16 = @divFloor(progress * 20, 100); // 20 character wide bar
        for (0..20) |i| {
            if (i < filled) {
                try progress_bar.appendSlice("━");
            } else {
                try progress_bar.appendSlice("░");
            }
        }

        if (seconds < 10) {
            _ = try std.fmt.bufPrint(&seconds_buf, "0{d}", .{seconds});
        } else {
            _ = try std.fmt.bufPrint(&seconds_buf, "{d}", .{seconds});
        }

        try stdout.print("⏰{d} min, {s} sec\n", .{ minutes, seconds_buf });
        try stdout.print("{s} {d}%", .{ progress_bar.items, progress });
        try stdout.flush();
        std.Thread.sleep(1 * time.ns_per_s);

        if (seconds == 0) {
            seconds = 60;
            minutes -= 1;
        }
        seconds -= 1;
    }
}
