const std = @import("std");
const mem = std.mem;
const time = std.time;
const heap = std.heap;
const process = std.process;

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var stderr_writer = std.fs.File.stderr().writer(&stdout_buffer);
    const stderr = &stderr_writer.interface;

    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    var user_mins: i8 = 0;
    var user_secs: i8 = 0;

    var read_min: bool = true;
    var read_sec: bool = true;

    if (args.len == 2) {
        const arg = args[1];
        if (mem.eql(u8, arg, "--help") or mem.eql(u8, arg, "-h")) {
            const help_file = try std.fs.cwd().openFile("./docs/help.txt", .{});
            defer help_file.close();

            var help_buf: [1024]u8 = undefined;
            var help_reader = help_file.reader(&help_buf);

            _ = try stdout.sendFile(&help_reader, .unlimited);
            // try stdout.print("Usage: pomodoro [options]\n", .{});
            // try stdout.print("\nOptions:\n", .{});
            // try stdout.print("\t-h, --help\n\t\t Print Help\n", .{});
            // try stdout.print("\t-m, --min\n\t\t Set Minutes\n", .{});
            // try stdout.print("\t-s, --sec\n\t\t Set Seconds\n", .{});
            // try stdout.flush();
            return;
        } else {
            user_mins = std.fmt.parseInt(i8, arg, 10) catch user_mins;
        }
    } else if (args.len > 2) {
        for (args[1..]) |arg| {
            if (mem.eql(u8, arg, "--min") or mem.eql(u8, arg, "-m")) {
                read_min = true;
            } else if (mem.eql(u8, arg, "--sec") or mem.eql(u8, arg, "-s")) {
                read_sec = true;
            } else if (read_min) {
                user_mins = std.fmt.parseInt(i8, arg, 10) catch |err| {
                    try stderr.print("Invalid integer for --min, {s}.\nError: {}", .{ arg, err });
                    try stderr.flush();
                    process.exit(1);
                };
                read_min = false;
            } else if (read_sec) {
                user_secs = std.fmt.parseInt(i8, arg, 10) catch {
                    try stderr.print("Invalid integer for --sec.\n", .{});
                    try stderr.flush();
                    process.exit(1);
                };
                read_sec = false;
            }
        }
    }

    if (user_mins == 0 and user_secs == 0) {
        try stdout.print("Done!\n", .{});
        try stdout.flush();
        return;
    }

    var cur_mins: i8 = user_mins;
    var cur_secs: i8 = user_secs;

    var secs_buf: [2]u8 = undefined;
    var elapsed_secs: f16 = 0;
    const total_secs: i16 = @as(i16, user_mins) * time.s_per_min + user_secs;

    var progress: i16 = 0;
    var progress_bar = std.array_list.Managed(u8).init(allocator);
    while (true) {
        try stdout.print("\x1b[2J\x1b[H", .{}); // Move up 2 lines, clear down

        if (cur_mins == 0 and cur_secs == 0) {
            try stdout.print("Done!", .{});
            try stdout.flush();
            break;
        }

        elapsed_secs = @as(f16, @floatFromInt((@as(i16, cur_mins) * time.s_per_min) + cur_secs));
        progress = @intFromFloat(100 - (100 * (elapsed_secs / @as(f16, @floatFromInt(total_secs)))));

        progress_bar.clearRetainingCapacity();

        const filled: i16 = @divFloor(progress * 20, 100); // 20 character wide bar
        for (0..20) |i| {
            if (i < filled) {
                try progress_bar.appendSlice("━");
            } else {
                try progress_bar.appendSlice("░");
            }
        }

        if (cur_secs < 10) {
            _ = try std.fmt.bufPrint(&secs_buf, "0{d}", .{cur_secs});
        } else {
            _ = try std.fmt.bufPrint(&secs_buf, "{d}", .{cur_secs});
        }

        try stdout.print("⏰ {d} min, {s} sec\n", .{ cur_mins, secs_buf });
        try stdout.print("{s} {d}%", .{ progress_bar.items, progress });
        try stdout.flush();
        std.Thread.sleep(1 * time.ns_per_s);

        if (cur_secs == 0) {
            cur_secs = 60;
            cur_mins -= 1;
        }
        cur_secs -= 1;
    }
}
