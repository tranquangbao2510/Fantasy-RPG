class_name CombatHUD
extends Control
## HUD combat tối thiểu: HP Player, thông báo bị hạ gục, gợi ý phím, số sát thương.
## Chỉ hiển thị theo signal; không tính sát thương và không sửa HealthComponent.

@export var damage_color: Color = Color(1, 0.95, 0.6)
@export var player_damage_color: Color = Color(1, 0.4, 0.4)
@export var defeat_color: Color = Color(1, 0.6, 0.2)

@onready var _hp_label: Label = %HPLabel
@onready var _hp_bar: ProgressBar = %HPBar
@onready var _death_panel: Control = %DeathPanel
@onready var _death_label: Label = %DeathLabel
@onready var _hint_label: Label = %HintLabel
@onready var _damage_numbers: DamageNumbers = %DamageNumbers


func _ready() -> void:
	_death_panel.hide()
	_hint_label.text = "%s: tấn công · %s: tương tác · %s: reset thử nghiệm" % [
		_action_text(&"basic_attack"), _action_text(&"interact"), _action_text(&"debug_reset")]
	_death_label.text = "Bạn đã bị hạ gục\nNhấn [%s] để reset thử nghiệm" % _action_text(&"debug_reset")


func bind_player_health(health: HealthComponent) -> void:
	health.health_changed.connect(_on_player_health_changed)
	health.died.connect(_death_panel.show)
	health.revived.connect(_death_panel.hide)
	_on_player_health_changed(health.current_health, health.max_health)
	_death_panel.visible = health.is_dead()


## Hiện số sát thương tại vị trí world; thêm chữ "Hạ gục!" nếu mục tiêu vừa chết.
func show_damage(world_position: Vector2, amount: int, is_player: bool, defeated: bool) -> void:
	_damage_numbers.spawn(world_position, str(amount), player_damage_color if is_player else damage_color)
	if defeated:
		_damage_numbers.spawn(world_position + Vector2(0, -14), "Hạ gục!", defeat_color)


func _on_player_health_changed(current: int, maximum: int) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_label.text = "HP %d / %d" % [current, maximum]


func _action_text(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			return key.as_text_physical_keycode() if key.physical_keycode != KEY_NONE else key.as_text_keycode()
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse != null:
			return "Chuột trái" if mouse.button_index == MOUSE_BUTTON_LEFT else "Chuột %d" % mouse.button_index
	return "?"
