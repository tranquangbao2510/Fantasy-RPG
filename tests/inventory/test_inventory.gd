extends "res://tests/test_base.gd"
## Kiểm thử headless cho Item data + Inventory + EquipmentSlots (TASK M1), logic thuần (không cần scene):
## 1. ItemDatabase: database thật hợp lệ; phát hiện id trùng / id rỗng / item null / item vũ khí thiếu weapon.
## 2. Inventory: add (stack, tràn sang ô mới, số dư khi đầy), remove theo id / ô, move, swap, merge, split,
##    transfer giữa hai túi, quick transfer, has/count_of, to_dict/load_dict (item lạ, ô lỗi, vượt max_stack).
## 3. EquipmentSlots: trang bị từ túi, đổi chỗ món cũ, sai ô bị từ chối, đồng bộ WeaponEquipment hai chiều.
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/inventory/test_inventory.gd
## Thoát mã 1 nếu có ca thất bại.

const DATABASE: ItemDatabase = preload("res://features/items/data/item_database.tres")
const SWORD: WeaponDefinition = preload("res://features/combat/weapons/data/test_sword.tres")
const DAGGER: WeaponDefinition = preload("res://features/combat/weapons/data/test_dagger.tres")



func _run_tests() -> void:
	_test_database()
	_test_add()
	_test_remove()
	_test_move_swap_merge_split()
	_test_transfer()
	_test_serialization()
	await _test_equipment()


func _bag(slots: int) -> Inventory:
	var bag: Inventory = Inventory.new()
	bag.database = DATABASE
	bag.size = slots
	return bag


func _item(id: StringName, max_stack: int = 10) -> ItemDefinition:
	var item: ItemDefinition = ItemDefinition.new()
	item.id = id
	item.display_name = String(id)
	item.max_stack = max_stack
	return item


# ---------------------------------------------------------------- 1. database

func _test_database() -> void:
	var errors: Array[String] = DATABASE.get_validation_errors()
	check("database_valid", errors.is_empty(), str(errors))
	check("database_count", DATABASE.get_item_ids().size() == 10, str(DATABASE.get_item_ids()))
	check("database_lookup", DATABASE.get_item(&"wood") != null and DATABASE.get_item(&"nope") == null)
	check("database_find_by_weapon", DATABASE.find_by_weapon(DAGGER) != null and DATABASE.find_by_weapon(DAGGER).id == &"test_dagger")
	check("database_icons", DATABASE.get_item_ids().all(func(id: StringName) -> bool: return DATABASE.get_item(id).icon != null))
	var broken: ItemDatabase = ItemDatabase.new()
	var weapon_without_data: ItemDefinition = _item(&"blade", 1)
	weapon_without_data.category = ItemDefinition.Category.WEAPON
	weapon_without_data.equip_slot = &"weapon"
	broken.items = [_item(&"a"), _item(&"b"), _item(&"a"), _item(&""), null, weapon_without_data]
	var broken_errors: Array[String] = broken.get_validation_errors()
	var text: String = "\n".join(broken_errors)
	check("database_detects_duplicate", text.contains("id trùng 'a'"), text)
	check("database_detects_missing_id", text.contains("id rỗng"), text)
	check("database_detects_null", text.contains("items[4]: null"), text)
	check("database_detects_weapon_without_definition", text.contains("blade") and text.contains("WeaponDefinition"), text)
	# Lúc dựng index: báo lỗi nhưng không crash; bản trùng không đè bản đầu, item lỗi không tra được.
	expect_error("[ItemDatabase] ")
	check("database_index_skips_invalid", broken.get_item(&"a") == broken.items[0] and broken.get_item(&"blade") == null
		and broken.get_item(&"b") != null)


# ---------------------------------------------------------------- 2. inventory

func _test_add() -> void:
	var bag: Inventory = _bag(3)
	var changes: Array[int] = [0]
	bag.changed.connect(func() -> void: changes[0] += 1)
	check("add_fits", bag.add(&"wood", 50) == 0 and bag.count_of(&"wood") == 50 and changes[0] == 1)
	# max_stack gỗ = 99: 50 + 80 → ô 0 đầy 99, ô 1 có 31.
	check("add_stacks_then_overflows_to_new_slot", bag.add(&"wood", 80) == 0 and bag.get_stack(0).count == 99 and bag.get_stack(1).count == 31)
	check("add_unstackable_items_one_per_slot", bag.add(&"test_sword", 2) == 1 and bag.get_stack(2).item_id == &"test_sword",
		"stacks: %s" % [bag.to_dict()])
	check("add_returns_remainder_when_full", bag.add(&"wood", 100) == 32 and bag.count_of(&"wood") == 198)
	check("is_full", bag.is_full() and bag.first_empty_slot() == -1)
	check("add_full_new_item_rejected", bag.add(&"stone", 5) == 5 and not bag.has(&"stone"))
	check("space_for", bag.space_for(&"wood") == 0 and _bag(2).space_for(&"herb") == 100)
	check("add_unknown_item_rejected", _bag(2).add(&"unknown", 3) == 3)
	check("has_count_of", bag.has(&"wood", 198) and not bag.has(&"wood", 199) and bag.count_of(&"test_sword") == 1)


func _test_remove() -> void:
	var bag: Inventory = _bag(4)
	bag.add(&"stone", 99)
	bag.add(&"stone", 20)
	check("remove_by_id_partial", bag.remove(&"stone", 30) == 30 and bag.count_of(&"stone") == 89 and bag.is_slot_empty(1),
		str(bag.to_dict()))
	check("remove_by_id_more_than_have", bag.remove(&"stone", 500) == 89 and bag.count_of(&"stone") == 0)
	bag.add(&"berry", 10)
	var taken: ItemStack = bag.remove_at(0, 4)
	check("remove_at_amount", taken.item_id == &"berry" and taken.count == 4 and bag.get_stack(0).count == 6)
	check("remove_at_all", bag.remove_at(0).count == 6 and bag.is_slot_empty(0))
	check("remove_at_empty", bag.remove_at(0) == null)


func _test_move_swap_merge_split() -> void:
	var bag: Inventory = _bag(5)
	bag.add(&"herb", 10)
	bag.replace_at(1, ItemStack.new(&"herb", 45))
	bag.replace_at(2, ItemStack.new(&"stone", 3))
	check("move_to_empty", bag.move(2, 4) and bag.is_slot_empty(2) and bag.get_stack(4).item_id == &"stone")
	check("swap", bag.swap(0, 4) and bag.get_stack(0).item_id == &"stone" and bag.get_stack(4).item_id == &"herb")
	# herb max 50: 10 vào 45 → 50, dư 5 ở lại.
	check("merge_leaves_remainder", bag.merge(4, 1) and bag.get_stack(1).count == 50 and bag.get_stack(4).count == 5)
	check("merge_full_target_fails", not bag.merge(4, 1))
	check("move_different_items_swaps", bag.move(0, 4) and bag.get_stack(0).item_id == &"herb" and bag.get_stack(4).item_id == &"stone")
	check("move_same_item_merges", bag.move(0, 1) == false and bag.get_stack(0).count == 5, "target full → không đổi")
	var target: int = bag.split(1, 20)
	check("split", target == 2 and bag.get_stack(1).count == 30 and bag.get_stack(2).count == 20)
	check("split_half", bag.split_half(1) == 3 and bag.get_stack(1).count == 15 and bag.get_stack(3).count == 15)
	check("split_full_bag_fails", bag.split(1, 2) == -1 and bag.get_stack(1).count == 15)
	check("split_single_fails", _single_split())


func _single_split() -> bool:
	var bag: Inventory = _bag(3)
	bag.add(&"test_helmet", 1)
	return bag.split_half(0) == -1 and bag.get_stack(1) == null


func _test_transfer() -> void:
	var bag: Inventory = _bag(3)
	var chest: Inventory = _bag(3)
	bag.add(&"wood", 30)
	chest.add(&"wood", 90)
	check("transfer_merges_with_remainder", bag.transfer_to(0, chest, 0) and chest.get_stack(0).count == 99 and bag.get_stack(0).count == 21)
	chest.replace_at(1, ItemStack.new(&"stone", 4))
	check("transfer_swaps_different_items", bag.transfer_to(0, chest, 1) and bag.get_stack(0).item_id == &"stone" and chest.get_stack(1).count == 21)
	check("transfer_to_empty", bag.transfer_to(0, chest, 2) and bag.is_slot_empty(0) and chest.get_stack(2).item_id == &"stone")
	check("quick_transfer_full_target", chest.quick_transfer(0, bag) == 99 and bag.count_of(&"wood") == 99 and chest.is_slot_empty(0))
	var small: Inventory = _bag(1)
	small.add(&"wood", 95)
	check("quick_transfer_partial", bag.quick_transfer(0, small) == 4 and bag.get_stack(0).count == 95 and small.get_stack(0).count == 99)


func _test_serialization() -> void:
	var bag: Inventory = _bag(6)
	bag.add(&"wood", 12)
	bag.replace_at(3, ItemStack.new(&"test_sword", 1))
	var restored: Inventory = _bag(6)
	restored.load_dict(JSON.parse_string(JSON.stringify(bag.to_dict())))
	check("roundtrip_json", JSON.stringify(restored.to_dict()) == JSON.stringify(bag.to_dict()) and restored.get_stack(3).item_id == &"test_sword",
		str(restored.to_dict()))
	var messy: Dictionary = {"slots": [
		{"slot": 0, "id": "wood", "count": 500},
		{"slot": 0, "id": "stone", "count": 1},
		{"slot": 1, "id": "gone_item", "count": 2},
		{"slot": 99, "id": "herb", "count": 2},
		{"slot": 2, "id": "berry"},
		"garbage",
		{"slot": 3, "id": "herb", "count": 7.0},
	]}
	restored.load_dict(messy)
	check("load_clamps_and_skips_bad_entries", restored.get_stack(0).count == 99 and restored.get_stack(0).item_id == &"wood"
		and restored.is_slot_empty(1) and restored.is_slot_empty(2) and restored.get_stack(3).count == 7, str(restored.to_dict()))
	restored.load_dict(null)
	check("load_garbage_empties", restored.first_empty_slot() == 0 and restored.count_of(&"wood") == 0)


# ---------------------------------------------------------------- 3. trang bị

func _test_equipment() -> void:
	var holder: Node = Node.new()
	var weapons: WeaponEquipment = WeaponEquipment.new()
	weapons.starting_weapon = SWORD
	var bag: Inventory = _bag(4)
	var equipment: EquipmentSlots = EquipmentSlots.new()
	equipment.database = DATABASE
	equipment.inventory = bag
	equipment.weapon_equipment = weapons
	holder.add_child(weapons)
	holder.add_child(bag)
	holder.add_child(equipment)
	root.add_child(holder)
	await process_frame
	check("equip_syncs_starting_weapon", equipment.get_stack(&"weapon") != null and equipment.get_stack(&"weapon").item_id == &"test_sword")
	bag.add(&"test_dagger", 1)
	bag.add(&"test_helmet", 1)
	bag.add(&"wood", 3)
	check("equip_weapon_from_bag_swaps_old", equipment.equip_from_inventory(0) and weapons.get_weapon() == DAGGER
		and bag.get_stack(0).item_id == &"test_sword" and equipment.get_stack(&"weapon").item_id == &"test_dagger")
	check("equip_head", equipment.equip_from_inventory(1) and equipment.get_stack(&"head").item_id == &"test_helmet" and bag.is_slot_empty(1))
	var reasons: Array[String] = []
	equipment.equip_rejected.connect(func(_id: StringName, reason: String) -> void: reasons.append(reason))
	check("equip_non_equippable_rejected", not equipment.equip_from_inventory(2) and bag.get_stack(2).item_id == &"wood" and reasons.size() == 1)
	check("equip_wrong_slot_rejected", not equipment.equip_from_inventory(0, &"head") and equipment.get_stack(&"head").item_id == &"test_helmet")
	# Luật bên ngoài (class) từ chối vũ khí: item ở lại túi, vũ khí không đổi.
	weapons.set_equip_validator(func(w: WeaponDefinition) -> String: return "" if w == DAGGER else "Class cấm")
	check("equip_rejected_by_weapon_rules", not equipment.equip_from_inventory(0) and weapons.get_weapon() == DAGGER and bag.get_stack(0).item_id == &"test_sword")
	weapons.set_equip_validator(Callable())
	# Phím debug (đổi vũ khí từ ngoài) → ô weapon đồng bộ theo.
	weapons.equip_weapon(SWORD)
	check("external_weapon_change_syncs_slot", equipment.get_stack(&"weapon").item_id == &"test_sword")
	# Hệ thống vũ khí gỡ vũ khí (vd. đổi class) → item về túi.
	weapons.unequip_weapon()
	check("external_unequip_returns_item", equipment.get_stack(&"weapon") == null and bag.count_of(&"test_sword") == 2)
	check("unequip_head_to_bag", equipment.unequip_to_inventory(&"head") and bag.has(&"test_helmet") and equipment.get_stack(&"head") == null)
	var saved: Dictionary = {"slots": {"weapon": {"id": "test_dagger", "count": 1}, "head": {"id": "wood", "count": 1}}}
	equipment.load_dict(saved)
	check("equipment_load", equipment.get_stack(&"weapon").item_id == &"test_dagger" and weapons.get_weapon() == DAGGER
		and equipment.get_stack(&"head") == null)
	holder.queue_free()
