class_name CombatHUD
extends Control
## HUD combat tối thiểu: HP Player, thông báo bị hạ gục, gợi ý phím, số sát thương.
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


func _ready() -> void:
	_death_panel.hide()
	_hint_label.text = "%s: tấn công · %s/%s/%s: đổi vũ khí (debug) · %s: tương tác · %s: reset thử nghiệm" % [
		InputHint.action_text(&"basic_attack"), InputHint.action_text(&"debug_weapon_1"), InputHint.action_text(&"debug_weapon_2"),
		InputHint.action_text(&"debug_weapon_3"), InputHint.action_text(&"interact"), InputHint.action_text(&"debug_reset")]
	_hint_label.text += "\n%s/%s/%s/%s: kỹ năng · %s: hủy ngắm/vận sức" % [
		InputHint.action_text(&"skill_slot_1"), InputHint.action_text(&"skill_slot_2"), InputHint.action_text(&"skill_slot_3"),
		InputHint.action_text(&"skill_slot_4"), InputHint.action_text(&"skill_cancel")]
	_weapon_label.text = "Vũ khí: —"
	_combo_label.text = "Combo: —"
	_death_label.text = "Bạn đã bị hạ gục\nNhấn [%s] để reset thử nghiệm" % InputHint.action_text(&"debug_reset")


func bind_player_health(health: HealthComponent) -> void:
	health.health_changed.connect(_on_player_health_changed)
	health.died.connect(_death_panel.show)
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


func _on_weapon_changed(weapon: WeaponDefinition) -> void:
	_weapon_label.text = "Vũ khí: %s" % (weapon.display_name if weapon != null else "—")


func _on_attack_phase_changed(phase: BasicAttackController.Phase, step_index: int, step_count: int) -> void:
	if phase == BasicAttackController.Phase.READY:
		return
	var phase_name: String = BasicAttackController.Phase.keys()[phase]
	_combo_label.text = "Combo %d/%d · %s" % [step_index + 1, step_count, phase_name]


func _on_combo_ended(completed: bool) -> void:
	_combo_label.text = "Combo: hoàn thành" if completed else "Combo: —"
