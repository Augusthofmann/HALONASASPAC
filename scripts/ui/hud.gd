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
var crew_readout: Label


func _ready() -> void:
	_apply_readability()
	clock.time_changed.connect(_on_time_changed)
	clock.pause_changed.connect(_on_pause_changed)
	clock.speed_changed.connect(_on_speed_changed)
	clock.campaign_finished.connect(_on_campaign_finished)
	resources.resources_changed.connect(_on_resources_changed)
	resources.life_support_changed.connect(_on_support_changed)
	resources.crew_survival_changed.connect(_on_crew_changed)
	simulation.conditions_changed.connect(_on_conditions_changed)
	simulation.scenario_changed.connect(_on_scenario_changed)
	simulation.solar_cleaned.connect(_on_solar_cleaned)
	simulation.crew_updated.connect(_on_crew_updated)
	simulation.incident_changed.connect(_on_incident_changed)
	var crew: Node = get_node_or_null("../../LunarBase/Astronaut/CrewTaskController")
	if crew != null:
		crew.state_changed.connect(_on_crew_state_changed)
		crew.task_finished.connect(_on_crew_task_finished)
	_create_controls()
	_update_time()
	_update_resources()
	_update_status()
	_update_banners()


func _apply_readability() -> void:
	$ResourcesPanel.offset_bottom = 265.0
	readout.offset_bottom = 245.0
	readout.add_theme_font_size_override("font_size", 20)
	$ResourcesPanel/Header.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_font_size_override("font_size", 18)
	heading.add_theme_font_size_override("font_size", 19)
	status.add_theme_font_size_override("font_size", 19)
	time_readout.add_theme_font_size_override("font_size", 21)
	for banner: Control in [notification, danger]:
		if banner != null:
			banner.get_node("Label").add_theme_font_size_override("font_size", 19)


func _create_controls() -> void:
	var controls := HBoxContainer.new()
	controls.name = "SimulationControls"
	controls.set_anchors_preset(Control.PRESET_CENTER_TOP)
	controls.position = Vector2(-320.0, 105.0)
	controls.add_theme_constant_override("separation", 8)
	add_child(controls)
	pause_button = Button.new()
	pause_button.add_theme_font_size_override("font_size", 21)
	pause_button.text = "PAUSE"
	pause_button.pressed.connect(func() -> void: clock.set_paused(not clock.paused))
	controls.add_child(pause_button)
	for multiplier: int in [1, 2, 5, 10]:
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 21)
		button.text = "%dx" % multiplier
		button.pressed.connect(func() -> void: clock.set_speed(multiplier))
		controls.add_child(button)
	solar_button = Button.new()
	solar_button.add_theme_font_size_override("font_size", 21)
	solar_button.text = "SOLAR: ON"
	solar_button.pressed.connect(_toggle_solar)
	controls.add_child(solar_button)
	var demo_button := Button.new()
	demo_button.add_theme_font_size_override("font_size", 21)
	demo_button.text = "DEMO"
	demo_button.tooltip_text = "Start a fictional guided demo (about 3 minutes)."
	demo_button.pressed.connect(_start_demo)
	controls.add_child(demo_button)
	var tasks := HBoxContainer.new()
	tasks.name = "CrewTasks"
	tasks.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tasks.position = Vector2(-380.0, 155.0)
	add_child(tasks)
	for entry: Array in [["CLEAN", "clean_solar"], ["WATER +1", "collect_water"], ["FOOD +1", "collect_food"], ["REPAIR", "repair"], ["ROVER", "rover"]]:
		var task_button := Button.new()
		task_button.add_theme_font_size_override("font_size", 20)
		task_button.text = entry[0]
		task_button.pressed.connect(_request_task.bind(entry[1]))
		tasks.add_child(task_button)
	crew_readout = Label.new()
	crew_readout.name = "CrewReadout"
	crew_readout.set_anchors_preset(Control.PRESET_CENTER_TOP)
	crew_readout.position = Vector2(-190.0, 205.0)
	crew_readout.add_theme_font_size_override("font_size", 20)
	add_child(crew_readout)
	_on_crew_updated()


func _request_task(task: String) -> void:
	var accepted: bool = simulation.start_rover() if task == "rover" else simulation.assign_task(task)
	if not accepted:
		status.text = "No available crew or rover.\nWait for a task to finish."
	else:
		var tips: Dictionary = {"clean_solar": "Dust blocks sunlight. Clean panels make more power.", "collect_water": "Water is precious on the Moon. Reuse saves supplies.", "collect_food": "Food keeps the crew healthy. Plan ahead!", "repair": "Fix leaks and equipment to save resources.", "rover": "Rovers explore while the crew shares limited supplies."}
		status.text = str(tips.get(task, ""))


func _start_demo() -> void:
	if simulation.has_node("DemoScenario"):
		return
	var demo: Node = load("res://scripts/simulation/demo_scenario.gd").new()
	demo.name = "DemoScenario"
	demo.clock = clock
	demo.simulation = simulation
	demo.message.connect(_on_demo_message)
	simulation.add_child(demo)


func _on_demo_message(message: String) -> void:
	heading.text = "DEMO · FICTIONAL"
	status.text = message


func _on_campaign_finished(success: bool) -> void:
	var layer := PanelContainer.new()
	layer.name = "CampaignResult"
	layer.set_anchors_preset(Control.PRESET_CENTER)
	layer.position = Vector2(-280.0, -110.0)
	layer.custom_minimum_size = Vector2(560.0, 220.0)
	add_child(layer)
	var column := VBoxContainer.new()
	column.name = "ResultContent"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(column)
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.text = "MISSION COMPLETE" if success else "MISSION ENDED"
	column.add_child(title)
	var result := Label.new()
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.text = "The crew completed 30 days!" if success else "The crew ran out of essential supplies."
	column.add_child(result)
	var restart := Button.new()
	restart.name = "Restart"
	restart.text = "RESTART MISSION"
	restart.pressed.connect(func() -> void: get_tree().reload_current_scene())
	column.add_child(restart)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_request_task("clean_solar")


func _on_crew_updated() -> void:
	if crew_readout == null:
		return
	var available: int = 0
	for member: Node in simulation.crew:
		if member.state == "idle":
			available += 1
	crew_readout.text = "CREW %d / %d AVAILABLE" % [available, simulation.crew.size()]
	if simulation.rover_crew != null:
		if simulation.rover_crew.state != "expedition":
			crew_readout.text += "   ROVER: BOARDING"
		else:
			var seconds: int = ceili(simulation.rover_remaining / float(clock.speed))
			crew_readout.text += "   ROVER: %02d:%02d REAL" % [floori(float(seconds) / 60.0), seconds % 60]


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
	_on_crew_updated()


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
	_update_status()


func _on_incident_changed(_incident: String) -> void:
	_update_banners()
	_update_status()
	_update_resources()


func _on_crew_state_changed(_state: String) -> void:
	_update_status()


func _on_crew_task_finished(_task: String) -> void:
	_update_status()


func _on_solar_cleaned(_efficiency: float) -> void:
	_update_resources()


func _update_time() -> void:
	var minutes: int = clock.elapsed_minutes
	var hour: int = floori(float(minutes % clock.MINUTES_PER_MIS_DAY) / 60.0)
	time_readout.text = "MISSION DAY %02d / 30\n%02d:%02d  •  %s" % [clock.mis_day, hour, minutes % 60, "COMPLETE" if clock.campaign_complete else ("PAUSED" if clock.paused else "%dx" % clock.speed)]
	subtitle.text = "MISSION DAY %02d / 30  ·  SOUTH POLAR OUTPOST" % clock.mis_day


func _update_resources() -> void:
	readout.text = "POWER %.2f kWh  SUN %.0f%%\nOXYGEN %.2f kg\nWATER %.2f kg\nFOOD %.2f kg\nRADIATION %.0f / 100\nRESEARCH %.0f" % [resources.energy_kwh, simulation.solar_efficiency * 100.0, resources.oxygen_kg, resources.water_kg, resources.food_kg, simulation.radiation_level, simulation.research]


func _update_banners() -> void:
	var warning: bool = simulation.active_scenario == "cme_warning" and simulation.radiation_level < 50.0
	var hazardous: bool = simulation.radiation_level >= 50.0
	if notification != null:
		notification.visible = warning or simulation.active_incident != ""
		if warning:
			notification.get_node("Label").text = "CME WARNING\nRadiation may rise. Stay ready."
		elif simulation.active_incident != "":
			var names: Dictionary = {"power_fault": "POWER FAULT", "water_leak": "WATER LEAK", "oxygen_leak": "OXYGEN LEAK"}
			notification.get_node("Label").text = "%s\nSend crew to REPAIR." % names.get(simulation.active_incident, "FAULT")
	if danger != null:
		danger.visible = hazardous
		if hazardous:
			danger.get_node("Label").text = "DANGER: RADIATION\nOutside work is unsafe. Crew shelters."


func _update_status() -> void:
	heading.text = "BASE STATUS"
	if not resources.crew_surviving:
		status.text = "CREW IN DANGER\nCheck power and supplies."
	elif not resources.life_support_powered:
		status.text = "OXYGEN SYSTEM OFF\nIt needs power and water to work."
	elif not resources.solar_enabled or resources.solar_generation_kw <= 0.0:
		status.text = "SOLAR POWER OFF\nBattery is supplying the base."
	else:
		var crew: Node = get_node_or_null("../../LunarBase/Astronaut/CrewTaskController")
		if crew != null and crew.state == "sheltering":
			status.text = "Crew sheltered\nRadiation exposure reduced."
		elif crew != null and crew.current_task == "clean_solar":
			status.text = "Solar cleaning in progress\nCrew is working outside."
		else:
			status.text = "Solar panels clean · Output 100%" if simulation.solar_efficiency >= simulation.solar_cleaned_efficiency else "Crew safe · Life support online\nPress C to clean solar panels."
