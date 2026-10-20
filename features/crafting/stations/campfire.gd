class_name Campfire
extends CraftingStation
## Lửa trại (TASK M3): item `campfire` (ItemDefinition.deploy_scene), dựng như lều (PlacementCheck) nhưng đặt trước mặt
## người chơi vì có thân va chạm. Giới hạn số lửa trại mỗi map: ItemDefinition.max_per_map.
## - Đang cháy: nguồn sáng (VisionLight — bán kính lớn hơn đèn lồng), trạm "Lửa trại" (nấu ăn).
## - Cháy `fuel_minutes` phút game (GameClock.time_passed, kể cả khi ngủ); thêm gỗ / cành để kéo dài (`fuel_values`,
##   tối đa `max_fuel_minutes`). Hết → tắt: ánh sáng tắt, không nấu được, vẫn đứng đó; thêm củi → nhóm lại.
## - E → cửa sổ Nấu (World): công thức lửa trại + nút thêm củi.
## Lưu bởi ItemPickupLayer (`deployed`, state = {fuel, lit}).

## Lửa vừa tắt (hết củi) / vừa nhóm lại.
signal lit_changed(lit: bool)
signal fuel_changed(minutes: float)

const ITEM_ID: StringName = &"campfire"

## Nhiên liệu lúc vừa dựng (phút game).
@export var initial_fuel_minutes: float = 240.0
@export var max_fuel_minutes: float = 720.0
## Mỗi món thêm vào kéo dài bao nhiêu phút game.
@export var fuel_values: Dictionary[StringName, float] = {&"wood": 120.0, &"branch": 45.0}

## ID ổn định của vật dựng (cùng tên field với Tent: ItemPickupLayer đặt khi khôi phục save).
var spot_id: String = ""
var item_id: StringName = ITEM_ID
var fuel_minutes: float = 0.0
var lit: bool = false
var _clock: GameClock

@onready var _light: VisionLight = $VisionLight
@onready var _flame: Node2D = $Visual/Flame


func _ready() -> void:
	super._ready()
	_clock = get_tree().get_first_node_in_group(GameClock.GROUP) as GameClock
	if _clock != null:
		_clock.time_passed.connect(burn)
	_apply()


## Gọi khi đặt từ item (ItemPickupLayer.spawn_deployed) — cháy với nhiên liệu ban đầu; id ổn định cho save.
func setup_from_item(p_item_id: StringName) -> void:
	item_id = p_item_id
	if spot_id.is_empty():
		spot_id = "campfire_%d_%04d" % [Time.get_unix_time_from_system(), randi() % 10000]
	fuel_minutes = initial_fuel_minutes
	lit = true


func get_deploy_id() -> String:
	return spot_id


func is_station_active() -> bool:
	return lit


func get_interaction_prompt() -> String:
	if lit:
		return "Nấu ăn / thêm củi (còn %s)" % format_fuel()
	return "Nhóm lửa (thêm gỗ / cành)"


## "3 giờ 20 phút"
func format_fuel() -> String:
	var minutes: int = ceili(fuel_minutes)
	return "%d giờ %02d phút" % [minutes / 60, minutes % 60]


## Thời gian game trôi: lửa đang cháy hao củi; hết → tắt.
func burn(minutes: float, _sleeping: bool = false) -> void:
	if not lit or minutes <= 0.0:
		return
	fuel_minutes = maxf(0.0, fuel_minutes - minutes)
	fuel_changed.emit(fuel_minutes)
	if fuel_minutes <= 0.0:
		_set_lit(false)


## Có thêm được món này làm củi không ("" nếu được).
func get_fuel_block_reason(fuel_item: StringName, inventory: Inventory) -> String:
	if not fuel_values.has(fuel_item):
		return "Không dùng làm củi được"
	if inventory == null or not inventory.has(fuel_item):
		return "Không có trong túi"
	if fuel_minutes + fuel_values[fuel_item] > max_fuel_minutes:
		return "Lửa đã đủ củi"
	return ""


## Thêm một món củi từ túi: kéo dài thời gian cháy; lửa đã tắt thì nhóm lại. "" nếu thành công.
func add_fuel(fuel_item: StringName, inventory: Inventory) -> String:
	var reason: String = get_fuel_block_reason(fuel_item, inventory)
	if not reason.is_empty():
		return reason
	inventory.remove(fuel_item, 1)
	fuel_minutes += fuel_values[fuel_item]
	fuel_changed.emit(fuel_minutes)
	if not lit:
		_set_lit(true)
	return ""


func save_deploy_state() -> Dictionary:
	return {"fuel": snappedf(fuel_minutes, 0.01), "lit": lit}


func load_deploy_state(state: Dictionary) -> void:
	var fuel: Variant = state.get("fuel")
	fuel_minutes = clampf(float(fuel), 0.0, max_fuel_minutes) if (fuel is int or fuel is float) else initial_fuel_minutes
	lit = state.get("lit", true) == true and fuel_minutes > 0.0
	_apply()


## Map isometric (ItemPickupLayer gọi khi đặt): vùng sáng tròn trên mặt đất.
func set_ground_squash(squash: float) -> void:
	if _light != null:
		_light.set_ground_squash(squash)


func get_light() -> VisionLight:
	return _light


func _set_lit(value: bool) -> void:
	if lit == value:
		return
	lit = value
	_apply()
	lit_changed.emit(lit)


func _apply() -> void:
	if _light != null:
		_light.visible = lit
	if _flame != null:
		_flame.visible = lit
