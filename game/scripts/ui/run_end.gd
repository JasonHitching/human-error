class_name RunEnd
extends RefCounted
## Pure text builders for the run-end hooks (near-miss breakdown, best teaser, streak). No Nodes.


## Lines: "Missed by N", top two costs, and the bot that hurt most. res comes from Career.end_day.
static func breakdown(res: Dictionary, complaint_penalty: int) -> Array[String]:
	var out: Array[String] = []
	var miss := int(res["target"]) - int(res["shipped"])
	if miss > 0:
		out.append("Missed by %d" % miss)
	var costs: Array = []  # [points, text]
	var comp := int(res.get("complaints", 0))
	if comp > 0:
		costs.append([comp * complaint_penalty, "Complaints: %d (-%d)" % [comp, comp * complaint_penalty]])
	var wasted := int(res.get("wasted", 0))
	if wasted > 0:
		costs.append([wasted, "Rejected good: %d" % wasted])
	var blocked := int(res.get("blocked_secs", 0))
	if blocked > 0:
		costs.append([blocked / 4, "Line blocked: %ds" % blocked])
	costs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for i in mini(2, costs.size()):
		out.append(String(costs[i][1]))
	var worst := worst_bot(res.get("bot_mistakes", {}))
	if worst != "":
		var m: Dictionary = res["bot_mistakes"][worst]
		out.append("Biggest problem: %s, %d %s" % [worst, int(m["count"]), String(m["top"]).replace("_", " ")])
	return out


## bot_mistakes: {bot: {count, top}}. Highest count wins; ties go to the name that sorts first.
static func worst_bot(bm: Dictionary) -> String:
	var best := ""
	var best_n := 0
	var names := bm.keys()
	names.sort()
	for n: String in names:
		var c := int(bm[n]["count"])
		if c > best_n:
			best_n = c
			best = n
	return best


## "Best: 13 days. You reached 8. Beat it in 6 more days." (days = days survived this run)
static func teaser(days: int, best_days: int, new_best: bool, praise: String) -> String:
	if new_best:
		return "NEW BEST: %d days\n%s" % [days, praise]
	if days == best_days:
		return "Best: %d days. You matched it. One more day beats it." % best_days
	return "Best: %d days. You reached %d. Beat it in %d more days." % [best_days, days, best_days - days + 1]


## Consecutive hit days ending at the latest history entry.
static func hit_streak(history: Array) -> int:
	var n := 0
	for i in range(history.size() - 1, -1, -1):
		if not bool(history[i]["hit"]):
			break
		n += 1
	return n


static func progress_line(res: Dictionary, bonus_threshold: float) -> String:
	if int(res["points"]) > 0:
		return "Training point banked: pick below"
	var need := ceili(float(res["target"]) * bonus_threshold) - int(res["shipped"])
	return "%d more points for a bonus training pick" % maxi(1, need)


## "COMMENDATIONS\n<line>\n...\nTotal: +N" for Meta.award's result ("" when nothing earned).
static func awards_text(a: Dictionary) -> String:
	if int(a.get("total", 0)) <= 0:
		return ""
	return "COMMENDATIONS\n%s\nTotal: +%d" % ["\n".join(a["lines"]), int(a["total"])]
