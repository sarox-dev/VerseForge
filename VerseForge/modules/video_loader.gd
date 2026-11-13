class_name VideoLoader
extends Node

var theme_path = OS.get_user_data_dir().path_join("temp/theme")

var video_path: String = ""


func update_video_path(path : String):
	video_path = path

func get_videos_from_folder(folder_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(folder_path)
	if dir == null:
		push_error("Cannot open folder: %s" % folder_path)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := folder_path.path_join(file_name)
		if !dir.dir_exists(full_path):
			var ext := file_name.get_extension().to_lower()
			if ext in ["mp4", "ogv", "webm", "mov", "mkv"]:
				result.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result


func get_frame_path(video_name : String) -> String:
	var frame_path : String = theme_path.path_join("video_frames").path_join(video_name)
	return frame_path

func clear_folder(path: String):
	var dir = DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.dir_exists(full_path):
			clear_folder(full_path)        # rekursīvi dzēš apakšmapes
			dir.remove(full_path)    # izdzēš apakšmapi
		else:
			dir.remove(full_path)    # izdzēš failu
		file_name = dir.get_next()
	dir.list_dir_end()




func ensure_dir_exists(path: String, base : String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		dir = DirAccess.open(base)
		if dir != null:
			dir.make_dir_recursive(path)


func frames_already_exist(frame_path: String) -> bool:
	var dir := DirAccess.open(frame_path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".jpg") or file_name.ends_with(".png"):
			dir.list_dir_end()
			return true
		file_name = dir.get_next()
	dir.list_dir_end()
	return false


func extract_frames(start_time: float = 0, end_time: float = 0):
	if video_path == "":
		print("Error: No video path is currently set with update_video_path()")
		return false
	
	var video_name : String = video_path.get_file().get_basename()
	var frame_path = theme_path.path_join("video_frames").path_join(video_name)
	
	ensure_dir_exists(frame_path, OS.get_user_data_dir())
	
	var args : Array = []
	
	if start_time > 0.0:
		args.append("-ss")
		args.append(str(start_time))
	
	if end_time > 0.0:
		args.append("-to")
		args.append(str(end_time))
	
	args.append("-i")
	args.append(video_path)
	args.append("-qscale:v")
	args.append("2")
	args.append(frame_path.path_join("%05d.jpg"))
	
	var ffmpeg : String = global.app_external.path_join("ffmpeg/ffmpeg.exe")
	var pid: int = OS.create_process(ffmpeg, args)

	if pid == -1:
		print("Failed to start ffmpeg process.")
		return false

	while OS.is_process_running(pid):
		await get_tree().process_frame

	var exit_code: int = OS.get_process_exit_code(pid)

	if exit_code != 0:
		print("FFmpeg failed with exit code: " + str(exit_code))
		return false
	
	print("Video ", video_name, " extracted.")
	return true

func get_video_info() -> Dictionary:
	var fps: float = 0.0
	var frames: int = 0

	var result = []
	var ffprobe : String = global.app_external.path_join("ffmpeg/ffprobe.exe")
	var exit_code = OS.execute(ffprobe, [
		"-v", "error",
		"-select_streams", "v:0",
		"-show_entries", "stream=avg_frame_rate,nb_frames",
		"-of", "csv=p=0",
		video_path
	], result, true)

	if exit_code == 0 and result.size() > 0:
		var output = result[0].strip_edges()
		var parts = output.split(",")
		if parts.size() >= 1:
			var rate = parts[0].split("/")
			if rate.size() == 2 and float(rate[1]) != 0:
				fps = float(rate[0]) / float(rate[1])
		if parts.size() >= 2:
			frames = int(parts[1])

	return {"fps": fps, "frames": frames}
