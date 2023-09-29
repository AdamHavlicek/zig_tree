const std = @import("std");

pub fn Root(comptime T: type) type {
    return struct {
        const Self = @This();

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

            fn set_char(self: *Node, char: T) void {
                self.data = char;
            }

            fn set_end_of_word(self: *Node) void {
                self.end_of_word = true;
                std.log.debug("setting this bad boy to {}\n", .{self.end_of_word});
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

        pub fn add_word(self: *Self, value: []const u8) !void {
            var last_child: ?*Node = null;
            for (value) |char| {
                if (last_child) |node| {
                    var new_child = try Node.init(node.allocator);
                    new_child.set_char(char);

                    try last_child.?.children.put(char, new_child);
                    last_child = last_child.?.children.getPtr(char);
                } else {
                    if (!self.children.contains(char)) {
                        var new_child = try Node.init(self.allocator);
                        new_child.set_char(char);

                        try self.children.put(char, new_child);
                        last_child = self.children.getPtr(char);
                    } else {
                        last_child = self.children.getPtr(char);
                    }
                }
            }

            last_child.?.*.set_end_of_word();
        }

        pub fn exists(self: *Self, value: []const u8) bool {
            var node: ?Node = null;
            for (value, 0..value.len) |char, index| {
                if (index == 0) {
                    node = self.children.get(char);
                    std.log.debug("{u}\n", .{node.?.data});
                } else if (node == null) {
                    break;
                } else {
                    node = node.?.children.get(char);
                    std.log.debug("{u}\n", .{node.?.data});
                }
            }

            if (node) |node_| {
                std.log.debug("last char is {u}\n", .{node_.data});
                std.log.debug("is this bad boy true? {}\n", .{node_.end_of_word});
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

pub fn main() !void {
    const word = "TESTER";
    var logging = std.heap.loggingAllocator(std.heap.page_allocator);
    var arena = std.heap.ArenaAllocator.init(logging.allocator());
    defer arena.deinit();

    const allocator = arena.allocator();
    const CharRoot = Root(u8);

    var root = try CharRoot.init(allocator);
    try root.add_word(word);

    std.debug.print("{}\n", .{root.exists(word)});
}

test "[Root] - [Node]" {}
