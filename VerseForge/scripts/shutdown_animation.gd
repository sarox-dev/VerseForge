extends Node2D

var center : Vector2 = Vector2.ZERO
var screen = null
@onready var camera_2d: Camera2D = $Camera2D
@onready var animation_player: AnimationPlayer = $container/AnimationPlayer
@onready var container: Node2D = $container


func set_screen(screen_obj, center_vec):
	screen = screen_obj
	center = center_vec

func _ready() -> void:
	var parent = get_parent()
	if parent is Window:
		parent.transparent = true
	if screen == null: return
	var dpi = global.get_screen_dpi_or_offset(screen["id"])
	var screen_width_inches = screen["size"].x / dpi
	
	var zoom_factor = 1 / screen_width_inches
	camera_2d.zoom = Vector2(1, 1) * zoom_factor
	var screen_pos = Vector2(screen["pos"]) - screen["offset"]
	camera_2d.position = screen_pos - center
	container.position = center
	animation_player.play("new_test")
