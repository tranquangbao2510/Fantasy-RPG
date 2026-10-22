class_name DayNightSettings
extends Resource
## Ánh sáng ngày/đêm + tầm nhìn đêm (TASK M2). Giá trị mặc định + lý do: docs/architecture.md mục 2m.
## Độ tối `darkness` (0 ngày → 1 đêm) chuyển mượt trong bình minh / hoàng hôn theo các mốc của TimeSettings.

@export_group("Màu môi trường (NightOverlay)")
@export var day_color: Color = Color(1, 0.96, 0.86)
## Giữa bình minh / hoàng hôn.
@export var twilight_color: Color = Color(1, 0.72, 0.55)
## Ban đêm (TASK M3): không đen hẳn — ngoài vùng sáng còn ánh trăng `moonlight` (kênh sáng nhất của màu môi trường;
## 0.16 ≈ 13 % độ sáng), đủ thấy bóng cây và địa hình nhưng không rõ chi tiết. `moon_tint`: sắc lạnh của ánh trăng.
@export_range(0.0, 1.0) var moonlight: float = 0.16
@export var moon_tint: Color = Color(0.72, 0.82, 1.0)

@export_group("Tầm nhìn đêm")
## Bán kính nhìn quanh Player (px đo trên MẶT ĐẤT; trên map iso thành ellipse 2:1). 160 ≈ 3.5 ô lưới.
@export var base_vision_radius: float = 160.0
## Phần trong cùng (tỉ lệ bán kính) sáng hoàn toàn; từ đó mờ dần tới mép.
@export_range(0.0, 0.95) var vision_inner_ratio: float = 0.6
@export var vision_color: Color = Color(0.8, 0.85, 1.0)
@export var vision_energy: float = 1.0
## Điểm có độ nhìn thấy ≥ ngưỡng này coi là "thấy được" (dùng cho logic/test).
@export_range(0.0, 1.0) var visible_threshold: float = 0.5

@export_group("Cảnh báo (TASK M4)")
## Phút trong ngày hiện "Trời sắp tối…" (17:00 — TASK M4.1: trước giờ quái đêm sinh SpawnTable.night_from_minute ≥ 1 giờ game). "Màn đêm buông xuống" lúc TimeSettings.night_start (tối hẳn).
@export_range(0, 1439) var dusk_warning_minute: int = 1020


## Màu môi trường theo độ tối: ngày → hoàng hôn → đêm. `moon` < 0 = dùng `moonlight` (TASK M6: Cài đặt → độ sáng ban
## đêm truyền giá trị riêng, không sửa Resource dùng chung).
func sun_color(darkness: float, moon: float = -1.0) -> Color:
	if darkness <= 0.5:
		return day_color.lerp(twilight_color, darkness * 2.0)
	return twilight_color.lerp(night_color(moon), (darkness - 0.5) * 2.0)


## Màu môi trường lúc tối hẳn: moon_tint chuẩn hóa (kênh lớn nhất = 1) × moonlight (hoặc `moon` nếu ≥ 0).
func night_color(moon: float = -1.0) -> Color:
	var level: float = moon if moon >= 0.0 else moonlight
	var peak: float = maxf(maxf(moon_tint.r, moon_tint.g), maxf(moon_tint.b, 0.001))
	return Color(moon_tint.r / peak * level, moon_tint.g / peak * level, moon_tint.b / peak * level)
