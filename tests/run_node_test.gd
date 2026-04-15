extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Missing test script path")
		quit(1)
		return

	var test_script: Script = load(args[0]) as Script
	if test_script == null:
		push_error("Failed to load test script: %s" % args[0])
		quit(1)
		return

	var test_node: Node = Node.new()
	test_node.set_script(test_script)
	root.add_child(test_node)
