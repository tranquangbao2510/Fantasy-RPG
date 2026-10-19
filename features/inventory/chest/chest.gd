class_name Chest
extends Interactable
## Rương chứa đồ (TASK M1): Interactable (phím E) có Inventory riêng. Tương tác phát `open_requested`; UI (World nối
## vào InventoryWindow) mở bảng rương + túi. Không tự biết UI.
## Save (group `saveable`, theo map): nội dung kho theo `chest_id` (ID ổn định, duy nhất trong map).
## `starting_items` chỉ là nội dung ban đầu của scene; save có dữ liệu thì thay hoàn toàn.

signal open_requested(chest: Chest)

@export var chest_id: String = ""
## item_id → số lượng, thêm vào kho lúc bắt đầu (dữ liệu thiết kế).
@export var starting_items: Dictionary[StringName, int] = {}

var _is_open: bool = false

@onready var _inventory: Inventory = $Inventory
@onready var _closed_visual: Node2D = $Visual/Closed
@onready var _open_visual: Node2D = $Visual/Open


func _ready() -> void:
	if chest_id.is_empty():
		push_error("[Chest] %s chưa có chest_id (không lưu được)." % get_path())
	for item_id: StringName in starting_items:
		var left: int = _inventory.add(item_id, starting_items[item_id])
		if left > 0:
			push_warning("[Chest] %s: không đủ chỗ cho %d %s." % [chest_id, left, item_id])
	_update_visual()


func get_inventory() -> Inventory:
	return _inventory


func get_interaction_prompt() -> String:
	return "Mở"


## Hiển thị nắp mở/đóng (UI gọi khi mở/đóng bảng rương).
func set_open(value: bool) -> void:
	_is_open = value
	_update_visual()


func is_open() -> bool:
	return _is_open


func _perform_interaction(_actor: Node2D) -> String:
	open_requested.emit(self)
	return ""


func _update_visual() -> void:
	_closed_visual.visible = not _is_open
	_open_visual.visible = _is_open


# --- Save ----------------------------------------------------------------------------------------

func get_save_id() -> String:
	return "chest:" + chest_id


func save_state() -> Dictionary:
	return {"inventory": _inventory.to_dict()}


func load_state(state: Dictionary) -> void:
	_inventory.load_dict(state.get("inventory", {}))
