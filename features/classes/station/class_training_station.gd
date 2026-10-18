class_name ClassTrainingStation
extends Interactable
## Trạm huấn luyện thử nghiệm (placeholder, không phải NPC chính thức): điểm hợp lệ để đổi class.
## Nhấn tương tác → mở phiên đổi class trên ClassManager của actor (UI mở theo signal của ClassManager).
## Phiên kết thúc khi actor rời quá session_range, đóng giao diện hoặc bị hạ gục.

## Khoảng cách tối đa (px, từ chân actor tới station) để giữ phiên đổi class.
@export var session_range: float = 72.0
## Class có thể mở khóa tại trạm này bằng thao tác debug (chưa có điều kiện mở khóa thật).
@export var debug_unlockable_classes: Array[ClassDefinition] = []


func _perform_interaction(actor: Node2D) -> String:
	var manager: ClassManager = ClassManager.find_in(actor)
	if manager == null or not manager.open_switch_session(self, session_range):
		return "Không thể huấn luyện lúc này."
	return "Trạm huấn luyện: chọn class trong bảng."


## Danh sách class trạm này mở khóa được bằng debug.
func get_debug_unlockable_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition: ClassDefinition in debug_unlockable_classes:
		if definition != null:
			ids.append(definition.class_id)
	return ids


## Mở khóa class (debug) — chỉ khi actor đang có phiên đổi class tại chính trạm này.
## Quest/NPC/khám phá sau này gọi thẳng ClassManager.unlock_class(), không đi qua trạm.
func debug_unlock_class(manager: ClassManager, class_id: StringName) -> bool:
	if manager == null or manager.get_switch_station() != self or not get_debug_unlockable_ids().has(class_id):
		return false
	return manager.unlock_class(class_id)
