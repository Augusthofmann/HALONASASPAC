extends Node
## Fictional timed presentation; standard mission timing and DONKI are unchanged.
signal message(text: String)

var clock: Node
var simulation: Node
var elapsed: float = 0.0
var step: int = 0


func _ready() -> void:
	clock.set_speed(1)
	simulation.resources.energy_kwh = simulation.resources.energy_capacity_kwh
	simulation.resources.water_kg = maxf(simulation.resources.water_kg, 20.0)
	simulation.resources.food_kg = maxf(simulation.resources.food_kg, 20.0)
	simulation._next_incident_minutes = 1000000.0
	message.emit("Fictional demo: watch power and supplies.\nDust blocks sunlight. Choose CLEAN.")


func _process(delta: float) -> void:
	if clock.paused or clock.campaign_complete:
		return
	elapsed += delta
	if step == 0 and elapsed >= 20.0:
		if simulation.solar_efficiency < simulation.solar_cleaned_efficiency:
			simulation.assign_task("clean_solar")
		message.emit("Cleaning helps panels make power.\nPower and water keep oxygen flowing.")
		step = 1
	elif step == 1 and elapsed >= 55.0:
		if simulation.start_rover():
			simulation.rover_remaining = 30.0
		message.emit("Demo rover trip: 30 seconds after boarding.\nResearch helps the mission explore.")
		step = 2
	elif step == 2 and elapsed >= 105.0:
		if simulation.start_scenario("cme_warning"):
			message.emit("Fictional CME warning: radiation may rise.\nCrew should prepare to shelter.")
		step = 3
	elif step == 3 and elapsed >= 135.0:
		simulation.assign_task("collect_water")
		if simulation.start_scenario("sep_event"):
			message.emit("Fictional radiation event!\nOutside crews return to shelter.")
		step = 4
	elif step == 4 and elapsed >= 180.0:
		simulation._next_incident_minutes = simulation._incident_timer_minutes + 720.0
		message.emit("Demo complete. Reusing water saves supplies.\nKeep balancing power, food and safety!")
		step = 5
