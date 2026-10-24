extends Control

# You can hardcode your key here for local tests or paste it into the UI LineEdit
@export var api_key: String = ""
@export var model_name: String = "gemini-3.8-flash"

@onready var api_key_input: LineEdit = $MarginContainer/VBoxContainer/API_key_INPUT
@onready var prompt_input: TextEdit = $MarginContainer/VBoxContainer/Prompt_INPUT
@onready var send_button: Button = $MarginContainer/VBoxContainer/SendButton
@onready var response_output: TextEdit = $MarginContainer/VBoxContainer/Response_OUTPUT
@onready var http_request: HTTPRequest = $MarginContainer/VBoxContainer/HTTPRequest

func _ready() -> void:
	send_button.pressed.connect(_on_send_pressed)
	http_request.request_completed.connect(_on_request_completed)
	
	if api_key != "":
		api_key_input.text = api_key
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
