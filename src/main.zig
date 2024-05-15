const std = @import("std");
const json = std.json;

const Package = struct {
    dependencies: json.ArrayHashMap([]u8),
    devDependencies: json.ArrayHashMap([]u8),
};

const Error = error{
    not_enough_args,
    yarn_nonzero_exit,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == std.heap.Check.leak) {
            std.debug.print("memory leak detected", .{});
        }
    }

    const alloc = gpa.allocator();

    const path: []const u8 = path: {
        var args = try std.process.argsWithAllocator(alloc);
        defer args.deinit();

        _ = args.skip();
        break :path args.next() orelse return Error.not_enough_args;
    };

    const json_bytes = json: {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        break :json try file.readToEndAlloc(alloc, 16 * 1024);
    };
    defer alloc.free(json_bytes);

    const parsed = parsed: {
        break :parsed try std.json.parseFromSlice(
            Package,
            alloc,
            json_bytes,
            .{ .ignore_unknown_fields = true },
        );
    };
    defer parsed.deinit();

    const pkg = parsed.value;

    var it = pkg.dependencies.map.iterator();
    while (it.next()) |value| {
        try update_package(alloc, value.key_ptr.*);
    }

    it = pkg.devDependencies.map.iterator();
    while (it.next()) |value| {
        try update_package(alloc, value.key_ptr.*);
    }
}

fn update_package(alloc: std.mem.Allocator, name: []const u8) !void {
    var nameArg = try alloc.alloc(u8, name.len + 2);
    defer alloc.free(nameArg);

    for (name, 0..) |byte, i| {
        nameArg[i] = byte;
    }
    nameArg[name.len] = '@';
    nameArg[name.len + 1] = '^';

    const argv: [3][]const u8 = .{
        "yarn",
        "upgrade",
        nameArg,
    };

    var proc = std.process.Child.init(&argv, alloc);

    const term = try proc.spawnAndWait();
    if (term.Exited != 0) {
        return Error.yarn_nonzero_exit;
    }
}
