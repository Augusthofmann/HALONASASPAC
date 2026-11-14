extends SceneTree
func _initialize() -> void:
	call_deferred("check")
func check() -> void:
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	var controller: Node = scene.get_node("LunarBase/Astronaut/CrewTaskController")
	assert(controller.start_task("clean_solar"))
	await physics_frame
	await physics_frame
	controller._process(10.0)
	var astronaut: Node3D = scene.get_node("LunarBase/Astronaut")
	var p: Vector3 = astronaut.global_position
	var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 50, p - Vector3.UP * 50, 1 << 19)
	var hit: Dictionary = astronaut.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty())
	assert(absf(p.y - hit.position.y - 0.02) < 0.05)
	print("GROUND_CHECK_PASSED")
	quit()
