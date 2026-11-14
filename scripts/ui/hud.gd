extends Control

@onready var clock: Node = get_node("../../GameManager")
@onready var resources: Node = get_node("../../ResourceManager")
@onready var simulation: Node = get_node("../../BaseSimulation")
@onready var readout: Label = $ResourcesPanel/Readout
@onready var time_readout: Label = $TimeReadout
@onready var subtitle: Label = $MissionPanel/Subtitle
@onready var heading: Label = $ObjectivePanel/Heading
@onready var status: Label = $ObjectivePanel/Text
@onready var notification: Control = get_node_or_null("NotificationBanner")
@onready var danger: Control = get_node_or_null("DangerBanner")

var pause_button: Button
var solar_button: Button


func _ready() -> void:
	clock.time_changed.connect(_on_time_changed)
	clock.pause_changed.connect(_on_pause_changed)
	clock.speed_changed.connect(_on_speed_changed)
	resources.resources_changed.connect(_on_resources_changed)
	resources.life_support_changed.connect(_on_support_changed)
	resources.crew_survival_changed.connect(_on_crew_changed)
	simulation.conditions_changed.connect(_on_conditions_changed)
	simulation.scenario_changed.connect(_on_scenario_changed)
	_create_controls()
	_update_time()
	_update_resources()
	_update_status()
	_update_banners()


func _create_controls() -> void:
	var controls := HBoxContainer.new()
	controls.name = "SimulationControls"
	controls.set_anchors_preset(Control.PRESET_CENTER_TOP)
	controls.position = Vector2(-205.0, 65.0)
	controls.add_theme_constant_override("separation", 8)
	add_child(controls)
	pause_button = Button.new()
	pause_button.text = "PAUSE"
	pause_button.pressed.connect(func() -> void: clock.set_paused(not clock.paused))
	controls.add_child(pause_button)
	for multiplier: int in [1, 2]:
		var button := Button.new()
		button.text = "%dx" % multiplier
		button.pressed.connect(func() -> void: clock.set_speed(multiplier))
		controls.add_child(button)
	solar_button = Button.new()
	solar_button.text = "SOLAR: ON"
	solar_button.pressed.connect(_toggle_solar)
	controls.add_child(solar_button)


func _toggle_solar() -> void:
	resources.solar_enabled = not resources.solar_enabled
	solar_button.text = "SOLAR: ON" if resources.solar_enabled else "SOLAR: OFF"
	_update_status()


func _on_time_changed(_day: int, _hour: int, _minute: int) -> void:
	_update_time()


func _on_pause_changed(_paused: bool) -> void:
	pause_button.text = "RESUME" if clock.paused else "PAUSE"
	_update_time()


func _on_speed_changed(_speed: int) -> void:
	_update_time()


func _on_resources_changed(_energy: float, _oxygen: float, _water: float, _food: float) -> void:
	_update_resources()


func _on_support_changed(_powered: bool) -> void:
	_update_status()


func _on_crew_changed(_surviving: bool) -> void:
	_update_status()
	_update_banners()


func _on_conditions_changed(_radiation: float, _dose: float, _research: float) -> void:
	_update_resources()
	_update_banners()


func _on_scenario_changed(_scenario: String) -> void:
	_update_banners()


func _update_time() -> void:
	var minutes: int = clock.elapsed_minutes
	var hour: int = floori(float(minutes % clock.MINUTES_PER_MIS_DAY) / 60.0)
	time_readout.text = "MISSION DAY %02d / 30\n%02d:%02d  •  %s" % [clock.mis_day, hour, minutes % 60, "COMPLETE" if clock.campaign_complete else ("PAUSED" if clock.paused else "%dx" % clock.speed)]
	subtitle.text = "MISSION DAY %02d / 30  ·  SOUTH POLAR OUTPOST" % clock.mis_day


func _update_resources() -> void:
	readout.text = "ENERGY    %.2f / %.2f kWh\nOXYGEN   %.2f / %.2f kg\nWATER      %.2f kg\nFOOD         %.2f kg\nRADIATION  %.0f / 100\nRESEARCH  %.1f" % [resources.energy_kwh, resources.energy_capacity_kwh, resources.oxygen_kg, resources.oxygen_capacity_kg, resources.water_kg, resources.food_kg, simulation.radiation_level, simulation.research]


func _update_banners() -> void:
	var warning: bool = simulation.active_scenario == "cme_warning" and simulation.radiation_level < 50.0
	var hazardous: bool = simulation.radiation_level >= 50.0 or not resources.crew_surviving
	if notification != null:
		notification.visible = warning
		if warning:
			notification.get_node("Label").text = "CME WARNING\nDangerous radiation approaching."
	if danger != null:
		danger.visible = hazardous
		if hazardous:
			danger.get_node("Label").text = "DANGER\n" + ("Radiation alert — protect crew." if simulation.radiation_level >= 50.0 else "Crew needs power and supplies.")


func _update_status() -> void:
	heading.text = "BASE STATUS"
	if not resources.crew_surviving:
		status.text = "CREW IN DANGER\nCheck power and supplies."
	elif not resources.life_support_powered:
		status.text = "LIFE SUPPORT OFFLINE\nRestore power before oxygen runs out."
	elif not resources.solar_enabled or resources.solar_generation_kw <= 0.0:
		status.text = "SOLAR POWER OFF\nBattery is supplying the base."
	else:
		status.text = "Crew safe · Life support online\nKeep the base powered."
