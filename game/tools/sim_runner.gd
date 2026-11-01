extends SceneTree
## Usage: godot --headless --path game -s res://tools/sim_runner.gd -- --seed 1 --runs 50 [--shift-seconds 180] [--bot none|greedy]


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
			"--bot": bot = args[i + 1]
	var ticks := int(shift * cfg.tick_rate)
	if not Bots.NAMES.has(bot):
		print("unknown bot: ", bot)
		quit(1)
		return
	var totals: Array[int] = []
	var faults := {"OVERHEATED": 0, "JAMMED": 0}
	var faulted_machine_ticks := 0
	var multi_fault_runs := 0
	var state_ticks := {}  # machine id -> {state name -> ticks}
	for r in runs:
		var f := Factory.new(cfg, seed_start + r)
		var multi := false
		for _t in ticks:
			Bots.act(bot, f)
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
		totals.append(f.shipped)
	var sum := 0
	for t in totals:
		sum += t
	print("bot=%s" % bot)
	print("runs=%d seed=%d shift=%ss shipped mean=%.1f min=%d max=%d" % [runs, seed_start, shift, float(sum) / runs, totals.min(), totals.max()])
	print("  faults/shift: OVERHEATED %.2f, JAMMED %.2f" % [float(faults["OVERHEATED"]) / runs, float(faults["JAMMED"]) / runs])
	var total_faults: int = faults["OVERHEATED"] + faults["JAMMED"]
	var secs := float(faulted_machine_ticks) / cfg.tick_rate / maxf(1.0, total_faults)
	print("  mean seconds faulted per fault: %.1f; runs with 2+ simultaneous faults: %.0f%%" % [secs, 100.0 * multi_fault_runs / runs])
	for id: String in state_ticks:
		var parts: Array[String] = []
		for s: String in state_ticks[id]:
			parts.append("%s %.0f%%" % [s, 100.0 * state_ticks[id][s] / (runs * ticks)])
		print("  %-10s %s" % [id, ", ".join(parts)])
	quit(0)
