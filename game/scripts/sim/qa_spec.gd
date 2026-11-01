class_name QaSpec
extends RefCounted
## The QA spec for a day: which decoys have become defects, which defects became acceptable, and the
## share of defects that are subtle. Deterministic per seed and day; pure data.


## {extra: decoys that are now defects, allowed: defects now acceptable, change: today's change text ("" = none),
## subtle_share: 0..1}.
static func for_day(config: SimConfig, seed: int, day: int) -> Dictionary:
	var extra: Array[String] = []
	var allowed: Array[String] = []
	var change := ""
	var last := -1000
	for d in range(config.spec_change_day, day + 1):
		change = ""
		if d - last < config.spec_change_gap:
			continue
		var r := RandomNumberGenerator.new()
		r.seed = seed * 6151 + d * 389
		if r.randf() >= config.spec_change_chance:
			continue
		var decoys: Array[String] = []
		for k in Factory.DECOYS:
			if not extra.has(k):
				decoys.append(k)
		var defects: Array[String] = []
		for k in Factory.DEFECTS:
			if not allowed.has(k):
				defects.append(k)
		var to_defect := r.randf() < 0.5
		if (to_defect and decoys.is_empty()) or (not to_defect and defects.size() <= 2):
			to_defect = not to_defect
		if to_defect and not decoys.is_empty():
			var k := decoys[r.randi_range(0, decoys.size() - 1)]
			extra.append(k)
			change = "New spec: %s is now a defect. Reject it." % nice(k)
		elif not to_defect and defects.size() > 2:
			var k := defects[r.randi_range(0, defects.size() - 1)]
			allowed.append(k)
			change = "New spec: %s is fine now. Customers like it. Don't ask." % nice(k)
		else:
			continue
		last = d
	return {"extra": extra, "allowed": allowed, "change": change, "subtle_share": subtle_share(config, day)}


static func subtle_share(config: SimConfig, day: int) -> float:
	if day < config.subtle_start_day:
		return 0.0
	return minf(config.subtle_share_max, config.subtle_share_base + config.subtle_share_per_day * float(day - config.subtle_start_day))


static func nice(kind: String) -> String:
	return kind.replace("_", " ")
