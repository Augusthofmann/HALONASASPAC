extends Node
## One simulation minute per real second at 1x. Fixed steps keep results independent of FPS.

signal time_changed(day: int, hour: int, minute: int)
signal speed_changed(multiplier: int)
signal pause_changed(paused: bool)
signal simulation_step(minutes: float)
signal campaign_finished(success: bool, reason: String)
signal mission_loaded(has_save: bool)
signal score_changed(score: int)
signal language_changed(language: String)

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
var mission_score: int = 0
var ui_language: String = "en"
var finish_reason: String = ""
var _autosave_elapsed: float = 0.0

const SAVE_PATH := "user://mission_beta_02.save"


func _ready() -> void:
	var start_fresh: bool = bool(get_tree().get_meta("start_fresh_mission", false))
	if start_fresh:
		get_tree().remove_meta("start_fresh_mission")
		has_saved_mission = false
		mission_started = true
		paused = false
	else:
		has_saved_mission = _load_mission()
		paused = true
	mission_loaded.emit(has_saved_mission)
	if resources != null:
		resources.crew_survival_changed.connect(_on_crew_survival_changed)


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
			finish_reason = "mission_complete"
			save_mission()
			campaign_finished.emit(resources != null and resources.crew_surviving, finish_reason)


func _on_crew_survival_changed(surviving: bool) -> void:
	if surviving or not mission_started or campaign_complete:
		return
	campaign_complete = true
	paused = true
	finish_reason = "life_support"
	save_mission()
	campaign_finished.emit(false, finish_reason)


func fail_mission(reason: String) -> void:
	if campaign_complete:
		return
	campaign_complete = true
	paused = true
	finish_reason = reason
	save_mission()
	campaign_finished.emit(false, finish_reason)


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


func add_score(points: int) -> void:
	if points <= 0 or campaign_complete:
		return
	mission_score += points
	score_changed.emit(mission_score)


func set_ui_language(language: String) -> void:
	if language not in ["en", "ru"] or ui_language == language:
		return
	ui_language = language
	language_changed.emit(ui_language)
	save_mission()


func save_mission() -> void:
	if resources == null or not mission_started:
		return
	var save := ConfigFile.new()
	save.set_value("mission", "elapsed_minutes", elapsed_minutes)
	save.set_value("mission", "speed", speed)
	save.set_value("mission", "campaign_complete", campaign_complete)
	save.set_value("mission", "score", mission_score)
	save.set_value("mission", "finish_reason", finish_reason)
	save.set_value("settings", "ui_language", ui_language)
	save.set_value("resources", "energy_kwh", resources.energy_kwh)
	save.set_value("resources", "oxygen_kg", resources.oxygen_kg)
	save.set_value("resources", "water_kg", resources.water_kg)
	save.set_value("resources", "food_kg", resources.food_kg)
	save.set_value("resources", "equipment_condition", resources.equipment_condition)
	save.set_value("resources", "crew_health", resources.crew_health)
	if simulation != null:
		save.set_value("simulation", "solar_efficiency", simulation.solar_efficiency)
		save.set_value("simulation", "research", simulation.research)
	save.save(SAVE_PATH)


func new_mission(start_immediately: bool = false) -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if start_immediately:
		get_tree().set_meta("start_fresh_mission", true)
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
	mission_score = maxi(0, int(save.get_value("mission", "score", 0)))
	finish_reason = str(save.get_value("mission", "finish_reason", ""))
	ui_language = str(save.get_value("settings", "ui_language", "en"))
	if resources != null:
		resources.energy_kwh = float(save.get_value("resources", "energy_kwh", resources.energy_kwh))
		resources.oxygen_kg = float(save.get_value("resources", "oxygen_kg", resources.oxygen_kg))
		resources.water_kg = float(save.get_value("resources", "water_kg", resources.water_kg))
		resources.food_kg = float(save.get_value("resources", "food_kg", resources.food_kg))
		resources.equipment_condition = float(save.get_value("resources", "equipment_condition", resources.equipment_condition))
		resources.crew_health = clampf(float(save.get_value("resources", "crew_health", resources.crew_health)), 0.0, 100.0)
		resources.crew_surviving = resources.crew_health > 0.0
	if simulation != null:
		simulation.solar_efficiency = float(save.get_value("simulation", "solar_efficiency", simulation.solar_efficiency))
		simulation.research = float(save.get_value("simulation", "research", simulation.research))
	return true
