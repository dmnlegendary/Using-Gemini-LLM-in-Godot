extends Control

# You can hardcode your key here for local tests or paste it into the UI LineEdit
@export var api_key: String = ""
@export var model_name: String = ""

@onready var api_key_input: LineEdit = $MarginContainer/VBoxContainer/API_key_INPUT
@onready var prompt_input: TextEdit = $MarginContainer/VBoxContainer/Prompt_INPUT
@onready var send_button: Button = $MarginContainer/VBoxContainer/SendButton
@onready var response_output: TextEdit = $MarginContainer/VBoxContainer/Response_OUTPUT
@onready var http_request: HTTPRequest = $MarginContainer/VBoxContainer/HTTPRequest
@onready var models_available_with_key: Array = []


func _ready() -> void:
	send_button.pressed.connect(_on_send_pressed)
	http_request.request_completed.connect(_on_request_completed)
	
	if api_key != "":
		api_key_input.text = api_key
	if model_name == "":
		model_name = "gemini-3.8-flash"

'''
# These two replacing functions work as testers for models available
# Also let us know if the API we're using actually works
func _on_send_pressed() -> void:
	var active_key: String = api_key_input.text.strip_edges()
	if active_key.is_empty():
		response_output.text = "Error: Key required."
		return

	send_button.disabled = true
	response_output.text = "Fetching supported models..."

	# Query ListModels
	var url: String = "https://generativelanguage.googleapis.com/v1/models"
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"x-goog-api-key: " + active_key
	]
	
	http_request.request(url, headers, HTTPClient.METHOD_GET)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	send_button.disabled = false
	var body_string: String = body.get_string_from_utf8()

	var json: JSON = JSON.new()
	if json.parse(body_string) == OK and json.data.has("models"):
		var model_list: Array = []
		for m in json.data["models"]:
			var methods: Array = m.get("supportedGenerationMethods", [])
			if "generateContent" in methods:
				# Strips "models/" so you get the clean name
				model_list.append(m.get("name", "").replace("models/", ""))
		
		response_output.text = "Available generateContent models:\n" + "\n".join(model_list)
	else:
		response_output.text = "Error / Raw Response:\n" + body_string
'''


func _on_send_pressed() -> void:
	var active_key: String = api_key_input.text.strip_edges()
	var prompt_text: String = prompt_input.text.strip_edges()
	print("The current model chosen is: ", model_name)
	
	if model_name not in models_available_with_key:
		response_output.text = "Error: The selected model is not available therefore API connection fails to access. Leave it blank or press the \"models button\" to know what models are available for your API key."
		if models_available_with_key.size() > 0: 
			print(models_available_with_key[0])
		model_name = "gemini-3.8-flash"
	print("The model selected is: ", model_name)
	
	if active_key.is_empty():
		response_output.text = "Error: Please enter a valid Gemini API Key."
		return
		
	if prompt_text.is_empty():
		response_output.text = "Error: Prompt cannot be empty."
		return

	# Disable input while waiting
	send_button.disabled = true
	response_output.text = "Thinking..."

	var url: String = "https://generativelanguage.googleapis.com/v1/models/%s:generateContent?key=%s" % [model_name, active_key]
	var headers: PackedStringArray = ["Content-Type: application/json"]
	
	var payload: Dictionary = {
		"contents": [
			{
				"parts": [
					{"text": prompt_text}
				]
			}
		]
	}
	
	var json_body: String = JSON.stringify(payload)
	var error: Error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	
	if error != OK:
		response_output.text = "HTTPRequest failed to dispatch: Error code %d" % error
		send_button.disabled = false

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	send_button.disabled = false
	var body_string: String = body.get_string_from_utf8()
	
	if response_code != 200:
		response_output.text = "HTTP Error %d:\n%s" % [response_code, body_string]
		return

	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(body_string)
	if parse_err != OK:
		response_output.text = "Failed to parse API response as JSON."
		return

	var data: Dictionary = json.data
	if data.has("candidates") and data["candidates"].size() > 0:
		var candidate: Dictionary = data["candidates"][0]
		if candidate.has("content") and candidate["content"].has("parts"):
			var generated_text: String = candidate["content"]["parts"][0].get("text", "")
			response_output.text = generated_text
			return

	response_output.text = "No text content found in response:\n" + body_string


func _on_watch_models_available_pressed() -> void:
	var active_key: String = api_key_input.text.strip_edges()
	active_key = active_key.trim_prefix('"').trim_suffix('"').trim_prefix("'").trim_suffix("'")
	
	if active_key.is_empty():
		response_output.text = "Error: Key required to check available models."
		return

	response_output.text = "Fetching supported models..."
	send_button.disabled = true

	# Create a temporary HTTPRequest node so it doesn't conflict with the chat request handler
	var temp_http: HTTPRequest = HTTPRequest.new()
	add_child(temp_http)

	# Use v1 endpoint where all Gemini models are exposed
	var url: String = "https://generativelanguage.googleapis.com/v1/models"
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"x-goog-api-key: " + active_key
	]
	
	var err: Error = temp_http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		response_output.text = "Failed to dispatch request: Error code %d" % err
		send_button.disabled = false
		temp_http.queue_free()
		return

	# 'await' pauses execution here until the network response arrives
	var response: Array = await temp_http.request_completed
	temp_http.queue_free() # Clean up node from scene tree
	send_button.disabled = false

	# Unpack the response: [result, response_code, headers, body]
	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]
	var body_string: String = response_body.get_string_from_utf8()

	if response_code != 200:
		response_output.text = "HTTP Error %d:\n%s" % [response_code, body_string]
		return

	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(body_string)
	if parse_err != OK:
		response_output.text = "Failed to parse API response as JSON."
		return

	if json.data is Dictionary and json.data.has("models"):
		var model_list: Array = []
		for m in json.data["models"]:
			var methods: Array = m.get("supportedGenerationMethods", [])
			# Only display models that can generate text/content
			if "generateContent" in methods:
				model_list.append(m.get("name", "").replace("models/", ""))
		
		# We save the models the user has access to
		print(model_list)
		models_available_with_key = model_list
		
		response_output.text = "Available Models for your Key (%d found):\n\n" % model_list.size()
		response_output.text += "\n".join(model_list)
	else:
		response_output.text = "Unexpected response structure:\n" + body_string


func _on_model_version_text_changed(new_text: String) -> void:
	model_name = new_text
