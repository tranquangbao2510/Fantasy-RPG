extends RefCounted
## SINH TỰ ĐỘNG bởi extract_shapes.gd từ scene trước TASK M7 — hình polygon placeholder cũ của đồ vật gameplay.
## generate_object_art.gd vẽ lại các hình này vào PNG để game nhìn y như cũ. Không sửa tay trừ khi muốn đổi placeholder.

## "asset/state" → danh sách [màu, điểm polygon (toạ độ local so với origin = chân vật, px world)] theo thứ tự vẽ.
const SHAPES: Dictionary = {
	"workbench/default": [
		[Color(0.33, 0.21, 0.11, 1.0), [Vector2(-18.0, 0.0), Vector2(-15.0, 0.0), Vector2(-15.0, -14.0), Vector2(-18.0, -14.0)]],
		[Color(0.33, 0.21, 0.11, 1.0), [Vector2(15.0, 0.0), Vector2(18.0, 0.0), Vector2(18.0, -14.0), Vector2(15.0, -14.0)]],
		[Color(0.58, 0.39, 0.22, 1.0), [Vector2(-22.0, -14.0), Vector2(-12.0, -21.0), Vector2(22.0, -21.0), Vector2(12.0, -14.0)]],
		[Color(0.44, 0.29, 0.16, 1.0), [Vector2(-22.0, -14.0), Vector2(12.0, -14.0), Vector2(22.0, -21.0), Vector2(22.0, -18.0), Vector2(12.0, -11.0), Vector2(-22.0, -11.0)]],
		[Color(0.78, 0.8, 0.84, 1.0), [Vector2(-12.0, -18.0), Vector2(-2.0, -18.0), Vector2(-2.0, -16.0), Vector2(-12.0, -16.0)]],
		[Color(0.3, 0.3, 0.33, 1.0), [Vector2(6.0, -20.0), Vector2(12.0, -20.0), Vector2(12.0, -17.0), Vector2(10.0, -17.0), Vector2(10.0, -15.0), Vector2(8.0, -15.0), Vector2(8.0, -17.0), Vector2(6.0, -17.0)]],
	],
	"campfire/default": [
		[Color(0.45, 0.44, 0.42, 1.0), [Vector2(-14.0, -1.0), Vector2(-10.0, -6.0), Vector2(0.0, -8.0), Vector2(10.0, -6.0), Vector2(14.0, -1.0), Vector2(10.0, 4.0), Vector2(0.0, 6.0), Vector2(-10.0, 4.0), Vector2(-7.0, 1.0), Vector2(0.0, 3.0), Vector2(7.0, 1.0), Vector2(9.0, -2.0), Vector2(0.0, -4.0), Vector2(-9.0, -2.0)]],
		[Color(0.42, 0.26, 0.13, 1.0), [Vector2(-10.0, -2.0), Vector2(-8.0, -5.0), Vector2(9.0, 1.0), Vector2(7.0, 4.0)]],
		[Color(0.5, 0.31, 0.16, 1.0), [Vector2(-9.0, 2.0), Vector2(8.0, -5.0), Vector2(10.0, -2.0), Vector2(-7.0, 5.0)]],
	],
	"stone_mill/default": [
		[Color(0.46, 0.45, 0.43, 1.0), [Vector2(-14.0, -2.0), Vector2(-14.0, -10.0), Vector2(-10.0, -14.0), Vector2(0.0, -16.0), Vector2(10.0, -14.0), Vector2(14.0, -10.0), Vector2(14.0, -2.0), Vector2(10.0, 2.0), Vector2(0.0, 4.0), Vector2(-10.0, 2.0)]],
		[Color(0.62, 0.61, 0.58, 1.0), [Vector2(-12.0, -16.0), Vector2(-9.0, -19.0), Vector2(0.0, -21.0), Vector2(9.0, -19.0), Vector2(12.0, -16.0), Vector2(9.0, -12.0), Vector2(0.0, -11.0), Vector2(-9.0, -12.0)]],
		[Color(0.25, 0.24, 0.23, 1.0), [Vector2(-3.0, -16.0), Vector2(0.0, -17.5), Vector2(3.0, -16.0), Vector2(0.0, -14.5)]],
		[Color(0.45, 0.3, 0.17, 1.0), [Vector2(7.0, -17.0), Vector2(9.0, -17.0), Vector2(9.0, -27.0), Vector2(7.0, -27.0)]],
	],
	"chest/closed": [
		[Color(0.55, 0.33, 0.15, 1.0), [Vector2(-14.0, -18.0), Vector2(14.0, -18.0), Vector2(14.0, 0.0), Vector2(-14.0, 0.0)]],
		[Color(0.42, 0.24, 0.1, 1.0), [Vector2(-15.0, -24.0), Vector2(15.0, -24.0), Vector2(15.0, -17.0), Vector2(-15.0, -17.0)]],
		[Color(0.95, 0.8, 0.25, 1.0), [Vector2(-2.0, -17.0), Vector2(2.0, -17.0), Vector2(2.0, -11.0), Vector2(-2.0, -11.0)]],
	],
	"chest/open": [
		[Color(0.55, 0.33, 0.15, 1.0), [Vector2(-14.0, -14.0), Vector2(14.0, -14.0), Vector2(14.0, 0.0), Vector2(-14.0, 0.0)]],
		[Color(0.15, 0.08, 0.04, 1.0), [Vector2(-12.0, -18.0), Vector2(12.0, -18.0), Vector2(14.0, -14.0), Vector2(-14.0, -14.0)]],
		[Color(0.42, 0.24, 0.1, 1.0), [Vector2(-15.0, -30.0), Vector2(15.0, -30.0), Vector2(12.0, -18.0), Vector2(-12.0, -18.0)]],
	],
	"bed/default": [
		[Color(0.42, 0.27, 0.15, 1.0), [Vector2(-20.0, -10.0), Vector2(20.0, -10.0), Vector2(20.0, 0.0), Vector2(-20.0, 0.0)]],
		[Color(0.35, 0.45, 0.7, 1.0), [Vector2(-12.0, -16.0), Vector2(19.0, -16.0), Vector2(19.0, -9.0), Vector2(-12.0, -9.0)]],
		[Color(0.92, 0.9, 0.82, 1.0), [Vector2(-19.0, -17.0), Vector2(-13.0, -17.0), Vector2(-13.0, -10.0), Vector2(-19.0, -10.0)]],
	],
	"tent/default": [
		[Color(0.45, 0.4, 0.22, 1.0), [Vector2(-16.0, 0.0), Vector2(0.0, -28.0), Vector2(16.0, 0.0)]],
		[Color(0.62, 0.55, 0.3, 1.0), [Vector2(-18.0, 2.0), Vector2(-2.0, -26.0), Vector2(0.0, -28.0), Vector2(4.0, 2.0)]],
		[Color(0.2, 0.16, 0.08, 1.0), [Vector2(-6.0, 2.0), Vector2(0.0, -12.0), Vector2(4.0, 2.0)]],
	],
	"notice_board/default": [
		[Color(0.4, 0.26, 0.14, 1.0), [Vector2(-13.0, -16.0), Vector2(-9.0, -16.0), Vector2(-9.0, 0.0), Vector2(-13.0, 0.0)]],
		[Color(0.4, 0.26, 0.14, 1.0), [Vector2(9.0, -16.0), Vector2(13.0, -16.0), Vector2(13.0, 0.0), Vector2(9.0, 0.0)]],
		[Color(0.62, 0.44, 0.24, 1.0), [Vector2(-17.0, -38.0), Vector2(17.0, -38.0), Vector2(17.0, -15.0), Vector2(-17.0, -15.0)]],
		[Color(0.94, 0.92, 0.82, 1.0), [Vector2(-9.0, -34.0), Vector2(7.0, -34.0), Vector2(7.0, -20.0), Vector2(-9.0, -20.0)]],
	],
	"class_training_station/default": [
		[Color(0.4, 0.36, 0.32, 1.0), [Vector2(-11.0, -6.0), Vector2(11.0, -6.0), Vector2(9.0, 0.0), Vector2(-9.0, 0.0)]],
		[Color(0.55, 0.5, 0.45, 1.0), [Vector2(-4.0, -34.0), Vector2(4.0, -34.0), Vector2(4.0, -6.0), Vector2(-4.0, -6.0)]],
		[Color(0.7, 0.3, 0.85, 1.0), [Vector2(4.0, -34.0), Vector2(16.0, -34.0), Vector2(16.0, -20.0), Vector2(10.0, -23.0), Vector2(4.0, -20.0)]],
	],
	"death_bag/default": [
		[Color(0.5, 0.36, 0.2, 1.0), [Vector2(-9.0, -2.0), Vector2(-10.0, -10.0), Vector2(-5.0, -16.0), Vector2(5.0, -16.0), Vector2(10.0, -10.0), Vector2(9.0, -2.0), Vector2(0.0, 1.0)]],
		[Color(0.85, 0.2, 0.2, 1.0), [Vector2(-5.0, -17.0), Vector2(5.0, -17.0), Vector2(4.0, -14.0), Vector2(-4.0, -14.0)]],
	],
	"training_dummy/default": [
		[Color(0.4, 0.26, 0.14, 1.0), [Vector2(-2.0, -14.0), Vector2(2.0, -14.0), Vector2(2.0, 0.0), Vector2(-2.0, 0.0)]],
		[Color(0.85, 0.72, 0.38, 1.0), [Vector2(-9.0, -30.0), Vector2(9.0, -30.0), Vector2(10.0, -12.0), Vector2(-10.0, -12.0)]],
		[Color(0.75, 0.62, 0.3, 1.0), [Vector2(-16.0, -26.0), Vector2(16.0, -26.0), Vector2(16.0, -22.0), Vector2(-16.0, -22.0)]],
		[Color(0.92, 0.82, 0.5, 1.0), [Vector2(-5.0, -38.0), Vector2(5.0, -38.0), Vector2(6.0, -30.0), Vector2(-6.0, -30.0)]],
		[Color(0.8, 0.15, 0.15, 1.0), [Vector2(-3.0, -24.0), Vector2(3.0, -24.0), Vector2(3.0, -18.0), Vector2(-3.0, -18.0)]],
	],
	"tree_stump/default": [
		[Color(0.36, 0.24, 0.14, 1.0), [Vector2(-10.0, 0.0), Vector2(-10.0, -9.0), Vector2(10.0, -9.0), Vector2(10.0, 0.0), Vector2(6.0, 3.0), Vector2(-6.0, 3.0)]],
		[Color(0.78, 0.62, 0.42, 1.0), [Vector2(-10.0, -9.0), Vector2(-6.0, -12.0), Vector2(6.0, -12.0), Vector2(10.0, -9.0), Vector2(6.0, -6.0), Vector2(-6.0, -6.0)]],
	],
	"rock_node/depleted": [
		[Color(0.5, 0.5, 0.52, 1.0), [Vector2(-12.0, 0.0), Vector2(-9.0, -4.0), Vector2(-4.0, -4.0), Vector2(-2.0, 0.0), Vector2(-6.0, 2.0)]],
		[Color(0.58, 0.58, 0.6, 1.0), [Vector2(2.0, -1.0), Vector2(5.0, -6.0), Vector2(11.0, -5.0), Vector2(12.0, -1.0), Vector2(7.0, 2.0)]],
		[Color(0.45, 0.45, 0.47, 1.0), [Vector2(-3.0, 4.0), Vector2(0.0, 1.0), Vector2(4.0, 2.0), Vector2(3.0, 5.0)]],
	],
	"berry_bush/berries": [
		[Color(0.82, 0.12, 0.2, 1.0), [Vector2(-19.0, -30.0), Vector2(-18.0, -32.0), Vector2(-16.0, -33.0), Vector2(-14.0, -32.0), Vector2(-13.0, -30.0), Vector2(-14.0, -28.0), Vector2(-16.0, -27.0), Vector2(-18.0, -28.0)]],
		[Color(0.9, 0.18, 0.28, 1.0), [Vector2(-7.0, -40.0), Vector2(-6.0, -42.0), Vector2(-4.0, -43.0), Vector2(-2.0, -42.0), Vector2(-1.0, -40.0), Vector2(-2.0, -38.0), Vector2(-4.0, -37.0), Vector2(-6.0, -38.0)]],
		[Color(0.82, 0.12, 0.2, 1.0), [Vector2(7.0, -27.0), Vector2(8.0, -29.0), Vector2(10.0, -30.0), Vector2(12.0, -29.0), Vector2(13.0, -27.0), Vector2(12.0, -25.0), Vector2(10.0, -24.0), Vector2(8.0, -25.0)]],
		[Color(0.7, 0.1, 0.25, 1.0), [Vector2(15.0, -38.0), Vector2(16.0, -40.0), Vector2(18.0, -41.0), Vector2(20.0, -40.0), Vector2(21.0, -38.0), Vector2(20.0, -36.0), Vector2(18.0, -35.0), Vector2(16.0, -36.0)]],
		[Color(0.9, 0.18, 0.28, 1.0), [Vector2(-1.0, -22.0), Vector2(0.0, -24.0), Vector2(2.0, -25.0), Vector2(4.0, -24.0), Vector2(5.0, -22.0), Vector2(4.0, -20.0), Vector2(2.0, -19.0), Vector2(0.0, -20.0)]],
	],
	"wild_potato/full": [
		[Color(0.3, 0.55, 0.25, 1.0), [Vector2(-2.0, 0.0), Vector2(-12.0, -8.0), Vector2(-9.0, -12.0), Vector2(0.0, -3.0)]],
		[Color(0.34, 0.6, 0.27, 1.0), [Vector2(2.0, 0.0), Vector2(12.0, -9.0), Vector2(9.0, -13.0), Vector2(0.0, -3.0)]],
		[Color(0.38, 0.66, 0.3, 1.0), [Vector2(-2.0, 0.0), Vector2(-3.0, -14.0), Vector2(0.0, -18.0), Vector2(3.0, -14.0), Vector2(2.0, 0.0)]],
		[Color(0.92, 0.88, 0.95, 1.0), [Vector2(-2.0, -18.0), Vector2(0.0, -20.0), Vector2(2.0, -18.0), Vector2(0.0, -16.0)]],
	],
	"wild_potato/depleted": [
		[Color(0.36, 0.26, 0.17, 1.0), [Vector2(-8.0, 0.0), Vector2(-5.0, -3.0), Vector2(0.0, -4.0), Vector2(5.0, -3.0), Vector2(8.0, 0.0), Vector2(5.0, 3.0), Vector2(0.0, 4.0), Vector2(-5.0, 3.0)]],
	],
}

## asset → [màu, polygon] của bóng đổ vẽ bằng code (ObjectShadow) — cùng hình với Polygon2D "Shadow" cũ.
const SHADOWS: Dictionary = {
	"workbench": [Color(0.0, 0.0, 0.0, 0.35), [Vector2(-24.0, 0.0), Vector2(-14.0, -7.0), Vector2(14.0, -7.0), Vector2(24.0, 0.0), Vector2(14.0, 7.0), Vector2(-14.0, 7.0)]],
	"campfire": [Color(0.0, 0.0, 0.0, 0.3), [Vector2(-16.0, 0.0), Vector2(-11.0, -5.0), Vector2(0.0, -7.0), Vector2(11.0, -5.0), Vector2(16.0, 0.0), Vector2(11.0, 5.0), Vector2(0.0, 7.0), Vector2(-11.0, 5.0)]],
	"stone_mill": [Color(0.0, 0.0, 0.0, 0.35), [Vector2(-16.0, 0.0), Vector2(-11.0, -5.0), Vector2(0.0, -7.0), Vector2(11.0, -5.0), Vector2(16.0, 0.0), Vector2(11.0, 5.0), Vector2(0.0, 7.0), Vector2(-11.0, 5.0)]],
	"chest": [Color(0.0, 0.0, 0.0, 0.35), [Vector2(-16.0, 0.0), Vector2(-10.0, -3.0), Vector2(10.0, -3.0), Vector2(16.0, 0.0), Vector2(10.0, 3.0), Vector2(-10.0, 3.0)]],
	"bed": [Color(0.0, 0.0, 0.0, 0.35), [Vector2(-22.0, 0.0), Vector2(-14.0, -6.0), Vector2(14.0, -6.0), Vector2(22.0, 0.0), Vector2(14.0, 6.0), Vector2(-14.0, 6.0)]],
	"tent": [Color(0.0, 0.0, 0.0, 0.35), [Vector2(-20.0, 0.0), Vector2(-12.0, -6.0), Vector2(12.0, -6.0), Vector2(20.0, 0.0), Vector2(12.0, 6.0), Vector2(-12.0, 6.0)]],
	"notice_board": [Color(0.0, 0.0, 0.0, 0.35), [Vector2(-16.0, 0.0), Vector2(-10.0, -3.0), Vector2(10.0, -3.0), Vector2(16.0, 0.0), Vector2(10.0, 3.0), Vector2(-10.0, 3.0)]],
	"class_training_station": [Color(0.0, 0.0, 0.0, 0.35), [Vector2(-14.0, 0.0), Vector2(-9.0, -4.0), Vector2(9.0, -4.0), Vector2(14.0, 0.0), Vector2(9.0, 4.0), Vector2(-9.0, 4.0)]],
	"death_bag": [Color(0.0, 0.0, 0.0, 0.35), [Vector2(-11.0, 0.0), Vector2(-7.0, -3.0), Vector2(7.0, -3.0), Vector2(11.0, 0.0), Vector2(7.0, 3.0), Vector2(-7.0, 3.0)]],
	"training_dummy": [Color(0.0, 0.0, 0.0, 0.35), [Vector2(-12.0, 0.0), Vector2(-7.0, -3.0), Vector2(7.0, -3.0), Vector2(12.0, 0.0), Vector2(7.0, 3.0), Vector2(-7.0, 3.0)]],
	"tree_stump": [Color(0.0, 0.0, 0.0, 0.3), [Vector2(-14.0, 0.0), Vector2(-10.0, -5.0), Vector2(0.0, -7.0), Vector2(10.0, -5.0), Vector2(14.0, 0.0), Vector2(10.0, 5.0), Vector2(0.0, 7.0), Vector2(-10.0, 5.0)]],
	"wild_potato": [Color(0.0, 0.0, 0.0, 0.25), [Vector2(-12.0, 0.0), Vector2(-8.0, -4.0), Vector2(0.0, -5.0), Vector2(8.0, -4.0), Vector2(12.0, 0.0), Vector2(8.0, 4.0), Vector2(0.0, 5.0), Vector2(-8.0, 4.0)]],
}
