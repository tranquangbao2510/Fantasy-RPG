class_name DayNightSettings
extends Resource
## Ánh sáng ngày/đêm + tầm nhìn đêm (TASK M2). Giá trị mặc định + lý do: docs/architecture.md mục 2m.
## Độ tối `darkness` (0 ngày → 1 đêm) chuyển mượt trong bình minh / hoàng hôn theo các mốc của TimeSettings.

@export_group("Màu SunTint (CanvasModulate)")
@export var day_color: Color = Color(1, 0.96, 0.86)
## Giữa bình minh / hoàng hôn.
@export var twilight_color: Color = Color(1, 0.72, 0.55)
## Ban đêm: gần đen → ngoài vùng sáng là bóng tối thật (không thấy địa hình, quái, item).
@export var night_color: Color = Color(0.03, 0.035, 0.07)

@export_group("Tầm nhìn đêm")
## Bán kính nhìn quanh Player (px đo trên MẶT ĐẤT; trên map iso thành ellipse 2:1). 160 ≈ 3.5 ô lưới.
@export var base_vision_radius: float = 160.0
## Phần trong cùng (tỉ lệ bán kính) sáng hoàn toàn; từ đó mờ dần tới mép.
@export_range(0.0, 0.95) var vision_inner_ratio: float = 0.6
@export var vision_color: Color = Color(0.8, 0.85, 1.0)
@export var vision_energy: float = 1.0
## Điểm có độ nhìn thấy ≥ ngưỡng này coi là "thấy được" (dùng cho logic/test).
@export_range(0.0, 1.0) var visible_threshold: float = 0.5


## Màu SunTint theo độ tối: ngày → hoàng hôn → đêm.
func sun_color(darkness: float) -> Color:
	if darkness <= 0.5:
		return day_color.lerp(twilight_color, darkness * 2.0)
	return twilight_color.lerp(night_color, (darkness - 0.5) * 2.0)
