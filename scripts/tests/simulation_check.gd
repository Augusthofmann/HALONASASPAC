extends SceneTree


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var scene: Node = load("res://scenes/tests/simulation_demo.tscn").instantiate()
	root.add_child(scene)
	var clock: Node = scene.get_node("GameManager")
	var resources: Node = scene.get_node("ResourceManager")
	clock.set_paused(true)
	clock._process(10.0)
	assert(clock.elapsed_minutes == 0, "Pause must stop the clock")
	clock.set_paused(false)
	clock.set_speed(2)
	clock._process(10.0 / 9.6)
	assert(clock.elapsed_minutes == 10, "2x speed must advance ten minutes")
	assert(resources.energy_kwh > 1.0, "Solar generation must charge the battery")
	assert(resources.oxygen_kg > 0.5, "Powered life support must make oxygen")
	assert(resources.water_kg < 2.0 and resources.food_kg < 2.0, "Crew must use supplies")
	resources.solar_generation_kw = 0.0
	clock._process(600.0)
	assert(not resources.life_support_powered, "Life support must stop without power")
	assert(not resources.crew_surviving, "Crew must enter critical state without oxygen")
	print("SIMULATION_CHECK_PASSED")
	quit()
