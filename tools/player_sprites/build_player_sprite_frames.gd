extends SceneTree
## Sinh SpriteFrames cho Player từ entities/player/art/hero_sprites.json (TASK CHAR-01). Chạy lại khi sheet đổi:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/player_sprites/build_player_sprite_frames.gd
## (Sheet mới chưa import thì chạy `--import` trước.)
##
## Mỗi sheet: hàng = hướng (thứ tự `directions`), cột = frame. Mỗi hàng thành một animation `<tên>_<hướng>`
## (vd. `walk_SW`) với fps/loop gốc trong JSON. Frame là AtlasTexture có `margin` đệm để mọi frame của mọi animation
## cùng kích thước canvas và cùng điểm chân → sprite chỉ cần một `offset` duy nhất. Điểm chân trong canvas (px texel),
## `texel_scale` và danh sách hướng lưu trong metadata của SpriteFrames (`anchor`, `texel_scale`, `directions`).
## GHI ĐÈ entities/player/art/hero_sprite_frames.tres.

const ART_DIR: String = "res://entities/player/art/"
const JSON_PATH: String = ART_DIR + "hero_sprites.json"
const OUTPUT_PATH: String = ART_DIR + "hero_sprite_frames.tres"


func _init() -> void:
	quit(_build())


func _build() -> int:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(JSON_PATH))
	if not data is Dictionary:
		push_error("Không đọc được %s" % JSON_PATH)
		return 1
	var directions: Array = data["directions"]
	var animations: Dictionary = data["animations"]
	# Canvas chung: đủ chỗ cho phần bên trái/phải/trên/dưới điểm chân lớn nhất của mọi animation.
	var before: Vector2 = Vector2.ZERO
	var after: Vector2 = Vector2.ZERO
	for anim_name: String in animations:
		var spec: Dictionary = animations[anim_name]
		var size: Vector2 = _vec(spec["frame_size"])
		var anchor: Vector2 = _vec(spec["anchor"])
		before = before.max(anchor)
		after = after.max(size - anchor)
	var canvas: Vector2 = before + after
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim_name: String in animations:
		var spec: Dictionary = animations[anim_name]
		var texture: Texture2D = load(ART_DIR + String(spec["file"])) as Texture2D
		var size: Vector2 = _vec(spec["frame_size"])
		var anchor: Vector2 = _vec(spec["anchor"])
		var count: int = int(spec["frames"])
		if texture == null:
			push_error("Thiếu texture %s (chưa import?)" % spec["file"])
			return 1
		if int(spec["rows"]) != directions.size() or texture.get_size() != Vector2(size.x * count, size.y * directions.size()):
			push_error("%s: kích thước %s không khớp %d frame × %d hướng × %s" % [spec["file"], texture.get_size(), count, directions.size(), size])
			return 1
		var margin: Rect2 = Rect2(before - anchor, canvas - size)
		for row: int in directions.size():
			var animation: StringName = StringName("%s_%s" % [anim_name, directions[row]])
			frames.add_animation(animation)
			frames.set_animation_speed(animation, float(spec["fps"]))
			frames.set_animation_loop(animation, bool(spec["loop"]))
			for col: int in count:
				var atlas: AtlasTexture = AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(Vector2(col, row) * size, size)
				atlas.margin = margin
				# Lọc tuyến tính không lấy màu từ frame bên cạnh trong sheet.
				atlas.filter_clip = true
				frames.add_frame(animation, atlas)
	frames.set_meta(&"anchor", before)
	frames.set_meta(&"texel_scale", float(data["texel_scale"]))
	frames.set_meta(&"directions", PackedStringArray(directions))
	var err: Error = ResourceSaver.save(frames, OUTPUT_PATH)
	if err != OK:
		push_error("Lưu %s thất bại (%s)" % [OUTPUT_PATH, error_string(err)])
		return 1
	print("Đã ghi %s: %d animation, canvas %s, anchor %s" % [OUTPUT_PATH, frames.get_animation_names().size(), canvas, before])
	return 0


func _vec(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))
