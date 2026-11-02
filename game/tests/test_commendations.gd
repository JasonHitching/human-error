extends TestCase

const P := "user://test_comm_save.json"
const RULES := {
	"per_day": 3, "per_clean_shift": 2, "streak_every": 3, "per_streak_milestone": 3,
	"per_lesson": 2, "per_twist_day": 2,
	"lines": {"days": "d{n}+{pts}", "clean": "c{n}+{pts}", "streak": "s{n}+{pts}", "lessons": "l{n}+{pts}", "twists": "t{n}+{pts}"},
}


func test_formula() -> void:
	var r := Meta.score({"days": 10, "clean_shifts": 4, "best_streak": 7, "lessons": 3, "twist_days": 5}, RULES)
	assert_eq(int(r["total"]), 30 + 8 + 6 + 6 + 10)
	assert_eq((r["lines"] as Array).size(), 5)
	assert_eq(String(r["lines"][0]), "d10+30")
	assert_eq(String(r["lines"][2]), "s7+6")


func test_empty_summary_is_zero() -> void:
	var r := Meta.score({}, RULES)
	assert_eq(int(r["total"]), 0)
	assert_eq((r["lines"] as Array).size(), 0)


func test_deterministic() -> void:
	var s := {"days": 5, "clean_shifts": 1, "best_streak": 3, "lessons": 0, "twist_days": 2}
	assert_eq(Meta.score(s, RULES), Meta.score(s, RULES))


func test_award_accumulates_and_persists() -> void:
	var m := Meta.new()
	m.award({"days": 4}, RULES)
	m.award({"days": 2}, RULES)
	assert_eq(m.balance(), 18)
	assert_true(SaveIO.write_meta(m, P))
	var m2 := SaveIO.load_meta(P, P + ".bad", "user://none.json")
	assert_eq(m2.balance(), 18)
	assert_eq(int(m2.commendations["earned"]), 18)


func test_default_rules_load() -> void:
	var r := Meta.load_commendation_rules()
	assert_true(int(r.get("per_day", 0)) > 0)


func test_career_summary() -> void:
	var cfg := SimConfig.load_default()
	var c := Career.new(cfg, 1)
	var s := c.summary()
	assert_eq(int(s["days"]), 1)
	assert_eq(int(s["best_streak"]), 0)


func test_home_builds() -> void:
	for bal: int in [0, 5, 999999]:
		var h := Home.new()
		var m := Meta.new()
		m.commendations["balance"] = bal
		Engine.get_main_loop().root.add_child(h)
		h.setup(m)
		assert_true(h.start_btn.custom_minimum_size.x >= 120 and h.start_btn.custom_minimum_size.y >= 80)
		h.queue_free()
