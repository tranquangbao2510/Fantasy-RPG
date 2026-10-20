class_name ItemUser
extends Node
## Dùng item trong túi (TASK M2): ăn/uống (ItemDefinition.consumable) hoặc đặt xuống thế giới (deploy_scene, vd. lều —
## World cung cấp `deploy_handler` vì chỉ World biết chỗ đặt hợp lệ). Thành công thì trừ 1 item khỏi ô.
## Quy tắc ăn: đang no (Đói ≥ HungerSettings.full_threshold) thì không ăn món có hồi đói; HP âm (thịt sống) không làm
## chết (tối thiểu còn 1 HP).

## Dùng thành công: message mô tả tác dụng (vd. "Đã ăn Bánh mì: +30 Đói").
signal used(item_id: StringName, message: String)

@export var database: ItemDatabase
@export var inventory: Inventory
@export var health: HealthComponent
@export var mana: ManaComponent
@export var hunger: HungerComponent
@export var buffs: BuffComponent

## Callable(item: ItemDefinition) -> String: đặt item xuống thế giới; "" = thành công, ngược lại là lý do.
var deploy_handler: Callable


## Lý do không dùng được item ("" nếu dùng được).
func get_block_reason(item: ItemDefinition) -> String:
	if item == null:
		return "Vật phẩm không tồn tại"
	if health != null and health.is_dead():
		return "Đã bị hạ gục"
	if item.consumable != null:
		if item.consumable.is_food() and hunger != null and hunger.is_full():
			return "Đang no, chưa ăn được."
		return ""
	if item.deploy_scene != null:
		return "" if deploy_handler.is_valid() else "Không dựng được ở đây."
	return "%s không dùng được." % item.display_name


## Dùng item ở ô `slot` của túi. Trả về "" nếu thành công, ngược lại là lý do.
func use_slot(slot: int) -> String:
	var stack: ItemStack = inventory.get_stack(slot) if inventory != null else null
	if stack == null:
		return "Ô trống."
	var item: ItemDefinition = database.get_item(stack.item_id) if database != null else null
	var reason: String = get_block_reason(item)
	if not reason.is_empty():
		return reason
	var message: String
	if item.consumable != null:
		apply_effect(item.consumable)
		message = "Đã dùng %s: %s" % [item.display_name, item.consumable.describe()]
	else:
		reason = deploy_handler.call(item)
		if not reason.is_empty():
			return reason
		message = "Đã đặt %s." % item.display_name
	inventory.remove_at(slot, 1)
	used.emit(item.id, message)
	return ""


func apply_effect(effect: ConsumableEffect) -> void:
	if hunger != null:
		hunger.restore(effect.hunger)
	if mana != null:
		mana.restore(effect.mana)
	if health != null and effect.health > 0:
		health.heal(effect.health)
	elif health != null and effect.health < 0:
		var damage: int = mini(-effect.health, health.current_health - 1)
		if damage > 0:
			health.apply_damage(damage)
	if buffs != null and effect.buff != null:
		buffs.apply(effect.buff)
