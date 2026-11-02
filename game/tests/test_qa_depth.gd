extends TestCase


func _fac(spec: Dictionary = {}) -> Factory:
	var f := Factory.new(SimConfig.load_default(), 1)
	f.worker.place(Worker.Location.OFFICE)
	f.apply_spec(spec)
	return f


func _put(f: Factory, item: Dictionary) -> void:
	f._qa_items.append(item)
	f._qa.input_count += 1


func test_spec_deterministic_and_changes_after_start_day() -> void:
	var c := SimConfig.load_default()
	for d in c.spec_change_day:
		var s := QaSpec.for_day(c, 5, d)
		assert_true(s["extra"].is_empty() and s["allowed"].is_empty(), "no change before spec_change_day")
	var changed := 0
	for seed in 20:
		var a := QaSpec.for_day(c, seed, 12)
		assert_eq(a, QaSpec.for_day(c, seed, 12), "same seed same spec")
		if not a["extra"].is_empty() or not a["allowed"].is_empty():
			changed += 1
	assert_true(changed > 0, "some seeds change the spec")


func test_spec_changes_at_most_every_gap_days() -> void:
	var c := SimConfig.load_default()
	for seed in 20:
		var last := -100
		for d in range(1, 25):
			if QaSpec.for_day(c, seed, d)["change"] != "":
				assert_true(d - last >= c.spec_change_gap, "gap respected")
				last = d


func test_spec_respected_by_scoring() -> void:
	var f := _fac({"extra": ["scuff"], "allowed": ["dent"]})
	_put(f, {"defect": "", "decoy": "scuff", "bot": ""})
	assert_eq(f.inspect(true), Factory.InspectResult.COMPLAINT, "scuff is a defect now")
	f._inspect_left = 0
	_put(f, {"defect": "dent", "decoy": "", "bot": ""})
	assert_eq(f.inspect(true), Factory.InspectResult.SHIPPED, "dent is fine now")
	f._inspect_left = 0
	_put(f, {"defect": "dent", "decoy": "", "bot": ""})
	assert_eq(f.inspect(false), Factory.InspectResult.WASTED, "rejecting an allowed dent wastes it")


func test_subtle_share_curve() -> void:
	var c := SimConfig.load_default()
	assert_eq(QaSpec.subtle_share(c, c.subtle_start_day - 1), 0.0)
	assert_near(QaSpec.subtle_share(c, c.subtle_start_day), c.subtle_share_base)
	assert_true(QaSpec.subtle_share(c, c.subtle_start_day + 2) > QaSpec.subtle_share(c, c.subtle_start_day))
	assert_near(QaSpec.subtle_share(c, 99), c.subtle_share_max)


func test_subtle_products_marked_by_share() -> void:
	var f := Factory.new(SimConfig.load_default(), 3)
	for m in f.machines:
		if m.bot != null:
			m.bot.sloppy = 1.0
	f.apply_spec({"subtle_share": 1.0})
	for i in 4000:
		f.step()
	var n := 0
	for it in f._qa_items:
		if it["defect"] != "":
			n += 1
			assert_true(it["subtle"], "all defects subtle at share 1")
	assert_true(n > 0, "some defects made")


func test_scan_reveals_and_costs_time() -> void:
	var f := _fac({})
	var item := {"defect": "crack", "decoy": "", "bot": "", "subtle": true}
	_put(f, item)
	assert_true(not f.item_visible_bad(item), "invisible before the scan")
	assert_eq(f.scan(), Factory.InspectResult.SCANNING)
	assert_true(f.item_visible_bad(item), "visible after the scan")
	assert_eq(f.subtle_scanned, 1)
	assert_true(f.inspect_busy(), "desk busy while scanning")
	assert_eq(f.inspect(false), Factory.InspectResult.BUSY)
	for i in f.scan_ticks:
		f.step()
	assert_eq(f.scan_ticks, 5, "scan_seconds 0.5 at 10 ticks/s")
	assert_eq(f.inspect(false), Factory.InspectResult.CAUGHT)
	assert_eq(f.subtle_caught, 1)


func test_unscanned_subtle_ships_as_complaint() -> void:
	var f := _fac({})
	_put(f, {"defect": "crack", "decoy": "", "bot": "", "subtle": true})
	assert_eq(f.inspect(true), Factory.InspectResult.COMPLAINT)
	assert_eq(f.subtle_shipped, 1)


func test_scan_replays() -> void:
	var f := _fac({})
	_put(f, {"defect": "crack", "decoy": "", "bot": "", "subtle": true})
	f.scan()
	assert_true(f.actions.back().has("scan"), "scan recorded")


func _back_item() -> Dictionary:
	return {"defect": "crack", "decoy": "", "bot": "", "back": true}


func test_back_defect_shipped_unflipped_is_complaint() -> void:
	var f := _fac()
	_put(f, _back_item())
	assert_false(f.item_visible_bad(f.qa_queue()[0]), "back defect hidden from the front")
	assert_eq(f.inspect(true), Factory.InspectResult.COMPLAINT, "unflipped back defect ships as a complaint")
	assert_eq(f.back_shipped, 1)


func test_flip_reveals_back_defect_and_costs_time() -> void:
	var f := _fac()
	_put(f, _back_item())
	f.flip()
	assert_true(f.inspect_busy(), "flip takes desk time")
	assert_true(f.item_visible_bad(f.qa_queue()[0]), "flip reveals the back defect")
	assert_eq(f.back_flipped, 1)
	f._inspect_left = 0
	assert_eq(f.inspect(false), Factory.InspectResult.CAUGHT)


func test_lamp_reveals_subtle_and_has_cooldown() -> void:
	var f := _fac()
	_put(f, {"defect": "dent", "decoy": "", "bot": "", "subtle": true})
	_put(f, {"defect": "dent", "decoy": "", "bot": "", "subtle": true})
	assert_eq(f.lamp(), Factory.InspectResult.SCANNING)
	assert_false(f.inspect_busy(), "lamp costs no desk time")
	assert_true(f.item_visible_bad(f.qa_queue()[0]), "lamp reveals the subtle defect")
	f.inspect(false)
	assert_eq(f.lamp(), Factory.InspectResult.BUSY, "lamp on cooldown")
	for _i in f.lamp_ticks:
		f.step()
	assert_true(f.lamp_ready(), "lamp recharged")


func test_back_defects_start_day_3_and_are_deterministic() -> void:
	var c := SimConfig.load_default()
	assert_eq(QaSpec.back_share(c, 1), 0.0)
	assert_eq(QaSpec.back_share(c, 2), 0.0)
	assert_true(QaSpec.back_share(c, 3) > 0.0)
	var runs: Array = []
	for _r in 2:
		var f := Factory.new(c, 7)
		f.apply_spec(QaSpec.for_day(c, 7, 6))
		var n := 0
		for _i in 400:
			var p := f._make_product(f.machines[0])
			if bool(p.get("back", false)):
				n += 1
		runs.append(n)
	assert_eq(runs[0], runs[1], "same seed, same back defects")
