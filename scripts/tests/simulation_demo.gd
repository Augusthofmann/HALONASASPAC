extends Node

@onready var clock: Node = $GameManager
@onready var resources: Node = $ResourceManager


func _ready() -> void:
	clock.resources = resources
	clock.time_changed.connect(_on_time_changed)
	resources.life_support_changed.connect(func(powered: bool) -> void: print("Life support powered: ", powered))
	resources.crew_survival_changed.connect(func(surviving: bool) -> void: print("Crew surviving: ", surviving))
	print("Demo controls: Space = pause, 1 = 1x, 2 = 2x, P = toggle solar power")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			clock.set_paused(not clock.paused)
			print("Paused: ", clock.paused)
		KEY_1:
			clock.set_speed(1)
		KEY_2:
			clock.set_speed(2)
		KEY_P:
			resources.solar_generation_kw = 0.0 if resources.solar_generation_kw > 0.0 else 1.0
			print("Solar generation kW: ", resources.solar_generation_kw)


func _on_time_changed(day: int, hour: int, minute: int) -> void:
	if minute % 10 == 0:
		print("Day %d %02d:%02d | energy %.2f kWh | oxygen %.2f kg | water %.2f kg | food %.2f kg | alive %s" % [day, hour, minute, resources.energy_kwh, resources.oxygen_kg, resources.water_kg, resources.food_kg, str(resources.crew_surviving)])
