extends Node2D

var center : Vector2 = Vector2.ZERO
var screen = null
@onready var camera_2d: Camera2D = $Camera2D
@onready var parralax_container: Node2D = $parralax


func set_screen(screen_obj, center_vec):
	screen = screen_obj
	center = center_vec
	

func _ready() -> void:
	if screen == null: return
	var dpi = global.get_screen_dpi_or_offset(screen["id"])
	var screen_width_inches = screen["size"].x / dpi
	
	var zoom_factor = 1 / screen_width_inches
	camera_2d.zoom = Vector2(1, 1) * zoom_factor
	var screen_pos = Vector2(screen["pos"]) - screen["offset"]
	camera_2d.position = screen_pos - center


func _process(delta: float) -> void:
	var offset_pos = Vector2(3000, -1000)
	for child in parralax_container.get_children():
		var child_scale = float(child.name)
		var new_pos = (global.parralax_pos * child_scale) - offset_pos
		child.global_position = child.global_position.lerp(new_pos, delta * 8)
