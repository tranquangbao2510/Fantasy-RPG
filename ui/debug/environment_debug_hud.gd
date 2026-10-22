class_name EnvironmentDebugHud
extends PanelContainer
## Bảng thông tin của Environment Prototype (TASK VISUAL 01): tầng hiện tại của Player, loại địa hình dưới chân,
## mức zoom; nút bật/tắt lớp Terrain Logic; thanh trượt "Tốc độ dọc" (DEBUG ONLY, VISUAL-02.1) chỉnh vertical_speed_scale
## của Player và mọi enemy lúc chạy để thử cảm giác di chuyển isometric — không lưu, mở lại scene là về giá trị export.

const REFRESH_INTERVAL: float = 0.2

@export var agent: ElevationAgent
@export var terrain_logic: TerrainLogic
@export var camera: GameCamera
@export var tracked_body: Node2D

var _elapsed: float = 0.0
var _speed_slider: HSlider
var _speed_label: Label

@onready var _info: Label = %Info
@onready var _logic_button: Button = %LogicButton


func _ready() -> void:
	# TASK M6: chỉ hiện khi bật bảng debug (F12, bản debug) — DebugKeysPanel.
	add_to_group(DebugKeysPanel.HUD_GROUP)
	visible = false
	_logic_button.toggled.connect(_on_logic_toggled)
	_logic_button.focus_mode = Control.FOCUS_NONE
	_build_speed_tuner()
	_refresh()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= REFRESH_INTERVAL:
		_elapsed = 0.0
		_refresh()


func _refresh() -> void:
	var lines: PackedStringArray = PackedStringArray(["Environment Prototype — art vẽ tay (bản đầu)"])
	if agent != null:
		lines.append("Tầng: %d%s" % [agent.get_tier(), " (đang chuyển tầng)" if agent.is_transitioning() else ""])
	if terrain_logic != null and tracked_body != null:
		lines.append("Địa hình (lưới logic): %s" % terrain_logic.get_terrain_at(tracked_body.global_position))
	if camera != null:
		lines.append("Zoom: %.2f× (lăn chuột)" % camera.get_zoom_value())
	_info.text = "\n".join(lines)


func _build_speed_tuner() -> void:
	if tracked_body == null or not (&"vertical_speed_scale" in tracked_body):
		return
	var row: HBoxContainer = HBoxContainer.new()
	_speed_label = Label.new()
	_speed_label.add_theme_font_size_override(&"font_size", 13)
	_speed_label.custom_minimum_size = Vector2(150, 0)
	row.add_child(_speed_label)
	_speed_slider = HSlider.new()
	_speed_slider.min_value = 0.3
	_speed_slider.max_value = 1.0
	_speed_slider.step = 0.05
	_speed_slider.custom_minimum_size = Vector2(110, 0)
	_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Không nhận focus: phím mũi tên dùng để di chuyển.
	_speed_slider.focus_mode = Control.FOCUS_NONE
	_speed_slider.value = float(tracked_body.get(&"vertical_speed_scale"))
	_speed_slider.value_changed.connect(_on_speed_changed)
	row.add_child(_speed_slider)
	_logic_button.get_parent().add_child(row)
	_update_speed_label()


func _on_speed_changed(value: float) -> void:
	tracked_body.set(&"vertical_speed_scale", value)
	for enemy: Node in get_tree().get_nodes_in_group(&"enemies"):
		if &"vertical_speed_scale" in enemy:
			enemy.set(&"vertical_speed_scale", value)
	_update_speed_label()


func _update_speed_label() -> void:
	_speed_label.text = "[Debug] Tốc độ dọc: %.2f" % _speed_slider.value


func _on_logic_toggled(pressed: bool) -> void:
	if terrain_logic != null:
		terrain_logic.visible = pressed
