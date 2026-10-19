extends SceneTree
## Kiểm thử headless cho combat trên map isometric (TASK VISUAL-02.1):
## 1. Enemy cùng tỉ lệ vận tốc dọc với Player; map cũ giữ 1.
## 2. Tầm đánh / vùng kỹ năng / tầm bay đạn đo trên mặt phẳng đất (tròn trên đất = ellipse 2:1).
## 3. Đòn đánh, kỹ năng, đạn chỉ trúng mục tiêu cùng tầng; hành lang cầu thang thuộc cả hai tầng; indicator theo tầng.
## 4. Đạn tầng 0 bị vách khối cao chặn; đạn bay qua mặt nước.
## + Hồi quy: map top-down cũ (world.tscn) vẫn đo tầm đánh theo màn hình, không lọc tầng.
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/environment/test_iso_combat.gd
## Thoát mã 1 nếu có ca thất bại.

const SCENE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"
const PROJECTILE_SCENE: PackedScene = preload("res://features/combat/projectile.tscn")
const GROUND_BURST: SkillDefinition = preload("res://features/skills/data/test_ground_burst.tres")
const S: float = IsoProjection.GROUND_SQUASH
## Mặc định IsoActorAdapter.vertical_speed_scale (VISUAL-02.2: 0.5 → 0.7 sau khi thử bằng slider).
const ISO_VERTICAL_SPEED: float = 0.7

var _world: Node
var _player: Player
var _player_agent: ElevationAgent
var _enemy: Enemy
var _enemy_agent: ElevationAgent
var _dummy: Node2D
var _dummy_health: HealthComponent
var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_world = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(_world)
	_player = _world.get_node("EntityContainer/Player") as Player
	_player_agent = _player.get_node("ElevationAgent") as ElevationAgent
	_enemy = _world.get_node("EntityContainer/SimpleEnemy") as Enemy
	_enemy_agent = _enemy.get_node("ElevationAgent") as ElevationAgent
	_dummy = _world.get_node("EntityContainer/TrainingDummy") as Node2D
	_dummy_health = _dummy.get_node("HealthComponent") as HealthComponent
	await _frames(5)
	await _test_speed_scale()
	await _test_melee_ground_range()
	await _test_skill_ground_area()
	await _test_projectile_ground_range()
	await _test_tier_filter()
	await _test_stairs_corridor()
	await _test_projectile_walls()
	await _test_legacy_map()
	print("RESULT %d/%d passed" % [_passed, _passed + _failed])
	quit(1 if _failed > 0 else 0)


func _check(label: String, ok: bool, detail: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if ok:
		_passed += 1
	else:
		_failed += 1


func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame


## Đặt thực thể tại điểm lưới (i, j) trên tầng `tier`, gán tầng cho agent.
func _place(body: Node2D, agent: ElevationAgent, grid: Vector2, tier: int) -> void:
	body.global_position = IsoProjection.to_screen(grid.x, grid.y, IsoProjection.TIER_HEIGHT * tier)
	if body is CharacterBody2D:
		(body as CharacterBody2D).velocity = Vector2.ZERO
	if agent != null:
		agent.initial_tier = tier
		agent.reset_state()


## Bãi thử trống trên tầng 0 (đồng cỏ phía nam) — xa vật cản, xa enemy/dummy khác.
const ARENA: Vector2 = Vector2(22.0, 35.0)


# ---------------------------------------------------------------- 1. tỉ lệ vận tốc dọc

func _test_speed_scale() -> void:
	_check("enemy_scale_matches_player", is_equal_approx(_enemy.vertical_speed_scale, _player.vertical_speed_scale) and is_equal_approx(_player.vertical_speed_scale, ISO_VERTICAL_SPEED),
		"player=%.2f enemy=%.2f" % [_player.vertical_speed_scale, _enemy.vertical_speed_scale])
	var legacy: Enemy = (load("res://entities/enemies/simple_enemy/simple_enemy.tscn") as PackedScene).instantiate() as Enemy
	_check("legacy_enemy_default_scale", is_equal_approx(legacy.vertical_speed_scale, 1.0))
	legacy.free()
	# Enemy đuổi Player thẳng theo chiều dọc màn hình: vận tốc dọc = move_speed × ISO_VERTICAL_SPEED.
	_place(_player, _player_agent, ARENA, 0)
	_place(_enemy, _enemy_agent, ARENA, 0)
	_enemy.global_position = _player.global_position + Vector2(0, -50)
	await _frames(4)
	var vy: float = absf(_enemy.velocity.y)
	_check("enemy_vertical_speed", absf(vy - _enemy.move_speed * ISO_VERTICAL_SPEED) < 1.0, "vy=%.1f move_speed=%.1f" % [vy, _enemy.move_speed])
	_enemy.global_position = _player.global_position + Vector2(-60, 0)
	await _frames(4)
	_check("enemy_horizontal_speed", absf(absf(_enemy.velocity.x) - _enemy.move_speed) < 1.0, "vx=%.1f" % _enemy.velocity.x)
	_park_enemy()


func _park_enemy() -> void:
	_place(_enemy, _enemy_agent, Vector2(4.0, 30.0), 0)
	await _frames(2)


# ---------------------------------------------------------------- 2. hình học trên mặt đất

## Player đánh thường về phía bù nhìn đặt lệch `offset` (màn hình) — trả về true nếu trúng.
func _swing_at(offset: Vector2, player_tier: int = 0, dummy_tier: int = 0) -> bool:
	_place(_player, _player_agent, ARENA, player_tier)
	await _frames(3)
	_dummy.global_position = _player.global_position + offset
	(_dummy.get_node("ElevationAgent") as ElevationAgent).initial_tier = dummy_tier
	(_dummy.get_node("ElevationAgent") as ElevationAgent).reset_state()
	_dummy_health.reset()
	await _frames(3)
	var attack: BasicAttackController = _player.get_node("BasicAttackController") as BasicAttackController
	attack.cancel()
	attack.set_aim_provider(func() -> Vector2: return offset)
	var before: int = _dummy_health.current_health
	attack.request_attack()
	await _frames(20)
	attack.cancel()
	return _dummy_health.current_health < before


func _test_melee_ground_range() -> void:
	# Kiếm thử, bước 1: tầm 32 px trên mặt đất; hurtbox bù nhìn bán kính 10 px trên mặt đất.
	_check("melee_hits_vertical_near", await _swing_at(Vector2(0, 14)), "ground dist 28")
	# Màn hình 24 px theo chiều dọc = 48 px trên mặt đất → ngoài tầm 32 + bán kính hurtbox 10 (theo màn hình thì sẽ trúng).
	_check("melee_misses_vertical_far", not await _swing_at(Vector2(0, 24)), "ground dist 48")
	_check("melee_hits_horizontal_near", await _swing_at(Vector2(28, 0)), "ground dist 28")
	_check("melee_misses_horizontal_far", not await _swing_at(Vector2(46, 0)), "ground dist 46")


func _test_skill_ground_area() -> void:
	var space: PhysicsDirectSpaceState2D = _player.get_world_2d().direct_space_state
	_place(_player, _player_agent, ARENA, 0)
	await _frames(3)
	var center: Vector2 = _player.global_position + Vector2(0, 40)
	var r: float = GROUND_BURST.radius
	var target: SkillTarget = SkillTarget.resolve(GROUND_BURST, _player.global_position, center, Vector2.DOWN, S)
	# Điểm ngắm 40 px màn hình theo chiều dọc = 80 px mặt đất (≤ cast_range) → không bị kẹp.
	_check("skill_target_not_clamped", target.point.is_equal_approx(center), "point=%s" % target.point)
	var far: SkillTarget = SkillTarget.resolve(GROUND_BURST, _player.global_position, _player.global_position + Vector2(0, 400), Vector2.DOWN, S)
	_check("skill_target_clamped_on_ground", absf((far.point - _player.global_position).y - GROUND_BURST.cast_range * S) < 0.5,
		"dy=%.1f" % (far.point - _player.global_position).y)
	(_dummy.get_node("ElevationAgent") as ElevationAgent).initial_tier = 0
	(_dummy.get_node("ElevationAgent") as ElevationAgent).reset_state()
	# Bù nhìn cách tâm r × 0.9 theo chiều ngang (mặt đất ≈ 0.9r) → trúng; theo chiều dọc màn hình r × 0.9 (mặt đất 1.8r) → trượt.
	_dummy.global_position = center + Vector2(r * 0.9, 0)
	await _frames(3)
	_check("skill_area_hits_horizontal", _found(space, target), "")
	_dummy.global_position = center + Vector2(0, r * 0.9)
	await _frames(3)
	_check("skill_area_misses_vertical", not _found(space, target), "")


func _found(space: PhysicsDirectSpaceState2D, target: SkillTarget) -> bool:
	var dummy_hurtbox: Hurtbox = _dummy.get_node("Hurtbox") as Hurtbox
	return SkillEffectExecutor.find_hurtboxes(GROUND_BURST, target, space, 32).has(dummy_hurtbox)


## Bắn một viên đạn từ `from` theo hướng màn hình `direction`; trả về [quãng màn hình đã bay, đã bị chặn sớm?].
func _shoot(from: Vector2, direction: Vector2, max_distance: float, obstacle_mask: int) -> Array:
	var projectile: Projectile = PROJECTILE_SCENE.instantiate() as Projectile
	var info: DamageInfo = DamageInfo.new(1, null)
	projectile.launch(info, direction, 400.0, max_distance, 0, S, obstacle_mask)
	_world.get_node("EntityContainer").add_child(projectile)
	projectile.global_position = from
	var last: Vector2 = from
	for i: int in 240:
		await physics_frame
		if not is_instance_valid(projectile) or projectile.is_spent():
			break
		last = projectile.global_position
	return [last - from]


func _test_projectile_ground_range() -> void:
	var from: Vector2 = IsoProjection.to_screen(ARENA.x, ARENA.y)
	var travelled: Vector2 = (await _shoot(from, Vector2.DOWN, 100.0, 0))[0]
	# 100 px trên mặt đất theo chiều dọc = 50 px màn hình (sai số một tick bay).
	_check("projectile_range_on_ground_vertical", absf(travelled.y - 50.0) < 8.0, "dy=%.1f" % travelled.y)
	travelled = (await _shoot(from, Vector2.RIGHT, 100.0, 0))[0]
	_check("projectile_range_on_ground_horizontal", absf(travelled.x - 100.0) < 8.0, "dx=%.1f" % travelled.x)


# ---------------------------------------------------------------- 3. lọc theo tầng

func _test_tier_filter() -> void:
	_check("melee_same_tier_hits", await _swing_at(Vector2(20, 0), 0, 0))
	_check("melee_other_tier_misses", not await _swing_at(Vector2(20, 0), 1, 0), "player tier 1, dummy tier 0 (cùng vị trí màn hình)")
	# Kỹ năng: DamageInfo mang tầng của người cast.
	var space: PhysicsDirectSpaceState2D = _player.get_world_2d().direct_space_state
	_place(_player, _player_agent, ARENA, 1)
	await _frames(3)
	var center: Vector2 = _player.global_position + Vector2(30, 0)
	_dummy.global_position = center
	(_dummy.get_node("ElevationAgent") as ElevationAgent).initial_tier = 0
	(_dummy.get_node("ElevationAgent") as ElevationAgent).reset_state()
	_dummy_health.reset()
	await _frames(3)
	var target: SkillTarget = SkillTarget.resolve(GROUND_BURST, _player.global_position, center, Vector2.DOWN, S)
	var hits: int = SkillEffectExecutor.execute(GROUND_BURST, target, _player, _player.get_health(), space, 32, _player_agent.get_tier_mask())
	_check("skill_other_tier_misses", hits == 0, "hits=%d" % hits)
	hits = SkillEffectExecutor.execute(GROUND_BURST, target, _player, _player.get_health(), space, 32, 1)
	_check("skill_same_tier_hits", hits == 1, "hits=%d" % hits)
	# Indicator kỹ năng vẽ ở z của tầng người cast.
	var caster: SkillCastingController = _player.get_node("SkillCastingController") as SkillCastingController
	_check("indicator_z_tier1", caster.get_indicator().z_index == ElevationMap.tier_z(1) + ElevationAgent.INDICATOR_Z_OFFSET, "z=%d" % caster.get_indicator().z_index)
	_place(_player, _player_agent, ARENA, 0)
	await _frames(3)
	_check("indicator_z_tier0", caster.get_indicator().z_index == ElevationMap.tier_z(0) + ElevationAgent.INDICATOR_Z_OFFSET, "z=%d" % caster.get_indicator().z_index)
	# Đạn: DamageInfo của RangedAttack mang tầng người bắn → Hurtbox khác tầng không nhận.
	var hurtbox: Hurtbox = _player.get_node("Hurtbox") as Hurtbox
	var bullet: DamageInfo = DamageInfo.new(5, _enemy)
	bullet.tier_mask = 1 << 1
	_check("projectile_damage_other_tier_rejected", not hurtbox.can_receive(bullet))
	bullet.tier_mask = 1 << 0
	_check("projectile_damage_same_tier_accepted", hurtbox.can_receive(bullet))
	var untiered: DamageInfo = DamageInfo.new(5, _enemy)
	_check("untiered_damage_accepted", hurtbox.can_receive(untiered), "map cũ: tier_mask = 0 không lọc")


func _test_stairs_corridor() -> void:
	# Giữa hành lang cầu thang: agent chuyển tầng, mask = tầng 0 | tầng 1 → trúng/bị trúng từ cả hai tầng.
	_player.global_position = IsoProjection.to_screen(10.75, 18.0, 32.0)
	_player.velocity = Vector2.ZERO
	await _frames(4)
	var hurtbox: Hurtbox = _player.get_node("Hurtbox") as Hurtbox
	_check("stairs_agent_transitioning", _player_agent.is_transitioning() and _player_agent.get_tier_mask() == 0b11, "mask=%d" % _player_agent.get_tier_mask())
	var low: DamageInfo = DamageInfo.new(5, _enemy)
	low.tier_mask = 1 << 0
	var high: DamageInfo = DamageInfo.new(5, _enemy)
	high.tier_mask = 1 << 1
	_check("stairs_hit_from_both_tiers", hurtbox.can_receive(low) and hurtbox.can_receive(high))
	_place(_player, _player_agent, ARENA, 0)
	await _frames(3)


# ---------------------------------------------------------------- 4. đạn và vách

func _test_projectile_walls() -> void:
	# Từ đồng cỏ trước mặt vách SW của plateau, bắn về phía plateau (hướng −j: lên-phải màn hình).
	# Làn bắn i = 12 không có vật cản nào khác trước chân vách (j = 17).
	var from: Vector2 = IsoProjection.to_screen(12.0, 21.0)
	var dir: Vector2 = IsoProjection.to_screen(0, -1)
	var wall_distance: float = GroundSpace.length(IsoProjection.to_screen(12.0, 17.0) - from, S)
	var blocked: Vector2 = (await _shoot(from, dir, 400.0, ElevationMap.tier_bit(0)))[0]
	_check("projectile_tier0_blocked_by_cliff", absf(GroundSpace.length(blocked, S) - wall_distance) < 12.0,
		"travel=%.0f wall=%.0f" % [GroundSpace.length(blocked, S), wall_distance])
	var free: Vector2 = (await _shoot(from, dir, 400.0, 0))[0]
	_check("projectile_without_tier_mask_not_blocked", GroundSpace.length(free, S) > wall_distance + 40.0, "travel=%.0f" % GroundSpace.length(free, S))
	# Qua suối: mặt nước chặn người đi nhưng không chặn đạn.
	var over: Vector2 = (await _shoot(IsoProjection.to_screen(24.0, 28.5), dir, 200.0, ElevationMap.tier_bit(0)))[0]
	_check("projectile_flies_over_water", GroundSpace.length(over, S) > 150.0, "travel=%.0f" % GroundSpace.length(over, S))


# ---------------------------------------------------------------- hồi quy map cũ

func _test_legacy_map() -> void:
	_world.queue_free()
	await _frames(2)
	var legacy: Node = (load("res://world/world.tscn") as PackedScene).instantiate()
	root.add_child(legacy)
	await _frames(5)
	var player: Player = legacy.get_node("EntityContainer/Player") as Player
	var dummy: Node2D = legacy.get_node("EntityContainer/TrainingDummy") as Node2D
	var health: HealthComponent = dummy.get_node("HealthComponent") as HealthComponent
	var attack: BasicAttackController = player.get_node("BasicAttackController") as BasicAttackController
	_check("legacy_player_scale", is_equal_approx(player.vertical_speed_scale, 1.0))
	# Map cũ: tầm 32 px đo theo màn hình. Chân Player cao hơn bù nhìn 18 px → gốc đòn (ngực, y −12) cách ~30 px
	# màn hình theo chiều dọc: vẫn trúng (cùng khoảng cách trên map iso = 60 px mặt đất → trượt).
	player.global_position = dummy.global_position + Vector2(0, -18)
	await _frames(3)
	attack.set_aim_provider(func() -> Vector2: return Vector2.DOWN)
	var before: int = health.current_health
	attack.request_attack()
	await _frames(20)
	_check("legacy_melee_screen_metric", health.current_health < before, "hp %d → %d" % [before, health.current_health])
	legacy.queue_free()
