extends Control

@onready var video_loader: VideoLoader = $VideoLoader
@onready var bg: TextureRect = $bg

@onready var title: Label = $vbox/title
@onready var author: Label = $vbox/author

@onready var bpm_text: Label = $debug/debug

@onready var beats_kick: Label = $debug/kick
@onready var beats_bass: Label = $debug/bass
@onready var beats_snare: Label = $debug/snare
@onready var beats_hihat: Label = $debug/hihat
@onready var beats_bright: Label = $debug/bright
@onready var downbeat_indicator: Label = $debug/downbeat


var main : Main
var streamer : FrameStreamer

var frame_path : String = ""
var frame_count : int = 0

var song_name : String = ""
var artist : String = ""

var base_path : String = ""

var video_array : Array = []
var can_start : bool = false

func _ready() -> void:
	var screen
	if global.screens.size() > 1:
		screen = global.screens[1]
	else:
		screen = global.screens[0]
	get_parent().initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_OTHER_SCREEN
	get_parent().current_screen = screen["id"]
	get_parent().size = screen["size"]
	
	base_path = global.app_external.path_join("hardcoded_themes/minecraft/video")
	video_array = video_loader.get_videos_from_folder(base_path)
	await load_videos(video_array)
	streamer = FrameStreamer.new(frame_path, frame_count)
	can_start = true




func _process(delta: float) -> void:
	if main == null:
		main = global.main_node
	
	if !can_start:
		return
	
	stream_video()
	
	
	var song_data = main.wsm.song_data
	
	song_name = song_data["song_name"]
	artist = song_data["artist"]
	
	title.text = song_name
	author.text = artist

func load_videos(array_of_videos : Array):
	for video in array_of_videos:
		video_loader.update_video_path(base_path.path_join(video))
		frame_path = video_loader.get_frame_path(video.get_basename())
		frame_count = video_loader.get_video_info()["frames"]
		if not video_loader.frames_already_exist(frame_path):
			await video_loader.extract_frames()
	print("All videos are loaded!")

var last_beats : Array = [0.0, 0.0, 0.0, 0.0, 0.0]

func stream_video():
	if not streamer: return
	
	var tex = streamer.get_next_frame()
	if tex != null: bg.texture = tex
	
	var freq: Dictionary = main.wsm.song_frequencies
	var beats: Array = freq.get("beat", last_beats)
	var downbeat: bool = freq.get("downbeat", false)
	var bpm: float = freq.get("bpm", 0.0)

	beats_bass.modulate.a *= 0.8
	beats_kick.modulate.a *= 0.8
	beats_snare.modulate.a *= 0.8
	beats_hihat.modulate.a *= 0.8
	beats_bright.modulate.a *= 0.8

	if last_beats[0] != beats[0]: beats_bass.modulate.a = 1.0
	if last_beats[1] != beats[1]: beats_kick.modulate.a = 1.0
	if last_beats[2] != beats[2]: beats_snare.modulate.a = 1.0
	if last_beats[3] != beats[3]: beats_hihat.modulate.a = 1.0
	if last_beats[4] != beats[4]: beats_bright.modulate.a = 1.0

	# Saglabā pēdējo sitienu stāvokli
	last_beats = beats

	# BPM teksta izvade
	bpm_text.text = "%d BPM" % [int(bpm)]

	# --- Downbeat indikators ---
	if downbeat:
		downbeat_indicator.modulate.a = 1.0
	else:
		downbeat_indicator.modulate.a *= 0.8

	
	if not downbeat and streamer.current_frame_index < frame_count:
		return
	
	if streamer.current_frame_index < bpm * 0.05: return

	var video : String = video_array.pick_random()
	frame_path = video_loader.get_frame_path(video.get_basename())
	video_loader.update_video_path(base_path.path_join(video))
	frame_count = video_loader.get_video_info()["frames"]
	streamer = FrameStreamer.new(frame_path, frame_count)
	
