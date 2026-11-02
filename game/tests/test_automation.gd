extends TestCase


func _career(seed: int = 1) -> Career:
	return Career.new(SimConfig.load_default(), seed)


func _train_all(c: Career, except: int = -1) -> void:
	for i in c.roster.size():
		if i != except:
			c.roster[i].levels["jam"] = c.config.trained_lessons


func test_flag_and_mult_apply() -> void:
	var c := _career()
	var b := c.roster[0]
	b.rates["jam"] = 6.0
	var before := b.rate_per_tick("jam", 10, 1.0, 1.0)
	assert_true(not (b.is_trained()))
	b.levels["misroute"] = c.config.trained_lessons - 1
	assert_true(not (b.is_trained()))
	b.learned["wrong_recipe"] = true  # a learned lesson counts too
	assert_true(b.is_trained())
	var after := b.rate_per_tick("jam", 10, 1.0, 1.0)
	assert_near(after / before, c.config.trained_mistake_mult * b.learn_mult / b.learn_mult, 0.0001)


func test_automation_only_when_all_trained() -> void:
	var c := _career()
	_train_all(c, 0)
	assert_true(not (c.check_automation()))
	c.roster[0].levels["jam"] = c.config.trained_lessons
	assert_true(c.check_automation())
	assert_true(c.automated)
	assert_eq(c.automated_day, c.day)


func test_late_rookie_delays_automation() -> void:
	var c := _career(3)
	_train_all(c)
	for d in range(1, 5):
		c.day = d
		c.start_day()
	assert_eq(c.rookies_joined, 1)
	assert_true(not c.check_automation())  # the rookie is untrained
	for b in c.roster:
		b.levels["jam"] = c.config.trained_lessons
	assert_true(c.check_automation())


func test_end_day_reports_automation_and_bonus() -> void:
	var c := _career()
	_train_all(c)
	var f := c.start_day()
	var res := c.end_day(f)
	assert_true(bool(res["automated"]))
	assert_true(not (bool(res["fired"])))
	var s := c.summary()
	assert_eq(int(s["automation_bonus"]), c.config.automation_bonus)
	var a := Meta.score(s, Meta.load_commendation_rules())
	assert_true(int(a["total"]) >= c.config.automation_bonus)
	var m := Meta.new()
	m.automations += 1
	assert_eq(Meta.from_dict(m.to_dict()).automations, 1)


func test_fired_career_is_not_automated() -> void:
	var c := _career()
	assert_eq(int(c.summary()["automation_bonus"]), 0)
	assert_true(not (c.automated))


func test_choose_offer_careful_trains_untrained_bot() -> void:
	var c := _career()
	var offs: Array[Dictionary] = [{"kind": "radio", "text": "r"}, {"kind": "train", "bot": c.roster[0].name, "mistake": "jam", "text": "t"}]
	assert_eq(c.choose_offer("human_careful", offs)["kind"], "train")
	assert_eq(c.choose_offer("careful", offs)["kind"], "train")
	assert_eq(c.choose_offer("greedy", offs)["kind"], "radio")
	assert_eq(c.choose_offer("human", offs)["kind"], "radio")


func test_run_end_texts_for_both_endings() -> void:
	var c := _career()
	assert_true(RunEnd.training_lines(c.roster).contains("AUTOMATED"))
	_train_all(c)
	assert_true(RunEnd.training_lines(c.roster).contains("TRAINED"))
	assert_true(c.foreman_line("automated") != "")
	assert_true(c.foreman_line("fired") != "")


func test_deterministic_per_seed() -> void:
	var a := _career(5)
	var b := _career(5)
	_train_all(a)
	_train_all(b)
	assert_eq(a.check_automation(), b.check_automation())
	assert_eq(a.roster[0].name, b.roster[0].name)
