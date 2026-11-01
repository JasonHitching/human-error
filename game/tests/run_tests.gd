extends SceneTree


func _init() -> void:
	var passed := 0
	var failed := 0
	var dir := DirAccess.open("res://tests")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append(f)
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		var methods: Array[String] = []
		for m in script.get_script_method_list():
			if String(m.name).begins_with("test_"):
				methods.append(m.name)
		methods.sort()
		for m in methods:
			var t: TestCase = script.new()
			t.call(m)
			if t.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for msg in t.failures:
					print("FAIL %s::%s: %s" % [f, m, msg])
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
