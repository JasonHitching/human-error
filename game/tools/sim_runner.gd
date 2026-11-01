extends SceneTree
## Usage: godot --headless --path game -s res://tools/sim_runner.gd -- --seed 1 --runs 50 [--shift-seconds 180] [--player none|greedy] (--bot is an alias)


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
	var args := OS.get_cmdline_user_args()
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
	var totals: Array[int] = []
	var faults := {"OVERHEATED": 0, "JAMMED": 0}
	var mistakes := {}
	var by_bot := {}  # bot name -> {mistake -> count}
	var faulted_machine_ticks := 0
	var multi_fault_runs := 0
	var scrapped := 0
	var clogs := 0
	var state_ticks := {}  # machine id -> {state name -> ticks}
	for r in runs:
		var f := Factory.new(cfg, seed_start + r)
		var multi := false
		for _t in ticks:
			Autoplayers.act(bot, f)
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
