extends TestCase


func test_breakdown_top_costs_and_worst_bot() -> void:
	var res := {"target": 20, "shipped": 14, "complaints": 2, "wasted": 3, "bot_mistakes": {"Loopy": {"count": 3, "top": "misroute"}, "Bolt": {"count": 1, "top": "jam"}}}
	var lines := RunEnd.breakdown(res, 3)
	assert_eq(lines[0], "Missed by 6")
	assert_eq(lines[1], "Complaints: 2 (-6)")
	assert_eq(lines[2], "Rejected good: 3")
	assert_eq(lines[3], "Biggest problem: Loopy, 3 misroute")


func test_breakdown_only_two_costs() -> void:
	var res := {"target": 20, "shipped": 14, "complaints": 1, "wasted": 5, "blocked_secs": 40, "bot_mistakes": {}}
	var lines := RunEnd.breakdown(res, 3)
	assert_eq(lines.size(), 3)
	assert_eq(lines[1], "Line blocked: 40s")
	assert_eq(lines[2], "Rejected good: 5")


func test_tally_and_worst_tie() -> void:
	var t := Career.mistake_tally([{"bot": "B", "mistake": "jam"}, {"bot": "A", "mistake": "jam"}, {"bot": "A", "mistake": "misroute"}, {"bot": "A", "mistake": "misroute"}, {"bot": "B", "mistake": "jam"}])
	assert_eq(int(t["A"]["count"]), 3)
	assert_eq(t["A"]["top"], "misroute")
	assert_eq(RunEnd.worst_bot({"B": {"count": 2, "top": "x"}, "A": {"count": 2, "top": "x"}}), "A")


func test_teaser() -> void:
	assert_eq(RunEnd.teaser(8, 13, false, ""), "Best: 13 days. You reached 8. Beat it in 6 more days.")
	assert_true(RunEnd.teaser(13, 13, false, "").contains("matched"))
	assert_true(RunEnd.teaser(14, 14, true, "Praise").begins_with("NEW BEST: 14"))


func test_hit_streak() -> void:
	assert_eq(RunEnd.hit_streak([{"hit": false}, {"hit": true}, {"hit": true}]), 2)
	assert_eq(RunEnd.hit_streak([{"hit": true}, {"hit": false}]), 0)
