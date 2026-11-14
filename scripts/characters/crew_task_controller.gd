extends Node
## Keyboard C starts the demonstration task. Movement uses mission speed and pauses with it.
signal state_changed(state: String)
signal task_finished(task: String)

@export var base: Node3D
@export var clock: Node
@export var simulation: Node
@export var movement_speed: float = 1.8
@export var cleaning_seconds: float = 4.0
## Offsets place the route in front of the base while retaining the scene's markers.
@export var home_visible_offset: Vector3 = Vector3(1.0, 0.0, 5.0)
@export var solar_visible_offset: Vector3 = Vector3(-3.0, -0.4, 5.0)
var crew_index: int = 0

var state: String = "idle"
var current_task: String = ""
var _destination: Vector3
var _travel_purpose: String = ""
var _work_remaining: float = 0.0
var _astronaut: Node3D
var _animation: AnimationPlayer
var _ground_y: float
var _route: Array[Vector3] = []
var _inside: bool = true


func _ready() -> void:
	_astronaut = get_parent() as Node3D
	_animation = _astronaut.get_node_or_null("Model/AnimationPlayer")
	var home: Node3D = base.get_node_or_null("AstronautHome")
	if home != null:
		_ground_y = home.global_position.y
		var habitat: Node3D = base.get_node_or_null("CrewHabitat")
		_astronaut.global_position = habitat.global_position if habitat != null else home.global_position
	_astronaut.visible = false
	simulation.scenario_changed.connect(_on_scenario_changed)
	simulation.radiation_hazard_changed.connect(_on_radiation_hazard_changed)
	_set_state("idle")
	if simulation.active_scenario in ["solar_flare", "sep_event"]:
		_begin_shelter()


func start_task(task: String) -> bool:
	if task not in ["clean_solar", "collect_food", "collect_water", "repair"] or state != "idle" or simulation.radiation_level >= 50.0 or clock.paused or clock.campaign_complete:
		return false
	var point_name: String = "TaskPoint_Hydroponics" if task in ["collect_food", "collect_water"] else ("TaskPoint_Science" if task == "repair" else "TaskPoint_Solar")
	var point: Node3D = base.get_node_or_null(point_name)
	if point == null:
		return false
	current_task = task
	var offset: Vector3 = solar_visible_offset if task == "clean_solar" else Vector3(0.0, 0.0, 4.0)
	_start_outside_route(point.global_position + base.global_basis * offset, "work")
	return true


func start_expedition() -> bool:
	if state != "idle":
		return false
	var rover_point: Node3D = base.get_node_or_null("TaskPoint_Rover")
	if rover_point == null:
		return false
	current_task = "rover"
	_start_outside_route(rover_point.global_position + base.global_basis * Vector3(0.0, 0.0, 2.0), "rover")
	return true


func finish_expedition() -> void:
	_astronaut.visible = true
	current_task = ""
	if simulation.active_scenario in ["solar_flare", "sep_event"]:
		_begin_shelter()
	else:
		_go_home()


func _process(delta: float) -> void:
	if clock.paused or clock.campaign_complete:
		return
	var scaled_delta: float = delta * clock.speed
	if state == "walking":
		var distance_left: float = movement_speed * scaled_delta
		while state == "walking" and distance_left > 0.0:
			var direction: Vector3 = _destination - _astronaut.global_position
			direction.y = 0.0
			var distance: float = direction.length()
			if distance > 0.001:
				_astronaut.rotation.y = atan2(direction.x, direction.z)
				var step: float = minf(distance, distance_left)
				_astronaut.global_position += direction.normalized() * step
				distance_left -= step
			if distance <= 0.001 or Vector2(_astronaut.global_position.x - _destination.x, _astronaut.global_position.z - _destination.z).length() < 0.01:
				_next_waypoint()
			else:
				break
	elif state == "working":
		_work_remaining -= scaled_delta
		if _work_remaining <= 0.0:
			match current_task:
				"clean_solar": simulation.clean_solar()
				"collect_food": simulation.resources.food_kg += 1.0
				"collect_water": simulation.resources.water_kg += 1.0
				"repair": simulation.repair_equipment()
			task_finished.emit(current_task)
			current_task = ""
			_go_home()
	_snap_to_ground()


func _snap_to_ground() -> void:
	if not _astronaut.is_inside_tree() or not _astronaut.visible:
		return
	var position: Vector3 = _astronaut.global_position
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 50.0, position - Vector3.UP * 50.0, 1 << 19)
	var hit: Dictionary = _astronaut.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var floor_height: float = hit.position.y + 0.02
		var habitat: Node3D = base.get_node_or_null("CrewHabitat")
		if habitat != null:
			var hatch: Vector3 = _hatch_position(habitat, 0.0)
			var hatch_distance: float = Vector2(position.x - hatch.x, position.z - hatch.z).length()
			if hatch_distance < 1.6:
				var ramp: float = clampf((hatch_distance - 0.15) / 1.45, 0.0, 1.0)
				floor_height = lerpf(hatch.y, floor_height, ramp)
		position.y = floor_height
		_astronaut.global_position = position


func _on_scenario_changed(scenario: String) -> void:
	if scenario == "" and (state == "sheltering" or _travel_purpose == "shelter"):
		simulation.protected_mode = false
		_go_home()


func _on_radiation_hazard_changed(active: bool) -> void:
	if active:
		_begin_shelter()


func _begin_shelter() -> void:
	if state == "expedition":
		return
	if _inside:
		current_task = ""
		_set_state("sheltering")
		return
	if current_task == "rover":
		simulation.cancel_rover_departure(self)
	current_task = ""
	_route_home("shelter")


func _go_home() -> void:
	if _inside:
		_set_state("idle")
		return
	_route_home("home")


func _route_home(purpose: String) -> void:
	var home: Node3D = base.get_node_or_null("AstronautHome")
	var habitat: Node3D = base.get_node_or_null("CrewHabitat")
	if home == null or habitat == null:
		_travel_purpose = ""
		_set_state("idle")
	else:
		var plaza: Vector3 = _home_position(home)
		var hatch_exit: Vector3 = _hatch_position(habitat, 1.2)
		var bypass_x: float = _habitat_bypass_x(habitat)
		_route.clear()
		_route.append(Vector3(_astronaut.global_position.x, _ground_y, plaza.z))
		_route.append(plaza)
		_route.append(Vector3(bypass_x, _ground_y, plaza.z))
		_route.append(Vector3(bypass_x, _ground_y, hatch_exit.z))
		_route.append(hatch_exit)
		_route.append(_hatch_position(habitat, 0.0))
		_begin_route(purpose)


func _home_position(home: Node3D) -> Vector3:
	var offset: Vector3 = home_visible_offset + Vector3((crew_index % 2) * 1.1, 0.0, floori(float(crew_index) / 2.0) * 1.1)
	var target: Vector3 = home.global_position + base.global_basis * offset
	target.y = _ground_y
	return target


func _start_outside_route(target: Vector3, purpose: String) -> void:
	var home: Node3D = base.get_node_or_null("AstronautHome")
	var habitat: Node3D = base.get_node_or_null("CrewHabitat")
	if _inside and home != null and habitat != null:
		_astronaut.global_position = _hatch_position(habitat, -0.1)
		_astronaut.visible = true
		_inside = false
	var plaza: Vector3 = _home_position(home) if home != null else _astronaut.global_position
	_route.clear()
	if habitat != null:
		var hatch_exit: Vector3 = _hatch_position(habitat, 1.2)
		var bypass_x: float = _habitat_bypass_x(habitat)
		_route.append(hatch_exit)
		_route.append(Vector3(bypass_x, _ground_y, hatch_exit.z))
		_route.append(Vector3(bypass_x, _ground_y, plaza.z))
	_route.append(plaza)
	_route.append(Vector3(target.x, _ground_y, plaza.z))
	_route.append(target)
	_begin_route(purpose)


func _hatch_position(habitat: Node3D, outward: float) -> Vector3:
	# The door and its steps are on the model's local -X/+Z diagonal.
	var hatch: Vector3 = habitat.to_global(Vector3(-0.75, 0.15, 0.75))
	var normal: Vector3 = (habitat.global_basis * Vector3(-1.0, 0.0, 1.0)).normalized()
	return hatch + normal * outward


func _habitat_bypass_x(habitat: Node3D) -> float:
	# The current station places the hatch behind the habitat; skirt its west side.
	return habitat.global_position.x - 3.2


func _begin_route(purpose: String) -> void:
	_travel_purpose = purpose
	_destination = _route.pop_front()
	_set_state("walking")


func _next_waypoint() -> void:
	if not _route.is_empty():
		_destination = _route.pop_front()
	else:
		_arrive()


func _arrive() -> void:
	var purpose: String = _travel_purpose
	_travel_purpose = ""
	match purpose:
		"work":
			_work_remaining = cleaning_seconds
			_set_state("working")
		"shelter":
			_inside = true
			_astronaut.visible = false
			_set_state("sheltering")
		"rover":
			_astronaut.visible = false
			_set_state("expedition")
		_:
			_inside = true
			_astronaut.visible = false
			_set_state("idle")


func _set_state(value: String) -> void:
	state = value
	if _animation != null:
		var animation_name: String = "Walking_A" if state == "walking" else "Idle_A"
		if _animation.has_animation(animation_name):
			_animation.play(animation_name)
	state_changed.emit(state)
