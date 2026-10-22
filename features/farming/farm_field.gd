class_name FarmField
extends Node2D
## Một vùng ruộng định sẵn (TASK M5): lưới `columns` × `rows` ô, chỉ cày / trồng được trong vùng này (không trồng tự do
## khắp map). Data-driven: thêm vùng khác = thêm một node FarmField (con của FarmLayer) và chỉnh export, không sửa code.
## - Origin của node = góc trên của ô (0, 0); ô (c, r) có tâm `(c + 0.5) × axis_i + (r + 0.5) × axis_j` (map isometric:
##   mỗi ô = đúng 1 ô lưới iso → axis_i = (32, 16), axis_j = (−32, 16); TASK M6 — M5 dùng nửa ô).
## - Tạo FarmPlot (Interactable) cho từng ô lúc _ready; luật / trạng thái từng ô nằm trong FarmPlot.
## - Vẽ đất (lớp `Soil`, z −1 — dưới người chơi / cây): viền vùng ruộng; ô đã cày màu đất khô / ướt khác nhau.

@export var field_id: String = "field"
@export_range(1, 32) var columns: int = 6
@export_range(1, 32) var rows: int = 4
@export var axis_i: Vector2 = Vector2(32, 16)
@export var axis_j: Vector2 = Vector2(-32, 16)

@export_group("Màu đất (placeholder)")
@export var dry_soil_color: Color = Color(0.7, 0.53, 0.33)
@export var wet_soil_color: Color = Color(0.27, 0.17, 0.1)
@export var furrow_color: Color = Color(0, 0, 0, 0.18)
@export var outline_color: Color = Color(0.95, 0.85, 0.55, 0.5)

var _plots: Dictionary[Vector2i, FarmPlot] = {}
var _soil: Node2D


func _ready() -> void:
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
			plot.clump_offsets = _clump_offsets()
			add_child(plot)
			plot.changed.connect(func(_plot: FarmPlot) -> void: _soil.queue_redraw())
			_plots[plot.cell] = plot


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


func _draw_soil() -> void:
	var outline: PackedVector2Array = PackedVector2Array([Vector2.ZERO, columns * axis_i, columns * axis_i + rows * axis_j, rows * axis_j, Vector2.ZERO])
	_soil.draw_polyline(outline, outline_color, 1.0)
	for plot: FarmPlot in _plots.values():
		if not plot.tilled:
			continue
		var polygon: PackedVector2Array = cell_polygon(plot.cell, 0.06)
		_soil.draw_colored_polygon(polygon, wet_soil_color if plot.is_wet() else dry_soil_color)
		# Hai luống cày song song trục i.
		for t: float in [0.35, 0.65]:
			var from: Vector2 = polygon[0].lerp(polygon[3], t)
			var to: Vector2 = polygon[1].lerp(polygon[2], t)
			_soil.draw_line(from.lerp(to, 0.1), to.lerp(from, 0.1), furrow_color, 1.0)


## Khóm cây trong một ô: ô nhỏ (nửa ô lưới iso như M5) một khóm ở tâm; ô lớn hơn 4 khóm theo hai trục, sau → trước.
func _clump_offsets() -> PackedVector2Array:
	if axis_i.length() < 30.0:
		return PackedVector2Array([Vector2.ZERO])
	var a: Vector2 = axis_i * 0.22
	var b: Vector2 = axis_j * 0.22
	var offsets: Array[Vector2] = [-a - b, a - b, -a + b, a + b]
	offsets.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y < q.y)
	return PackedVector2Array(offsets)


## Vẽ lại đất (vd. sang ngày mới: đất ướt hôm qua thành khô).
func refresh_soil() -> void:
	if _soil != null:
		_soil.queue_redraw()
