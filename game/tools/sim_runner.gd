extends SceneTree
## Usage: godot --headless --path game -s res://tools/sim_runner.gd -- --seed 1 --runs 50 [--shift-seconds 180] [--tier 1|2] [--player none|greedy|careful] (--bot is an alias)


func _init() -> void:
	var seed_start := 1
	var runs := 10
	var tier := 1
	var targs := OS.get_cmdline_user_args()
	for i in targs.size() - 1:
		if targs[i] == "--tier":
			tier = int(targs[i + 1])
	var cfg := SimConfig.load_tier(tier)
	if not cfg.is_valid():
		print("config errors: ", cfg.errors)
		quit(1)
		return
	var shift := cfg.shift_seconds
	if OS.has_environment("WS"): cfg.walk_speed = float(OS.get_environment("WS"))  # TMPX
	if OS.has_environment("QC"): cfg.qa_capacity = int(OS.get_environment("QC"))  # TMPX
	var bot := "none"
	var career := false
	var args := OS.get_cmdline_user_args()
	career = args.has("--career")
	var perks_arg := "none"
	var night_arg := -1
	for i in args.size() - 1:
		match args[i]:
			"--night": night_arg = int(args[i + 1])
			"--seed": seed_start = int(args[i + 1])
			"--runs": runs = int(args[i + 1])
			"--shift-seconds": shift = float(args[i + 1])
			"--player", "--bot": bot = args[i + 1]
			"--perks": perks_arg = args[i + 1]
	if args.has("--daily"):  # --daily [YYYY-MM-DD]: the daily's career (tier 1, no perks; default today)
		var di := args.find("--daily")
		var date := args[di + 1] if di + 1 < args.size() and not args[di + 1].begins_with("--") else Time.get_date_string_from_system()
		if not Daily.is_date(date):
			print("bad --daily date: ", date)
			quit(1)
			return
		career = true
		cfg = SimConfig.load_tier(Daily.TIER)
		perks_arg = "none"
		seed_start = Daily.seed_for(date)
		print("daily %s seed=%d" % [date, seed_start])
	var ticks := int(shift * cfg.tick_rate)
	if not Autoplayers.NAMES.has(bot):
		print("unknown player: ", bot)
		quit(1)
		return
	if night_arg >= 0 and not career:
		_print_night(cfg, night_arg, seed_start)
		return
	if career:
		_night_secs = night_arg if night_arg >= 0 else int(NightShift.load_rules().get("cap_seconds", 28800))
		_run_career(cfg, bot, seed_start, runs, _parse_perks(perks_arg))
		return
	var totals: Array[int] = []
	var faults := {"OVERHEATED": 0, "JAMMED": 0}
	var mistakes := {}
	var by_bot := {}  # bot name -> {mistake -> count}
	var faulted_machine_ticks := 0
	var multi_fault_runs := 0
	var scrapped := 0
	var clogs := 0
	var state_ticks := {}  # machine id -> {state name -> ticks}
	var qa := QaStats.new()
	var calm_ticks_sum := 0
	var calm_win_sum := 0
	var runs_2win := 0
	var runs_stretch_ok := 0
	var runs_multi_prob := 0
	var longest_sum := 0.0
	for r in runs:
		var f := Factory.new(cfg, seed_start + r)
		var prng := Autoplayers.make_rng(seed_start + r)
		var mem := {}
		var multi := false
		var calm_run := 0
		var prob_run := 0
		var longest := 0
		var wins := 0
		var multi_prob := false
		for _t in ticks:
			Autoplayers.act(bot, f, prng, mem)
			f.step()
			var n_faulted := 0
			for m in f.machines:
				if m.is_faulted():
					n_faulted += 1
				var d: Dictionary = state_ticks.get_or_add(m.id, {})
				d[m.state_name()] = int(d.get(m.state_name(), 0)) + 1
			faulted_machine_ticks += n_faulted
			multi = multi or n_faulted >= 2
			var np := f._problem_count()
			multi_prob = multi_prob or np >= 2
			if np == 0:
				calm_ticks_sum += 1
				calm_run += 1
				if calm_run == int(8 * cfg.tick_rate):
					wins += 1
				prob_run = 0
			else:
				calm_run = 0
				prob_run += 1
				longest = maxi(longest, prob_run)
		multi_fault_runs += 1 if multi else 0
		calm_win_sum += wins
		runs_2win += 1 if wins >= 2 else 0
		runs_stretch_ok += 1 if longest <= 30 * cfg.tick_rate else 0
		runs_multi_prob += 1 if multi_prob else 0
		longest_sum += float(longest) / cfg.tick_rate
		for k: String in faults:
			faults[k] += f.fault_counts[k]
		for k: String in f.mistake_counts:
			mistakes[k] = int(mistakes.get(k, 0)) + int(f.mistake_counts[k])
		for ev in f.mistake_log:
			var d: Dictionary = by_bot.get_or_add(ev["bot"], {})
			d[ev["mistake"]] = int(d.get(ev["mistake"], 0)) + 1
		qa.add(f)
		scrapped += f.scrapped
		clogs += f.clog_count
		totals.append(f.shipped)
	var sum := 0
	for t in totals:
		sum += t
	print("player=%s" % bot)
	print("runs=%d seed=%d shift=%ss shipped mean=%.1f min=%d max=%d" % [runs, seed_start, shift, float(sum) / runs, totals.min(), totals.max()])
	print("  faults/shift: OVERHEATED %.2f, JAMMED %.2f" % [float(faults["OVERHEATED"]) / runs, float(faults["JAMMED"]) / runs])
	var total_faults: int = faults["OVERHEATED"] + faults["JAMMED"]
	var secs := float(faulted_machine_ticks) / cfg.tick_rate / maxf(1.0, total_faults)
	print("  mean seconds faulted per fault: %.1f; runs with 2+ simultaneous faults: %.0f%%" % [secs, 100.0 * multi_fault_runs / runs])
	print("  calm: %.1f%% of shift with no active problem" % (100.0 * calm_ticks_sum / (runs * ticks)))
	print("  calm windows >= 8 s: %.2f/shift (>=2 in %.0f%% of runs); longest problem stretch: %.1f s avg (<=30 s in %.0f%% of runs); 2+ simultaneous problems in %.0f%% of runs" % [
		float(calm_win_sum) / runs, 100.0 * runs_2win / runs, longest_sum / runs, 100.0 * runs_stretch_ok / runs, 100.0 * runs_multi_prob / runs])
	var parts_m: Array[String] = []
	for k: String in mistakes:
		parts_m.append("%s %.2f" % [k, float(mistakes[k]) / runs])
	print("  mistakes/shift: ", ", ".join(parts_m))
	print("  ", qa.report())
	print("  ", qa.worker_report())
	print("  scrapped/shift: %.2f, clogs/shift: %.2f" % [float(scrapped) / runs, float(clogs) / runs])
	for b: String in by_bot:
		var pb: Array[String] = []
		for k: String in by_bot[b]:
			pb.append("%s %.2f" % [k, float(by_bot[b][k]) / runs])
		print("  bot %-7s %s" % [b, ", ".join(pb)])
	for id: String in state_ticks:
		var parts: Array[String] = []
		for s: String in state_ticks[id]:
			parts.append("%s %.0f%%" % [s, 100.0 * state_ticks[id][s] / (runs * ticks)])
		print("  %-10s %s" % [id, ", ".join(parts)])
	quit(0)


var _night_secs := 0


## --night <seconds>: the default roster's estimate (also in careers: that absence is applied after every shift).
func _print_night(cfg: SimConfig, secs: int, seed: int) -> void:
	var c := Career.new(cfg, seed)
	var est := NightShift.estimate(c.roster, secs, seed)
	print("night shift away=%ds -> commendations %d, mess_level %d" % [secs, est["commendations"], est["mess_level"]])
	for l: String in est["lines"]:
		print("  ", l)
	quit(0)


func _parse_perks(arg: String) -> Array:
	if arg == "none" or arg == "":
		return []
	var out: Array = []
	for p: Variant in Meta.load_perks().get("perks", []):
		out.append(String((p as Dictionary)["id"]))
	if arg == "all":
		return out
	var picked: Array = []
	for id in arg.split(","):
		if out.has(id):
			picked.append(id)
	return picked


func _run_career(cfg: SimConfig, player: String, seed_start: int, runs: int, perks: Array = []) -> void:
	const DAY_CAP := 30
	var days: Array[int] = []
	var fail_causes := {}
	var lessons_total := 0
	var rookies_total := 0
	var taken := {}  # offer kind -> careers that took it
	var twist_days := {}  # twist id -> [days, failed]
	var ys := TwistStats.new()
	var qa := QaStats.new()
	var rules := Meta.load_commendation_rules()
	var comm_total := 0
	var auto_days: Array[int] = []
	for r in runs:
		var c := Career.new(cfg, seed_start + r, perks)
		while not c.fired and c.day <= DAY_CAP:
			var f := c.start_day()
			var prng := Autoplayers.make_rng(c.seed * 1000 + c.day)
			var mem := {}
			for _t in int(cfg.shift_seconds * cfg.tick_rate):
				Autoplayers.act(player, f, prng, mem)
				f.step()
			qa.add(f, c.day)
			var res := c.end_day(f)
			if c.day >= cfg.twist_start_day:
				ys.add(c.day, f.twist_id != "", not res["hit"])
			if f.twist_id != "":
				var td: Array = twist_days.get(f.twist_id, [0, 0])
				td[0] += 1
				td[1] += 0 if res["hit"] else 1
				twist_days[f.twist_id] = td
			if not res["hit"]:
				var top := ""
				var best := -1
				for k: String in f.mistake_counts:
					if int(f.mistake_counts[k]) > best:
						best = int(f.mistake_counts[k])
						top = k
				fail_causes[top] = int(fail_causes.get(top, 0)) + 1
			if c.fired or c.automated:
				break
			var offs := c.offers()
			while c.points > 0 and not offs.is_empty():
				c.apply(c.choose_offer(player, offs))
				offs = c.offers()
				if c.automated:
					break
			if c.automated:
				break
			c.next_day()
			c.night_mess = int(NightShift.estimate(c.roster, _night_secs, c.seed * 31 + c.day)["mess_level"])
		if c.automated:
			auto_days.append(c.automated_day)
		lessons_total += c.lessons_learned
		rookies_total += c.rookies_joined
		for k: String in c.offers_taken:
			taken[k] = int(taken.get(k, 0)) + 1
		days.append(mini(c.day, DAY_CAP))
		comm_total += int(Meta.score(c.summary(), rules)["total"])
	days.sort()
	var sum := 0
	for d in days:
		sum += d
	print("career player=%s runs=%d seed=%d (days survived, cap %d)%s" % [player, runs, seed_start, DAY_CAP, "" if perks.is_empty() else " perks=" + ",".join(perks)])
	print("  days mean=%.1f median=%d min=%d max=%d" % [float(sum) / runs, days[days.size() / 2], days[0], days[days.size() - 1]])
	auto_days.sort()
	print("  automated %.0f%%, median automation day %s" % [100.0 * auto_days.size() / runs, str(auto_days[auto_days.size() / 2]) if not auto_days.is_empty() else "-"])
	print("  days p10=%d" % days[days.size() / 10])
	print("  commendations/career mean %.1f" % (float(comm_total) / runs))
	print("  lessons learned/career %.2f, rookies joined/career %.2f" % [float(lessons_total) / runs, float(rookies_total) / runs])
	var tk: Array[String] = []
	for k: String in ["radio", "supervise", "auto_inspect"]:
		tk.append("%s %.0f%%" % [k, 100.0 * int(taken.get(k, 0)) / runs])
	print("  offers taken (careers): ", ", ".join(tk))
	print("  day-1 queue full %.0f%% of shifts" % (100.0 * qa.day1_full / maxf(1.0, qa.day1_shifts)))
	print("  ", qa.report(true))
	print("  ", qa.worker_report())
	var keys: Array = twist_days.keys()
	keys.sort()
	for k: String in keys:
		var td: Array = twist_days[k]
		print("  twists: %-14s days %4d failed-days %.1f%%" % [k, td[0], 100.0 * td[1] / td[0]])
	for line in ys.report_lines():
		print(line)
	var parts: Array[String] = []
	for k: String in fail_causes:
		parts.append("%s %d" % [k, fail_causes[k]])
	var top_k := ""
	var top_n := -1
	for k: String in fail_causes:
		if int(fail_causes[k]) > top_n:
			top_n = int(fail_causes[k])
			top_k = k
	print("  failed shifts by top mistake: %s; main reason: %s" % [", ".join(parts), top_k if top_k != "" else "none"])
	quit(0)


## QA desk stats summed over shifts (a "run" = one shift; for careers, one day).
class QaStats:
	var shifts := 0
	var ticks := 0
	var idle := 0
	var complaints := 0
	var caught := 0
	var wasted := 0
	var shipped := 0
	var queue_sum := 0
	var queue_max := 0
	var full_shifts := 0
	var day1_shifts := 0
	var day1_full := 0
	var loc_ticks := [0, 0, 0]  # office, floor, transit
	var trips := 0
	var walk := 0

	var tick_rate := 10

	func add(f: Factory, day: int = 0) -> void:
		shifts += 1
		if day == 1:
			day1_shifts += 1
			day1_full += 1 if f.qa_full_seen else 0
		tick_rate = f._config.tick_rate
		for l in 3:
			loc_ticks[l] += int(f.worker.ticks_in[l])
		trips += f.worker.trips
		walk += f.worker.walk_ticks
		ticks += f.qa_ticks
		idle += f.idle_ticks
		complaints += f.complaints
		caught += f.caught
		wasted += f.wasted
		shipped += f.shipped
		queue_sum += f.qa_queue_sum
		queue_max = maxi(queue_max, f.qa_queue_max)
		full_shifts += 1 if f.qa_full_seen else 0

	func report(per_day: bool = false) -> String:
		var n := float(maxi(1, shifts))
		var unit := "day" if per_day else "shift"
		return "QA: idle %.1f%%, shipped/%s %.1f, complaints/%s %.2f, caught %.2f, wasted %.2f, queue avg %.2f max %d, %s with full queue %.0f%%" % [
			100.0 * idle / maxf(1.0, ticks), unit, shipped / n, unit, complaints / n, caught / n, wasted / n,
			queue_sum / maxf(1.0, ticks), queue_max, ("days" if per_day else "runs"), 100.0 * full_shifts / n]

	func worker_report() -> String:
		var t := maxf(1.0, loc_ticks[0] + loc_ticks[1] + loc_ticks[2])
		return "worker: office %.1f%%, floor %.1f%%, transit %.1f%%, trips/shift %.1f, walk: seconds/shift %.1f" % [
			100.0 * loc_ticks[0] / t, 100.0 * loc_ticks[1] / t, 100.0 * loc_ticks[2] / t, float(trips) / maxf(1.0, shifts),
			float(walk) / tick_rate / maxf(1.0, shifts)]
