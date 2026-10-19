class_name ItemPickup
extends Node2D
## Vật phẩm nằm trên đất. Origin = điểm chạm đất (Y-sort theo chân); icon nổi lên xuống phía trên bóng.
## Phải là con của ItemPickupLayer (layer lo nhặt / lưu). Tầng: ElevationAgent con (z theo tầng, chỉ nhặt khi cùng
## tầng với người nhặt); map không có ElevationMap thì bỏ qua tầng.
## - Pickup đặt sẵn trong map: `pickup_id` ổn định (duy nhất trong map) → đã nhặt thì không xuất hiện lại sau khi load.
## - Pickup do người chơi vứt (`pickup_id` rỗng): layer lưu lại vị trí + nội dung.

@export var item_id: StringName = &""
@export_range(1, 999) var count: int = 1
## ID ổn định cho pickup đặt sẵn; rỗng = pickup sinh lúc chạy (vứt ra).
@export var pickup_id: String = ""
@export var icon_scale: float = 0.3
@export var bob_height: float = 2.5
@export var bob_speed: float = 3.0

var data: Dictionary = {}
## Pickup vứt ra chỉ nhặt được sau khi người nhặt đã ra khỏi vùng hút một lần (không tự nhặt lại ngay chỗ vừa vứt).
var armed: bool = true

var _time: float = 0.0

@onready var _icon: Sprite2D = $Icon


func _ready() -> void:
	_time = randf() * TAU
	refresh_icon()


func _process(delta: float) -> void:
	_time += delta
	_icon.position.y = -10.0 - (sin(_time * bob_speed) * 0.5 + 0.5) * bob_height


func is_placed() -> bool:
	return not pickup_id.is_empty()


func get_tier() -> int:
	var agent: ElevationAgent = ElevationAgent.find_for(self)
	return agent.get_tier() if agent != null else -1


func get_item_stack() -> ItemStack:
	return ItemStack.new(item_id, count, data)


func refresh_icon() -> void:
	if _icon == null:
		return
	var layer: ItemPickupLayer = get_parent() as ItemPickupLayer
	var item: ItemDefinition = layer.database.get_item(item_id) if layer != null and layer.database != null else null
	_icon.texture = item.icon if item != null else null
	_icon.scale = Vector2(icon_scale, icon_scale)
