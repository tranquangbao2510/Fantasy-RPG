class_name CombatDebugPanel
extends PanelContainer
## Bảng debug combat (chỉ dùng để kiểm thử, ẩn mặc định). Mở/đóng: action `debug_combat_panel` (F3).
## Chỉ đọc trạng thái qua public API và gọi API có sẵn (heal, reset_state, ScenarioController); không tự tính damage.
## Không chặn input combat: có thể vừa đánh vừa quan sát. Click trên bảng do GUI xử lý nên không xuyên thành đòn đánh.

signal opened
signal closed

const TOGGLE_ACTION: StringName = &"debug_combat_panel"
const REFRESH_INTERVAL: float = 0.2
const MODE_NAMES: Array[String] = ["N", "Q", "I"]

var _world: World
var _refresh_left: float = 0.0

@onready var _status_label: Label = %StatusLabel
@onready var _scenario_label: Label = %ScenarioLabel
@onready var _scenario_list: VBoxContainer = %ScenarioList
@onready var _debug_info_toggle: CheckButton = %DebugInfoToggle


func _ready() -> void:
	hide()
	%HealButton.pressed.connect(_on_heal_pressed)
	%ResetEnemiesButton.pressed.connect(_on_reset_enemies_pressed)
	%RestartButton.pressed.connect(_on_restart_pressed)
	%ResetAllButton.pressed.connect(_on_reset_all_pressed)
	_debug_info_toggle.toggled.connect(_on_debug_info_toggled)


func bind(world: World) -> void:
	_world = world
	var controller: ScenarioController = world.scenario_controller
	if controller == null:
		_scenario_label.text = "Không có tình huống (chỉ có trong Combat Sandbox)."
		return
	controller.scenario_started.connect(func(_index: int) -> void: _refresh_scenarios())
	var scenarios: Array[CombatScenario] = controller.get_scenarios()
	for index: int in scenarios.size():
		var button: Button = Button.new()
		button.text = scenarios[index].display_name
		button.tooltip_text = scenarios[index].description
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override(&"font_size", 11)
		button.pressed.connect(controller.start_scenario.bind(index))
		_scenario_list.add_child(button)
	_refresh_scenarios()


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	show()
	_refresh_status()
	opened.emit()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


## Nút có text bắt đầu bằng prefix (dùng cho kiểm thử / debug).
func find_button(prefix: String) -> Button:
	for node: Node in find_children("*", "BaseButton", true, false):
		var button: Button = node as Button
		if button != null and button.text.begins_with(prefix):
			return button
	return null


func get_status_text() -> String:
	return _status_label.text


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or _world == null:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_status()


func _refresh_status() -> void:
	_refresh_left = REFRESH_INTERVAL
	if _world == null:
		return
	var lines: Array[String] = []
	var health: HealthComponent = _world.player_health
	lines.append("HP %d / %d%s" % [health.current_health, health.max_health, " (bị hạ gục)" if health.is_dead() else ""])
	var current: ClassDefinition = _world.player_classes.get_current_class() if _world.player_classes != null else null
	lines.append("Class: %s" % (current.display_name if current != null else "—"))
	var weapon: WeaponDefinition = _world.player_weapon.get_weapon()
	lines.append("Vũ khí: %s" % ("%s (%s)" % [weapon.display_name, weapon.weapon_type_id] if weapon != null else "—"))
	var loadout: SkillLoadout = _world.player_skills
	for slot: int in SkillLoadout.SLOT_COUNT:
		var runtime: SkillRuntime = loadout.get_runtime(slot)
		var key: String = InputHint.action_text(SkillCastingController.SLOT_ACTIONS[slot])
		if runtime == null:
			lines.append("[%s] —" % key)
			continue
		var state: String = "sẵn sàng" if runtime.can_cast() else "%.1fs" % runtime.get_cooldown_remaining()
		lines.append("[%s] %s %s · %d/%d · %s" % [key, runtime.definition.short_name, MODE_NAMES[runtime.cast_mode],
			runtime.get_charges(), runtime.get_max_charges(), state])
	var controller: ScenarioController = _world.scenario_controller
	if controller != null:
		lines.append("Enemy hoạt động: %d / %d" % [controller.get_active_enemy_count(), controller.get_spawned_count()])
	lines.append("Đạn đang bay: %d · FPS %d" % [get_tree().get_nodes_in_group(Projectile.GROUP).size(), Engine.get_frames_per_second()])
	_status_label.text = "\n".join(lines)


func _refresh_scenarios() -> void:
	var controller: ScenarioController = _world.scenario_controller
	var current: CombatScenario = controller.get_current_scenario()
	_scenario_label.text = "Tình huống: %s\n%s" % [current.display_name, current.description] if current != null else "Tình huống: —"
	for button: Node in _scenario_list.get_children():
		(button as Button).disabled = current != null and (button as Button).text == current.display_name


func _on_heal_pressed() -> void:
	var health: HealthComponent = _world.player_health
	health.heal(health.max_health)


func _on_reset_enemies_pressed() -> void:
	if _world.scenario_controller != null:
		_world.scenario_controller.reset_enemies()


func _on_restart_pressed() -> void:
	if _world.scenario_controller != null:
		_world.scenario_controller.restart()


func _on_reset_all_pressed() -> void:
	_world.reset_test_state()


func _on_debug_info_toggled(enabled: bool) -> void:
	get_tree().call_group(EnemyDebugView.GROUP, &"set_debug_visible", enabled)
	EnemyDebugView.shown = enabled
