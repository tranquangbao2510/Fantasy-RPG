class_name EnvironmentDebugHud
extends PanelContainer
## Bảng thông tin của Environment Prototype (TASK VISUAL 01): tầng hiện tại của Player, loại địa hình dưới chân,
## mức zoom; nút bật/tắt lớp Terrain Logic. Chỉ đọc public API, không điều khiển gameplay.

const REFRESH_INTERVAL: float = 0.2

@export var agent: ElevationAgent
@export var terrain_logic: TerrainLogic
@export var camera: GameCamera
@export var tracked_body: Node2D

var _elapsed: float = 0.0

@onready var _info: Label = %Info
@onready var _logic_button: Button = %LogicButton


func _ready() -> void:
	_logic_button.toggled.connect(_on_logic_toggled)
	_logic_button.focus_mode = Control.FOCUS_NONE
	_refresh()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= REFRESH_INTERVAL:
		_elapsed = 0.0
		_refresh()


func _refresh() -> void:
	var lines: PackedStringArray = PackedStringArray(["Environment Prototype — placeholder art"])
	if agent != null:
		lines.append("Tầng: %d%s" % [agent.get_tier(), " (đang chuyển tầng)" if agent.is_transitioning() else ""])
	if terrain_logic != null and tracked_body != null:
		lines.append("Địa hình (lưới logic): %s" % terrain_logic.get_terrain_at(tracked_body.global_position))
	if camera != null:
		lines.append("Zoom: %.2f× (lăn chuột)" % camera.get_zoom_value())
	_info.text = "\n".join(lines)


func _on_logic_toggled(pressed: bool) -> void:
	if terrain_logic != null:
		terrain_logic.visible = pressed
