class_name WindowsManager
extends Node

var screens := {} # {screen_id: {theme: Node, visible: bool}}
var active_screens := [] # saraksts ar screen_id kuri jāparāda
var themes := {} # {theme_name: PackedScene}

func _ready() -> void:
	_register_builtin_themes()
	init_windows()

func _register_builtin_themes() -> void:
	# Hardcoded themes
	themes["default"] = preload("res://hardcoded_themes/Basic dark visualizer.tscn")
	
	# Te vēlāk vari pievienot custom themes no user foldera

func init_windows() -> void:
	for screen_id in active_screens:
		if themes.has("default"):
			var theme_instance = themes["default"].instantiate()
			register_screen(screen_id, theme_instance)
			add_child(theme_instance)

func register_screen(screen_id: int, theme_node: Node) -> void:
	screens[screen_id] = {
		"theme": theme_node,
		"visible": true
	}

func set_theme(screen_id: int, theme_name: String) -> void:
	if screens.has(screen_id) and themes.has(theme_name):
		var theme_instance = themes[theme_name].instantiate()
		var old_theme = screens[screen_id].theme
		if old_theme:
			old_theme.queue_free()
		add_child(theme_instance)
		screens[screen_id].theme = theme_instance

func show_screen(screen_id: int) -> void:
	if screens.has(screen_id):
		screens[screen_id].visible = true
		_update_screen_visibility(screen_id)

func hide_screen(screen_id: int) -> void:
	if screens.has(screen_id):
		screens[screen_id].visible = false
		_update_screen_visibility(screen_id)

func toggle_screen(screen_id: int) -> void:
	if screens.has(screen_id):
		screens[screen_id].visible = !screens[screen_id].visible
		_update_screen_visibility(screen_id)

func get_data(screen_id: int) -> Dictionary:
	if screens.has(screen_id) and screens[screen_id].theme.has_method("get_data"):
		return screens[screen_id].theme.get_data()
	return {}

func _update_screen_visibility(screen_id: int) -> void:
	var scr = screens[screen_id]
	if scr.visible:
		scr.theme.show()
	else:
		scr.theme.hide()
