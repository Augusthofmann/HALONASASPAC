extends SceneTree
func _initialize() -> void:
	call_deferred("check")
func check() -> void:
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("GameManager").start_mission()
	var controller: Node = scene.get_node("LunarBase/Astronaut/CrewTaskController")
	assert(controller.start_task("clean_solar"))
	await physics_frame
	await physics_frame
	var astronaut: Node3D = scene.get_node("LunarBase/Astronaut")
	for step in range(40):
		controller._process(0.25)
		var p: Vector3 = astronaut.global_position
		var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 50, p - Vector3.UP * 50, 1 << 19)
		var hit: Dictionary = astronaut.get_world_3d().direct_space_state.intersect_ray(query)
		assert(not hit.is_empty())
		assert(p.y >= hit.position.y + controller.ground_clearance - 0.01)
	print("GROUND_CHECK_PASSED")
	quit()
