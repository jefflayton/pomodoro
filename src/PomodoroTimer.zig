const std = @import("std");
const time = std.time;

pub const PomodoroTimerState = enum {
    work,
    short_break,
    long_break,
};

state: PomodoroTimerState = .work,
work_duration: u16,
short_break_duration: u16,
long_break_duration: u16,
time_remaining: u16,
is_running: bool = false,
last_update: i64,

pub const PomodoroTimer = @This();
const Self = PomodoroTimer;

pub fn init(work_mins: u16, short_break_mins: u16, long_break_mins: u16) PomodoroTimer {
    const work_secs: u16 = work_mins * time.s_per_min;
    return .{
        .work_duration = work_secs,
        .short_break_duration = short_break_mins * time.s_per_min,
        .long_break_duration = long_break_mins * time.s_per_min,
        .time_remaining = work_secs,
        .last_update = std.time.milliTimestamp(),
    };
}

pub fn start(self: *Self) void {
    self.is_running = true;
    self.last_update = std.time.milliTimestamp();
}

pub fn pause(self: *Self) void {
    self.is_running = false;
}

pub fn update(self: *Self) bool {
    if (!self.is_running) return false;

    const now: i64 = std.time.milliTimestamp();
    const elapsed_ms = now - self.last_update;
    self.last_update = now;

    const elapsed_secs: u16 = @as(u16, @intCast(@divFloor(elapsed_ms, time.ms_per_s)));

    if (elapsed_secs > 0) {
        if (self.time_remaining > elapsed_secs) {
            self.time_remaining -= elapsed_secs;
        } else {
            self.time_remaining = 0;
            return true;
        }
    }

    return false;
}

pub fn getProgress(self: *Self) f16 {
    const total: f16 = switch (self.state) {
        .work => @floatFromInt(self.work_duration),
        .short_break => @floatFromInt(self.short_break_duration),
        .long_break => @floatFromInt(self.long_break_duration),
    };

    const remaining: f16 = @floatFromInt(self.time_remaining);
    return (total - remaining) / total;
}

pub fn getMinutes(self: *Self) u16 {
    return self.time_remaining / time.s_per_min;
}

pub fn getSeconds(self: *Self) u16 {
    return self.time_remaining % time.s_per_min;
}

pub fn formatTime(self: *Self, buf: []u8) ![]const u8 {
    const mins = self.getMinutes();
    const secs = self.getSeconds();
    return std.fmt.bufPrint(buf, "{d:0>2}:{d:0>2}", .{ mins, secs });
}

fn nextState(self: *Self) void {
    switch (self.phase) {
        .work => {
            if (self.num_completed % 4 == 0 and self.num_completed > 0) {
                self.state = .long_break;
                self.time_remaining = self.long_break_duration;
            } else {
                self.state = .short_break;
                self.time_remaining = self.short_break_duration;
            }
        },
        .short_break, .long_break => {
            self.state = .work;
            self.time_remaining = self.work_duration;
        },
    }
}
