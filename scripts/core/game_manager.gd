extends Node
## One simulation minute per real second at 1x. Fixed steps keep results independent of FPS.

signal time_changed(day: int, hour: int, minute: int)
signal speed_changed(multiplier: int)
signal pause_changed(paused: bool)

@export_range(0.1, 60.0, 0.1) var seconds_per_game_minute: float = 1.0
@export var resources: Node

var speed: int = 1
var paused: bool = false
var elapsed_minutes: int = 0
var _accumulator: float = 0.0


func _process(delta: float) -> void:
	if paused:
		return
	_accumulator += delta * float(speed)
	while _accumulator >= seconds_per_game_minute:
		_accumulator -= seconds_per_game_minute
		elapsed_minutes += 1
		if resources != null:
			resources.advance_minutes(1.0)
		time_changed.emit(1 + floori(float(elapsed_minutes) / 1440.0), floori(float(elapsed_minutes) / 60.0) % 24, elapsed_minutes % 60)


func set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	pause_changed.emit(paused)


func set_speed(value: int) -> void:
	if value != 1 and value != 2:
		push_warning("Simulation speed must be 1 or 2")
		return
	if speed == value:
		return
	speed = value
	speed_changed.emit(speed)
