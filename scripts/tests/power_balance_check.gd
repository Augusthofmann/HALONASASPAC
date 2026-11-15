extends SceneTree

func _initialize() -> void:
	var resource_manager: Node = load("res://scripts/simulation/resource_manager.gd").new()
	resource_manager.energy_capacity_kwh = 2.0
	resource_manager.energy_kwh = 2.0
	resource_manager.solar_generation_kw = 1.0
	resource_manager.equipment_condition = 1.0
	resource_manager.advance_minutes(60.0)
	assert(is_equal_approx(resource_manager.energy_kwh, 2.0), "Surplus generation must keep a full battery full")
	resource_manager.energy_kwh = 0.0
	resource_manager.solar_generation_kw = 0.2
	resource_manager.oxygen_kg = 0.5
	resource_manager.advance_minutes(60.0)
	assert(not resource_manager.life_support_powered, "Habitat has priority when power is insufficient")
	assert(resource_manager.oxygen_kg < 0.5, "Unpowered life support must not produce oxygen")
	assert(resource_manager.energy_kwh >= 0.0 and resource_manager.energy_kwh <= 2.0)
	resource_manager.free()
	print("POWER_BALANCE_CHECK_PASSED")
	quit()
