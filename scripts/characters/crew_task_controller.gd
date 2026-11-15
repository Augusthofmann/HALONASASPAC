extends Node
## Keyboard C starts the demonstration task. Movement uses mission speed and pauses with it.
signal state_changed(state: String)
signal task_finished(task: String)

@export var base: Node3D
@export var clock: Node
@export var simulation: Node
@export var movement_speed: float = 1.8
@export var cleaning_seconds: float = 4.0
@export_range(0.05, 1.0, 0.01) var ground_clearance: float = 0.38
@export var solar_visible_offset: Vector3 = Vector3(0.0, 0.0, -2.2)
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
var _return_route: Array[Vector3] = []
var _display_scale: Vector3 = Vector3.ONE
var _task_height_offset: float = 0.0


func _ready() -> void:
	_astronaut = get_parent() as Node3D
	_display_scale = _astronaut.scale
	_animation = _astronaut.get_node_or_null("Model/AnimationPlayer")
	_configure_movement_animations()
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
	if task not in ["clean_solar", "solar_maintenance", "collect_food", "collect_water", "collect_oxygen", "repair", "repair_water", "repair_oxygen", "repair_science"] or state != "idle" or simulation.radiation_level >= 50.0 or clock.paused or clock.campaign_complete:
		return false
	var point: Node3D = _task_anchor(task)
	if point == null:
		return false
	current_task = task
	_spawn_for_task(point)
	_work_remaining = cleaning_seconds
	_set_state("working")
	return true


func _task_anchor(task: String) -> Node3D:
	if task in ["clean_solar", "solar_maintenance", "repair"]:
		return base.get_node_or_null("SolarArraySouth")
	if task in ["collect_water", "repair_water"]:
		return base.get_node_or_null("WaterStorage")
	if task in ["collect_oxygen", "repair_oxygen"]:
		return base.get_node_or_null("CargoDepot")
	if task == "repair_science":
		return base.get_node_or_null("ScienceDome")
	return base.get_node_or_null("HydroponicsFarm")


func _spawn_for_task(anchor: Node3D) -> void:
	var offset: Vector3 = anchor.global_basis.z.normalized() * 1.6
	# The south array sits slightly above the regolith. Lift the worker so the
	# suit reads as standing beside the panel rather than clipping into its base.
	_task_height_offset = 0.55 if String(anchor.name) == "SolarArraySouth" else 0.0
	_astronaut.global_position = _grounded_position(anchor.global_position + offset)
	_astronaut.scale = Vector3.ONE * 0.01
	_astronaut.visible = true
	_inside = false
	var face_target: Vector3 = anchor.global_position - _astronaut.global_position
	face_target.y = 0.0
	if face_target.length_squared() > 0.001:
		_astronaut.rotation.y = atan2(face_target.x, face_target.z)
	var arrival := create_tween()
	arrival.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	arrival.tween_property(_astronaut, "scale", _display_scale, 0.45)
	arrival.parallel().tween_property(_astronaut, "position:y", _astronaut.position.y + 0.18, 0.18)
	arrival.tween_property(_astronaut, "position:y", _astronaut.position.y, 0.27)


func start_expedition() -> bool:
	if state != "idle":
		return false
	var rover_point: Node3D = base.get_node_or_null("TaskPoint_Rover")
	if rover_point == null:
		return false
	current_task = "rover"
	var rover_work: Vector3 = rover_point.global_position + base.global_basis * Vector3(0.0, 0.0, 2.0)
	_start_outside_route(rover_work, "rover", ["RouteHub", "RouteRover"])
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
		_set_animation_paused(true)
		return
	_set_animation_paused(false)
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
				"clean_solar", "solar_maintenance":
					simulation.clean_solar()
					simulation.repair_equipment()
				"collect_food": simulation.resources.food_kg += 1.0
				"collect_water": simulation.resources.refill_water()
				"collect_oxygen": simulation.resources.oxygen_kg = simulation.resources.oxygen_capacity_kg
				"repair": simulation.repair_equipment()
				"repair_water":
					simulation.repair_water_system()
				"repair_oxygen":
					simulation.repair_oxygen_system()
				"repair_science":
					simulation.repair_equipment()
					simulation.research += 10.0
			task_finished.emit(current_task)
			current_task = ""
			_go_home()
	_snap_to_ground()


func _snap_to_ground() -> void:
	if not _astronaut.is_inside_tree() or not _astronaut.visible:
		return
	var position: Vector3 = _grounded_position(_astronaut.global_position)
	if not is_equal_approx(position.y, _astronaut.global_position.y):
		_astronaut.global_position = position


func _grounded_position(position: Vector3) -> Vector3:
	if not _astronaut.is_inside_tree():
		return position
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 50.0, position - Vector3.UP * 50.0, 1 << 19)
	var hit: Dictionary = _astronaut.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		position.y = hit.position.y + ground_clearance + _task_height_offset
	else:
		# Keep an actor visible even during the first physics frame before the
		# terrain collider becomes available.
		position.y = maxf(position.y, _ground_y + ground_clearance)
	return position


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
	_astronaut.visible = false
	_astronaut.scale = _display_scale
	_task_height_offset = 0.0
	_inside = true
	_set_state("sheltering")


func _go_home() -> void:
	# Tasks are staged in place; remove the worker instead of sending it through
	# a long off-screen return route.
	_astronaut.visible = false
	_astronaut.scale = _display_scale
	_task_height_offset = 0.0
	_inside = true
	_set_state("idle")


func _route_home(purpose: String) -> void:
	var home: Node3D = base.get_node_or_null("AstronautHome")
	var habitat: Node3D = base.get_node_or_null("CrewHabitat")
	if home == null or habitat == null:
		_travel_purpose = ""
		_set_state("idle")
	else:
		var front_apron: Vector3 = _grounded_position(home.global_position)
		_route.clear()
		for index: int in range(_return_route.size() - 1, -1, -1):
			_route.append(_return_route[index])
		_route.append(front_apron)
		_begin_route(purpose)


func _start_outside_route(target: Vector3, purpose: String, network_nodes: Array[String]) -> void:
	var home: Node3D = base.get_node_or_null("AstronautHome")
	var habitat: Node3D = base.get_node_or_null("CrewHabitat")
	if _inside and home != null and habitat != null:
		# AstronautHome is the authored exit point by the module. Do not add a
		# gameplay offset here: an offset makes the crew appear from open terrain.
		_astronaut.global_position = _grounded_position(home.global_position)
		_astronaut.visible = true
		_inside = false
	_route.clear()
	_return_route.clear()
	# Bring the crew into the camera-facing apron first.  The old routes began
	# by sending them behind the habitat, so their only visible movement was a
	# distant speck disappearing away from the player.
	var camera_apron := _camera_facing_apron()
	_route.append(camera_apron)
	_return_route.append(camera_apron)
	for node_name: String in network_nodes:
		var marker: Node3D = base.get_node_or_null(node_name)
		if marker != null:
			var waypoint := _grounded_position(marker.global_position)
			_route.append(waypoint)
			_return_route.append(waypoint)
	_route.append(target)
	_begin_route(purpose)


func _camera_facing_apron() -> Vector3:
	var camera: Camera3D = base.get_node_or_null("../Camera3D")
	if camera == null:
		return _grounded_position(_astronaut.global_position)
	var direction: Vector3 = camera.global_position - _astronaut.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return _grounded_position(_astronaut.global_position)
	# Keep the actor in the play area rather than marching all the way to the
	# camera; this is enough to place their first, clearly visible walk segment
	# on the foreground side of the base.
	return _grounded_position(_astronaut.global_position + direction.normalized() * 4.5)


func _begin_route(purpose: String) -> void:
	for index: int in _route.size():
		_route[index] = _grounded_position(_route[index])
	_travel_purpose = purpose
	_destination = _grounded_position(_route.pop_front())
	_set_state("walking")


func _next_waypoint() -> void:
	if not _route.is_empty():
		_destination = _grounded_position(_route.pop_front())
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
			# Do not restart a clip every frame: it makes the walk pose visibly snap
			# when a route contains several short waypoints.
			if _animation.current_animation != animation_name:
				_animation.play(animation_name, 0.15)
	state_changed.emit(state)


func _configure_movement_animations() -> void:
	if _animation == null:
		return
	# Imported glTF clips are not guaranteed to carry loop metadata.  Crew can
	# walk for longer than one source clip, so both locomotion states must loop.
	for animation_name: String in ["Idle_A", "Walking_A"]:
		var clip: Animation = _animation.get_animation(animation_name)
		if clip != null:
			clip.loop_mode = Animation.LOOP_LINEAR


func _set_animation_paused(paused: bool) -> void:
	if _animation == null:
		return
	if paused:
		if _animation.is_playing():
			_animation.pause()
	elif not _animation.is_playing() and state in ["walking", "working"]:
		_animation.play("Walking_A" if state == "walking" else "Idle_A", 0.15)
