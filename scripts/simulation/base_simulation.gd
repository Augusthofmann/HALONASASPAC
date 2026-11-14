extends Node
## Local, fictional values for gameplay; no live space-weather data is used.
signal conditions_changed(radiation_level: float, crew_dose: float, research: float)
signal scenario_changed(scenario: String)
signal solar_cleaned(efficiency: float)
signal crew_updated
signal incident_changed(incident: String)
signal radiation_hazard_changed(active: bool)

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
@export var protected_mode: bool = false
@export var research_points_per_hour: float = 1.0
@export_range(0.0, 1.0) var solar_efficiency: float = 0.6
@export var solar_cleaned_efficiency: float = 1.0
@export_range(0.35, 0.8, 0.01) var crew_visual_scale: float = 0.55

var radiation_level: float = 0.0 # fictional 0–100 risk index
var crew_dose: float = 0.0 # fictional cumulative dose units
var research: float = 0.0
var active_scenario: String = ""
var _remaining_minutes: float = 0.0
var _cme_delay_minutes: float = 0.0
var _elapsed: float = 0.0
var _solar_overlays: Dictionary = {}
var crew: Array[Node] = []
var rover_remaining: float = 0.0
var rover_crew: Node = null
var _rover_overlays: Dictionary = {}
var active_incident: String = ""
var _incident_timer_minutes: float = 0.0
var _next_incident_minutes: float = 720.0
var _rng := RandomNumberGenerator.new()
var _radiation_hazard: bool = false


func _ready() -> void:
	_rng.randomize()
	clock.simulation_step.connect(advance_minutes)
	radiation_level = clampf(background_radiation_level, 0.0, 100.0)
	_refresh_power()
	_set_solar_dust(solar_efficiency < solar_cleaned_efficiency)
	_create_terrain_collider()
	var astronaut: Node = base.get_node_or_null("Astronaut") if is_instance_valid(base) else null
	if astronaut != null:
		for index in range(4):
			var actor: Node = astronaut if index == 0 else load("res://scenes/characters/astronaut.tscn").instantiate()
			if index > 0:
				actor.name = "Astronaut%d" % (index + 1)
				base.add_child(actor)
			actor.scale = Vector3.ONE * crew_visual_scale
			var controller: Node = load("res://scripts/characters/crew_task_controller.gd").new()
			controller.name = "CrewTaskController"
			controller.base = base
			controller.clock = clock
			controller.simulation = self
			controller.crew_index = index
			actor.add_child(controller)
			crew.append(controller)
			controller.state_changed.connect(func(_state: String) -> void: crew_updated.emit())
			controller.task_finished.connect(func(_task: String) -> void: crew_updated.emit())


func _create_terrain_collider() -> void:
	var terrain: MeshInstance3D = get_node_or_null("../LunarWorld/LeibnitzBetaTerrain")
	if terrain == null or terrain.mesh == null or terrain.has_node("CrewGround"):
		return
	var body := StaticBody3D.new()
	body.name = "CrewGround"
	body.collision_layer = 1 << 19
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = terrain.mesh.create_trimesh_shape()
	body.add_child(shape)
	terrain.add_child(body)


func _process(delta: float) -> void:
	if rover_crew == null or rover_crew.state != "expedition" or clock.paused or clock.campaign_complete:
		return
	rover_remaining = maxf(0.0, rover_remaining - delta * clock.speed)
	if rover_remaining <= 0.0:
		research += 200.0
		rover_crew.finish_expedition()
		rover_crew = null
		_set_rover_gray(false)
		conditions_changed.emit(radiation_level, crew_dose, research)
	crew_updated.emit()


func assign_task(task: String) -> bool:
	for member: Node in crew:
		if member.start_task(task):
			crew_updated.emit()
			return true
	return false


func start_rover() -> bool:
	if rover_crew != null or radiation_level >= 50.0 or clock.paused or clock.campaign_complete or base.get_node_or_null("Rover") == null:
		return false
	for member: Node in crew:
		if member.start_expedition():
			rover_crew = member
			rover_remaining = 300.0
			_set_rover_gray(true)
			crew_updated.emit()
			return true
	return false


func cancel_rover_departure(member: Node) -> void:
	if rover_crew == member and member.state != "expedition":
		rover_crew = null
		rover_remaining = 0.0
		_set_rover_gray(false)
		crew_updated.emit()


func _set_rover_gray(enabled: bool) -> void:
	var rover: Node = base.get_node_or_null("Rover")
	if rover != null:
		_rover_meshes(rover, enabled)


func _rover_meshes(node: Node, enabled: bool) -> void:
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node
		if enabled and not _rover_overlays.has(mesh):
			_rover_overlays[mesh] = mesh.material_override
			var gray := StandardMaterial3D.new()
			gray.albedo_color = Color(0.42, 0.42, 0.42)
			mesh.material_override = gray
		elif not enabled and _rover_overlays.has(mesh):
			mesh.material_override = _rover_overlays[mesh]
			_rover_overlays.erase(mesh)
	for child: Node in node.get_children():
		_rover_meshes(child, enabled)


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
	if active_incident == "":
		_incident_timer_minutes += minutes
		if _incident_timer_minutes >= _next_incident_minutes:
			var options: Array[String] = ["power_fault", "water_leak", "oxygen_leak"]
			start_incident(options[_rng.randi_range(0, options.size() - 1)])
	_refresh_power()
	_update_radiation()
	var habitat: Node = base.get_node_or_null("CrewHabitat") if is_instance_valid(base) else null
	var protected_count: int = 0
	for member: Node in crew:
		if member.state == "sheltering" or (member.state == "idle" and member._inside):
			protected_count += 1
	protected_mode = crew.size() > 0 and protected_count == crew.size()
	var protected_fraction: float = float(protected_count) / float(crew.size()) if crew.size() > 0 else (1.0 if protected_mode else 0.0)
	var transmission: float = 1.0 - protected_fraction * (1.0 - habitat_radiation_transmission) if is_instance_valid(habitat) and habitat.is_inside_tree() else 1.0
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


func start_incident(incident: String) -> bool:
	if active_incident != "" or incident not in ["power_fault", "water_leak", "oxygen_leak"]:
		return false
	active_incident = incident
	match incident:
		"power_fault": resources.equipment_condition = minf(resources.equipment_condition, 0.45)
		"water_leak": resources.water_leak_kg_per_hour = 0.2
		"oxygen_leak": resources.oxygen_leak_kg_per_hour = 0.2
	incident_changed.emit(active_incident)
	return true


func repair_equipment() -> void:
	resources.equipment_condition = 1.0
	resources.water_leak_kg_per_hour = 0.0
	resources.oxygen_leak_kg_per_hour = 0.0
	active_incident = ""
	_incident_timer_minutes = 0.0
	_next_incident_minutes = _rng.randf_range(720.0, 1440.0)
	incident_changed.emit(active_incident)


func _refresh_power() -> void:
	var count: int = 0
	if is_instance_valid(base):
		for child: Node in base.get_children():
			if String(child.name).begins_with("SolarArray") and child.is_inside_tree():
				count += 1
	resources.solar_generation_kw = count * power_per_array_kw * clampf(solar_efficiency, 0.0, 1.0)


func clean_solar() -> void:
	solar_efficiency = clampf(solar_cleaned_efficiency, 0.0, 1.0)
	_refresh_power()
	_set_solar_dust(false)
	solar_cleaned.emit(solar_efficiency)


func _set_solar_dust(dirty: bool) -> void:
	if not is_instance_valid(base):
		return
	for child: Node in base.get_children():
		if String(child.name).begins_with("SolarArray"):
			_set_mesh_dust(child, dirty)


func _set_mesh_dust(node: Node, dirty: bool) -> void:
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node
		if dirty and not _solar_overlays.has(mesh):
			_solar_overlays[mesh] = mesh.material_overlay
			var dust := StandardMaterial3D.new()
			dust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dust.albedo_color = Color(0.32, 0.22, 0.12, 0.45)
			dust.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.material_overlay = dust
		elif not dirty and _solar_overlays.has(mesh):
			mesh.material_overlay = _solar_overlays[mesh]
			_solar_overlays.erase(mesh)
	for child: Node in node.get_children():
		_set_mesh_dust(child, dirty)


func _update_radiation() -> void:
	radiation_level = background_radiation_level
	if active_scenario == "solar_flare":
		radiation_level = flare_radiation_level
	elif active_scenario == "cme_warning" and _elapsed >= _cme_delay_minutes:
		radiation_level = cme_radiation_level
	elif active_scenario == "sep_event":
		radiation_level = sep_radiation_level
	radiation_level = clampf(radiation_level, 0.0, 100.0)
	var hazardous: bool = radiation_level >= 50.0
	if hazardous != _radiation_hazard:
		_radiation_hazard = hazardous
		radiation_hazard_changed.emit(hazardous)
