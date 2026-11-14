extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	var sim: Node = scene.get_node("BaseSimulation")
	var clock: Node = scene.get_node("GameManager")
	var resources: Node = scene.get_node("ResourceManager")
	var hud: Node = scene.get_node("UI/UIStub")
	assert(sim.crew.size() == 4)
	for member: Node in sim.crew:
		assert(member.state == "idle" and not member.get_parent().visible)
		member._process(20.0)
		assert(member.state == "idle" and not member.get_parent().visible)
	assert(hud.get_node("CrewReadout").text.contains("4 / 4"))
	for index in range(1, 5):
		hud.get_node("SimulationControls").get_child(index).pressed.emit()
		assert(clock.speed == [1, 2, 5, 10][index - 1])
	assert(clock.speed == 10)
	hud.get_node("CrewTasks").get_child(2).pressed.emit()
	assert(sim.crew[0].state == "walking" and sim.crew[0].get_parent().visible)
	assert(sim.crew[0]._route.size() == 5)
	var habitat: Node3D = scene.get_node("LunarBase/CrewHabitat")
	var initial_local: Vector3 = habitat.to_local(sim.crew[0].get_parent().global_position)
	# Entrance is the model's diagonal door, not the nearby square wall detail.
	assert(initial_local.distance_to(Vector3(-0.75, 0.15, 0.75)) < 0.06)
	assert(sim.assign_task("collect_water"))
	assert(sim.assign_task("repair"))
	assert(sim.start_rover())
	assert(not sim.start_rover() and not sim.assign_task("clean_solar"))
	for i in range(3):
		sim.crew[i]._process(20.0)
		sim.crew[i]._process(1.0)
	assert(resources.food_kg == 3.0 and resources.water_kg == 3.0 and resources.equipment_condition == 1.0)
	sim.crew[3]._process(20.0)
	assert(sim._rover_overlays.size() > 0 and not sim.rover_crew.get_parent().visible)
	var before: float = sim.research
	clock.set_paused(true)
	sim._process(300.0)
	assert(is_equal_approx(sim.rover_remaining, 300.0))
	clock.set_paused(false)
	clock.set_speed(2)
	sim._process(10.0)
	assert(is_equal_approx(sim.rover_remaining, 280.0))
	clock.set_speed(5)
	sim._process(10.0)
	assert(is_equal_approx(sim.rover_remaining, 230.0))
	clock.set_speed(10)
	sim._process(22.9)
	assert(is_equal_approx(sim.research, before))
	sim._process(0.1)
	assert(is_equal_approx(sim.research, before + 200.0) and sim.rover_crew == null and sim._rover_overlays.is_empty())
	assert(sim.crew[3].get_parent().visible)
	for member: Node in sim.crew:
		member._process(20.0)
		assert(member.state == "idle" and not member.get_parent().visible)
	resources.oxygen_kg = 0.5
	resources.energy_kwh = 2.0
	resources.solar_enabled = true
	resources.advance_minutes(10.0)
	assert(resources.oxygen_kg > 0.5)
	for incident: String in ["power_fault", "water_leak", "oxygen_leak"]:
		assert(sim.start_incident(incident))
		assert(hud.get_node("NotificationBanner").visible)
		match incident:
			"power_fault": assert(resources.equipment_condition <= 0.45)
			"water_leak": assert(resources.water_leak_kg_per_hour > 0.0)
			"oxygen_leak": assert(resources.oxygen_leak_kg_per_hour > 0.0)
		sim.repair_equipment()
		assert(sim.active_incident == "" and resources.equipment_condition == 1.0)
		assert(resources.water_leak_kg_per_hour == 0.0 and resources.oxygen_leak_kg_per_hour == 0.0)
	sim._incident_timer_minutes = sim._next_incident_minutes
	sim.advance_minutes(1.0)
	assert(sim.active_incident in ["power_fault", "water_leak", "oxygen_leak"])
	sim.repair_equipment()
	resources.energy_kwh = 0.0
	resources.solar_enabled = false
	var oxygen_before: float = resources.oxygen_kg
	resources.advance_minutes(10.0)
	assert(not resources.life_support_powered and resources.oxygen_kg < oxygen_before)
	print("CREW_TASKS_CHECK_PASSED")
	quit()
