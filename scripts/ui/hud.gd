extends Control

@onready var clock: Node = get_node("../../GameManager")
@onready var resources: Node = get_node("../../ResourceManager")
@onready var simulation: Node = get_node("../../BaseSimulation")
@onready var readout: Label = $ResourcesPanel/Readout
@onready var time_readout: Label = $TimeReadout
@onready var subtitle: Label = $MissionPanel/Subtitle
@onready var heading: Label = $ObjectivePanel/Heading
@onready var status: Label = $ObjectivePanel/Text
@onready var notification: Control = get_node_or_null("NotificationBanner")
@onready var danger: Control = get_node_or_null("DangerBanner")

var pause_button: Button
var solar_button: Button
var crew_readout: Label
var briefing: PanelContainer
var mission_menu: PanelContainer
var comic_font: SystemFont
var mission_goals: Label
var score_readout: Label
var resource_rows: Dictionary = {}
var resource_header: Label
var resources_group: Label
var actions_group: Label
var pending_commands: Array[Dictionary] = []
const COMMAND_DELAY_MINUTES: float = 15.0
var menu_paused_mission: bool = false
var sudoku_panel: PanelContainer
var sudoku_result: Label
var sudoku_paused_mission: bool = false
var kojima_progress: int = 0
var sudoku_reward_claimed: bool = false

const KOJIMA_CODE := [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]
const SUDOKU_PUZZLE := [
	[5, 3, 0, 0, 7, 0, 0, 0, 0],
	[6, 0, 0, 1, 9, 5, 0, 0, 0],
	[0, 9, 8, 0, 0, 0, 0, 6, 0],
	[8, 0, 0, 0, 6, 0, 0, 0, 3],
	[4, 0, 0, 8, 0, 3, 0, 0, 1],
	[7, 0, 0, 0, 2, 0, 0, 0, 6],
	[0, 6, 0, 0, 0, 0, 2, 8, 0],
	[0, 0, 0, 4, 1, 9, 0, 0, 5],
	[0, 0, 0, 0, 8, 0, 0, 7, 9],
]
const SUDOKU_SOLUTION := [
	[5, 3, 4, 6, 7, 8, 9, 1, 2], [6, 7, 2, 1, 9, 5, 3, 4, 8], [1, 9, 8, 3, 4, 2, 5, 6, 7],
	[8, 5, 9, 7, 6, 1, 4, 2, 3], [4, 2, 6, 8, 5, 3, 7, 9, 1], [7, 1, 3, 9, 2, 4, 8, 5, 6],
	[9, 6, 1, 5, 3, 7, 2, 8, 4], [2, 8, 7, 4, 1, 9, 6, 3, 5], [3, 4, 5, 2, 8, 6, 1, 7, 9],
]


func _ready() -> void:
	# The HUD owns the full canvas. Children receive their clicks inside the
	# same Control tree as their visuals, preventing a web resize from sending
	# pointer events to a displaced scene layer.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# This trainer never captures the pointer for camera control. Explicitly keep
	# it visible after a browser tab returns focus as well.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	comic_font = SystemFont.new()
	comic_font.font_names = PackedStringArray(["Comic Sans MS", "Comic Sans", "Chalkboard", "sans-serif"])
	_apply_readability()
	clock.time_changed.connect(_on_time_changed)
	clock.pause_changed.connect(_on_pause_changed)
	clock.speed_changed.connect(_on_speed_changed)
	clock.campaign_finished.connect(_on_campaign_finished)
	clock.score_changed.connect(_on_score_changed)
	resources.resources_changed.connect(_on_resources_changed)
	resources.life_support_changed.connect(_on_support_changed)
	resources.crew_survival_changed.connect(_on_crew_changed)
	simulation.conditions_changed.connect(_on_conditions_changed)
	simulation.scenario_changed.connect(_on_scenario_changed)
	simulation.solar_cleaned.connect(_on_solar_cleaned)
	simulation.crew_updated.connect(_on_crew_updated)
	simulation.incident_changed.connect(_on_incident_changed)
	simulation.action_cooldown_changed.connect(_on_action_cooldown_changed)
	simulation.dust_storm_changed.connect(_on_dust_storm_changed)
	clock.simulation_step.connect(_advance_command_queue)
	var crew: Node = get_node_or_null("../../LunarBase/Astronaut/CrewTaskController")
	if crew != null:
		crew.state_changed.connect(_on_crew_state_changed)
		crew.task_finished.connect(_on_crew_task_finished)
	_create_controls()
	_create_mission_goals()
	_create_resource_bars()
	_create_sudoku_panel()
	_refresh_language()
	if not clock.mission_started:
		_create_mission_briefing()
	_update_time()
	_update_resources()
	_update_status()
	_update_banners()
	_update_mission_goals()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _apply_readability() -> void:
	_apply_comic_theme(self)
	$MissionPanel.add_theme_stylebox_override("panel", _button_style(Color("fff4d6"), Color("1b1f2e")))
	$ResourcesPanel.add_theme_stylebox_override("panel", _button_style(Color("1b1f2e"), Color("ff7a2f")))
	$ObjectivePanel.add_theme_stylebox_override("panel", _button_style(Color("fff4d6"), Color("1b1f2e")))
	if notification != null:
		notification.add_theme_stylebox_override("panel", _button_style(Color("303030"), Color("ffd56a")))
	if danger != null:
		danger.add_theme_stylebox_override("panel", _button_style(Color("352323"), Color("ff9f9f")))
	# Keep the systems card short: values are arranged in paired columns so the
	# final research line cannot escape the panel on a 1080p web viewport.
	$ResourcesPanel.offset_bottom = 205.0
	readout.offset_bottom = 170.0
	readout.add_theme_font_size_override("font_size", 18)
	readout.visible = false
	$MissionPanel/Title.add_theme_color_override("font_color", Color("1b1f2e"))
	$MissionPanel/Subtitle.add_theme_color_override("font_color", Color("1b1f2e"))
	heading.add_theme_color_override("font_color", Color("1b1f2e"))
	status.add_theme_color_override("font_color", Color("1b1f2e"))
	$ResourcesPanel/Header.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_font_size_override("font_size", 18)
	heading.add_theme_font_size_override("font_size", 19)
	status.add_theme_font_size_override("font_size", 19)
	time_readout.add_theme_font_size_override("font_size", 21)
	for banner: Control in [notification, danger]:
		if banner != null:
			banner.get_node("Label").add_theme_font_size_override("font_size", 19)


func _apply_comic_theme(node: Control) -> void:
	node.add_theme_font_override("font", comic_font)
	for child: Node in node.get_children():
		if child is Control:
			_apply_comic_theme(child)


func _button_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = border
	style.shadow_color = Color("10131d")
	style.shadow_size = 4
	style.shadow_offset = Vector2(4.0, 4.0)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style


func _make_button(label: String, color: Color = Color("1b1f2e"), border: Color = Color("ff7a2f")) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.add_theme_font_override("font", comic_font)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("fff4d6"))
	button.add_theme_color_override("font_hover_color", Color("fff4d6"))
	button.add_theme_stylebox_override("normal", _button_style(color, border))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.16), Color.WHITE))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.18), border.darkened(0.2)))
	return button


func _create_controls() -> void:
	var actions_panel := PanelContainer.new()
	actions_panel.name = "GameplayActions"
	actions_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	actions_panel.offset_left = -340.0
	actions_panel.offset_top = 290.0
	actions_panel.offset_right = -28.0
	actions_panel.offset_bottom = 850.0
	actions_panel.add_theme_stylebox_override("panel", _button_style(Color("242424"), Color("a8a8a8")))
	add_child(actions_panel)
	var actions := VBoxContainer.new()
	actions.name = "CrewTasks"
	actions.add_theme_constant_override("separation", 6)
	actions_panel.add_child(actions)
	var title := Label.new()
	title.text = "MISSION CONTROLS"
	title.name = "GameplayTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", comic_font)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("ff7a2f"))
	actions.add_child(title)
	pause_button = _make_button("PAUSE MENU", Color("4a4a4a"), Color("d6d6d6"))
	actions.add_child(pause_button)
	pause_button.pressed.connect(_toggle_mission_menu)
	resources_group = Label.new()
	resources_group.text = "RESOURCES"
	resources_group.add_theme_font_override("font", comic_font)
	resources_group.add_theme_font_size_override("font_size", 18)
	resources_group.add_theme_color_override("font_color", Color("ff7a2f"))
	actions.add_child(resources_group)
	for entry: Array in [["COLLECT FOOD", "collect_food"]]:
		var resource_button := _make_button(entry[0])
		resource_button.custom_minimum_size = Vector2(0.0, 38.0)
		actions.add_child(resource_button)
		resource_button.pressed.connect(_request_task.bind(entry[1]))
	actions_group = Label.new()
	actions_group.text = "ACTIONS"
	actions_group.add_theme_font_override("font", comic_font)
	actions_group.add_theme_font_size_override("font_size", 18)
	actions_group.add_theme_color_override("font_color", Color("ff7a2f"))
	actions.add_child(actions_group)
	solar_button = _make_button("SOLAR: ON", Color("3d483c"), Color("8ccf7a"))
	actions.add_child(solar_button)
	solar_button.pressed.connect(_toggle_solar)
	for entry: Array in [["SOLAR SERVICE", "solar_maintenance"], ["REPAIR WATER", "repair_water"], ["REPAIR O₂", "repair_oxygen"], ["SCIENCE", "repair_science"], ["RAISE SHIELD", "shield"], ["ROVER", "rover"]]:
		var task_button := _make_button(entry[0], Color("303030"), Color("909090"))
		task_button.custom_minimum_size = Vector2(0.0, 38.0)
		actions.add_child(task_button)
		task_button.pressed.connect(_request_task.bind(entry[1]))
	crew_readout = Label.new()
	crew_readout.name = "CrewReadout"
	crew_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crew_readout.add_theme_font_override("font", comic_font)
	crew_readout.add_theme_font_size_override("font_size", 16)
	actions.add_child(crew_readout)
	var speed_switcher := HBoxContainer.new()
	speed_switcher.name = "SpeedSwitcher"
	speed_switcher.set_anchors_preset(Control.PRESET_CENTER_TOP)
	speed_switcher.position = Vector2(-126.0, 145.0)
	speed_switcher.add_theme_constant_override("separation", 4)
	add_child(speed_switcher)
	for multiplier: int in [1, 2, 5, 10]:
		var speed_button := _make_button("%dx" % multiplier)
		speed_button.custom_minimum_size = Vector2(58.0, 32.0)
		speed_button.add_theme_font_size_override("font_size", 16)
		speed_switcher.add_child(speed_button)
		speed_button.pressed.connect(func() -> void: clock.set_speed(multiplier))
	_on_crew_updated()
	_create_mission_menu()


func _create_resource_bars() -> void:
	var rows := VBoxContainer.new()
	rows.name = "ResourceBars"
	rows.position = Vector2(14.0, 42.0)
	rows.size = Vector2(284.0, 145.0)
	rows.add_theme_constant_override("separation", 4)
	$ResourcesPanel.add_child(rows)
	resource_header = $ResourcesPanel/Header
	for entry: Array in [["power", "POWER"], ["oxygen", "O₂"], ["water", "WATER"], ["food", "FOOD"]]:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0.0, 24.0)
		rows.add_child(row)
		var icon := Label.new()
		icon.text = entry[1]
		icon.custom_minimum_size = Vector2(48.0, 0.0)
		icon.add_theme_font_override("font", comic_font)
		icon.add_theme_font_size_override("font_size", 12)
		icon.add_theme_color_override("font_color", Color("62d5df") if entry[0] == "power" else Color("fff4d6"))
		row.add_child(icon)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(138.0, 18.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_theme_stylebox_override("background", _button_style(Color("10131d"), Color("fff4d6")))
		bar.add_theme_stylebox_override("fill", _button_style(Color("62d5df") if entry[0] == "power" else Color("ff7a2f"), Color("1b1f2e")))
		row.add_child(bar)
		var value := Label.new()
		value.custom_minimum_size = Vector2(62.0, 0.0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_override("font", comic_font)
		value.add_theme_font_size_override("font_size", 14)
		value.add_theme_color_override("font_color", Color("fff4d6"))
		row.add_child(value)
		resource_rows[entry[0]] = {"bar": bar, "value": value}


func _create_mission_goals() -> void:
	mission_goals = Label.new()
	mission_goals.name = "MissionGoals"
	mission_goals.position = Vector2(18.0, 82.0)
	mission_goals.size = Vector2(455.0, 160.0)
	mission_goals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_goals.add_theme_font_override("font", comic_font)
	mission_goals.add_theme_font_size_override("font_size", 18)
	mission_goals.add_theme_color_override("font_color", Color("1b1f2e"))
	$MissionPanel.add_child(mission_goals)
	var score_card := PanelContainer.new()
	score_card.name = "ScoreCard"
	score_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	score_card.offset_left = 28.0
	score_card.offset_top = 320.0
	score_card.offset_right = 520.0
	score_card.offset_bottom = 382.0
	score_card.add_theme_stylebox_override("panel", _button_style(Color("242424"), Color("ffd56a")))
	add_child(score_card)
	score_readout = Label.new()
	score_readout.name = "ScoreReadout"
	score_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_readout.add_theme_font_override("font", comic_font)
	score_readout.add_theme_font_size_override("font_size", 30)
	score_readout.add_theme_color_override("font_color", Color("ffd56a"))
	score_card.add_child(score_readout)


func _create_sudoku_panel() -> void:
	sudoku_panel = PanelContainer.new()
	sudoku_panel.name = "KojimaSudoku"
	sudoku_panel.set_anchors_preset(Control.PRESET_CENTER)
	sudoku_panel.offset_left = -360.0
	sudoku_panel.offset_top = -430.0
	sudoku_panel.offset_right = 360.0
	sudoku_panel.offset_bottom = 430.0
	sudoku_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	sudoku_panel.add_theme_stylebox_override("panel", _button_style(Color("202020"), Color("ffd56a")))
	sudoku_panel.visible = false
	add_child(sudoku_panel)
	var column := VBoxContainer.new()
	column.name = "SudokuColumn"
	column.add_theme_constant_override("separation", 10)
	sudoku_panel.add_child(column)
	var title := Label.new()
	title.text = "KOJIMA SUDOKU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", comic_font)
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	var hint := Label.new()
	hint.text = "Click empty squares to choose a number."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", comic_font)
	hint.add_theme_font_size_override("font_size", 18)
	column.add_child(hint)
	var grid := GridContainer.new()
	grid.name = "SudokuGrid"
	grid.columns = 9
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)
	for row in range(9):
		for column_index in range(9):
			var given: int = SUDOKU_PUZZLE[row][column_index]
			var cell := _make_button(str(given) if given > 0 else "", Color("383838") if given > 0 else Color("252525"), Color("999999"))
			cell.custom_minimum_size = Vector2(62.0, 62.0)
			cell.add_theme_font_size_override("font_size", 26)
			cell.set_meta("row", row)
			cell.set_meta("column", column_index)
			cell.set_meta("given", given > 0)
			cell.pressed.connect(_cycle_sudoku_cell.bind(cell))
			grid.add_child(cell)
	sudoku_result = Label.new()
	sudoku_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sudoku_result.add_theme_font_override("font", comic_font)
	sudoku_result.add_theme_font_size_override("font_size", 20)
	column.add_child(sudoku_result)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	var check := _make_button("CHECK", Color("3d4b3b"), Color("a8e38b"))
	check.pressed.connect(_check_sudoku)
	actions.add_child(check)
	var close := _make_button("CLOSE")
	close.pressed.connect(_close_sudoku)
	actions.add_child(close)


func _cycle_sudoku_cell(cell: Button) -> void:
	if bool(cell.get_meta("given")):
		return
	var current: int = int(cell.text) if cell.text.is_valid_int() else 0
	cell.text = "" if current >= 9 else str(current + 1)
	sudoku_result.text = ""


func _check_sudoku() -> void:
	var grid: GridContainer = sudoku_panel.get_node_or_null("SudokuColumn/SudokuGrid")
	if grid == null:
		return
	for cell: Button in grid.get_children():
		var row: int = int(cell.get_meta("row"))
		var column_index: int = int(cell.get_meta("column"))
		if not cell.text.is_valid_int() or int(cell.text) != SUDOKU_SOLUTION[row][column_index]:
			sudoku_result.text = "Not quite! Keep trying."
			return
	sudoku_result.text = "SOLVED!" if sudoku_reward_claimed else "SOLVED! +150 POINTS"
	if not sudoku_reward_claimed:
		clock.add_score(150)
		sudoku_reward_claimed = true
	for cell: Button in grid.get_children():
		cell.disabled = true


func _open_sudoku() -> void:
	sudoku_paused_mission = not clock.paused
	clock.set_paused(true)
	sudoku_panel.visible = true
	sudoku_result.text = ""


func _close_sudoku() -> void:
	sudoku_panel.visible = false
	if sudoku_paused_mission:
		clock.set_paused(false)
		sudoku_paused_mission = false


func _create_mission_menu() -> void:
	var russian: bool = clock.ui_language == "ru"
	mission_menu = PanelContainer.new()
	mission_menu.name = "MissionMenu"
	mission_menu.set_anchors_preset(Control.PRESET_CENTER)
	mission_menu.offset_left = -260.0
	mission_menu.offset_top = -270.0
	mission_menu.offset_right = 260.0
	mission_menu.offset_bottom = 270.0
	mission_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	mission_menu.add_theme_stylebox_override("panel", _button_style(Color("242424"), Color("c6c6c6")))
	mission_menu.visible = false
	add_child(mission_menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	mission_menu.add_child(column)
	var title := Label.new()
	title.name = "MenuTitle"
	title.text = "МЕНЮ ПАУЗЫ" if russian else "MISSION MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", comic_font)
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	var hint := Label.new()
	hint.text = "Choose a big button. You can always come back!"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", comic_font)
	hint.add_theme_font_size_override("font_size", 18)
	column.add_child(hint)
	var resume := _make_button("К БАЗЕ" if russian else "BACK TO BASE", Color("3d4b3b"), Color("a8e38b"))
	resume.name = "MenuResume"
	resume.pressed.connect(_toggle_mission_menu)
	column.add_child(resume)
	var pause := _make_button("ПАУЗА / ПРОДОЛЖИТЬ" if russian else "PAUSE / RESUME")
	pause.name = "MenuPause"
	pause.pressed.connect(func() -> void: clock.set_paused(not clock.paused))
	column.add_child(pause)
	var demo := _make_button("ЗАПУСТИТЬ ДЕМО" if russian else "PLAY THE DEMO", Color("4a3e53"), Color("ce9ee8"))
	demo.name = "MenuDemo"
	demo.pressed.connect(_start_demo)
	column.add_child(demo)
	var save := _make_button("СОХРАНИТЬ МИССИЮ" if russian else "SAVE MISSION", Color("394754"), Color("92c8e8"))
	save.name = "MenuSave"
	save.pressed.connect(_save_from_menu)
	column.add_child(save)
	var languages := HBoxContainer.new()
	languages.alignment = BoxContainer.ALIGNMENT_CENTER
	languages.add_theme_constant_override("separation", 8)
	column.add_child(languages)
	var english := _make_button("ENGLISH")
	english.custom_minimum_size = Vector2(190.0, 38.0)
	english.pressed.connect(_set_language.bind("en"))
	languages.add_child(english)
	var russian_button := _make_button("РУССКИЙ")
	russian_button.custom_minimum_size = Vector2(190.0, 38.0)
	russian_button.pressed.connect(_set_language.bind("ru"))
	languages.add_child(russian_button)
	var reset := _make_button("НОВАЯ МИССИЯ" if russian else "NEW MISSION", Color("513838"), Color("ff9f9f"))
	reset.name = "MenuNewMission"
	reset.pressed.connect(func() -> void: clock.new_mission(true))
	column.add_child(reset)


func _toggle_mission_menu() -> void:
	if mission_menu != null:
		if not mission_menu.visible:
			menu_paused_mission = not clock.paused
			clock.set_paused(true)
			mission_menu.visible = true
		elif menu_paused_mission:
			clock.set_paused(false)
			menu_paused_mission = false
			mission_menu.visible = false
		else:
			mission_menu.visible = false


func _save_from_menu() -> void:
	clock.save_mission()
	status.text = "MISSION SAVED!" if clock.ui_language == "en" else "МИССИЯ СОХРАНЕНА!"


func _set_language(language: String) -> void:
	clock.set_ui_language(language)
	_refresh_language()
	_update_mission_goals()
	status.text = "Language: English" if language == "en" else "Язык: Русский"


func _refresh_language() -> void:
	var russian: bool = clock.ui_language == "ru"
	$MissionPanel/Title.text = "ЛУННАЯ БАЗА · ЛЕЙБНИЦ БЕТА" if russian else "OUTPOST · LEIBNITZ BETA"
	if resource_header != null:
		resource_header.text = "СИСТЕМЫ БАЗЫ" if russian else "BASE SYSTEMS"
	if resources_group != null:
		resources_group.text = "РЕСУРСЫ" if russian else "RESOURCES"
	if actions_group != null:
		actions_group.text = "ДЕЙСТВИЯ" if russian else "ACTIONS"
	var gameplay_title: Label = get_node_or_null("GameplayActions/CrewTasks/GameplayTitle")
	if gameplay_title != null:
		gameplay_title.text = "УПРАВЛЕНИЕ БАЗОЙ" if russian else "MISSION CONTROLS"
	_set_localized_text("MissionMenu/MenuTitle", "МЕНЮ ПАУЗЫ", "MISSION MENU")
	_set_localized_text("MissionMenu/MenuResume", "К БАЗЕ", "BACK TO BASE")
	_set_localized_text("MissionMenu/MenuPause", "ПАУЗА / ПРОДОЛЖИТЬ", "PAUSE / RESUME")
	_set_localized_text("MissionMenu/MenuDemo", "ЗАПУСТИТЬ ДЕМО", "PLAY THE DEMO")
	_set_localized_text("MissionMenu/MenuSave", "СОХРАНИТЬ МИССИЮ", "SAVE MISSION")
	_set_localized_text("MissionMenu/MenuNewMission", "НОВАЯ МИССИЯ", "NEW MISSION")
	_update_time()


func _set_localized_text(path: String, russian_text: String, english_text: String) -> void:
	var control: Control = get_node_or_null(path)
	if control != null and "text" in control:
		control.text = russian_text if clock.ui_language == "ru" else english_text


func _create_mission_briefing() -> void:
	var russian: bool = clock.ui_language == "ru"
	briefing = PanelContainer.new()
	briefing.name = "MissionBriefing"
	briefing.set_anchors_preset(Control.PRESET_CENTER)
	briefing.offset_left = -300.0
	briefing.offset_top = -175.0
	briefing.offset_right = 300.0
	briefing.offset_bottom = 175.0
	briefing.mouse_filter = Control.MOUSE_FILTER_STOP
	briefing.add_theme_stylebox_override("panel", _button_style(Color("242424"), Color("e8e8e8")))
	add_child(briefing)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	briefing.add_child(column)
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.name = "MainTitle"
	title.text = "ЮНЫЙ АСТРОНАВТ\nТРЕНАЖЁР МИССИЙ" if russian else "JUNIOR ASTRONAUT\nMISSION TRAINER"
	column.add_child(title)
	var copy := Label.new()
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_font_size_override("font_size", 18)
	copy.text = "Построй безопасную лунную базу, помогай экипажу и закончи 30-дневную миссию." if russian else "Build a safe lunar base, guide the crew, and finish a 30-day mission."
	column.add_child(copy)
	var load := _make_button("ЗАГРУЗИТЬ ИГРУ" if russian else "LOAD GAME", Color("3d4b3b"), Color("a8e38b"))
	load.disabled = not clock.has_saved_mission
	load.tooltip_text = "No saved mission yet." if not clock.has_saved_mission else "Continue the saved mission."
	load.pressed.connect(_start_mission)
	column.add_child(load)
	var fresh := _make_button("НОВАЯ ИГРА" if russian else "NEW GAME", Color("3d4b3b"), Color("a8e38b"))
	fresh.pressed.connect(func() -> void: clock.new_mission(true))
	column.add_child(fresh)
	var credits := _make_button("АВТОРЫ" if russian else "CREDITS", Color("424242"), Color("d6d6d6"))
	credits.pressed.connect(_show_credits)
	column.add_child(credits)


func _start_mission() -> void:
	briefing.queue_free()
	briefing = null
	clock.start_mission()


func _show_credits() -> void:
	var credits := PanelContainer.new()
	credits.name = "Credits"
	credits.set_anchors_preset(Control.PRESET_CENTER)
	credits.offset_left = -280.0
	credits.offset_top = -180.0
	credits.offset_right = 280.0
	credits.offset_bottom = 180.0
	credits.mouse_filter = Control.MOUSE_FILTER_STOP
	credits.add_theme_stylebox_override("panel", _button_style(Color("242424"), Color("d0d0d0")))
	add_child(credits)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	credits.add_child(column)
	var title := Label.new()
	title.text = "CREDITS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", comic_font)
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	var text := Label.new()
	text.text = "Created by HALO team\n\nWith help SI\n\n3D assets: KayKit Space Base and Prototype Packs\n\nTerrain assets: NASA Lunar Terrain data"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_override("font", comic_font)
	text.add_theme_font_size_override("font_size", 18)
	column.add_child(text)
	var back := _make_button("BACK")
	back.pressed.connect(func() -> void: credits.queue_free())
	column.add_child(back)


func _request_task(task: String) -> void:
	for command: Dictionary in pending_commands:
		if command.task == task:
			status.text = "Signal already sent. Keep your radio on!"
			return
	pending_commands.append({"task": task, "remaining": COMMAND_DELAY_MINUTES})
	status.text = "Signal sent! Crew hears it in %d mission minutes." % COMMAND_DELAY_MINUTES


func _advance_command_queue(minutes: float) -> void:
	for index in range(pending_commands.size() - 1, -1, -1):
		var command: Dictionary = pending_commands[index]
		command.remaining = float(command.remaining) - minutes
		if float(command.remaining) <= 0.0:
			pending_commands.remove_at(index)
			_execute_task_command(str(command.task))


func _execute_task_command(task: String) -> void:
	var accepted: bool
	if task == "rover":
		accepted = simulation.start_rover()
	elif task == "shield":
		accepted = simulation.activate_emergency_shield()
	else:
		accepted = simulation.assign_task(task)
	if not accepted:
		var cooldown: float = simulation.action_cooldown_remaining(task)
		if cooldown > 0.0:
			status.text = "ACTION COOLDOWN\nTry again in %d mission minutes." % ceili(cooldown)
		else:
			status.text = "Action unavailable.\nWait for crew, power, or the current alert."
	else:
		var tips: Dictionary = {"solar_maintenance": "Crew is cleaning SolarArraySouth.", "repair_water": "Crew is fixing WaterStorage.", "repair_oxygen": "Crew is fixing the oxygen system.", "collect_food": "Crew is harvesting food at HydroponicsFarm.", "repair_science": "Crew is restoring ScienceDome instruments.", "shield": "Shield raised! The habitat is extra safe.", "rover": "Rovers explore while the crew shares limited supplies."}
		status.text = str(tips.get(task, ""))


func _start_demo() -> void:
	if simulation.has_node("DemoScenario"):
		return
	var demo: Node = load("res://scripts/simulation/demo_scenario.gd").new()
	demo.name = "DemoScenario"
	demo.clock = clock
	demo.simulation = simulation
	demo.message.connect(_on_demo_message)
	simulation.add_child(demo)


func _on_demo_message(message: String) -> void:
	heading.text = "DEMO · FICTIONAL"
	status.text = message


func _on_campaign_finished(success: bool) -> void:
	var layer := PanelContainer.new()
	layer.name = "CampaignResult"
	layer.set_anchors_preset(Control.PRESET_CENTER)
	layer.position = Vector2(-280.0, -110.0)
	layer.custom_minimum_size = Vector2(560.0, 220.0)
	add_child(layer)
	var column := VBoxContainer.new()
	column.name = "ResultContent"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(column)
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.text = "MISSION COMPLETE" if success else "MISSION ENDED"
	column.add_child(title)
	var result := Label.new()
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.text = "The crew completed 30 days!" if success else "The crew ran out of essential supplies."
	column.add_child(result)
	var restart := Button.new()
	restart.name = "Restart"
	restart.text = "RESTART MISSION"
	restart.pressed.connect(func() -> void: clock.new_mission())
	column.add_child(restart)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KOJIMA_CODE[kojima_progress]:
		kojima_progress += 1
	else:
		kojima_progress = 1 if event.keycode == KOJIMA_CODE[0] else 0
	if kojima_progress == KOJIMA_CODE.size():
		kojima_progress = 0
		if not sudoku_panel.visible:
			_open_sudoku()
		return
	if event.keycode == KEY_C:
		_request_task("solar_maintenance")


func _on_crew_updated() -> void:
	if crew_readout == null:
		return
	var available: int = 0
	for member: Node in simulation.crew:
		if member.state == "idle":
			available += 1
	crew_readout.text = "CREW %d / %d AVAILABLE" % [available, simulation.crew.size()]
	if simulation.rover_crew != null:
		if simulation.rover_crew.state != "expedition":
			crew_readout.text += "   ROVER: BOARDING"
		else:
			var seconds: int = ceili(simulation.rover_remaining / float(clock.speed))
			crew_readout.text += "   ROVER: %02d:%02d REAL" % [floori(float(seconds) / 60.0), seconds % 60]


func _toggle_solar() -> void:
	resources.solar_enabled = not resources.solar_enabled
	solar_button.text = "SOLAR: ON" if resources.solar_enabled else "SOLAR: OFF"
	_update_status()


func _on_time_changed(_day: int, _hour: int, _minute: int) -> void:
	_update_time()
	_update_mission_goals()


func _on_score_changed(_score: int) -> void:
	_update_mission_goals()


func _on_pause_changed(_paused: bool) -> void:
	pause_button.text = "PAUSE MENU"
	if clock.paused:
		clock.save_mission()
	_update_time()


func _on_speed_changed(_speed: int) -> void:
	_update_time()
	_on_crew_updated()


func _on_resources_changed(_energy: float, _oxygen: float, _water: float, _food: float) -> void:
	_update_resources()
	_update_mission_goals()


func _on_support_changed(_powered: bool) -> void:
	_update_status()


func _on_crew_changed(_surviving: bool) -> void:
	_update_status()
	_update_banners()


func _on_conditions_changed(_radiation: float, _dose: float, _research: float) -> void:
	_update_resources()
	_update_banners()
	_update_mission_goals()


func _on_scenario_changed(_scenario: String) -> void:
	_update_banners()
	_update_status()


func _on_incident_changed(_incident: String) -> void:
	_update_banners()
	_update_status()
	_update_resources()


func _on_dust_storm_changed(_active: bool) -> void:
	_update_banners()
	_update_status()


func _on_action_cooldown_changed(_action: String, remaining_minutes: float) -> void:
	if remaining_minutes > 0.0:
		status.text = "ACTION COOLDOWN\nTry again in %d mission minutes." % ceili(remaining_minutes)


func _on_crew_state_changed(_state: String) -> void:
	_update_status()


func _on_crew_task_finished(_task: String) -> void:
	_update_status()


func _on_solar_cleaned(_efficiency: float) -> void:
	_update_resources()


func _update_time() -> void:
	var minutes: int = clock.elapsed_minutes
	var hour: int = floori(float(minutes % clock.MINUTES_PER_MIS_DAY) / 60.0)
	var russian: bool = clock.ui_language == "ru"
	var state: String = "ГОТОВО" if russian and clock.campaign_complete else ("ПАУЗА" if russian and clock.paused else ("COMPLETE" if clock.campaign_complete else ("PAUSED" if clock.paused else "%dx" % clock.speed)))
	time_readout.text = ("ДЕНЬ МИССИИ %02d / 30\n%02d:%02d  •  %s" if russian else "MISSION DAY %02d / 30\n%02d:%02d  •  %s") % [clock.mis_day, hour, minutes % 60, state]
	subtitle.text = ("ДЕНЬ МИССИИ %02d / 30 · ЮЖНЫЙ ПОЛЮС" if russian else "MISSION DAY %02d / 30 · SOUTH POLAR OUTPOST") % clock.mis_day


func _update_resources() -> void:
	if resource_rows.is_empty():
		return
	_update_resource_row("power", resources.energy_kwh, resources.energy_capacity_kwh, "%.1f kWh" % resources.energy_kwh)
	_update_resource_row("oxygen", resources.oxygen_kg, resources.oxygen_capacity_kg, "%.1f kg" % resources.oxygen_kg)
	_update_resource_row("water", resources.water_kg, resources.water_capacity_kg, "%.1f kg" % resources.water_kg)
	_update_resource_row("food", resources.food_kg, 2.0, "%.1f kg" % resources.food_kg)


func _update_resource_row(key: String, amount: float, capacity: float, text: String) -> void:
	var row: Dictionary = resource_rows[key]
	var bar: ProgressBar = row["bar"]
	var value: Label = row["value"]
	bar.value = clampf(amount / maxf(capacity, 0.01) * 100.0, 0.0, 100.0)
	value.text = text


func _update_banners() -> void:
	var warning: bool = simulation.active_scenario == "cme_warning" and simulation.radiation_level < 50.0
	var hazardous: bool = simulation.radiation_level >= 50.0
	if notification != null:
		notification.visible = warning or simulation.active_incident != "" or simulation.dust_storm_active
		if warning:
			notification.get_node("Label").text = "CME WARNING\nRadiation may rise. Stay ready."
		elif simulation.active_incident != "":
			var names: Dictionary = {"power_fault": "POWER FAULT", "water_leak": "WATER LEAK", "oxygen_leak": "OXYGEN LEAK"}
			notification.get_node("Label").text = "%s\nSend crew to REPAIR." % names.get(simulation.active_incident, "FAULT")
		elif simulation.dust_storm_active:
			notification.get_node("Label").text = "DUST STORM\nSolar panels are losing power!"
	if danger != null:
		danger.visible = hazardous
		if hazardous:
			danger.get_node("Label").text = "DANGER: RADIATION\nOutside work is unsafe. Crew shelters."


func _update_status() -> void:
	heading.text = "CREW RADIO" if clock.ui_language == "en" else "РАЦИЯ ЭКИПАЖА"
	if not resources.crew_surviving:
		status.text = "Commander, we need help now!" if clock.ui_language == "en" else "Командир, нам срочно нужна помощь!"
	elif not resources.life_support_powered:
		status.text = "O₂ machine is sleepy. Give it power and water!" if clock.ui_language == "en" else "Машина O₂ уснула. Дай ей воду и энергию!"
	elif not resources.solar_enabled or resources.solar_generation_kw <= 0.0:
		status.text = "Sun power is off. Battery is doing the hard work!" if clock.ui_language == "en" else "Солнечная энергия выключена. Батарея старается!"
	else:
		var crew: Node = get_node_or_null("../../LunarBase/Astronaut/CrewTaskController")
		if crew != null and crew.state == "sheltering":
			status.text = "We are safe inside, commander!" if clock.ui_language == "en" else "Мы в укрытии, командир!"
		elif crew != null and crew.current_task in ["clean_solar", "solar_maintenance", "repair"]:
			status.text = "Cleaning the panels — shiny power incoming!" if clock.ui_language == "en" else "Чистим панели — скоро будет энергия!"
		else:
			status.text = "Everything is awesome, commander!" if simulation.solar_efficiency >= simulation.solar_cleaned_efficiency else ("All okay, commander! Press C — panels are dusty." if clock.ui_language == "en" else "Всё хорошо, командир! Нажми C — панели запылились.")


func _update_mission_goals() -> void:
	if mission_goals == null:
		return
	var stage: int = floori(float(clock.mis_day - 1) / 5.0)
	var first_day: int = stage * 5 + 1
	var last_day: int = mini(first_day + 4, 30)
	var goal_a: String
	var goal_b: String
	var goal_c: String
	var done_a: bool
	var done_b: bool
	var done_c: bool
	match stage % 3:
		0:
			goal_a = "Clean the solar panels  +100"
			goal_b = "Earn 300 research"
			goal_c = "Score 500 points"
			done_a = simulation.solar_efficiency >= simulation.solar_cleaned_efficiency
			done_b = simulation.research >= 300.0
			done_c = clock.mission_score >= 500
		1:
			goal_a = "Store 1.5 kg water"
			goal_b = "Store 1.2 kg oxygen"
			goal_c = "Score 750 points"
			done_a = resources.water_kg >= 1.5
			done_b = resources.oxygen_kg >= 1.2
			done_c = clock.mission_score >= 750
		_:
			goal_a = "Keep crew health above 80%"
			goal_b = "Earn 600 research"
			goal_c = "Score 1000 points"
			done_a = resources.crew_health >= 80.0
			done_b = simulation.research >= 600.0
			done_c = clock.mission_score >= 1000
	if clock.ui_language == "ru":
		mission_goals.text = "ГЛАВНАЯ ЦЕЛЬ\nДоживи до 30-го дня и сохрани экипаж.\n\nЗАДАЧИ ДНЕЙ %02d–%02d\n%s %s\n%s %s\n%s %s" % [first_day, last_day, "✓" if done_a else "□", goal_a, "✓" if done_b else "□", goal_b, "✓" if done_c else "□", goal_c]
	else:
		mission_goals.text = "MAIN GOAL\nReach Day 30 and keep the crew safe.\n\nTASKS · DAYS %02d–%02d\n%s %s\n%s %s\n%s %s" % [first_day, last_day, "✓" if done_a else "□", goal_a, "✓" if done_b else "□", goal_b, "✓" if done_c else "□", goal_c]
	if score_readout != null:
		score_readout.text = ("ВСЕГО ОЧКОВ: %d" if clock.ui_language == "ru" else "TOTAL SCORE: %d") % clock.mission_score
