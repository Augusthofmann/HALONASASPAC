extends Node
## All rates are game-balancing assumptions, not NASA measurements.
## Power: kW, stored energy: kWh; oxygen, water, food: kg.

signal resources_changed(energy_kwh: float, oxygen_kg: float, water_kg: float, food_kg: float)
signal life_support_changed(powered: bool)
signal crew_survival_changed(surviving: bool)
signal crew_health_changed(health: float)

@export_group("Storage")
@export var energy_capacity_kwh: float = 2.0
@export var energy_kwh: float = 1.0
@export var oxygen_capacity_kg: float = 2.0
@export var oxygen_kg: float = 0.5
@export var water_capacity_kg: float = 2.0
@export var water_kg: float = 2.0
@export var food_kg: float = 2.0

@export_group("Rates per game hour")
@export var solar_generation_kw: float = 1.0
@export var solar_enabled: bool = true
@export_range(0.0, 1.0) var equipment_condition: float = 0.65
@export var habitat_consumption_kw: float = 0.25
@export var life_support_consumption_kw: float = 0.5
@export var oxygen_production_kg_per_hour: float = 0.03
@export var oxygen_use_kg_per_hour: float = 0.02
@export var water_use_kg_per_hour: float = 0.05
@export var water_reclamation_kg_per_hour: float = 0.08
@export var food_use_kg_per_hour: float = 0.03
## Simplified, fictional rates for the prototype, not NASA measurements.
@export var water_per_oxygen_kg: float = 1.125
@export_range(0.0, 1.0) var water_recycling_fraction: float = 0.75
var water_leak_kg_per_hour: float = 0.0
var oxygen_leak_kg_per_hour: float = 0.0

var life_support_powered: bool = true
var crew_surviving: bool = true
var crew_health: float = 100.0


func advance_minutes(minutes: float) -> void:
	if minutes <= 0.0:
		return
	var hours: float = minutes / 60.0
	var generated: float = maxf(0.0, solar_generation_kw) * equipment_condition * hours if solar_enabled else 0.0
	var habitat_demand: float = maxf(0.0, habitat_consumption_kw) * hours
	var support_demand: float = maxf(0.0, life_support_consumption_kw) * hours
	# Generation can power consumers directly even when the battery starts full.
	var available: float = maxf(0.0, energy_kwh) + generated
	var habitat_powered: bool = available >= habitat_demand
	if habitat_powered:
		available -= habitat_demand
	var support_powered: bool = habitat_powered and available >= support_demand
	if support_powered:
		available -= support_demand
	energy_kwh = clampf(available, 0.0, energy_capacity_kwh)
	if life_support_powered != support_powered:
		life_support_powered = support_powered
		life_support_changed.emit(support_powered)
	if support_powered:
		var oxygen_made: float = minf(maxf(0.0, oxygen_capacity_kg - oxygen_kg), maxf(0.0, oxygen_production_kg_per_hour) * hours)
		if water_per_oxygen_kg > 0.0:
			oxygen_made = minf(oxygen_made, water_kg / water_per_oxygen_kg)
			water_kg = maxf(0.0, water_kg - oxygen_made * water_per_oxygen_kg)
		oxygen_kg += oxygen_made
	oxygen_kg = maxf(0.0, oxygen_kg - (oxygen_use_kg_per_hour + oxygen_leak_kg_per_hour) * hours)
	# Water reclamation mirrors oxygen generation: when life support has power,
	# the closed-loop system replenishes more water than normal crew use.
	var recycled: float = clampf(water_recycling_fraction, 0.0, 1.0) if support_powered else 0.0
	var reclaimed: float = water_reclamation_kg_per_hour * hours if support_powered else 0.0
	water_kg = clampf(water_kg + reclaimed - (water_use_kg_per_hour * (1.0 - recycled) + water_leak_kg_per_hour) * hours, 0.0, water_capacity_kg)
	food_kg = maxf(0.0, food_kg - food_use_kg_per_hour * hours)
	var essentials_missing: bool = oxygen_kg <= 0.0 or water_kg <= 0.0 or food_kg <= 0.0
	var previous_health: float = crew_health
	# A missing essential does not instantly erase the crew: their health falls
	# over time, giving the player a chance to fix the base.
	if essentials_missing:
		crew_health = maxf(0.0, crew_health - 15.0 * hours)
	else:
		crew_health = minf(100.0, crew_health + 2.0 * hours)
	if not is_equal_approx(previous_health, crew_health):
		crew_health_changed.emit(crew_health)
	var surviving: bool = crew_health > 0.0
	if crew_surviving != surviving:
		crew_surviving = surviving
		crew_survival_changed.emit(surviving)
	resources_changed.emit(energy_kwh, oxygen_kg, water_kg, food_kg)


func refill_water() -> void:
	water_kg = water_capacity_kg
	resources_changed.emit(energy_kwh, oxygen_kg, water_kg, food_kg)
