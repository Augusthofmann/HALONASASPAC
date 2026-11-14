extends Node
## One simulation minute per real second at 1x. Fixed steps keep results independent of FPS.

signal time_changed(day: int, hour: int, minute: int)
signal speed_changed(multiplier: int)
signal pause_changed(paused: bool)
signal simulation_step(minutes: float)
signal campaign_finished(success: bool)
signal mission_loaded(has_save: bool)

const MINUTES_PER_MIS_DAY: int = 1440
const MAX_MIS_DAYS: int = 30
const REAL_SECONDS_PER_MIS_DAY: float = 300.0

@export var resources: Node
@export var simulation: Node
@export var autosave_seconds: float = 12.0

var speed: int = 1
var paused: bool = false
var elapsed_minutes: int = 0
var mis_day: int = 1
var campaign_complete: bool = false
var _accumulator: float = 0.0
var has_saved_mission: bool = false
var mission_started: bool = false
var _autosave_elapsed: float = 0.0

const SAVE_PATH := "user://mission_beta_02.save"


func _ready() -> void:
	has_saved_mission = _load_mission()
	paused = true
	mission_loaded.emit(has_saved_mission)


func _process(delta: float) -> void:
	if paused or campaign_complete:
		return
	_autosave_elapsed += delta
	if _autosave_elapsed >= autosave_seconds:
		_autosave_elapsed = 0.0
		save_mission()
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
		if campaign_complete:
			save_mission()
			campaign_finished.emit(resources != null and resources.crew_surviving)


func set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	pause_changed.emit(paused)


func set_speed(value: int) -> void:
	if value not in [1, 2, 5, 10]:
		push_warning("Simulation speed must be 1, 2, 5 or 10")
		return
	if speed == value:
		return
	speed = value
	speed_changed.emit(speed)


func start_mission() -> void:
	mission_started = true
	set_paused(false)


func save_mission() -> void:
	if resources == null or not mission_started:
		return
	var save := ConfigFile.new()
	save.set_value("mission", "elapsed_minutes", elapsed_minutes)
	save.set_value("mission", "speed", speed)
	save.set_value("mission", "campaign_complete", campaign_complete)
	save.set_value("resources", "energy_kwh", resources.energy_kwh)
	save.set_value("resources", "oxygen_kg", resources.oxygen_kg)
	save.set_value("resources", "water_kg", resources.water_kg)
	save.set_value("resources", "food_kg", resources.food_kg)
	save.set_value("resources", "equipment_condition", resources.equipment_condition)
	if simulation != null:
		save.set_value("simulation", "solar_efficiency", simulation.solar_efficiency)
		save.set_value("simulation", "research", simulation.research)
	save.save(SAVE_PATH)


func new_mission() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().reload_current_scene()


func _load_mission() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var save := ConfigFile.new()
	if save.load(SAVE_PATH) != OK:
		return false
	elapsed_minutes = maxi(0, int(save.get_value("mission", "elapsed_minutes", 0)))
	mis_day = mini(MAX_MIS_DAYS, 1 + floori(float(elapsed_minutes) / MINUTES_PER_MIS_DAY))
	speed = int(save.get_value("mission", "speed", 1))
	campaign_complete = bool(save.get_value("mission", "campaign_complete", false))
	if resources != null:
		resources.energy_kwh = float(save.get_value("resources", "energy_kwh", resources.energy_kwh))
		resources.oxygen_kg = float(save.get_value("resources", "oxygen_kg", resources.oxygen_kg))
		resources.water_kg = float(save.get_value("resources", "water_kg", resources.water_kg))
		resources.food_kg = float(save.get_value("resources", "food_kg", resources.food_kg))
		resources.equipment_condition = float(save.get_value("resources", "equipment_condition", resources.equipment_condition))
	if simulation != null:
		simulation.solar_efficiency = float(save.get_value("simulation", "solar_efficiency", simulation.solar_efficiency))
		simulation.research = float(save.get_value("simulation", "research", simulation.research))
	return true
