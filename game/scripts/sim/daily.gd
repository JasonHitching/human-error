class_name Daily
extends RefCounted
## Daily career: one shared seed per local calendar day. Pure: dates are passed in, no clock, no IO.

const TIER := 1  # fair and comparable: tier 1, no perks
const KEEP := 30  # dates of best kept in the save
const SEED_BASE := 1000000


## Deterministic seed for a "YYYY-MM-DD" string (FNV-1a, 31-bit, offset so it never collides with small test seeds).
static func seed_for(date_string: String) -> int:
	var h := 2166136261
	for b in date_string.to_utf8_buffer():
		h = ((h ^ int(b)) * 16777619) & 0xFFFFFFFF
	return SEED_BASE + (h & 0x3FFFFFFF)


static func is_date(s: String) -> bool:
	var p := s.split("-")
	if p.size() != 3 or p[0].length() != 4 or p[1].length() != 2 or p[2].length() != 2:
		return false
	for x in p:
		if not x.is_valid_int():
			return false
	return int(p[1]) >= 1 and int(p[1]) <= 12 and int(p[2]) >= 1 and int(p[2]) <= 31


## True when `b` is exactly the calendar day after `a`.
static func is_next_day(a: String, b: String) -> bool:
	if not is_date(a) or not is_date(b):
		return false
	var ua := Time.get_unix_time_from_datetime_string(a + "T00:00:00")
	var ub := Time.get_unix_time_from_datetime_string(b + "T00:00:00")
	return ub - ua == 86400
