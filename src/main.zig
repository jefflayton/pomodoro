const std = @import("std");
const mem = std.mem;
const time = std.time;
const heap = std.heap;
const process = std.process;

const PomodorTimer = @import("./PomodoroTimer.zig");
const cli = @import("./cli.zig");

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

    var work_mins: u16 = 25;
    var short_break_mins: u16 = 5;
    var long_break_mins: u16 = 15;

    var read_work_mins = false;
    var read_short_break_mins = false;
    var read_long_break_mins = false;

    var run_cli = true;

    for (args[1..]) |arg| {
        if (mem.eql(u8, arg, "--help") or mem.eql(u8, arg, "-h")) {
            const help_file = try std.fs.cwd().openFile("./docs/help.txt", .{});
            defer help_file.close();

            var help_buf: [1024]u8 = undefined;
            var help_reader = help_file.reader(&help_buf);

            _ = try stdout.sendFile(&help_reader, .unlimited);
            return;
        } else if (mem.eql(u8, arg, "--cli")) {
            run_cli = true;
        } else if (mem.eql(u8, arg, "--work") or mem.eql(u8, arg, "-w")) {
            read_work_mins = true;
        } else if (mem.eql(u8, arg, "--short-break") or mem.eql(u8, arg, "-s")) {
            read_short_break_mins = true;
        } else if (mem.eql(u8, arg, "--long-break") or mem.eql(u8, arg, "-l")) {
            read_long_break_mins = true;
        } else if (read_work_mins) {
            work_mins = std.fmt.parseInt(u16, arg, 10) catch |err| {
                try stderr.print("Invalid integer for --work, {s}.\nError: {}", .{ arg, err });
                try stderr.flush();
                process.exit(1);
            };
            read_work_mins = false;
        } else if (read_short_break_mins) {
            short_break_mins = std.fmt.parseInt(u16, arg, 10) catch {
                try stderr.print("Invalid integer for --short-break.\n", .{});
                try stderr.flush();
                process.exit(1);
            };
            read_short_break_mins = false;
        } else if (read_long_break_mins) {
            long_break_mins = std.fmt.parseInt(u16, arg, 10) catch {
                try stderr.print("Invalid integer for --sec.\n", .{});
                try stderr.flush();
                process.exit(1);
            };
            read_long_break_mins = false;
        }
    }

    var timer = PomodorTimer.init(work_mins, short_break_mins, long_break_mins);

    try cli.run(allocator, &timer, stdout);
}
