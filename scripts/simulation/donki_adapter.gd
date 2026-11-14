extends Node
## Optional historical context only; records never automatically change gameplay.
signal events_ready(events: Dictionary, source: String)

const START_DATE := "2026-06-01"
const END_DATE := "2026-06-30"
const CACHE_PATH := "user://donki_2026_06.json"
const TYPES := ["FLR", "CME", "SEP"]
const STUB := {"FLR": [], "CME": [], "SEP": []}

var events: Dictionary = STUB.duplicate(true)
var source: String = "stub"
var _busy: bool = false


func _ready() -> void:
	load_offline()


func load_offline() -> void:
	events = STUB.duplicate(true)
	source = "stub"
	if FileAccess.file_exists(CACHE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_PATH))
		if parsed is Dictionary and _valid_events(parsed):
			events = parsed
			source = "cache"
	events_ready.emit(events, source)


func refresh() -> void:
	if _busy:
		return
	var api_key: String = OS.get_environment("NASA_API_KEY").strip_edges()
	if api_key.is_empty():
		load_offline()
		return
	_busy = true
	var downloaded: Dictionary = {}
	for kind: String in TYPES:
		var request := HTTPRequest.new()
		request.timeout = 10.0
		add_child(request)
		var url: String = "https://api.nasa.gov/DONKI/%s?startDate=%s&endDate=%s&api_key=%s" % [kind, START_DATE, END_DATE, api_key.uri_encode()]
		if request.request(url) != OK:
			request.queue_free()
			_busy = false
			load_offline()
			return
		var response: Array = await request.request_completed
		request.queue_free()
		var decoded: Variant = JSON.parse_string(response[3].get_string_from_utf8())
		if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200 or not decoded is Array:
			_busy = false
			load_offline()
			return
		downloaded[kind] = decoded
	events = downloaded
	source = "network"
	var file: FileAccess = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(events))
	_busy = false
	events_ready.emit(events, source)


func _valid_events(candidate: Dictionary) -> bool:
	for kind: String in TYPES:
		if not candidate.get(kind) is Array:
			return false
	return true
