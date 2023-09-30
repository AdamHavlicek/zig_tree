const std = @import("std");

pub fn Root(comptime T: type) type {
    return struct {
        const Self = @This();

        const Slice = []const T;

        const ChildrenType = std.AutoHashMap(T, Node);

        allocator: std.mem.Allocator,
        children: *ChildrenType,

        const Node = struct {
            allocator: std.mem.Allocator,
            data: T,
            end_of_word: bool,
            children: *ChildrenType,

            fn init(allocator: std.mem.Allocator) !Node {
                var children = try allocator.create(ChildrenType);
                children.* = ChildrenType.init(allocator);

                return .{
                    .allocator = allocator,
                    .end_of_word = false,
                    .data = 0,
                    .children = children,
                };
            }

            fn set_end_of_word(self: *Node) void {
                self.end_of_word = true;
            }
        };

        pub fn init(allocator: std.mem.Allocator) !Self {
            var children = try allocator.create(ChildrenType);
            children.* = ChildrenType.init(allocator);

            return .{
                .allocator = allocator,
                .children = children,
            };
        }

        pub fn add_word(self: *Self, value: Slice) !void {
            var last_child: ?*Node = null;
            for (value) |char| {
                var children = if (last_child) |node| node.children else self.children;

                if (!children.contains(char)) {
                    var new_child = try Node.init(children.allocator);
                    new_child.data = char;

                    try children.put(char, new_child);
                }

                last_child = children.getPtr(char);
            }

            last_child.?.*.set_end_of_word();
        }

        pub fn exists(self: *Self, value: Slice) bool {
            if (value.len == 0) {
                return false;
            }

            var node: ?Node = self.children.get(value[0]);
            for (value[1..value.len]) |char| {
                if (node) |node_| {
                    node = node_.children.get(char);
                } else {
                    break;
                }
            }

            if (node) |node_| {
                return node_.end_of_word;
            } else {
                return false;
            }
        }

        pub fn deinit(self: *Root) void {
            _ = self;
        }
    };
}

const CharRoot = Root(u8);

pub fn loadWords(allocator: std.mem.Allocator, path: []const u8, root: *CharRoot) !void {
    _ = allocator;
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    var file_buffer = std.io.bufferedReader(file.reader());
    var in_stream = file_buffer.reader();

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try root.add_word(line);
    }
}

pub fn main() !void {
    // var logging = std.heap.loggingAllocator(std.heap.page_allocator);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const path = args[1];
    const word = args[2];

    var root = try CharRoot.init(allocator);
    try loadWords(allocator, path, &root);

    std.debug.print("{}\n", .{root.exists(word)});
}

test "[Root] - [Node]" {}
