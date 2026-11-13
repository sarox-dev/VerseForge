extends AwaitableHTTPRequest
var headers = ["Content-Type: application/json"]


var requested_data : Dictionary

func get_data(status_data : Dictionary):
	var resp_get := await async_request(global.server_url + "/commands")
	if not (resp_get.success() and resp_get.status_ok()):
		print("Kļūda saņemot komandu: ", resp_get.status)
	else:
		var data_body = resp_get.body_as_json()
		if data_body == requested_data:
			return requested_data
		requested_data = data_body
	var resp := await async_request(global.server_url + "/commands",
	headers, HTTPClient.METHOD_POST, JSON.stringify(status_data))

	if not (resp.success() and resp.status_ok()):
		print("Kļūda nosūtot request_menu komandu: ", resp.status)
	return requested_data
