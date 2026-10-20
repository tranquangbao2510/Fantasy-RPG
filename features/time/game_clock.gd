class_name GameClock
extends Node
## Đồng hồ trong game (TASK M2). Một node trong World (KHÔNG phải Autoload). Thời gian = `total_minutes` tính từ
## 0:00 ngày 1; ngày mới bắt đầu lúc 0:00. Chạy theo `_process` nên dừng khi SceneTree bị pause (mở túi đồ không pause).
## - advance(phút): mọi thay đổi thời gian (trôi tự nhiên, ngủ, debug) đi qua đây → phát `time_passed` + các mốc
##   (`minute_changed`, `hour_changed` cho từng giờ vượt qua, `day_started` cho từng nửa đêm, `phase_changed`).
## - Hệ thống theo thời gian (đói, thể lực, ánh sáng) nghe signal; GameClock không biết họ.
## - Debug (chỉ build debug): `debug_time_fast` bật/tắt tua ×N, `debug_time_skip` nhảy +N phút.
## Save (group `saveable`, global — thời gian đi theo người chơi qua mọi map): {day, minute}.

signal minute_changed(day: int, minute_of_day: int)
signal hour_changed(day: int, hour: int)
signal day_started(day: int)
signal phase_changed(phase: Phase)
## Mọi lần thời gian trôi (kể cả nhảy giờ). sleeping: true khi do ngủ / ngất.
signal time_passed(game_minutes: float, sleeping: bool)

enum Phase { DAWN, DAY, DUSK, NIGHT }

const PHASE_NAMES: Array[String] = ["Bình minh", "Ban ngày", "Hoàng hôn", "Ban đêm"]
const MINUTES_PER_DAY: int = 1440
const STATE_VERSION: int = 1
## Group để node cần đọc giờ (lửa trại, TASK M3) tìm đồng hồ của map mà không cần đường dẫn.
const GROUP: StringName = &"game_clock"

@export var settings: TimeSettings
## false = đứng yên (vd. đang ngủ — màn hình mờ).
@export var running: bool = true

## Hệ số tốc độ (debug tua nhanh).
var time_scale: float = 1.0
var total_minutes: float = 0.0
var _phase: Phase = Phase.DAY


func _ready() -> void:
	add_to_group(GROUP)
	if settings == null or not settings.is_valid():
		push_warning("[GameClock] TimeSettings thiếu/không hợp lệ — dùng mặc định.")
		settings = TimeSettings.new()
	set_time(settings.start_day, settings.start_minute)


func _process(delta: float) -> void:
	if running:
		advance(delta * settings.get_minutes_per_second() * time_scale)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed(&"debug_time_fast"):
		time_scale = 1.0 if time_scale != 1.0 else settings.debug_fast_multiplier
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"debug_time_skip"):
		advance(settings.debug_skip_minutes)
		get_viewport().set_input_as_handled()


func get_day() -> int:
	return floori(total_minutes / MINUTES_PER_DAY) + 1


## Phút trong ngày (0..1439, có phần lẻ).
func get_minute_of_day() -> float:
	return fposmod(total_minutes, MINUTES_PER_DAY)


func get_hour() -> int:
	return floori(get_minute_of_day() / 60.0)


## 0..1 trong ngày (0 = 0:00).
func get_day_fraction() -> float:
	return get_minute_of_day() / MINUTES_PER_DAY


func get_phase() -> Phase:
	return _phase


func get_phase_name() -> String:
	return PHASE_NAMES[_phase]


## "06:05"
func format_time() -> String:
	var minute: int = floori(get_minute_of_day())
	return "%02d:%02d" % [minute / 60, minute % 60]


static func phase_at(minute_of_day: float, time: TimeSettings) -> Phase:
	if minute_of_day >= time.night_start or minute_of_day < time.dawn_start:
		return Phase.NIGHT
	if minute_of_day < time.day_start:
		return Phase.DAWN
	if minute_of_day < time.dusk_start:
		return Phase.DAY
	return Phase.DUSK


## Số phút từ bây giờ tới lần kế tiếp đồng hồ chỉ `minute_of_day` (luôn > 0, tối đa một ngày).
func minutes_until(minute_of_day: float) -> float:
	var diff: float = fposmod(minute_of_day - get_minute_of_day(), MINUTES_PER_DAY)
	return diff if diff > 0.0 else float(MINUTES_PER_DAY)


## Cho thời gian trôi `minutes` phút game và phát các mốc vượt qua.
func advance(minutes: float, sleeping: bool = false) -> void:
	if minutes <= 0.0:
		return
	var old_total: float = total_minutes
	total_minutes += minutes
	time_passed.emit(minutes, sleeping)
	var old_minute: int = floori(old_total)
	var new_minute: int = floori(total_minutes)
	if new_minute == old_minute:
		return
	for hour_index: int in range(floori(old_total / 60.0) + 1, floori(total_minutes / 60.0) + 1):
		var day: int = hour_index / 24 + 1
		var hour: int = hour_index % 24
		if hour == 0:
			day_started.emit(day)
		hour_changed.emit(day, hour)
	_emit_phase_changes(old_total)
	minute_changed.emit(get_day(), floori(get_minute_of_day()))


## Đặt thời gian (load save / bắt đầu). Không phát time_passed; phát minute_changed + phase_changed để UI làm mới.
func set_time(day: int, minute_of_day: float) -> void:
	total_minutes = (maxi(day, 1) - 1) * MINUTES_PER_DAY + clampf(minute_of_day, 0.0, MINUTES_PER_DAY - 0.001)
	minute_changed.emit(get_day(), floori(get_minute_of_day()))
	_update_phase(false)
	phase_changed.emit(_phase)


## Phát phase_changed cho từng mốc phase vượt qua trong (old_total, total_minutes] theo thứ tự (nhảy giờ dài vẫn báo
## đủ: ban ngày → hoàng hôn → đêm...).
func _emit_phase_changes(old_total: float) -> void:
	var day_index: int = floori(old_total / MINUTES_PER_DAY)
	while true:
		var base: float = day_index * MINUTES_PER_DAY
		for boundary: int in [settings.dawn_start, settings.day_start, settings.dusk_start, settings.night_start]:
			var at: float = base + boundary
			if at > old_total and at <= total_minutes:
				var phase: Phase = phase_at(float(boundary), settings)
				if phase != _phase:
					_phase = phase
					phase_changed.emit(_phase)
		if base + MINUTES_PER_DAY > total_minutes:
			break
		day_index += 1
	_update_phase(true)


func _update_phase(emit: bool) -> void:
	var phase: Phase = phase_at(get_minute_of_day(), settings)
	if phase != _phase:
		_phase = phase
		if emit:
			phase_changed.emit(_phase)


# --- Save ----------------------------------------------------------------------------------------

func get_save_id() -> String:
	return "clock"


func is_save_global() -> bool:
	return true


func save_state() -> Dictionary:
	return {"version": STATE_VERSION, "day": get_day(), "minute": snappedf(get_minute_of_day(), 0.01)}


func load_state(state: Dictionary) -> void:
	var day: Variant = state.get("day", settings.start_day)
	var minute: Variant = state.get("minute", settings.start_minute)
	set_time(int(day) if (day is int or day is float) else settings.start_day,
		float(minute) if (minute is int or minute is float) else float(settings.start_minute))
