class_name Enemy
extends CharacterBody2D
## Enemy prototype dùng chung cho mọi kiểu hành vi thử nghiệm. Khác biệt nằm ở dữ liệu export và
## AttackComponent gắn vào (MeleeAttack, RangedAttack), không ở script riêng.
## State: IDLE → CHASE → ATTACK → RECOVERY (đang hồi đòn) → DEAD. Không pathfinding (có thể kẹt sau vật cản).
## Chỉ đọc vị trí và is_dead() của target; không truy cập HP. Di chuyển + knockback luôn qua move_and_slide().
##
## TASK M4 (quái đêm) — hành vi bật bằng dữ liệu; mặc định tắt hết nên enemy cũ (Combat Sandbox) không đổi:
## - WANDER: lang thang quanh điểm sinh (`wander_radius` > 0) thay vì đứng yên khi chưa thấy mục tiêu.
## - ALERT: vừa phát hiện → khựng lại `alert_time` giây, phát `alerted` (âm thanh sau này) rồi mới đuổi.
## - Phát hiện theo `detection` (DetectionProfile): bán kính đổi theo việc mục tiêu chạy / đi / đứng yên / cầm đèn;
##   đang đuổi thì nhớ mục tiêu tới khi xa hơn bán kính × lose_multiplier.
## - FLEE: HP dưới `flee_health_ratio` → bỏ chạy khỏi mục tiêu (không quay lại).
## - AVOID_LIGHT (`light_averse`): không bước vào vùng sáng an toàn (VisionLight.safe_zone — lửa trại, đá rune, đèn
##   giường) mà lượn ở rìa; đang ở trong thì đi ra; mục tiêu cầm đèn tới gần (trong bán kính đèn × held_light_repel_ratio)
##   thì lùi lại.
## - CIRCLE: có `pack` (EnemyPack, do EnemySpawner gán) và `circle_radius` > 0 → vây quanh mục tiêu, lần lượt từng con
##   lao vào (tốc độ × `lunge_speed_multiplier`) khi tới lượt.
##
## TASK M4.1:
## - Tìm đường (`use_navigation`): NavigationAgent2D con (navigation layer = tầng hiện tại, navmesh của TierNavigation) —
##   đuổi, vây, bỏ chạy, lang thang, lượn quanh vùng sáng đều đi theo đường tìm được; map chưa có navmesh → đi thẳng như cũ.
##   Mục tiêu không tới được (khác tầng, trên đảo...) quá `unreachable_give_up_time` giây → mất dấu, lang thang
##   `lost_cooldown` giây. Quái gần nhau tách ra (`separation_radius`).
## - Đuốc: mục tiêu cầm đèn — quái sợ sáng ở trong bán kính đèn thì lùi; trong [bán kính, bán kính × held_light_repel_ratio]
##   thì lượn quanh, không áp sát, và HÚT thời gian cháy của đuốc (× `torch_drain_multiplier`, Player.drain_held_light).

signal state_changed(state: State)
## Vừa phát hiện mục tiêu (TASK M4; âm thanh / HUD gắn sau).
signal alerted(enemy: Enemy)

## Giá trị cũ giữ nguyên thứ tự; trạng thái M4 thêm vào sau.
enum State { IDLE, CHASE, ATTACK, RECOVERY, DEAD, WANDER, ALERT, FLEE, AVOID_LIGHT, CIRCLE }

enum MovementMode {
	CHASE,         ## Đuổi tới tầm đánh rồi tấn công (Melee Chaser).
	STATIONARY,    ## Không di chuyển; tấn công khi target vào tầm (Stationary Attacker).
	KEEP_DISTANCE, ## Giữ khoảng cách preferred_distance, tấn công trong tầm (Ranged).
}

## Nhìn trước bao nhiêu giây khi tránh vùng sáng.
const LIGHT_LOOKAHEAD: float = 0.3

@export var target: Node2D
@export var movement_mode: MovementMode = MovementMode.CHASE
@export var move_speed: float = 70.0
## Hệ số vận tốc theo trục dọc màn hình (cùng cơ chế với Player.vertical_speed_scale): 1 = map top-down cũ;
## map isometric 2:1 dùng 0.5 (IsoActorAdapter đặt) để tốc độ đều trên mặt đất.
@export var vertical_speed_scale: float = 1.0
## Chỉ phát hiện target trong khoảng này (px, từ chân tới chân).
@export var detection_range: float = 150.0
## Tỉ lệ của attack.attack_range dùng làm khoảng cách bắt đầu tấn công.
@export_range(0.1, 1.0) var attack_trigger_ratio: float = 0.8
## KEEP_DISTANCE: lùi lại khi target gần hơn preferred_distance × retreat_ratio.
@export var preferred_distance: float = 110.0
@export_range(0.1, 1.0) var retreat_ratio: float = 0.75
@export var attack: AttackComponent

@export_group("Quái đêm (TASK M4)")
## Loại enemy (khóa trong bảng spawn / save). Rỗng = enemy đặt tay không cần loại.
@export var enemy_id: StringName = &""
## ID lưu ổn định cho enemy đặt sẵn trong scene (HP, vị trí, đã chết). Rỗng = không tự lưu (enemy do EnemySpawner
## sinh ra được spawner lưu).
@export var save_id: String = ""
@export var detection: DetectionProfile
@export var wander_radius: float = 0.0
@export_range(0.1, 1.0) var wander_speed_ratio: float = 0.5
@export var alert_time: float = 0.0
@export_range(0.0, 1.0) var flee_health_ratio: float = 0.0
@export var light_averse: bool = false
## Khoảng đệm quanh vùng sáng (px mặt đất) quái sợ sáng giữ khoảng cách.
@export var light_margin: float = 6.0
## Quái sợ sáng lùi khi mục tiêu cầm đèn ở gần hơn bán kính đèn (phần cộng thêm của đuốc / đèn lồng) × hệ số này.
@export var held_light_repel_ratio: float = 1.5
@export var circle_radius: float = 0.0
## Tốc độ xoay vòng vây (radian/giây).
@export var circle_speed: float = 0.8
@export var lunge_speed_multiplier: float = 1.0
## Nghỉ sau khi nhả lượt tấn công của bầy (giây) để con khác vào.
@export var pack_rest_time: float = 1.2
## Đuốc của mục tiêu cháy nhanh gấp bao nhiêu lần khi quái sợ sáng lượn quanh vùng đèn (TASK M4.1).
@export var torch_drain_multiplier: float = 4.0
## Tốc độ lượn quanh rìa vùng sáng an toàn (radian/giây).
@export var light_hover_speed: float = 0.6

@export_group("Tìm đường (TASK M4.1)")
@export var use_navigation: bool = false
@export var unreachable_give_up_time: float = 3.0
@export var lost_cooldown: float = 6.0
## Quái gần nhau hơn khoảng này (px mặt đất) đẩy nhau ra.
@export var separation_radius: float = 16.0

## Bầy (EnemySpawner gán trước khi thêm vào cây). null = đánh đơn.
var pack: EnemyPack

var _state: State = State.IDLE
var _spawn_position: Vector2
## Tỉ lệ dọc của mặt đất cho khoảng cách AI (detection, tầm đánh, giữ khoảng cách). 1 = map cũ. Xem GroundSpace.
var _ground_squash: float = 1.0
var _alerted: bool = false
var _alert_left: float = 0.0
var _fleeing: bool = false
var _wander_point: Vector2
var _wander_wait: float = 0.0
var _pack_rest: float = 0.0
var _circle_angle: float = 0.0
var _fading: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _nav: NavigationAgent2D
var _nav_goal: Vector2 = Vector2.INF
var _unreachable_time: float = 0.0
var _lost_left: float = 0.0
var _hover_sign: float = 1.0
## Điểm lượn quanh vùng sáng gần nhất (đã kéo về navmesh) — test / debug.
var hover_point: Vector2 = Vector2.INF

@onready var _health: HealthComponent = $HealthComponent
@onready var _knockback: KnockbackComponent = $KnockbackComponent


func _ready() -> void:
	_spawn_position = global_position
	_wander_point = global_position
	_rng.randomize()
	_circle_angle = _rng.randf() * TAU
	_health.died.connect(_on_died)
	if attack != null:
		attack.attack_finished.connect(_on_attack_finished)
	if not save_id.is_empty():
		add_to_group(&"saveable")
	_hover_sign = 1.0 if _rng.randf() < 0.5 else -1.0
	if use_navigation:
		_nav = NavigationAgent2D.new()
		_nav.name = "NavigationAgent2D"
		_nav.path_desired_distance = 6.0
		_nav.target_desired_distance = 24.0
		_nav.path_max_distance = 40.0
		add_child(_nav)


func _exit_tree() -> void:
	if pack != null:
		pack.remove_member(self)


func _physics_process(delta: float) -> void:
	if _state == State.DEAD or _fading:
		return
	velocity = Vector2.ZERO
	_pack_rest = maxf(0.0, _pack_rest - delta)
	_lost_left = maxf(0.0, _lost_left - delta)
	_set_state(_think(delta))
	# Knockback cộng vào velocity rồi đi qua move_and_slide() nên vật cản vẫn chặn.
	velocity += _knockback.get_velocity()
	move_and_slide()


func get_state() -> State:
	return _state


func get_health() -> HealthComponent:
	return _health


func is_dead() -> bool:
	return _health.is_dead()


func is_fading() -> bool:
	return _fading


## Đang để ý mục tiêu (phát hiện / đuổi / vây / đánh) — dùng cho luật ngủ, chỉ báo ngoài màn hình.
func is_hunting() -> bool:
	return not is_dead() and not _fading and not _fleeing and _alerted


func is_fleeing() -> bool:
	return _fleeing


## Khoảng cách trên mặt đất tới một điểm world.
func ground_distance_to(point: Vector2) -> float:
	return GroundSpace.length(point - global_position, _ground_squash)


## Đang mất dấu mục tiêu không tới được (lang thang, bỏ qua mục tiêu).
func is_lost() -> bool:
	return _lost_left > 0.0


func get_navigation_agent() -> NavigationAgent2D:
	return _nav


## Bán kính phát hiện hiện tại đối với target (px mặt đất).
func get_detection_radius() -> float:
	if detection == null or not is_instance_valid(target):
		return detection_range
	return detection_range * detection.multiplier_for(target)


func get_ground_squash() -> float:
	return _ground_squash


## Reset thử nghiệm: về vị trí spawn, hồi đầy HP, hủy đòn đang đánh.
func reset_state() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_knockback.clear()
	if attack != null:
		attack.cancel()
	_health.reset()
	_alerted = false
	_fleeing = false
	_lost_left = 0.0
	_unreachable_time = 0.0
	_set_state(State.IDLE)


## Biến mất (TASK M4, bình minh): ngừng AI + nhận đòn, mờ dần `duration` giây rồi giải phóng. 0 = biến mất ngay.
func fade_out(duration: float) -> void:
	if _fading:
		return
	_fading = true
	velocity = Vector2.ZERO
	if attack != null:
		attack.cancel()
	if pack != null:
		pack.remove_member(self)
	for node: Node in find_children("*", "Hurtbox", true, false):
		(node as Area2D).set_deferred(&"monitorable", false)
	if duration <= 0.0 or not is_inside_tree():
		queue_free()
		return
	var tween: Tween = create_tween()
	tween.tween_property(self, ^"modulate:a", 0.0, duration)
	tween.tween_callback(queue_free)


## Áp trạng thái đã lưu (HP, vị trí, tầng). HP ≤ 0 → không áp (người gọi tự bỏ enemy).
func apply_saved(state: Dictionary) -> void:
	var hp: Variant = state.get("hp")
	if hp is int or hp is float:
		_health.restore(int(hp))
	var saved_position: Variant = state.get("position")
	if saved_position is Array and saved_position.size() == 2 and (saved_position[0] is float or saved_position[0] is int) \
			and (saved_position[1] is float or saved_position[1] is int):
		global_position = Vector2(saved_position[0], saved_position[1])
	var agent: ElevationAgent = ElevationAgent.find_for(self)
	var tier: Variant = state.get("tier", -1)
	if agent != null and (tier is int or tier is float) and int(tier) >= 0:
		agent.set_tier(int(tier))


## Trạng thái runtime để lưu: {hp, position, tier}.
func capture_state() -> Dictionary:
	var agent: ElevationAgent = ElevationAgent.find_for(self)
	return {
		"hp": _health.current_health,
		"position": [snappedf(global_position.x, 0.01), snappedf(global_position.y, 0.01)],
		"tier": agent.get_tier() if agent != null else -1,
	}


## Quyết định state và velocity (chưa gồm knockback) cho tick này.
func _think(delta: float) -> State:
	if attack == null:
		return State.IDLE
	if not _fleeing and flee_health_ratio > 0.0 and float(_health.current_health) < _health.max_health * flee_health_ratio:
		_fleeing = true
		if pack != null:
			pack.release_turn(self)
		attack.cancel()
	if _fleeing:
		return _flee()
	if not _has_live_target() or _lost_left > 0.0:
		_alerted = false
		return _idle_or_wander(delta)
	if attack.is_attacking():
		return State.ATTACK
	var to_target: Vector2 = target.global_position - global_position
	# Khoảng cách và hướng đo trên mặt đất; vận tốc màn hình = hướng mặt đất × (1, vertical_speed_scale).
	var ground: Vector2 = GroundSpace.to_ground(to_target, _ground_squash)
	var distance: float = ground.length()
	if light_averse:
		var escape: Vector2 = _light_escape(distance)
		if escape != Vector2.ZERO:
			velocity = _move_velocity((escape + _separation()).normalized())
			return State.AVOID_LIGHT
	var radius: float = get_detection_radius()
	var keep_range: float = radius * (detection.lose_multiplier if detection != null else 1.0)
	if distance > (keep_range if _alerted else radius):
		_alerted = false
		return _idle_or_wander(delta)
	if not _alerted:
		_alerted = true
		_alert_left = alert_time
		alerted.emit(self)
	if _alert_left > 0.0:
		_alert_left -= delta
		return State.ALERT
	if light_averse:
		var light: VisionLight = VisionLight.find_safe_light(_scene_root(), target.global_position, light_margin)
		if light != null:
			return _hover_light(light, delta)
	var in_range: bool = distance <= attack.attack_range * attack_trigger_ratio
	if movement_mode == MovementMode.KEEP_DISTANCE and distance < preferred_distance * retreat_ratio:
		velocity = -_move_velocity(ground / distance)
		return State.CHASE
	if pack != null and circle_radius > 0.0 and not _has_pack_turn(distance):
		return _circle(distance)
	if in_range:
		if attack.attack(to_target):
			return State.ATTACK
		return State.RECOVERY if attack.is_recovering() else State.ATTACK
	if movement_mode == MovementMode.STATIONARY:
		return State.IDLE
	var speed: float = lunge_speed_multiplier if pack != null and pack.get_attacker() == self else 1.0
	velocity = _steer_to(target.global_position, speed)
	if _nav != null and not _nav.get_current_navigation_path().is_empty() and not _nav.is_target_reachable():
		_unreachable_time += delta
		if _unreachable_time >= unreachable_give_up_time:
			_give_up()
			return _idle_or_wander(delta)
	else:
		_unreachable_time = 0.0
	return State.CHASE


func set_ground_squash(squash: float) -> void:
	_ground_squash = squash


func _move_velocity(ground_dir: Vector2) -> Vector2:
	return ground_dir * Vector2(1.0, vertical_speed_scale) * move_speed


## Vận tốc theo hướng mặt đất × hệ số tốc độ; quái sợ sáng bỏ thành phần đi vào vùng sáng (lượn dọc rìa).
func _steer(ground_dir: Vector2, speed_ratio: float = 1.0) -> Vector2:
	var direction: Vector2 = ground_dir
	if light_averse:
		direction = _avoid_light(direction)
	return _move_velocity(direction) * speed_ratio


## Vận tốc đi tới điểm world: theo đường tìm được (nếu có navmesh), tách khỏi quái gần, quái sợ sáng tránh vùng sáng.
func _steer_to(point: Vector2, speed_ratio: float = 1.0) -> Vector2:
	var direction: Vector2 = GroundSpace.direction(point - global_position, _ground_squash)
	if _nav != null:
		_sync_navigation_layer()
		if _nav_goal == Vector2.INF or _nav_goal.distance_to(point) > 8.0:
			_nav_goal = point
			_nav.target_position = point
		var next: Vector2 = _nav.get_next_path_position()
		if not _nav.get_current_navigation_path().is_empty() and next.distance_to(global_position) > 0.5:
			direction = GroundSpace.direction(next - global_position, _ground_squash)
	var separation: Vector2 = _separation()
	if separation != Vector2.ZERO:
		direction = (direction + separation).normalized()
	return _steer(direction, speed_ratio)


## Đẩy ra khỏi quái khác ở quá gần (hướng mặt đất, độ lớn ≤ 1).
func _separation() -> Vector2:
	if separation_radius <= 0.0 or not is_inside_tree():
		return Vector2.ZERO
	var push: Vector2 = Vector2.ZERO
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var other: Enemy = node as Enemy
		if other == null or other == self or other.is_dead():
			continue
		var away: Vector2 = GroundSpace.to_ground(global_position - other.global_position, _ground_squash)
		var d: float = away.length()
		if d < separation_radius:
			push += (away / maxf(d, 0.01)) * (1.0 - d / separation_radius) if d > 0.01 else Vector2.from_angle(_rng.randf() * TAU)
	return push.limit_length(1.0)


## Navigation layer = tầng hiện tại (ElevationAgent). Quái không đổi tầng (để sau) nên chỉ tìm đường trong tầng mình.
func _sync_navigation_layer() -> void:
	var agent: ElevationAgent = ElevationAgent.find_for(self)
	var layer: int = 1 << clampi(agent.get_tier() if agent != null else 0, 0, 31)
	if _nav.navigation_layers != layer:
		_nav.navigation_layers = layer
		_nav_goal = Vector2.INF


## Điểm world về navmesh của tầng mình (điểm cuối của đường tìm tới đó); không có navmesh → giữ nguyên.
func _snap_to_navmesh(point: Vector2) -> Vector2:
	if _nav == null or not is_inside_tree():
		return point
	var path: PackedVector2Array = NavigationServer2D.map_get_path(get_world_2d().navigation_map, global_position, point, true,
		_nav.navigation_layers)
	return path[path.size() - 1] if not path.is_empty() else point


func _give_up() -> void:
	_alerted = false
	_unreachable_time = 0.0
	_lost_left = lost_cooldown
	_nav_goal = Vector2.INF
	if pack != null:
		pack.release_turn(self)


## Mục tiêu đứng trong vùng sáng an toàn: lượn quanh rìa (điểm trên vòng ngoài vùng sáng, kéo về navmesh).
func _hover_light(light: VisionLight, delta: float) -> State:
	var rel: Vector2 = GroundSpace.to_ground(global_position - light.global_position, _ground_squash)
	var angle: float = rel.angle() + _hover_sign * maxf(light_hover_speed * delta, 0.0) + _hover_sign * 0.35
	var ring: float = light.radius + light_margin + 12.0
	hover_point = _snap_to_navmesh(light.global_position + GroundSpace.to_screen(Vector2.from_angle(angle) * ring, _ground_squash))
	velocity = _steer_to(hover_point, 0.8)
	return State.AVOID_LIGHT


## Bỏ thành phần hướng vào nguồn sáng an toàn sắp chạm (nhìn trước LIGHT_LOOKAHEAD giây).
func _avoid_light(ground_dir: Vector2) -> Vector2:
	var ahead: Vector2 = global_position + _move_velocity(ground_dir) * LIGHT_LOOKAHEAD
	var light: VisionLight = VisionLight.find_safe_light(_scene_root(), ahead, light_margin)
	if light == null:
		return ground_dir
	var outward: Vector2 = GroundSpace.direction(global_position - light.global_position, _ground_squash)
	var inward: float = minf(0.0, ground_dir.dot(outward))
	var tangent: Vector2 = ground_dir - outward * inward
	if tangent.length() < 0.2:
		tangent = outward.orthogonal() * (1.0 if ground_dir.cross(outward) <= 0.0 else -1.0)
	return tangent.normalized()


## Hướng (mặt đất) cần lùi để thoát ánh sáng; ZERO nếu không bị ánh sáng đe dọa.
func _light_escape(target_distance: float) -> Vector2:
	var light: VisionLight = VisionLight.find_safe_light(_scene_root(), global_position, light_margin)
	if light != null:
		return GroundSpace.direction(global_position - light.global_position, _ground_squash)
	if target.has_method(&"get_held_light_radius"):
		var held: float = float(target.call(&"get_held_light_radius"))
		var away: Vector2 = GroundSpace.direction(global_position - target.global_position, _ground_squash)
		if held > 0.0 and target_distance < held:
			return away
		if held > 0.0 and target_distance < held * held_light_repel_ratio:
			# Trong vành đèn: lượn quanh, giữ khoảng giữa vành, hút thời gian cháy của đuốc.
			if target.has_method(&"drain_held_light"):
				target.call(&"drain_held_light", torch_drain_multiplier)
			var middle: float = held * (1.0 + held_light_repel_ratio) * 0.5
			var radial: float = clampf((middle - target_distance) / maxf(held * 0.25, 1.0), -1.0, 1.0)
			return (away.orthogonal() * _hover_sign + away * radial).normalized()
	return Vector2.ZERO


func _idle_or_wander(delta: float) -> State:
	if wander_radius <= 0.0 or movement_mode == MovementMode.STATIONARY:
		return State.IDLE
	var light: VisionLight = VisionLight.find_safe_light(_scene_root(), global_position, light_margin) if light_averse else null
	if light != null:
		velocity = _move_velocity(GroundSpace.direction(global_position - light.global_position, _ground_squash))
		return State.AVOID_LIGHT
	if _wander_wait > 0.0:
		_wander_wait -= delta
		return State.IDLE
	var to_point: Vector2 = GroundSpace.to_ground(_wander_point - global_position, _ground_squash)
	if to_point.length() < 6.0:
		_wander_wait = _rng.randf_range(1.0, 3.0)
		var offset: Vector2 = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(wander_radius * 0.3, wander_radius)
		_wander_point = _snap_to_navmesh(_spawn_position + GroundSpace.to_screen(offset, _ground_squash))
		return State.IDLE
	velocity = _steer_to(_wander_point, wander_speed_ratio)
	return State.WANDER


func _flee() -> State:
	if not is_instance_valid(target):
		return State.FLEE
	var away: Vector2 = GroundSpace.to_ground(global_position - target.global_position, _ground_squash)
	if away.length() > maxf(detection_range, get_detection_radius()) * 2.0:
		return State.FLEE
	var away_dir: Vector2 = away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	velocity = _steer_to(global_position + GroundSpace.to_screen(away_dir * 160.0, _ground_squash))
	return State.FLEE


## Bầy: được lao vào khi đã ở gần (trong vòng vây) và giành được lượt; đang nghỉ sau lượt trước thì không.
func _has_pack_turn(distance: float) -> bool:
	if pack.get_attacker() == self:
		return true
	if _pack_rest > 0.0 or distance > circle_radius * 1.4:
		return false
	return pack.request_turn(self)


## Vây quanh mục tiêu ở bán kính circle_radius, các thành viên tản đều theo slot.
func _circle(distance: float) -> State:
	_circle_angle = fmod(_circle_angle + circle_speed * get_physics_process_delta_time(), TAU)
	var angle: float = _circle_angle + pack.get_slot(self) * TAU
	var spot: Vector2 = target.global_position + GroundSpace.to_screen(Vector2.from_angle(angle) * circle_radius, _ground_squash)
	var to_spot: Vector2 = GroundSpace.to_ground(spot - global_position, _ground_squash)
	if to_spot.length() < 4.0:
		return State.CIRCLE
	velocity = _steer_to(spot, 1.0 if distance > circle_radius * 1.4 else 0.8)
	return State.CHASE if distance > circle_radius * 1.4 else State.CIRCLE


func _set_state(state: State) -> void:
	if state != _state:
		_state = state
		state_changed.emit(_state)


func _has_live_target() -> bool:
	if not is_instance_valid(target):
		return false
	if target.has_method(&"is_dead"):
		var target_dead: bool = target.call(&"is_dead")
		return not target_dead
	return true


func _scene_root() -> Node:
	return get_tree().current_scene if is_inside_tree() else null


func _on_attack_finished() -> void:
	if pack != null and pack.get_attacker() == self:
		pack.release_turn(self)
		_pack_rest = pack_rest_time


func _on_died() -> void:
	velocity = Vector2.ZERO
	if attack != null:
		attack.cancel()
	if pack != null:
		pack.remove_member(self)
	_set_state(State.DEAD)


# --- Save (TASK M4) — chỉ enemy đặt sẵn có save_id; enemy do EnemySpawner sinh ra được spawner lưu. -----------

func get_save_id() -> String:
	return "enemy:" + save_id


func save_state() -> Dictionary:
	var state: Dictionary = capture_state()
	state["version"] = 1
	state["dead"] = is_dead()
	return state


## Đã chết trong save → bỏ khỏi map (không rơi đồ lại). Field thiếu → giữ giá trị của scene.
func load_state(state: Dictionary) -> void:
	if state.get("dead", false) == true:
		set_physics_process(false)
		queue_free()
		return
	apply_saved(state)
	_spawn_position = global_position
	_wander_point = global_position
