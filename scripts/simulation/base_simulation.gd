extends Node
## Local, fictional values for gameplay; no live space-weather data is used.
signal conditions_changed(radiation_level: float, crew_dose: float, research: float)
signal scenario_changed(scenario: String)

@export var base: Node
@export var clock: Node
@export var resources: Node
@export var power_per_array_kw: float = 1.0 / 3.0
@export_range(0.0, 1.0) var habitat_radiation_transmission: float = 0.2
@export var background_radiation_level: float = 5.0
@export var flare_radiation_level: float = 70.0
@export var cme_radiation_level: float = 60.0
@export var sep_radiation_level: float = 95.0
@export var dose_per_level_per_hour: float = 0.01
@export var protected_mode: bool = true
@export var research_points_per_hour: float = 1.0

var radiation_level: float = 0.0 # fictional 0–100 risk index
var crew_dose: float = 0.0 # fictional cumulative dose units
var research: float = 0.0
var active_scenario: String = ""
var _remaining_minutes: float = 0.0
var _cme_delay_minutes: float = 0.0
var _elapsed: float = 0.0


func _ready() -> void:
	clock.simulation_step.connect(advance_minutes)
	radiation_level = clampf(background_radiation_level, 0.0, 100.0)
	_refresh_power()


func start_scenario(scenario: String) -> bool:
	if active_scenario != "" or scenario not in ["solar_flare", "cme_warning", "sep_event"]:
		return false
	active_scenario = scenario
	_elapsed = 0.0
	_cme_delay_minutes = 30.0 if scenario == "cme_warning" else 0.0
	_remaining_minutes = 90.0 if scenario == "cme_warning" else 60.0
	_update_radiation()
	scenario_changed.emit(active_scenario)
	return true


func advance_minutes(minutes: float) -> void:
	if minutes <= 0.0:
		return
	_refresh_power()
	_update_radiation()
	var habitat: Node = base.get_node_or_null("CrewHabitat") if is_instance_valid(base) else null
	var transmission: float = habitat_radiation_transmission if protected_mode and is_instance_valid(habitat) and habitat.is_inside_tree() else 1.0
	crew_dose += radiation_level * dose_per_level_per_hour * transmission * minutes / 60.0
	var dome: Node = base.get_node_or_null("ScienceDome") if is_instance_valid(base) else null
	if is_instance_valid(dome) and dome.is_inside_tree() and resources.life_support_powered and resources.crew_surviving:
		research += research_points_per_hour * minutes / 60.0
	if active_scenario != "":
		_elapsed += minutes
		if _elapsed >= _remaining_minutes:
			active_scenario = ""
			scenario_changed.emit(active_scenario)
	_update_radiation()
	conditions_changed.emit(radiation_level, crew_dose, research)


func _refresh_power() -> void:
	var count: int = 0
	if is_instance_valid(base):
		for child: Node in base.get_children():
			if String(child.name).begins_with("SolarArray") and child.is_inside_tree():
				count += 1
	resources.solar_generation_kw = count * power_per_array_kw


func _update_radiation() -> void:
	radiation_level = background_radiation_level
	if active_scenario == "solar_flare":
		radiation_level = flare_radiation_level
	elif active_scenario == "cme_warning" and _elapsed >= _cme_delay_minutes:
		radiation_level = cme_radiation_level
	elif active_scenario == "sep_event":
		radiation_level = sep_radiation_level
	radiation_level = clampf(radiation_level, 0.0, 100.0)
