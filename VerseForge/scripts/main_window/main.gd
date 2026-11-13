class_name Main
extends Control
@onready var lyrics_window = $lyrics
@onready var wsm: WebSocketManager = $WebSocketManager
@onready var start_info: Label = $start_animation/Label
@onready var version_text: Label = $start_animation/version


var success = -1
func _ready():
	global.main_node = self
	version_text.text = "\n\n" + global.current_version
	var versionControl : VersionControl = VersionControl.new()
	add_child(versionControl)
	versionControl.check_for_update()
	call_deferred(&"start_main")


func start_main():
	for i in range(3000):
		if global.version_data == {}:
			await get_tree().process_frame
			continue
		if global.version_data.has("error"):
			print("Erroroororoorrnonononom!")
			break
		if global.version_data.has("new"):
			print("Update available!")
			start_info.text = "New update (%s)" % global.version_data.get("new")
			break
		if global.version_data.has("old"):
			start_info.text = "All good"
			break
	lyrics_window.show()
