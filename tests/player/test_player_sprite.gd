extends "res://tests/test_base.gd"
## Kiểm thử headless cho sprite 8 hướng của Player (TASK CHAR-01):
## 1. SpriteFrames sinh từ hero_sprites.json: đủ 9 animation × 8 hướng, anchor/texel_scale, sheet có mipmaps,
##    nhân vật cao < 64 px world.
## 2. Chọn hướng: 8 vector mặt đất → đúng hàng sheet, trên map iso (squash 0.5) và map cũ (squash 1).
## 3. Trạng thái → animation trong Environment Prototype: idle / run / walk, combo attack_1/2/3 (tua khớp
##    windup + active + recovery của mọi vũ khí thử), cast (tua theo cast time), hit (không chặn di chuyển),
##    death giữ frame cuối, reset về idle.
## 4. Map cũ (world.tscn): squash 1, hướng theo màn hình.
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/player/test_player_sprite.gd
## Thoát mã 1 nếu có ca thất bại.

const SCENE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"
const FRAMES: SpriteFrames = preload("res://entities/player/art/hero_sprite_frames.tres")
const SPRITES_JSON: String = "res://entities/player/art/hero_sprites.json"
const WEAPONS: Array[WeaponDefinition] = [
	preload("res://features/combat/weapons/data/test_sword.tres"),
	preload("res://features/combat/weapons/data/test_dagger.tres"),
	preload("res://features/combat/weapons/data/test_heavy.tres"),
]
const SELF_HEAL: SkillDefinition = preload("res://features/skills/data/test_self_heal.tres")
const S: float = IsoProjection.GROUND_SQUASH
## Bãi trống trên tầng 0 (giống test_iso_combat).
const ARENA: Vector2 = Vector2(22.0, 35.0)
## Hướng mặt đất của từng hàng sheet (S = về camera, theo chiều kim đồng hồ trên màn hình).
const GROUND_DIRECTIONS: Array[Vector2] = [
	Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(-1, -1),
	Vector2(0, -1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1),
]

var _world: Node
var _player: Player
var _sprite: PlayerSprite


func _run_tests() -> void:
	_test_frames()
	_test_direction_rows()
	_world = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(_world)
	_player = _world.get_node("EntityContainer/Player") as Player
	_sprite = _player.get_node("Visual/Sprite") as PlayerSprite
	await frames(5)
	_park_enemy()
	_place_player()
	await frames(3)
	await _test_locomotion()
	await _test_attack()
	await _test_cast()
	await _test_hit()
	await _test_death()
	await _test_legacy_map()


func _place_player() -> void:
	_player.reset_state()
	var agent: ElevationAgent = _player.get_node("ElevationAgent") as ElevationAgent
	_player.global_position = IsoProjection.to_screen(ARENA.x, ARENA.y)
	agent.initial_tier = 0
	agent.reset_state()


## Đưa enemy ra xa để không đánh Player trong lúc thử.
func _park_enemy() -> void:
	var enemy: Node2D = _world.get_node("EntityContainer/SimpleEnemy") as Node2D
	enemy.global_position = IsoProjection.to_screen(4.0, 30.0)
	enemy.set_physics_process(false)


# ---------------------------------------------------------------- 1. SpriteFrames

func _test_frames() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPRITES_JSON))
	var animations: Dictionary = data["animations"]
	var missing: Array[String] = []
	for anim_name: String in animations:
		var spec: Dictionary = animations[anim_name]
		for dir: String in PlayerSprite.DIRECTIONS:
			var full: StringName = StringName("%s_%s" % [anim_name, dir])
			if not FRAMES.has_animation(full) or FRAMES.get_frame_count(full) != int(spec["frames"]) \
					or not is_equal_approx(FRAMES.get_animation_speed(full), float(spec["fps"])) \
					or FRAMES.get_animation_loop(full) != bool(spec["loop"]):
				missing.append(String(full))
	check("frames_all_animations", missing.is_empty() and FRAMES.get_animation_names().size() == animations.size() * 8, str(missing))
	check("frames_directions_order", Array(FRAMES.get_meta(&"directions")) == Array(PlayerSprite.DIRECTIONS))
	check("frames_texel_scale", is_equal_approx(FRAMES.get_meta(&"texel_scale"), float(data["texel_scale"])))
	# Mọi frame (mọi animation) cùng canvas; điểm chân của từng animation rơi đúng `anchor` chung.
	var anchor: Vector2 = FRAMES.get_meta(&"anchor")
	var aligned: bool = true
	for anim_name: String in animations:
		var spec: Dictionary = animations[anim_name]
		var atlas: AtlasTexture = FRAMES.get_frame_texture(StringName(anim_name + "_S"), 0) as AtlasTexture
		var own_anchor: Vector2 = Vector2(spec["anchor"][0], spec["anchor"][1])
		aligned = aligned and atlas.margin.position + own_anchor == anchor and atlas.filter_clip
	check("frames_anchor_aligned", aligned, "anchor=%s" % anchor)
	var mipmapped: bool = true
	for anim_name: String in animations:
		var texture: Texture2D = load("res://entities/player/art/" + String(animations[anim_name]["file"]))
		mipmapped = mipmapped and texture.get_image().has_mipmaps()
	check("sheets_have_mipmaps", mipmapped)
	# Chiều cao nhân vật (phần đục của idle_S frame 0, từ đỉnh tới điểm chân) đổi sang px world.
	var idle: Dictionary = animations["idle"]
	var image: Image = (load("res://entities/player/art/" + String(idle["file"])) as Texture2D).get_image()
	image.clear_mipmaps()
	var used: Rect2i = image.get_region(Rect2i(0, 0, int(idle["frame_size"][0]), int(idle["frame_size"][1]))).get_used_rect()
	var height: float = (float(idle["anchor"][1]) - used.position.y) * float(data["texel_scale"])
	check("character_height_under_64", height > 20.0 and height < 64.0, "height=%.1f px world" % height)


# ---------------------------------------------------------------- 2. chọn hướng

func _test_direction_rows() -> void:
	var iso_ok: bool = true
	var legacy_ok: bool = true
	for row: int in GROUND_DIRECTIONS.size():
		var ground: Vector2 = GROUND_DIRECTIONS[row]
		iso_ok = iso_ok and PlayerSprite.direction_index(GroundSpace.to_screen(ground, S), S) == row
		legacy_ok = legacy_ok and PlayerSprite.direction_index(ground, 1.0) == row
	check("direction_rows_iso", iso_ok)
	check("direction_rows_legacy", legacy_ok)
	# Cùng vector màn hình (1, 0.4): trên mặt đất iso là (1, 0.8) → SE; map cũ góc 22° → E.
	check("direction_uses_ground_plane", PlayerSprite.direction_index(Vector2(1, 0.4), S) == 7
		and PlayerSprite.direction_index(Vector2(1, 0.4), 1.0) == 6)
	# Lệch 20° so với W vẫn làm tròn về W.
	check("direction_rounds_to_nearest", PlayerSprite.direction_index(GroundSpace.to_screen(Vector2.from_angle(PI + 0.35), S), S) == 2)


# ---------------------------------------------------------------- 3. trạng thái → animation

func _hold(actions: Array[StringName], frames: int) -> void:
	for action: StringName in actions:
		Input.action_press(action)
	await frames(frames)


func _release(actions: Array[StringName]) -> void:
	for action: StringName in actions:
		Input.action_release(action)


func _test_locomotion() -> void:
	check("iso_squash", is_equal_approx(_sprite._ground_squash, S))
	check("start_idle_S", _sprite.animation == &"idle_S" and _sprite.is_playing(), String(_sprite.animation))
	var cases: Array = [
		[[&"move_right"], &"run_E"],
		[[&"move_down"], &"run_S"],
		[[&"move_up", &"move_left"], &"run_NW"],
		[[&"move_up", &"move_right"], &"run_NE"],
	]
	for c: Array in cases:
		var actions: Array[StringName] = []
		actions.assign(c[0])
		await _hold(actions, 6)
		check("move_%s" % c[1], _sprite.animation == c[1], String(_sprite.animation))
		_release(actions)
		await frames(3)
		# Thả phím: đứng yên, giữ hướng vừa đi.
		var idle: StringName = StringName(String(c[1]).replace("run_", "idle_"))
		check("release_%s" % idle, _sprite.animation == idle, String(_sprite.animation))
		_place_player()
		await frames(2)
	# Chậm hơn ngưỡng run (vd. passive làm chậm) → walk.
	var speed: float = _player.move_speed
	_player.move_speed = _sprite.run_speed_threshold * 0.6
	await _hold([&"move_left"], 6)
	check("slow_move_walk", _sprite.animation == &"walk_W", String(_sprite.animation))
	_release([&"move_left"])
	_player.move_speed = speed
	_place_player()
	await frames(2)


func _test_attack() -> void:
	var attack: BasicAttackController = _player.get_node("BasicAttackController") as BasicAttackController
	var equipment: WeaponEquipment = _player.get_node("WeaponEquipment") as WeaponEquipment
	# Luật class ↔ vũ khí không thuộc phạm vi test này: bỏ để thử đủ 3 vũ khí.
	equipment.set_equip_validator(Callable())
	# Đánh về phía trên-trái màn hình (mặt đất NW).
	attack.set_aim_provider(func() -> Vector2: return GroundSpace.to_screen(Vector2(-1, -1), S))
	for weapon: WeaponDefinition in WEAPONS:
		check("equip_%s" % weapon.weapon_id, equipment.equip_weapon(weapon))
		var timing_ok: bool = true
		var anim_ok: bool = true
		var finish_ok: bool = true
		var detail: String = ""
		for step: int in weapon.combo.get_step_count():
			attack.request_attack()
			await frames(1)
			var data: ComboStepDefinition = weapon.combo.get_step(step)
			var expected: StringName = StringName("%s_NW" % PlayerSprite.attack_animation(step))
			var target: float = data.windup + data.active + data.recovery
			anim_ok = anim_ok and _sprite.animation == expected
			timing_ok = timing_ok and absf(_sprite.get_action_duration() - target) < 0.001 \
				and is_equal_approx(_sprite.speed_scale, _sprite.get_native_duration(PlayerSprite.attack_animation(step)) / target)
			while attack.is_attacking():
				await physics_frame
			# Hết recovery thì animation cũng vừa tới (gần) frame cuối.
			var last: int = _sprite.sprite_frames.get_frame_count(expected) - 1
			finish_ok = finish_ok and _sprite.frame >= last - 2
			detail += "%s:%s f%d/%d " % [step, _sprite.animation, _sprite.frame, last]
			await frames(1)
		check("attack_animations_%s" % weapon.weapon_id, anim_ok, detail)
		check("attack_speed_matches_step_%s" % weapon.weapon_id, timing_ok)
		check("attack_ends_with_step_%s" % weapon.weapon_id, finish_ok, detail)
		while attack.get_phase() != BasicAttackController.Phase.READY:
			await physics_frame
		await frames(1)
		check("after_combo_idle_%s" % weapon.weapon_id, _sprite.animation == &"idle_NW", String(_sprite.animation))
	equipment.equip_weapon(WEAPONS[0])
	check("attack_animation_cycle", PlayerSprite.attack_animation(3) == &"attack_1" and PlayerSprite.attack_animation(2) == &"attack_3")


func _test_cast() -> void:
	var loadout: SkillLoadout = _player.get_node("SkillLoadout") as SkillLoadout
	var caster: SkillCastingController = _player.get_node("SkillCastingController") as SkillCastingController
	loadout.set_equip_validator(Callable())
	var slot: int = 3
	loadout.unequip_skill(slot)
	check("equip_self_heal", loadout.equip_skill(slot, SELF_HEAL))
	loadout.set_cast_mode(slot, SkillDefinition.CastMode.INSTANT)
	var press: InputEventAction = InputEventAction.new()
	press.action = SkillCastingController.SLOT_ACTIONS[slot]
	press.pressed = true
	caster.handle_input(press)
	await frames(1)
	check("cast_animation", _sprite.get_animation_base() == &"cast" and caster.get_state() == SkillCastingController.State.CASTING,
		String(_sprite.animation))
	check("cast_speed_matches_cast_time", absf(_sprite.get_action_duration() - SELF_HEAL.cast_time) < 0.001,
		"%.3f vs %.3f" % [_sprite.get_action_duration(), SELF_HEAL.cast_time])
	while caster.is_busy():
		await physics_frame
	await frames(2)
	check("cast_ends_idle", _sprite.get_animation_base() == &"idle", String(_sprite.animation))
	# Kỹ năng không vận sức vẫn phát cast tối thiểu; hủy cast → về locomotion ngay.
	caster.cast_started.emit(slot, 0.0)
	await frames(1)
	check("instant_cast_min_duration", absf(_sprite.get_action_duration() - _sprite.min_cast_duration) < 0.001)
	caster.cast_cancelled.emit(slot)
	await frames(1)
	check("cast_cancel_idle", _sprite.get_animation_base() == &"idle", String(_sprite.animation))


func _test_hit() -> void:
	var health: HealthComponent = _player.get_health()
	health.reset()
	health.apply_damage(1)
	await frames(1)
	check("hit_animation", _sprite.get_animation_base() == &"hit", String(_sprite.animation))
	# Không chặn input: vẫn đi được ngay trong lúc phát hit.
	var start: Vector2 = _player.global_position
	await _hold([&"move_right"], 4)
	check("hit_does_not_block_movement", _player.global_position.x > start.x + 4.0 and _sprite.get_animation_base() == &"hit",
		"dx=%.1f %s" % [_player.global_position.x - start.x, _sprite.animation])
	_release([&"move_right"])
	await seconds(_sprite.hit_duration + 0.05)
	check("hit_ends", _sprite.get_animation_base() == &"idle", String(_sprite.animation))
	# Đang đánh thì bị trúng không ngắt animation đòn.
	var attack: BasicAttackController = _player.get_node("BasicAttackController") as BasicAttackController
	attack.request_attack()
	await frames(1)
	health.apply_damage(1)
	await frames(1)
	check("hit_keeps_attack", _sprite.get_animation_base() == &"attack_1", String(_sprite.animation))
	while attack.get_phase() != BasicAttackController.Phase.READY:
		await physics_frame
	_place_player()
	await frames(2)


func _test_death() -> void:
	var health: HealthComponent = _player.get_health()
	_sprite.set_facing(GroundSpace.to_screen(Vector2(1, 0), S))
	health.apply_damage(health.max_health)
	await frames(1)
	check("death_animation", _sprite.animation == &"death_E", String(_sprite.animation))
	await seconds(_sprite.death_duration + 0.2)
	var last: int = _sprite.sprite_frames.get_frame_count(&"death_E") - 1
	check("death_holds_last_frame", _sprite.animation == &"death_E" and _sprite.frame == last and not _sprite.is_playing(),
		"%s f%d/%d" % [_sprite.animation, _sprite.frame, last])
	_place_player()
	await frames(2)
	check("reset_idle_S", _sprite.animation == &"idle_S" and _sprite.is_playing(), String(_sprite.animation))


# ---------------------------------------------------------------- 4. map cũ

func _test_legacy_map() -> void:
	_world.queue_free()
	await frames(2)
	var legacy: Node = (load("res://world/world.tscn") as PackedScene).instantiate()
	root.add_child(legacy)
	await frames(5)
	var player: Player = legacy.get_node("EntityContainer/Player") as Player
	var sprite: PlayerSprite = player.get_node("Visual/Sprite") as PlayerSprite
	check("legacy_squash", is_equal_approx(sprite._ground_squash, 1.0))
	check("legacy_offset_scale", sprite.offset == -(FRAMES.get_meta(&"anchor") as Vector2) and sprite.scale == Vector2(0.5, 0.5))
	await _hold([&"move_up", &"move_right"], 6)
	check("legacy_move_NE", sprite.animation == &"run_NE", String(sprite.animation))
	_release([&"move_up", &"move_right"])
	legacy.queue_free()
