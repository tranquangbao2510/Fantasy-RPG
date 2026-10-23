class_name FarmField
extends Node2D
## Một vùng ruộng định sẵn (TASK M5): lưới `columns` × `rows` ô, chỉ cày / trồng được trong vùng này (không trồng tự do
## khắp map). Data-driven: thêm vùng khác = thêm một node FarmField (con của FarmLayer) và chỉnh export, không sửa code.
## - Origin của node = góc trên của ô (0, 0); ô (c, r) có tâm `(c + 0.5) × axis_i + (r + 0.5) × axis_j` (map isometric:
##   mỗi ô = đúng 1 ô lưới iso → axis_i = (32, 16), axis_j = (−32, 16); TASK M6 — M5 dùng nửa ô).
## - Tạo FarmPlot (Interactable) cho từng ô lúc _ready; luật / trạng thái từng ô nằm trong FarmPlot.
## - Đất (lớp `Soil`, z −1 — dưới người chơi / cây): viền vùng ruộng vẽ bằng code; ô đã cày là ObjectSprite `soil_tilled`
##   (TASK M7, ảnh đất khô); đất ướt = cùng ảnh nhân `wet_soil_tint` (không có ảnh riêng).
## - Group `farm_fields`: PlacementCheck không cho dựng lều / lửa trại chạm vùng ruộng ("Quá gần ruộng", TASK M6.1).

const GROUP: StringName = &"farm_fields"

@export var field_id: String = "field"
@export_range(1, 32) var columns: int = 6
@export_range(1, 32) var rows: int = 4
@export var axis_i: Vector2 = Vector2(32, 16)
@export var axis_j: Vector2 = Vector2(-32, 16)

@export_group("Đất")
## Tint của ảnh đất cày khi ướt (ảnh khô × tint). Mặc định = màu ướt / màu khô của placeholder M5 → y như trước.
@export var wet_soil_tint: Color = Color(0.27 / 0.7, 0.17 / 0.53, 0.1 / 0.33)
@export var outline_color: Color = Color(0.95, 0.85, 0.55, 0.5)

var _plots: Dictionary[Vector2i, FarmPlot] = {}
var _soil: Node2D
var _soil_sprites: Dictionary[Vector2i, ObjectSprite] = {}


func _ready() -> void:
	add_to_group(GROUP)
	y_sort_enabled = true
	_soil = Node2D.new()
	_soil.name = "Soil"
	_soil.z_index = -1
	add_child(_soil)
	_soil.draw.connect(_draw_soil)
	for r: int in rows:
		for c: int in columns:
			var plot: FarmPlot = FarmPlot.new()
			plot.name = "Plot_%d_%d" % [c, r]
			plot.cell = Vector2i(c, r)
			plot.position = cell_center(Vector2i(c, r))
			add_child(plot)
			var soil: ObjectSprite = ObjectSprite.new()
			soil.name = "Soil_%d_%d" % [c, r]
			soil.position = plot.position
			soil.asset = &"soil_tilled"
			_soil.add_child(soil)
			_soil_sprites[plot.cell] = soil
			plot.changed.connect(_update_soil)
			_plots[plot.cell] = plot
			_update_soil(plot)


func get_layer() -> FarmLayer:
	return get_parent() as FarmLayer


## Tâm ô (toạ độ local của field).
func cell_center(cell: Vector2i) -> Vector2:
	return (cell.x + 0.5) * axis_i + (cell.y + 0.5) * axis_j


func get_plot(cell: Vector2i) -> FarmPlot:
	return _plots.get(cell)


func get_plots() -> Array[FarmPlot]:
	var result: Array[FarmPlot] = []
	result.assign(_plots.values())
	return result


## Ô chứa điểm world (null nếu ngoài vùng ruộng).
func plot_at(world_point: Vector2) -> FarmPlot:
	var local: Vector2 = to_local(world_point)
	var basis: Transform2D = Transform2D(axis_i, axis_j, Vector2.ZERO)
	var grid: Vector2 = basis.affine_inverse() * local
	var cell: Vector2i = Vector2i(floori(grid.x), floori(grid.y))
	return _plots.get(cell)


## Đa giác (local) của một ô.
func cell_polygon(cell: Vector2i, inset: float = 0.0) -> PackedVector2Array:
	var a: Vector2 = cell.x * axis_i + cell.y * axis_j
	var corners: PackedVector2Array = PackedVector2Array([a, a + axis_i, a + axis_i + axis_j, a + axis_j])
	if inset <= 0.0:
		return corners
	var center: Vector2 = cell_center(cell)
	for k: int in corners.size():
		corners[k] = corners[k].lerp(center, inset)
	return corners


## Viền vùng ruộng (vẽ bằng code, dưới ảnh đất cày).
func _draw_soil() -> void:
	var outline: PackedVector2Array = PackedVector2Array([Vector2.ZERO, columns * axis_i, columns * axis_i + rows * axis_j, rows * axis_j, Vector2.ZERO])
	_soil.draw_polyline(outline, outline_color, 1.0)


## Ảnh đất cày của một ô: hiện khi đã cày, tint khi ướt.
func get_soil_sprite(cell: Vector2i) -> ObjectSprite:
	return _soil_sprites.get(cell)


func _update_soil(plot: FarmPlot) -> void:
	var soil: ObjectSprite = _soil_sprites.get(plot.cell)
	if soil == null:
		return
	soil.visible = plot.tilled
	soil.modulate = wet_soil_tint if plot.is_wet() else Color.WHITE


## Cập nhật lại đất (vd. sang ngày mới: đất ướt hôm qua thành khô).
func refresh_soil() -> void:
	for plot: FarmPlot in _plots.values():
		_update_soil(plot)
