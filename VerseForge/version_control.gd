class_name VersionControl
extends Node

const REPO_API_URL = "https://api.github.com/repos/heatssoftware/VerseForgeMVP/releases/latest"
const HEADERS = [
	"User-Agent: VerseForgeClient",
	"Accept: application/vnd.github+json"
]
func check_for_update():
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	http.request(REPO_API_URL, HEADERS, HTTPClient.METHOD_GET)

func _on_request_completed(result, response_code, headers, body):
	if response_code != 200:
		print("❌ Failed to fetch release info " + str(response_code))
		global.version_data = { "error": 1 }
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) == TYPE_DICTIONARY and data.has("tag_name"):
		var remote_version : String = data["tag_name"]
		var local_version : String = global.current_version
		
		if remote_version != local_version:
			print("⬆️ Update available!")
			global.version_data = {
				"new": remote_version,
				"desc": "New version"
			}
		else:
			print("✅ Already up to date.")
			global.version_data = { "old": true }
		
		print("Local version: ", local_version)
		print("Remote version: ", remote_version)
