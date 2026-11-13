extends Control

const BAR_COUNT := 100

var bar_theme : Theme = preload("res://assets/themes/bar_theme.tres")

@onready var hbox: HBoxContainer = $margin/hbox

func _ready() -> void:
	
	for i in range(BAR_COUNT):
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 1
		bar.value = 0
		bar.show_percentage = false
		bar.theme = bar_theme
		bar.fill_mode = 3
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_FILL
		hbox.add_child(bar)

func _process(_delta: float) -> void:
	var audio_data = global.main_node.wsm.song_frequencies
	var bins = audio_data["bins"]
	var vol = audio_data["volume"]
	if bins.size() >= BAR_COUNT / 2 and vol != 0:
		var max_val : float = vol * 0.15

		for i in range(BAR_COUNT):
			var bar := hbox.get_child(i) as ProgressBar
			var original = bins[i]

			bar.max_value = max_val

			if original > bar.value:
				bar.value = lerp(bar.value, original, 0.9)
			else:
				bar.value = lerp(bar.value, original, 0.5)
				if bar.value < 0.04:
					bar.value = 0.01
	else:
		for child in hbox.get_children():
			child.value = 0
