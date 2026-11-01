extends SceneTree
## Usage: godot --headless --path game -s res://tools/sim_runner.gd -- --seed 1 --runs 50 [--shift-seconds 180] [--player none|greedy|careful] (--bot is an alias)


func _init() -> void:
	var seed_start := 1
	var runs := 10
	var cfg := SimConfig.load_default()
	if not cfg.is_valid():
		print("config errors: ", cfg.errors)
		quit(1)
		return
	var shift := cfg.shift_seconds
	var bot := "none"
	var career := false
	var args := OS.get_cmdline_user_args()
	career = args.has("--career")
	for i in args.size() - 1:
		match args[i]:
			"--seed": seed_start = int(args[i + 1])
			"--runs": runs = int(args[i + 1])
			"--shift-seconds": shift = float(args[i + 1])
			"--player", "--bot": bot = args[i + 1]
	var ticks := int(shift * cfg.tick_rate)
	if not Autoplayers.NAMES.has(bot):
		print("unknown player: ", bot)
		quit(1)
		return
	if career:
		_run_career(cfg, bot, seed_start, runs)
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
	for r in runs:
		var f := Factory.new(cfg, seed_start + r)
		var prng := Autoplayers.make_rng(seed_start + r)
		var multi := false
		for _t in ticks:
			Autoplayers.act(bot, f, prng)
			f.step()
			var n_faulted := 0
			for m in f.machines:
				if m.is_faulted():
					n_faulted += 1
				var d: Dictionary = state_ticks.get_or_add(m.id, {})
				d[m.state_name()] = int(d.get(m.state_name(), 0)) + 1
			faulted_machine_ticks += n_faulted
			multi = multi or n_faulted >= 2
		multi_fault_runs += 1 if multi else 0
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
	var parts_m: Array[String] = []
	for k: String in mistakes:
		parts_m.append("%s %.2f" % [k, float(mistakes[k]) / runs])
	print("  mistakes/shift: ", ", ".join(parts_m))
	print("  ", qa.report())
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


func _run_career(cfg: SimConfig, player: String, seed_start: int, runs: int) -> void:
	const DAY_CAP := 30
	var days: Array[int] = []
	var fail_causes := {}
	var qa := QaStats.new()
	for r in runs:
		var c := Career.new(cfg, seed_start + r)
		while not c.fired and c.day <= DAY_CAP:
			var f := c.start_day()
			var prng := Autoplayers.make_rng(c.seed * 1000 + c.day)
			for _t in int(cfg.shift_seconds * cfg.tick_rate):
				Autoplayers.act(player, f, prng)
				f.step()
			qa.add(f)
			var res := c.end_day(f)
			if not res["hit"]:
				var top := ""
				var best := -1
				for k: String in f.mistake_counts:
					if int(f.mistake_counts[k]) > best:
						best = int(f.mistake_counts[k])
						top = k
				fail_causes[top] = int(fail_causes.get(top, 0)) + 1
			if c.fired:
				break
			var offs := c.offers()
			while c.points > 0 and not offs.is_empty():
				c.apply(offs[0])
				offs = c.offers()
			c.next_day()
		days.append(mini(c.day, DAY_CAP))
	days.sort()
	var sum := 0
	for d in days:
		sum += d
	print("career player=%s runs=%d seed=%d (days survived, cap %d)" % [player, runs, seed_start, DAY_CAP])
	print("  days mean=%.1f median=%d min=%d max=%d" % [float(sum) / runs, days[days.size() / 2], days[0], days[days.size() - 1]])
	print("  ", qa.report(true))
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

	func add(f: Factory) -> void:
		shifts += 1
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
