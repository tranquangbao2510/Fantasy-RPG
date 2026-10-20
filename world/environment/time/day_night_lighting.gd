class_name DayNightLighting
extends Node
## Ánh sáng ngày/đêm + tầm nhìn đêm của một map (TASK M2). Đọc GameClock, mỗi frame:
## - `darkness` (0 ngày → 1 đêm, chuyển mượt trong bình minh/hoàng hôn theo TimeSettings);
## - SunTint (CanvasModulate) = DayNightSettings.sun_color(darkness): ban đêm chỉ còn ánh trăng (`moonlight`, TASK M3) cho
##   mọi thứ vẽ trên canvas của map (địa hình, quái, item); UI ở CanvasLayer riêng không bị ảnh hưởng;
## - mọi VisionLight (group `vision_light`) sáng theo darkness (PointLight2D MIX kéo vùng tối về màu đèn, TASK M3);
##   VisionLight của Player: bán kính = base_vision_radius + bán kính sáng của đồ đang mặc (đèn lồng), màu theo đèn;
## - node trong group `daylight_fx` (tia nắng, đốm nắng) mờ dần theo darkness.
## Kỹ thuật chọn: CanvasModulate + Light2D chạy trên renderer Compatibility, không cần shader/SDF; xem 2m.
## Phát `darkness_changed` để hệ thống khác (vd. quái đêm M6) dùng.

signal darkness_changed(darkness: float)

const DAYLIGHT_GROUP: StringName = &"daylight_fx"

@export var clock: GameClock
@export var settings: DayNightSettings
@export var sun_tint: CanvasModulate
## Player (đọc EquipmentSlots để cộng bán kính đèn lồng).
@export var player: Node2D
@export var player_light: VisionLight

var darkness: float = 0.0
var _last_emitted: float = -1.0
var _daylight_alpha: Dictionary[CanvasItem, float] = {}


func _ready() -> void:
	if settings == null:
		settings = DayNightSettings.new()
	for node: Node in get_tree().get_nodes_in_group(DAYLIGHT_GROUP):
		var item: CanvasItem = node as CanvasItem
		if item != null:
			_daylight_alpha[item] = item.self_modulate.a
	update_lighting()


func _process(_delta: float) -> void:
	update_lighting()


## Độ tối tại phút trong ngày theo các mốc phase của TimeSettings.
static func darkness_at(minute_of_day: float, time: TimeSettings) -> float:
	if minute_of_day >= time.day_start and minute_of_day < time.dusk_start:
		return 0.0
	if minute_of_day >= time.dawn_start and minute_of_day < time.day_start:
		return 1.0 - smoothstep(float(time.dawn_start), float(time.day_start), minute_of_day)
	if minute_of_day >= time.dusk_start and minute_of_day < time.night_start:
		return smoothstep(float(time.dusk_start), float(time.night_start), minute_of_day)
	return 1.0


## Bán kính nhìn hiện tại của Player (px mặt đất).
func get_vision_radius() -> float:
	return settings.base_vision_radius + _equipment_light_radius()


## Độ nhìn thấy tại điểm world (0..1): 1 ban ngày; ban đêm = max(ánh trăng, mức che phủ lớn nhất của các VisionLight).
func get_visibility(point: Vector2) -> float:
	if darkness <= 0.0:
		return 1.0
	var cover: float = settings.moonlight
	for node: Node in get_tree().get_nodes_in_group(VisionLight.GROUP):
		var light: VisionLight = node as VisionLight
		if light != null and is_ancestor_of_scene(light):
			cover = maxf(cover, light.cover_at(point))
	return 1.0 - darkness * (1.0 - cover)


func is_point_visible(point: Vector2) -> bool:
	return get_visibility(point) >= settings.visible_threshold


func update_lighting() -> void:
	if clock == null:
		return
	darkness = darkness_at(clock.get_minute_of_day(), clock.settings)
	var ambient: Color = settings.sun_color(darkness)
	if sun_tint != null:
		sun_tint.color = ambient
	if player_light != null:
		player_light.radius = get_vision_radius()
		player_light.inner_ratio = settings.vision_inner_ratio
		player_light.energy = settings.vision_energy
		var equipment: EquipmentSlots = _player_equipment()
		player_light.color = equipment.get_light_color(settings.vision_color) if equipment != null else settings.vision_color
	for node: Node in get_tree().get_nodes_in_group(VisionLight.GROUP):
		var light: VisionLight = node as VisionLight
		light.ambient = ambient
		light.set_darkness(darkness)
	for item: CanvasItem in _daylight_alpha:
		if is_instance_valid(item):
			item.self_modulate.a = _daylight_alpha[item] * (1.0 - darkness)
	if absf(darkness - _last_emitted) > 0.01 or (darkness != _last_emitted and (darkness == 0.0 or darkness == 1.0)):
		_last_emitted = darkness
		darkness_changed.emit(darkness)


func is_ancestor_of_scene(node: Node) -> bool:
	var scene: Node = owner if owner != null else get_parent()
	return scene == null or scene.is_ancestor_of(node)


func _player_equipment() -> EquipmentSlots:
	return player.call(&"get_equipment") as EquipmentSlots if player != null and player.has_method(&"get_equipment") else null


func _equipment_light_radius() -> float:
	var equipment: EquipmentSlots = _player_equipment()
	return equipment.get_light_radius() if equipment != null else 0.0
