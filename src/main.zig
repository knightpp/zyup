const std = @import("std");
const json = std.json;

const Package = struct {
    dependencies: json.ArrayHashMap([]u8),
    devDependencies: json.ArrayHashMap([]u8),
};

const Error = error{
    NotEnoughArgs,
    YarnNonZeroExit,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) {
            std.debug.print("memory leak detected", .{});
        }
    }

    const alloc = gpa.allocator();

        var args = try std.process.argsWithAllocator(alloc);
        defer args.deinit();

    const path = path: {
        _ = args.skip();
        break :path args.next() orelse return Error.NotEnoughArgs;
    };

    const json_bytes = json: {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        break :json try file.readToEndAlloc(alloc, 16 * 1024);
    };
    defer alloc.free(json_bytes);

    const parsed = try std.json.parseFromSlice(
        Package,
        alloc,
        json_bytes,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const pkg = parsed.value;

    const deps = .{
        pkg.dependencies.map,
        pkg.devDependencies.map,
    };
    inline for (deps) |map| {
        var it = map.iterator();
        while (it.next()) |value| {
            try updatePackage(alloc, value.key_ptr.*);
        }
    }
}

fn updatePackage(alloc: std.mem.Allocator, name: []const u8) !void {
    const nameArg = try std.mem.concat(alloc, u8, &[_][]const u8{ name, "@^" });
    defer alloc.free(nameArg);

    const argv = .{
        "yarn",
        "upgrade",
        nameArg,
    };

    var proc = std.process.Child.init(&argv, alloc);

    const term = try proc.spawnAndWait();
    if (term.Exited != 0) {
        return Error.YarnNonZeroExit;
    }
}
