extends Node2D

var intro_scene = preload("res://scenes/intro/intro_scene.tscn")
var shutdown_scene = preload("res://scenes/shutdown_animation.tscn")

func start(scene_type : String = "intro"):
	if scene_type == "intro" and (global.parralax_pos == Vector2.ZERO or not global.parralax_face):
		return
	
	global.update_screen_list()
	if global.screens.is_empty():
		return

	var total_pos = Vector2.ZERO
	for screen in global.screens:
		total_pos += Vector2(screen["pos"])
	var center_pos = total_pos / global.screens.size()

	var selected_scene = get_selected_scene(scene_type)
	for screen in global.screens:
		create_window(screen, center_pos, selected_scene)
	
	if scene_type == "intro":
		await get_tree().create_timer(10).timeout
	if scene_type == "shutdown":
		await get_tree().create_timer(3).timeout
	queue_free()

func create_window(screen, center, scene : PackedScene):
	var window = Window.new()
	window.size = screen["size"]
	window.position = screen["pos"]
	window.borderless = true
	window.always_on_top = true
	window.popup_window = true
	window.unfocusable = true
	window.name = str(screen["id"])

	var instance = scene.instantiate()
	instance.set_screen(screen, center)
	window.add_child(instance)
	add_child(window)

func delete_windows():
	for child in get_children():
		if child is Window:
			child.hide()
			child.queue_free()


func get_selected_scene(scene_string : String) -> PackedScene:
	if scene_string == "intro": return intro_scene
	if scene_string == "shutdown": return shutdown_scene
	
	return intro_scene
