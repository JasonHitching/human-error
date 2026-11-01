class_name Haptics
extends RefCounted
## Phone vibration helper. No-op where unsupported (web, headless, desktop).

static var enabled: bool = true


static func supported() -> bool:
	return not OS.has_feature("web") and (OS.has_feature("android") or OS.has_feature("ios")) and DisplayServer.get_name() != "headless"


## Vibrate for ms milliseconds. Returns whether a vibration was requested.
static func pulse(ms: int) -> bool:
	if not enabled or not supported():
		return false
	Input.vibrate_handheld(ms)
	return true
