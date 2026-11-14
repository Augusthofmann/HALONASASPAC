extends Node
## All rates are game-balancing assumptions, not NASA measurements.
## Power: kW, stored energy: kWh; oxygen, water, food: kg.

signal resources_changed(energy_kwh: float, oxygen_kg: float, water_kg: float, food_kg: float)
signal life_support_changed(powered: bool)
signal crew_survival_changed(surviving: bool)

@export_group("Storage")
@export var energy_capacity_kwh: float = 2.0
@export var energy_kwh: float = 1.0
@export var oxygen_capacity_kg: float = 2.0
@export var oxygen_kg: float = 0.5
@export var water_kg: float = 2.0
@export var food_kg: float = 2.0

@export_group("Rates per game hour")
@export var solar_generation_kw: float = 1.0
@export var habitat_consumption_kw: float = 0.25
@export var life_support_consumption_kw: float = 0.5
@export var oxygen_production_kg_per_hour: float = 0.30
@export var oxygen_use_kg_per_hour: float = 0.20
@export var water_use_kg_per_hour: float = 0.05
@export var food_use_kg_per_hour: float = 0.03

var life_support_powered: bool = true
var crew_surviving: bool = true


func advance_minutes(minutes: float) -> void:
	if minutes <= 0.0:
		return
	var hours: float = minutes / 60.0
	var generated: float = maxf(0.0, solar_generation_kw) * hours
	var habitat_demand: float = maxf(0.0, habitat_consumption_kw) * hours
	var support_demand: float = maxf(0.0, life_support_consumption_kw) * hours
	var available: float = minf(energy_capacity_kwh, energy_kwh + generated)
	var habitat_powered: bool = available >= habitat_demand
	if habitat_powered:
		available -= habitat_demand
	var support_powered: bool = available >= support_demand
	if support_powered:
		available -= support_demand
	energy_kwh = clampf(available, 0.0, energy_capacity_kwh)
	if life_support_powered != support_powered:
		life_support_powered = support_powered
		life_support_changed.emit(support_powered)
	if support_powered:
		oxygen_kg = minf(oxygen_capacity_kg, oxygen_kg + oxygen_production_kg_per_hour * hours)
	oxygen_kg = maxf(0.0, oxygen_kg - oxygen_use_kg_per_hour * hours)
	water_kg = maxf(0.0, water_kg - water_use_kg_per_hour * hours)
	food_kg = maxf(0.0, food_kg - food_use_kg_per_hour * hours)
	var surviving: bool = habitat_powered and oxygen_kg > 0.0 and water_kg > 0.0 and food_kg > 0.0
	if crew_surviving != surviving:
		crew_surviving = surviving
		crew_survival_changed.emit(surviving)
	resources_changed.emit(energy_kwh, oxygen_kg, water_kg, food_kg)
