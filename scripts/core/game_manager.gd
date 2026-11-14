extends Node
## One simulation minute per real second at 1x. Fixed steps keep results independent of FPS.

signal time_changed(day: int, hour: int, minute: int)
signal speed_changed(multiplier: int)
signal pause_changed(paused: bool)
signal simulation_step(minutes: float)

const MINUTES_PER_MIS_DAY: int = 1440
const MAX_MIS_DAYS: int = 30
const REAL_SECONDS_PER_MIS_DAY: float = 300.0

@export var resources: Node

var speed: int = 1
var paused: bool = false
var elapsed_minutes: int = 0
var mis_day: int = 1
var campaign_complete: bool = false
var _accumulator: float = 0.0


func _process(delta: float) -> void:
	if paused or campaign_complete:
		return
	_accumulator += delta * float(speed) * MINUTES_PER_MIS_DAY / REAL_SECONDS_PER_MIS_DAY
	while _accumulator >= 1.0 and not campaign_complete:
		_accumulator -= 1.0
		elapsed_minutes += 1
		simulation_step.emit(1.0)
		if resources != null:
			resources.advance_minutes(1.0)
		campaign_complete = elapsed_minutes >= MAX_MIS_DAYS * MINUTES_PER_MIS_DAY
		mis_day = mini(MAX_MIS_DAYS, 1 + floori(float(elapsed_minutes) / MINUTES_PER_MIS_DAY))
		time_changed.emit(mis_day, floori(float(elapsed_minutes % MINUTES_PER_MIS_DAY) / 60.0), elapsed_minutes % 60)


func set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	pause_changed.emit(paused)


func set_speed(value: int) -> void:
	if value not in [1, 2, 5]:
		push_warning("Simulation speed must be 1, 2 or 5")
		return
	if speed == value:
		return
	speed = value
	speed_changed.emit(speed)
