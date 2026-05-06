extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Missing test script path")
		quit(1)
		return

	if _uses_wrapper(args[0]):
		await _run_wrapped_test(args[0])
		return

	var test_script: Script = ResourceLoader.load(args[0], "", ResourceLoader.CACHE_MODE_IGNORE) as Script
	if test_script == null:
		push_error("Failed to load test script: %s" % args[0])
		quit(1)
		return

	var test_instance: Object = test_script.new()
	if not test_instance is Node:
		push_error("Test script must extend Node: %s" % args[0])
		quit(1)
		return

	var test_node: Node = test_instance as Node
	root.add_child(test_node)
	await process_frame
	await process_frame
	var total: int = int(test_node.get("_total"))
	var passed: int = int(test_node.get("_passed"))
	var exit_code: int = 0 if total <= 0 or passed == total else 1

	test_node.queue_free()
	test_node = null
	test_instance = null
	test_script = null
	call_deferred("_quit_after_cleanup", exit_code)


func _uses_wrapper(path: String) -> bool:
	return path in [
		"res://tests/test_bazaar_content.gd",
		"tests/test_bazaar_content.gd",
		"res://tests/test_shop_service_vendors.gd",
		"tests/test_shop_service_vendors.gd",
	]


func _run_wrapped_test(path: String) -> void:
	var normalized_path: String = path if path.begins_with("res://") else "res://" + path
	var source := "extends Node\nconst TestScript = preload(\"%s\")\nvar child: Node\nfunc _ready() -> void:\n\tchild = TestScript.new()\n\tadd_child(child)\n" % normalized_path
	var wrapper_script := GDScript.new()
	wrapper_script.source_code = source
	var error := wrapper_script.reload(false)
	if error != OK:
		push_error("Failed to compile wrapper for test script: %s" % normalized_path)
		quit(1)
		return

	var wrapper: Node = wrapper_script.new()
	set_meta("node_test_runner_controls_quit", true)
	root.add_child(wrapper)
	await process_frame
	await process_frame
	var child: Node = wrapper.get("child") as Node
	var total: int = int(child.get("_total"))
	var passed: int = int(child.get("_passed"))
	var exit_code: int = 0 if total <= 0 or passed == total else 1

	wrapper.queue_free()
	wrapper = null
	child = null
	wrapper_script = null
	call_deferred("_quit_after_cleanup", exit_code)


func _quit_after_cleanup(exit_code: int) -> void:
	if has_meta("node_test_runner_controls_quit"):
		remove_meta("node_test_runner_controls_quit")
	await process_frame
	await process_frame
	quit(exit_code)
