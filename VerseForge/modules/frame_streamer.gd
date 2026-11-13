class_name FrameStreamer

var frame_folder : String
var total_frames : int
var current_frame_index : int = 1
var buffer_size : int = 3
var frame_buffer : Array = []

func _init(folder: String, frames: int):
	frame_folder = folder
	total_frames = frames
	current_frame_index = 1
	frame_buffer = []


func get_next_frame() -> Texture:
	while frame_buffer.size() < buffer_size and current_frame_index < total_frames:
		var img = Image.new()
		var path = "%s/%05d.jpg" % [frame_folder, current_frame_index]
		if not FileAccess.file_exists(path):
			print("File doesn't exist: ", path)
			break
		img.load(path)
		var tex = ImageTexture.create_from_image(img)
		frame_buffer.append(tex)
		current_frame_index += 1
	
	# Atgriež pirmo frame no buffer
	if frame_buffer.size() > 0:
		return frame_buffer.pop_front()
	return null  # ja frame beigušies
