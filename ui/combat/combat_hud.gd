class_name CombatHUD
extends Control
## HUD Player: HP, thông báo bị hạ gục, gợi ý phím, số sát thương; từ TASK M2 thêm đồng hồ (Ngày N · giờ · phase),
## thanh Mana / Stamina, Đói (đỏ + nhấp nháy khi thấp), buff đang có. Các phần M2 chỉ hiện khi được bind.
## Chỉ hiển thị theo signal; không tính sát thương và không sửa HealthComponent.

@export var damage_color: Color = Color(1, 0.95, 0.6)
@export var player_damage_color: Color = Color(1, 0.4, 0.4)
@export var defeat_color: Color = Color(1, 0.6, 0.2)
@export var heal_color: Color = Color(0.45, 1, 0.5)

@onready var _hp_label: Label = %HPLabel
@onready var _hp_bar: ProgressBar = %HPBar
@onready var _death_panel: Control = %DeathPanel
@onready var _death_label: Label = %DeathLabel
@onready var _hint_label: Label = %HintLabel
@onready var _damage_numbers: DamageNumbers = %DamageNumbers
@onready var _weapon_label: Label = %WeaponLabel
@onready var _combo_label: Label = %ComboLabel
@onready var _class_label: Label = %ClassLabel

var _classes: ClassManager
var _character: CharacterLevel
var _clock: GameClock
var _hunger: HungerComponent
var _buffs: BuffComponent
var _death_panel_enabled: bool = true
var _clock_label: Label
var _phase_icon: ColorRect
var _mana_bar: ProgressBar
var _stamina_bar: ProgressBar
var _stat_label: Label
var _buff_label: Label
var _blink_time: float = 0.0


func _ready() -> void:
	_death_panel.hide()
	_hint_label.text = "%s: tấn công · %s/%s/%s: đổi vũ khí (debug) · %s: tương tác / khai thác · %s: chế tạo · %s: reset thử nghiệm" % [
		InputHint.action_text(&"basic_attack"), InputHint.action_text(&"debug_weapon_1"), InputHint.action_text(&"debug_weapon_2"),
		InputHint.action_text(&"debug_weapon_3"), InputHint.action_text(&"interact"), InputHint.action_text(&"craft_toggle"),
		InputHint.action_text(&"debug_reset")]
	_hint_label.text += "\n%s/%s/%s/%s: kỹ năng · %s: hủy ngắm/vận sức · %s: bảng class (debug)" % [
		InputHint.action_text(&"skill_slot_1"), InputHint.action_text(&"skill_slot_2"), InputHint.action_text(&"skill_slot_3"),
		InputHint.action_text(&"skill_slot_4"), InputHint.action_text(&"skill_cancel"), InputHint.action_text(&"debug_progression")]
	_hint_label.text += "\n%s: chạy · %s: né · %s: túi đồ · %s/%s: lưu/tải nhanh · %s/%s: tua giờ ×10 / +1 giờ (debug)" % [
		InputHint.action_text(&"sprint"), InputHint.action_text(&"dodge"), InputHint.action_text(&"inventory_toggle"),
		InputHint.action_text(&"quick_save"), InputHint.action_text(&"quick_load"), InputHint.action_text(&"debug_time_fast"),
		InputHint.action_text(&"debug_time_skip")]
	_class_label.text = "Class: —"
	_weapon_label.text = "Vũ khí: —"
	_combo_label.text = "Combo: —"
	_death_label.text = "Bạn đã bị hạ gục\nNhấn [%s] để reset thử nghiệm" % InputHint.action_text(&"debug_reset")


func bind_player_health(health: HealthComponent) -> void:
	health.health_changed.connect(_on_player_health_changed)
	health.died.connect(func() -> void: _death_panel.visible = _death_panel_enabled)
	health.revived.connect(_death_panel.hide)
	_on_player_health_changed(health.current_health, health.max_health)
	_death_panel.visible = health.is_dead()


func bind_weapon(equipment: WeaponEquipment) -> void:
	equipment.weapon_changed.connect(_on_weapon_changed)
	_on_weapon_changed(equipment.get_weapon())


## Dòng debug combo: "Combo 2/3 · ACTIVE". Chỉ hiển thị trạng thái do controller báo.
func bind_attack(controller: BasicAttackController) -> void:
	controller.phase_changed.connect(_on_attack_phase_changed)
	controller.combo_ended.connect(_on_combo_ended)


## Dòng "Class: Test Fighter · Lv 2" (class đang dùng + character level).
func bind_progression(classes: ClassManager, character: CharacterLevel) -> void:
	_classes = classes
	_character = character
	classes.class_switched.connect(func(_previous: StringName, _class_id: StringName) -> void: _update_class_label())
	if character != null:
		character.level_changed.connect(func(_level: int) -> void: _update_class_label())
	_update_class_label()


## Hiện số sát thương tại vị trí world; thêm chữ "Hạ gục!" nếu mục tiêu vừa chết.
func show_damage(world_position: Vector2, amount: int, is_player: bool, defeated: bool) -> void:
	_damage_numbers.spawn(world_position, str(amount), player_damage_color if is_player else damage_color)
	if defeated:
		_damage_numbers.spawn(world_position + Vector2(0, -14), "Hạ gục!", defeat_color)


func show_heal(world_position: Vector2, amount: int) -> void:
	_damage_numbers.spawn(world_position, "+%d" % amount, heal_color)


func _on_player_health_changed(current: int, maximum: int) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_label.text = "HP %d / %d" % [current, maximum]


func _update_class_label() -> void:
	var current: ClassDefinition = _classes.get_current_class()
	_class_label.text = "Class: %s" % (current.display_name if current != null else "—")
	if _character != null:
		_class_label.text += " · Lv %d" % _character.get_level()


func _on_weapon_changed(weapon: WeaponDefinition) -> void:
	_weapon_label.text = "Vũ khí: %s" % (weapon.display_name if weapon != null else "—")


func _on_attack_phase_changed(phase: BasicAttackController.Phase, step_index: int, step_count: int) -> void:
	if phase == BasicAttackController.Phase.READY:
		return
	var phase_name: String = BasicAttackController.Phase.keys()[phase]
	_combo_label.text = "Combo %d/%d · %s" % [step_index + 1, step_count, phase_name]


func _on_combo_ended(completed: bool) -> void:
	_combo_label.text = "Combo: hoàn thành" if completed else "Combo: —"


## Map có cơ chế chết/hồi sinh (DeathController) thì không hiện bảng "bị hạ gục / R để reset".
func set_death_panel_enabled(enabled: bool) -> void:
	_death_panel_enabled = enabled
	if not enabled:
		_death_panel.hide()


## Đồng hồ: "Ngày 2 · 18:40 · Hoàng hôn" + ô màu phase.
func bind_clock(clock: GameClock) -> void:
	_clock = clock
	_ensure_survival_rows()
	clock.minute_changed.connect(func(_day: int, _minute: int) -> void: _update_clock())
	clock.phase_changed.connect(func(_phase: GameClock.Phase) -> void: _update_clock())
	_update_clock()


## Mana / Stamina / Đói / buff của Player.
func bind_survival(mana: ManaComponent, stamina: StaminaComponent, hunger: HungerComponent, buffs: BuffComponent) -> void:
	_ensure_survival_rows()
	_hunger = hunger
	_buffs = buffs
	mana.mana_changed.connect(func(current: float, maximum: float) -> void: _set_bar(_mana_bar, current, maximum))
	stamina.stamina_changed.connect(func(current: float, maximum: float) -> void: _set_bar(_stamina_bar, current, maximum))
	stamina.exhausted_changed.connect(func(exhausted: bool) -> void:
		_stamina_bar.modulate = Color(1, 0.45, 0.45) if exhausted else Color.WHITE)
	hunger.hunger_changed.connect(func(_value: float, _maximum: float) -> void: _update_stats())
	buffs.buffs_changed.connect(_update_stats)
	_set_bar(_mana_bar, mana.current, mana.get_max())
	_set_bar(_stamina_bar, stamina.current, stamina.get_max())
	_update_stats()


func get_clock_text() -> String:
	return _clock_label.text if _clock_label != null else ""


func get_stat_text() -> String:
	return _stat_label.text if _stat_label != null else ""


func is_hunger_warning() -> bool:
	return _hunger != null and _hunger.is_low()


func _process(delta: float) -> void:
	if _stat_label == null:
		return
	_blink_time += delta
	# Đói thấp: chữ đỏ nhấp nháy.
	_stat_label.modulate.a = 0.45 + 0.55 * absf(sin(_blink_time * 4.0)) if is_hunger_warning() else 1.0
	if _buffs != null and _buff_label.visible:
		_buff_label.text = "\n".join(_buffs.describe())


func _ensure_survival_rows() -> void:
	if _mana_bar != null:
		return
	var box: VBoxContainer = _hp_bar.get_parent() as VBoxContainer
	# Khung cũ cao cố định 80 px: cho giãn xuống dưới theo nội dung mới (không tràn lên mép trên màn hình).
	box.grow_vertical = Control.GROW_DIRECTION_END
	box.offset_bottom = box.offset_top
	var clock_row: HBoxContainer = HBoxContainer.new()
	clock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_icon = ColorRect.new()
	_phase_icon.custom_minimum_size = Vector2(12, 12)
	_phase_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_phase_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_row.add_child(_phase_icon)
	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override(&"font_size", 14)
	clock_row.add_child(_clock_label)
	box.add_child(clock_row)
	box.move_child(clock_row, 0)
	_mana_bar = _make_bar(Color(0.3, 0.5, 1.0))
	box.add_child(_mana_bar)
	box.move_child(_mana_bar, _hp_bar.get_index() + 1)
	_stamina_bar = _make_bar(Color(0.95, 0.8, 0.3))
	box.add_child(_stamina_bar)
	box.move_child(_stamina_bar, _mana_bar.get_index() + 1)
	_stat_label = Label.new()
	_stat_label.add_theme_font_size_override(&"font_size", 13)
	box.add_child(_stat_label)
	box.move_child(_stat_label, _stamina_bar.get_index() + 1)
	_buff_label = Label.new()
	_buff_label.add_theme_font_size_override(&"font_size", 12)
	_buff_label.add_theme_color_override(&"font_color", Color(0.7, 1, 0.7))
	_buff_label.hide()
	box.add_child(_buff_label)
	box.move_child(_buff_label, _stat_label.get_index() + 1)


func _make_bar(color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(180, 6)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.55)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override(&"background", back)
	bar.add_theme_stylebox_override(&"fill", fill)
	return bar


func _set_bar(bar: ProgressBar, current: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = current
	bar.tooltip_text = "%d / %d" % [roundi(current), roundi(maximum)]


func _update_clock() -> void:
	const PHASE_COLORS: Array[Color] = [Color(1, 0.7, 0.5), Color(1, 0.9, 0.4), Color(0.9, 0.5, 0.35), Color(0.35, 0.45, 0.9)]
	_clock_label.text = "Ngày %d · %s · %s" % [_clock.get_day(), _clock.format_time(), _clock.get_phase_name()]
	_phase_icon.color = PHASE_COLORS[_clock.get_phase()]


func _update_stats() -> void:
	if _hunger == null:
		return
	var low: bool = _hunger.is_low()
	_stat_label.text = "Đói %d / %d%s" % [roundi(_hunger.value), roundi(_hunger.get_max()), " — cần ăn!" if low else ""]
	_stat_label.add_theme_color_override(&"font_color", Color(1, 0.4, 0.35) if low else Color(0.95, 0.9, 0.8))
	var buff_lines: Array[String] = _buffs.describe() if _buffs != null else []
	_buff_label.visible = not buff_lines.is_empty()
	_buff_label.text = "\n".join(buff_lines)
