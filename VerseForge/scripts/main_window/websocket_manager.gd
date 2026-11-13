class_name WebSocketManager
extends Node

var peer := WebSocketPeer.new()
var task_running = false


var song_data : Dictionary = {"artist": "", "song_name": "", "lyrics":[0.0, ""], "progress": 0, "progress_timestamp": 0, "length": 0, "paused": true, "cover_path": ""}
var song_frequencies : Dictionary = {"bins": [0.0], "volume": 0.0, "beat": [0.0, 0.0, 0.0, 0.0, 0.0], "bpm": 0.0, "downbeat": false}


var restart_server_time : float = 0.0

func _ready():
	var ws_err = peer.connect_to_url("ws://127.0.0.1:1234")
	if ws_err != OK:
		print("Failed to connect WS: %s" % ws_err)
	else:
		print("Connecting to WS server ws://127.0.0.1:1234")

func _process(delta):
	peer.poll()

	if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		restart_server_time = 0
		while peer.get_available_packet_count() > 0:
			var msg = peer.get_packet().get_string_from_utf8()
			var data : Dictionary = JSON.parse_string(msg)
			if data == null or typeof(data) != TYPE_DICTIONARY:
				print("[SERVER RAW]    ", msg)
				continue
			process_data(data)
	else:
		restart_server_time += delta
		if restart_server_time > 8:
			restart_server_time = 0
			print("Starting up new server process.")
			global.start_server()


func send_request(action : String):
	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("Error: Websocket peer is not open.")
		return
	
	var msg : Dictionary = {"action": action}
	peer.send_text(JSON.stringify(msg))
	print("[CLIENT]    ", action)



func process_data(data : Dictionary):
	match data.get("action", ""):
		"connected":
			_handle_simple_status(data)
			send_request("start_audio")
			send_request("start_visualizer")
		"error":
			_handle_error(data)
		"audio_started", "audio_stopped", "visualizer_started", "visualizer_stopped":
			_handle_simple_status(data)
		"song_frequencies":
			song_frequencies = data["payload"]
		"song_update":
			song_data = data["payload"]
		"server_exit":
			_handle_simple_status(data)
			get_tree().quit()
		_:
			_handle_default(data)

func _handle_error(data : Dictionary):
	print("[SERVER ERROR]", data)

func _handle_default(data: Dictionary):
	print("[SERVER INFO]    ", data)

func _handle_simple_status(data : Dictionary):
	var action = data["action"]
	print("[SERVER] OK   ", action)
