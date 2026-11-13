extends Control
var time_offset : float = 0.5
var start_time = Time.get_ticks_msec() / 1000.0
var current_time := 0.0
var server_time := 0.0
var song_line_index := 0
var lyrics_line := ""
var lyrics_split := []
var time_till_next_line := 0.0
var previous_text := ""
var displayed_text := ""

@onready var window_appear : Tween

@onready var song_label = $container/TITLE/song
@onready var artist_label = $container/TITLE/artist
@onready var lyrics = $container/lyrics/lyrics

@onready var title_container = $container/TITLE
@onready var progress_bar = $container/ProgressBar

@onready var image_rect = $image

var main_node : Main


var last_song = ""
var last_artist = ""
var word_count : int = 0
var current_screen
var screen_center

var song_name : String
var artist : String
var progress : float
var server_timestamp : float
var song_lyrics : Array
var temp_path : String
var song_image

func _ready():
	var screen
	if global.screens.size() > 1:
		screen = global.screens[1]
	else:
		screen = global.screens[0]
	current_screen = screen
	screen_center = current_screen["size"] * 0.5
	get_parent().initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_OTHER_SCREEN
	get_parent().current_screen = screen["id"]
	get_parent().size = screen["size"]
	
	title_container.custom_minimum_size.y = screen_center.y
	image_rect.position = Vector2(screen_center.x, screen_center.y * 1.22) - (image_rect.size / 2)


var image_scale : Vector2 = Vector2.ONE
var target_scale : Vector2 = Vector2.ONE

var beat_freq_indices = [1, 20, 50, 80, 95]
var beat_strengths = [1, 0.3, 0.2, 0.15, 0.1]  # cik stipri katrs beat ietekmē skalas

func _process(_delta):
	if main_node == null:
		main_node = global.main_node
	var scale_factor = 0.8  # default

	var audio_data = global.main_node.wsm.song_frequencies
	var bins = audio_data["bins"]
	var beats = audio_data["beat"]

	# filtrē tikai tos beat indices, kas nav 0.0
	for i in range(5):
		if beats[i] != 0.0:
			var freq_val = 1.0
			if i < bins.size() and beat_freq_indices[i] < bins.size():
				freq_val = bins[beat_freq_indices[i]]
			scale_factor = 1.0 + freq_val * beat_strengths[i]
			break
		else:
			scale_factor = 0.8 + 0.2 * (bins[0] if bins.size() > 0 else 1.0)

	target_scale = Vector2.ONE * scale_factor


	if image_scale < target_scale:
		image_scale = image_scale.lerp(target_scale, 0.9)
	else:
		image_scale = image_scale.lerp(target_scale, 0.2)

	image_rect.scale = image_scale
	
	var song_data = main_node.wsm.song_data
	
	song_name = song_data["song_name"]
	artist = song_data["artist"]
	song_lyrics = song_data["lyrics"]
	progress = song_data["progress"]
	server_timestamp = song_data["progress_timestamp"]
	temp_path = song_data["cover_path"]
	
	var paused = song_data["paused"]
	var length = song_data["length"]
	
	if not paused:
		current_time = server_time + (Time.get_ticks_msec()/1000.0 - server_timestamp)
	else:
		current_time = server_time
	
	if server_time != progress:
		server_time = progress
		start_time = Time.get_ticks_msec() / 1000.0 - server_time

		song_line_index = 0
		for i in range(song_lyrics.size()):
			if song_lyrics[i] == null or song_lyrics[i].size() == 0:
				continue
			if song_lyrics[i][1] == null:
				continue
			if song_lyrics[i][1] >= current_time:
				song_line_index = i
				break
	
	if last_song != song_name:
		last_song = song_name
		song_label.text = "[wave][center][b]"+ song_name + "[/b][/center][/wave]"
		song_lyrics = []
		clear_lyrics()
		
		song_image = null
		image_rect.texture = null
		display_image()
		
	if last_artist != artist:
		last_artist = artist
		artist_label.text = "[wave][center]" + artist + "[/center][/wave]"
	
	if paused:
		clear_lyrics()
	
	if lyrics.text == "":
		animate_size(screen_center.y * 0.8)
	else:
		animate_size(screen_center.y * 0.2)

	progress_bar.max_value = length
	progress_bar.value = current_time
	if not paused:
		show_lyrics()
	
	#command_data()

func clear_lyrics():
	lyrics.text = ""
	lyrics_line = ""

func show_lyrics():
	if song_lyrics.size() != 0:
		if progress > song_lyrics[song_lyrics.size() - 1][1]:
			clear_lyrics()
			return
	if song_lyrics.is_empty() or song_line_index >= song_lyrics.size():
		clear_lyrics()
		return
	
	if song_lyrics[song_line_index] != null and song_lyrics[song_line_index][1] != null and current_time >= song_lyrics[song_line_index][1]:
		lyrics_line = song_lyrics[song_line_index][0]
		song_line_index += 1
		previous_text = displayed_text
	
	lyrics_split = lyrics_line.split(" ")

	if lyrics_split.is_empty():
		lyrics.text = ""
		return

	var line_start_time = get_time()
	var line_end_time = line_start_time + 4.0
	if song_line_index < song_lyrics.size() and song_lyrics[song_line_index][1] != null:
		var a = song_lyrics[song_line_index][1]
		line_end_time = a - (abs(line_start_time - a) * 0.4)
	
	var word_progress = clamp((current_time - line_start_time) / (line_end_time - line_start_time), 0, 1)
	var last_word_count = word_count
	word_count = int(word_progress * lyrics_split.size())
	word_count = clamp(word_count, 1, lyrics_split.size())

	displayed_text = " ".join(lyrics_split.slice(0, word_count))
	
	lyrics.text = previous_text + "\n" + displayed_text

var tween : Tween
func animate_size(target_size: float):
	if tween:
		tween.kill()
	tween = get_tree().create_tween()
	tween.tween_property(title_container, "custom_minimum_size:y",
	target_size, 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func display_image():
	if temp_path != "":
		song_image = global.find_and_load_image(temp_path)
		if song_image:
			image_rect.texture = song_image

func get_time():
	var time = song_lyrics[song_line_index - 1][1]
	if time is not float or time == null:
		time = song_lyrics[song_line_index - 2][1]
	if time is not float or time == null:
		return 0.0
	return time

#func command_data():
	#var req = global.main_node.commands
	#if not req.is_requesting:
		#var request = await req.get_data({"request_termination": false})
		#global.request_termination = request["request_termination"]
