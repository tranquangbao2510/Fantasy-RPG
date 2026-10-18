class_name ComboDefinition
extends Resource
## Chuỗi đánh thường của một loại vũ khí (dữ liệu thiết kế, chỉ đọc lúc chạy).

@export var steps: Array[ComboStepDefinition] = []
## Nhấn sớm trong khoảng này (giây) trước khi bước hiện tại kết thúc recovery sẽ được ghi nhớ (tối đa 1 lần).
@export var input_buffer: float = 0.2


func get_step_count() -> int:
	return steps.size()


func get_step(index: int) -> ComboStepDefinition:
	return steps[index] if index >= 0 and index < steps.size() else null


func is_valid() -> bool:
	if steps.is_empty() or input_buffer < 0.0:
		return false
	for step: ComboStepDefinition in steps:
		if step == null or not step.is_valid():
			return false
	return true
