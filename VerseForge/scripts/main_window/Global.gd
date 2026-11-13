extends Node

var current_version : String = "v0.0.0"
var version_data : Dictionary = {}

var editing_writer_project : bool = false
var editing_theme_project : bool = false


var multiWinSetup = preload("res://scenes/intro/multi_window_setup.tscn")


var parralax_face : bool = false
var parralax_pos : Vector2 = Vector2.ZERO

var debug_mode : bool = false
var font = preload("res://assets/fonts/roboto/Roboto-default.ttf")

var sleep_animation_enabled : bool = true

var old_screen_count = DisplayServer.get_screen_count()
var screen_count = DisplayServer.get_screen_count()

var screens = []
var screen_real : Array = []
var request_termination : bool = false

# Executables
var python_path = "python"
var app_external : String
var py_server : String = ""

var editor_exe_path : String
var godot_exe_path := "C:/code/.godot/4.4/Godot.exe"

var main_node : Main



func start_server():
	if debug_mode:
		OS.create_process(global.python_path, [global.py_server])
	else:
		OS.create_process(global.py_server, [])




func _ready():
	Engine.max_fps = 30
	Engine.physics_ticks_per_second = 30
	Engine.physics_jitter_fix = 0
	debug_mode = OS.has_feature("editor")
	
	if debug_mode:
		app_external = ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir()
		py_server = app_external.path_join("server.py")
		print("Path to server: ", py_server)
	else:
		app_external = OS.get_executable_path().get_base_dir()
		py_server = app_external.path_join("server.exe")
	
	editor_exe_path = app_external.path_join("VerseForge_Editor.exe")
	start_server()
	
	update_screen_list()
	set_screen_real(0, 1)
	set_screen_real(1, 2, Vector2(350, 700))
	update_screen_list()

func check_new_screen():
	screen_count = DisplayServer.get_screen_count()
	if old_screen_count != screen_count:
		update_screen_list()
		old_screen_count = screen_count

func update_screen_list():
	screens = []
	for screen in range(screen_count):
		var pos = DisplayServer.screen_get_position(screen)
		var dpi = get_screen_dpi_or_offset(screen)
		if dpi is bool: dpi = DisplayServer.screen_get_dpi(screen)
		screens.append({
			"id": screen,
			"size": DisplayServer.screen_get_size(screen),
			"pos": pos,
			"offset": get_screen_dpi_or_offset(screen, true),
			"dpi": dpi
			})

func get_screen_dpi_or_offset(id : int, get_offset : bool = false):
	if id >= screen_real.size(): return Vector2.ZERO
	if get_offset:
		if screen_real[id]["id"] == id: return screen_real[id]["offset"]
		for screen in screen_real:
			if screen["id"] == id: return screen["offset"]
	
	if screen_real[id]["id"] == id: return screen_real[id]["dpi"]
	for screen in screen_real:
		if screen["id"] == id: return screen["dpi"]
	return false

func set_screen_real(screen_id : int, real_width : float, offset : Vector2 = Vector2.ZERO):
	if screens.size() <= screen_id: return
	var dpi = screens[screen_id]["size"].x / real_width
	var value = { "id": screen_id, "dpi": dpi, "offset": offset }
	var found = false
	for i in range(screen_real.size()):
		if screen_real[i]["id"] == screen_id:
			screen_real[i] = value
			found = true
			break
	if not found:
		screen_real.append(value)

var song_image

func _process(_delta: float) -> void:
	if request_termination:
		get_tree().quit()

var editor_canvas : Node2D

var settings_control : Control
var editor_control : Control
var writer_control : Control

func find_and_load_image(ipath: String):
	if ipath == "":
		print("❌ Neizdevās atrast attēlu:  ", ipath)
		return null
	var img = Image.load_from_file(ipath)
	var texture = ImageTexture.create_from_image(img)
	return texture


func get_screen_index_for_mouse() -> int:
	var mouse_pos = DisplayServer.mouse_get_position()
	
	for i in range(screen_count):
		var screen_rect = DisplayServer.screen_get_usable_rect(i)
		if screen_rect.has_point(mouse_pos):
			return i
	return DisplayServer.window_get_current_screen()

func setup_window(window: Window, initial_pos : Window.WindowInitialPosition, window_size = 1.0):
	var screen_id = get_screen_index_for_mouse()
	if screens.size() > screen_id:
		var popup_screen = screens[screen_id]
		window.size = popup_screen["size"] * window_size
		window.initial_position = initial_pos
		if window.initial_position == Window.WINDOW_INITIAL_POSITION_CENTER_OTHER_SCREEN:
			window.current_screen = screen_id
		return true
	return false


func get_center_from_cameras_in_world(cameras : Array):
	var positions = Vector2.ZERO
	for cam in cameras:
		positions += cam.position
	return positions / cameras.size()
	

func sleep_pc():
	if sleep_animation_enabled:
		var multi_win = multiWinSetup.instantiate()
		main_node.add_child(multi_win)
		multi_win.start("shutdown")
	await get_tree().create_timer(3.0).timeout
	OS.execute("cmd", ["/c", "powercfg -h off & rundll32.exe powrprof.dll,SetSuspendState Sleep"])


func shutdown_pc(time : int = 0):
	OS.execute("shutdown", ["/s", "/t", time])
