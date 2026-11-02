class_name SettingsOverlay
extends ColorRect
## Settings card behind the top-bar cog: Sound, Haptics, Back to home, Close.

signal sound_toggled
signal haptics_toggled
signal effects_toggled
signal mode_toggled
signal home_pressed

const SCENE := preload("res://scenes/ui/settings_overlay.tscn")

# Layout lives in scenes/ui/settings_overlay.tscn; this script themes buttons and wires signals.
@onready var sound_btn: Button = %SoundBtn
@onready var haptics_btn: Button = %HapticsBtn
@onready var effects_btn: Button = %EffectsBtn
@onready var mode_btn: Button = %ModeBtn
@onready var home_btn: Button = %HomeBtn
@onready var close_btn: Button = %CloseBtn


static func create() -> SettingsOverlay:
	return SCENE.instantiate() as SettingsOverlay


func _ready() -> void:
	for b: Button in [sound_btn, haptics_btn, effects_btn, mode_btn, home_btn]:
		UiTheme.style_button(b, "secondary", 28)
	UiTheme.style_button(close_btn, "primary", 28)
	sound_btn.pressed.connect(sound_toggled.emit)
	haptics_btn.pressed.connect(haptics_toggled.emit)
	effects_btn.pressed.connect(effects_toggled.emit)
	mode_btn.pressed.connect(mode_toggled.emit)
	home_btn.pressed.connect(home_pressed.emit)
	close_btn.pressed.connect(close)


func open(sound_on: bool, haptics_on: bool, full_game: bool = false) -> void:
	refresh(sound_on, haptics_on, full_game)
	visible = true


func refresh(sound_on: bool, haptics_on: bool, full_game: bool = false) -> void:
	mode_btn.text = "Full game (dev): on" if full_game else "Full game (dev): off"
	sound_btn.text = "Sound: on" if sound_on else "Sound: off"
	haptics_btn.text = "Haptics: on" if haptics_on else "Haptics: off"
	effects_btn.text = "Effects: on" if FloorFx.enabled else "Effects: off"


func close() -> void:
	visible = false
