extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	var clock: Node = scene.get_node("GameManager")
	var simulation: Node = scene.get_node("BaseSimulation")
	var resources: Node = scene.get_node("ResourceManager")
	var hud: Node = scene.get_node("UI/UIStub")
	var initial_day_length: float = clock.REAL_SECONDS_PER_MIS_DAY
	hud._start_demo()
	var demo: Node = simulation.get_node("DemoScenario")
	assert(initial_day_length == 300.0 and clock.REAL_SECONDS_PER_MIS_DAY == 300.0)
	demo._process(20.0)
	assert(demo.step == 1 and simulation.crew[0].current_task == "clean_solar")
	simulation.crew[0]._process(20.0)
	simulation.crew[0]._process(5.0)
	simulation.crew[0]._process(20.0)
	assert(is_equal_approx(simulation.solar_efficiency, 1.0))
	demo._process(35.0)
	assert(simulation.rover_crew != null and simulation.rover_remaining == 30.0)
	simulation.rover_crew._process(30.0)
	var before_research: float = simulation.research
	simulation._process(30.0)
	assert(simulation.research >= before_research + 200.0)
	demo._process(50.0)
	assert(simulation.active_scenario == "cme_warning" and simulation.radiation_level < 50.0)
	simulation.advance_minutes(30.0)
	assert(simulation.radiation_level >= 50.0)
	simulation.advance_minutes(60.0)
	demo._process(30.0)
	assert(simulation.active_scenario == "sep_event")
	assert(simulation.crew[0].current_task == "")
	simulation.advance_minutes(60.0)
	demo._process(45.0)
	assert(demo.step == 5)
	resources.water_kg = 10000.0
	resources.food_kg = 10000.0
	resources.energy_kwh = resources.energy_capacity_kwh
	simulation._next_incident_minutes = 10000000.0
	simulation.repair_equipment()
	simulation._next_incident_minutes = 10000000.0
	clock._process(9000.0)
	assert(clock.campaign_complete and hud.has_node("CampaignResult"))
	var result: Node = hud.get_node("CampaignResult")
	assert(result.get_node("ResultContent/Restart").text == "RESTART MISSION")
	print("PRESENTATION_CHECK_PASSED")
	quit()
