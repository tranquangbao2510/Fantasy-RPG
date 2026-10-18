class_name IsoProjection
extends RefCounted
## Phép chiếu dimetric 2:1 dùng cho môi trường isometric (TASK VISUAL-02).
## Tile thoi 64×32 px world. Trục lưới: i → xuống-phải (đông nam), j → xuống-trái (tây nam).
## Điểm (i, j, z) — i, j theo đơn vị tile, z là độ cao px — chiếu lên màn hình:
##   x = (i − j) × 32,  y = (i + j) × 16 − z.
## Physics/collision vẫn ở không gian màn hình; hình thoi/ellipse 2:1 là footprint đúng trên mặt đất.

const TILE_SIZE: Vector2 = Vector2(64, 32)
const HALF: Vector2 = Vector2(32, 16)
## Chiều cao một tầng địa hình (px màn hình, đùn thẳng xuống).
const TIER_HEIGHT: float = 64.0
## Tỉ lệ dọc của mặt phẳng đất (ellipse/thoi dẹt 2:1).
const GROUND_SQUASH: float = 0.5


static func to_screen(i: float, j: float, z: float = 0.0) -> Vector2:
	return Vector2((i - j) * HALF.x, (i + j) * HALF.y - z)


## Ngược lại (z = 0): toạ độ lưới từ điểm màn hình.
static func to_grid(screen: Vector2) -> Vector2:
	return Vector2(screen.x / HALF.x + screen.y / HALF.y, screen.y / HALF.y - screen.x / HALF.x) * 0.5


## Polygon màn hình từ danh sách điểm lưới (i, j).
static func polygon(grid_points: PackedVector2Array, z: float = 0.0) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for g: Vector2 in grid_points:
		out.append(to_screen(g.x, g.y, z))
	return out


## Ellipse dẹt 2:1 (footprint trên mặt đất) quanh center, bán kính ngang rx.
static func ground_ellipse(center: Vector2, rx: float, sides: int = 12) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for k: int in sides:
		var a: float = TAU * k / sides
		out.append(center + Vector2(cos(a) * rx, sin(a) * rx * GROUND_SQUASH))
	return out
