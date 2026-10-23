@tool
class_name ObjectSprite
extends Sprite2D
## Hình của một đồ vật gameplay (TASK M7): ảnh PNG theo `asset` + `state`, thay cho Visual vẽ bằng Polygon2D.
## Mọi thông số đọc từ `object_art.json` (sinh bởi tools/object_art/generate_object_art.gd): file của từng trạng thái,
## kích thước ảnh, `anchor` (texel, điểm chạm đất = origin của node), `texel_scale` (0.5 = 2 texel / 1 px world).
## Thay art: ghi đè PNG cùng tên, cùng kích thước, chân vật đặt đúng anchor — không sửa scene / code.
## Đổi trạng thái bằng tên: `set_state(&"open")` (closed / open, full / depleted, stage_0..n...). Trạng thái không có
## trong JSON → push_error, giữ ảnh cũ. Bóng đổ KHÔNG nằm trong ảnh: ObjectShadow vẽ bằng code (xem style guide mục 13).

const CATALOG_PATH: String = "res://core/object_art/object_art.json"

@export var asset: StringName = &"":
	set(value):
		asset = value
		_refresh()
@export var state: StringName = &"default":
	set(value):
		state = value
		_refresh()

static var _catalog: Dictionary = {}

var _holding: bool = false


func _init() -> void:
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _ready() -> void:
	_refresh()


func set_state(value: StringName) -> void:
	state = value


## Đổi cả asset lẫn trạng thái cùng lúc (vd. ô ruộng đổi loại cây) — nạp ảnh một lần, không kiểm tra cặp trung gian.
func set_asset_state(new_asset: StringName, new_state: StringName) -> void:
	_holding = true
	asset = new_asset
	state = new_state
	_holding = false
	_refresh()


func get_state() -> StringName:
	return state


func has_state(value: StringName) -> bool:
	return get_asset_info(asset).get("states", {}).has(String(value))


## Tên các trạng thái của asset theo thứ tự trong JSON.
func get_states() -> PackedStringArray:
	return PackedStringArray((get_asset_info(asset).get("states", {}) as Dictionary).keys())


## Đường dẫn PNG của trạng thái hiện tại ("" nếu không có).
func get_texture_path() -> String:
	return texture.resource_path if texture != null else ""


## Thông tin một asset trong object_art.json ({} nếu không có).
static func get_asset_info(asset_name: StringName) -> Dictionary:
	return get_catalog().get("assets", {}).get(String(asset_name), {})


## Toàn bộ object_art.json (nạp một lần).
static func get_catalog() -> Dictionary:
	if _catalog.is_empty():
		var json: JSON = load(CATALOG_PATH) as JSON
		if json == null or not (json.data is Dictionary):
			push_error("[ObjectSprite] Không đọc được %s" % CATALOG_PATH)
			return {}
		_catalog = json.data
	return _catalog


## Đọc lại JSON ở lần dùng sau (tool / test sau khi sinh lại).
static func reload_catalog() -> void:
	_catalog = {}


func _refresh() -> void:
	if _holding or asset == &"" or not is_inside_tree():
		return
	var info: Dictionary = get_asset_info(asset)
	if info.is_empty():
		push_error("[ObjectSprite] %s: asset '%s' không có trong %s" % [get_path(), asset, CATALOG_PATH])
		return
	var file: String = str(info.get("states", {}).get(String(state), ""))
	if file.is_empty():
		push_error("[ObjectSprite] %s: asset '%s' không có trạng thái '%s'" % [get_path(), asset, state])
		return
	var anchor: Array = info.get("anchor", [0, 0])
	var texel_scale: float = float(get_catalog().get("texel_scale", 0.5))
	texture = load(str(info.get("dir", "")).path_join(file)) as Texture2D
	offset = -Vector2(float(anchor[0]), float(anchor[1]))
	scale = Vector2(texel_scale, texel_scale)
