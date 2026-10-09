extends SceneTree
## Runs every test_*() method of every tests/test_*.gd script. Use ./run_tests.sh, which also
## fails the run on script errors (those abort a test without failing its checks).


func _init() -> void:
	var total := 0
	var failed := 0
	for file in DirAccess.get_files_at("res://tests"):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load("res://tests/" + file)
		if script == null:
			print("FAIL ", file, ": does not load")
			failed += 1
			continue
		for method in script.get_script_method_list():
			var method_name: String = method.name
			if not method_name.begins_with("test_"):
				continue
			var case: RulesTestCase = script.new()
			case.call(method_name)
			total += 1
			if not case.failures.is_empty():
				failed += 1
				print("FAIL ", file, " ", method_name)
				for failure in case.failures:
					print("     ", failure)
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
