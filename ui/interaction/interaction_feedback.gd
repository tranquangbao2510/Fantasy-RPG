class_name InteractionFeedback
extends PanelContainer
## Thông báo kết quả tương tác, tự ẩn sau display_time giây.
## Thông báo mới thay thế thông báo cũ và đặt lại thời gian.

@export var display_time: float = 2.5

@onready var _label: Label = $Label
@onready var _hide_timer: Timer = $HideTimer


func _ready() -> void:
	hide()
	_hide_timer.timeout.connect(hide)


func show_message(message: String) -> void:
	if message.is_empty():
		return
	_label.text = message
	show()
	_hide_timer.start(display_time)
