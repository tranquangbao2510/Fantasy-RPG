class_name SleepController
extends Node
## Ngủ, ngất, điểm tỉnh dậy (TASK M2). Một node trong World (map có GameClock).
## - try_sleep(chỗ ngủ): chỉ từ `sleep_from_minute` tới trước `wake_minute`. TASK M4: không ngủ được khi có quái đang đuổi hoặc ở
##   gần (get_nearby_threat, "Có quái gần đây"). Màn hình mờ → thời gian nhảy tới
##   wake_minute (time_passed sleeping=true: đói giảm theo nhịp ngủ) → hồi HP (giường 100 %, lều 70 % — TASK M3) + mana
##   theo SleepSettings → chỗ ngủ thành điểm tỉnh dậy / hồi sinh của Player → tự lưu game (SaveService) → "Ngày N" → sáng lại.
## - Còn thức lúc `faint_hour` (2:00) → ngất (TASK M3): tỉnh lại TẠI CHỖ lúc wake_minute, không hồi HP/mana, không tự lưu,
##   đói − `faint_hunger_penalty` (ngoài phần giảm theo nhịp ngủ). (M2: tỉnh ở điểm tỉnh dậy.)
## - Điểm tỉnh dậy: Player.respawn_point {map_id, kind, id} → chỗ ngủ đó nếu còn trong map; không thì giường "nhà"
##   (Bed.home) gần nhất; không có giường nào → tại chỗ. Lều bị thu → điểm tỉnh dậy về nhà.
## Không biết UI cụ thể: dùng `overlay` (SleepOverlay: fade_out / fade_in / show_title) nếu có.

signal slept(day: int)
signal fainted(day: int)

@export var clock: GameClock
@export var player: Player
@export var settings: SleepSettings
@export var overlay: SleepOverlay
## map_id của map chứa node này (World.map_id) — ghi vào điểm tỉnh dậy.
@export var map_id: StringName = &""
## Tự lưu sau khi ngủ (test có thể tắt).
@export var autosave: bool = true

var _busy: bool = false


func _ready() -> void:
	if settings == null:
		settings = SleepSettings.new()
	if clock != null:
		clock.hour_changed.connect(_on_hour_changed)


func is_busy() -> bool:
	return _busy


## Lý do không ngủ được lúc này ("" nếu được).
func get_sleep_block_reason() -> String:
	if _busy:
		return "Đang ngủ."
	if player == null or player.is_dead():
		return "Không thể ngủ lúc này."
	if clock != null and not settings.can_sleep_at(clock.get_minute_of_day()):
		return "Chưa tới giờ ngủ (ngủ được %s)." % settings.format_window()
	if get_nearby_threat() != null:
		return "Có quái gần đây."
	return ""


## Quái đang đuổi Player hoặc ở gần hơn SleepSettings.enemy_block_radius (TASK M4); null nếu an toàn.
func get_nearby_threat() -> Enemy:
	var scene: Node = owner if owner != null else get_parent()
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or enemy.is_dead() or enemy.is_fading() or (scene != null and not scene.is_ancestor_of(enemy)):
			continue
		if enemy.is_hunting() or enemy.ground_distance_to(player.global_position) < settings.enemy_block_radius:
			return enemy
	return null


## Ngủ ở chỗ ngủ. Trả về "" nếu bắt đầu ngủ, ngược lại là lý do.
func try_sleep(spot: RestSpot) -> String:
	var reason: String = get_sleep_block_reason()
	if not reason.is_empty():
		return reason
	_sleep(spot, false)
	return ""


## Ngất ngay (debug / test). Bình thường tự xảy ra lúc faint_hour.
func faint() -> void:
	if not _busy and player != null and not player.is_dead():
		_sleep(null, true)


## Chỗ tỉnh dậy / hồi sinh hiện tại (null nếu map không có chỗ ngủ nào).
func get_wake_spot() -> RestSpot:
	var point: Dictionary = player.respawn_point if player != null else {}
	if str(point.get("map_id", "")) == String(map_id):
		for spot: RestSpot in _spots():
			if spot.spot_id == str(point.get("id", "")) and spot.get_kind() == str(point.get("kind", "")):
				return spot
	return get_home_spot()


## Giường "nhà" gần Player nhất (null nếu không có).
func get_home_spot() -> RestSpot:
	var best: RestSpot = null
	for spot: RestSpot in _spots():
		if spot.is_home() and (best == null or _distance(spot) < _distance(best)):
			best = spot
	return best


## Đặt chỗ ngủ làm điểm tỉnh dậy / hồi sinh của Player.
func set_wake_spot(spot: RestSpot) -> void:
	if player != null and spot != null:
		player.respawn_point = {"map_id": String(map_id), "kind": spot.get_kind(), "id": spot.spot_id}


## Lều bị thu: nếu đang là điểm tỉnh dậy thì về nhà.
func forget_spot(spot: RestSpot) -> void:
	if player != null and str(player.respawn_point.get("id", "")) == spot.spot_id \
			and str(player.respawn_point.get("kind", "")) == spot.get_kind():
		player.respawn_point = {}


## Đưa Player tới chỗ tỉnh dậy với `health_ratio` HP (dùng cho ngất, hồi sinh).
func move_player_to_wake_spot(health_ratio: float) -> void:
	var spot: RestSpot = get_wake_spot()
	var at: Vector2 = spot.get_wake_position() if spot != null else player.global_position
	var tier: int = spot.get_tier() if spot != null else -1
	player.respawn_at(at, tier, health_ratio)


func _sleep(spot: RestSpot, fainted_now: bool) -> void:
	_busy = true
	player.set_control_locked(true)
	if clock != null:
		clock.running = false
	if overlay != null:
		await overlay.fade_out(settings.fade_time)
	if clock != null:
		clock.advance(clock.minutes_until(settings.wake_minute), true)
	if fainted_now:
		player.get_hunger().restore(-settings.faint_hunger_penalty)
	else:
		set_wake_spot(spot)
		var health: HealthComponent = player.get_health()
		var ratio: float = settings.heal_ratio_for(spot.get_kind() if spot != null else "bed")
		health.heal(roundi(health.max_health * ratio))
		player.get_mana().restore(player.get_mana().get_max() * settings.sleep_mana_ratio)
		if spot != null:
			player.respawn_at(spot.get_wake_position(), spot.get_tier(), float(health.current_health) / health.max_health)
	var day: int = clock.get_day() if clock != null else 1
	if not fainted_now and autosave:
		var saves: Node = get_node_or_null(^"/root/SaveService")
		if saves != null:
			saves.call(&"save_game")
	if overlay != null:
		await overlay.show_title(("Ngày %d" % day) if not fainted_now else "Bạn ngất vì thức quá khuya — Ngày %d" % day, settings.title_time)
		await overlay.fade_in(settings.fade_time)
	if clock != null:
		clock.running = true
	player.set_control_locked(false)
	_busy = false
	if fainted_now:
		fainted.emit(day)
	else:
		slept.emit(day)


func _on_hour_changed(_day: int, hour: int) -> void:
	if hour == settings.faint_hour and not _busy:
		faint.call_deferred()


func _spots() -> Array[RestSpot]:
	var result: Array[RestSpot] = []
	var scene: Node = owner if owner != null else get_parent()
	for node: Node in get_tree().get_nodes_in_group(RestSpot.GROUP):
		if scene == null or scene.is_ancestor_of(node):
			if not node.is_queued_for_deletion():
				result.append(node as RestSpot)
	return result


func _distance(spot: RestSpot) -> float:
	return spot.global_position.distance_to(player.global_position) if player != null else 0.0
