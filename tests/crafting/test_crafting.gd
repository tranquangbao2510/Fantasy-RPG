extends "res://tests/test_base.gd"
## Kiểm thử logic TASK M3 (không cần map): dữ liệu công thức / node tài nguyên / bảng rơi đồ hợp lệ, chế tạo (đủ, thiếu
## nguyên liệu không trừ đồ, thiếu trạm, túi đầy bị chặn, nguyên liệu nhường ô), độ bền công cụ (trừ đúng, vỡ đúng lúc),
## đuốc cháy hết, luật class cho công cụ, migration v2 → v3 (thuần dữ liệu).
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/crafting/test_crafting.gd

const DATABASE: ItemDatabase = preload("res://features/items/data/item_database.tres")
const BOOK: RecipeBook = preload("res://features/crafting/data/recipe_book.tres")
const NODE_DEFS: Array[String] = ["tree", "rock", "berry_bush", "grass"]
const ENEMY_LOOT: Array[String] = ["simple_enemy_loot", "ranged_enemy_loot", "stationary_attacker_loot"]
const FIGHTER: ClassDefinition = preload("res://features/classes/data/test_fighter.tres")
const CASTER: ClassDefinition = preload("res://features/classes/data/test_caster.tres")


func _run_tests() -> void:
	_test_data()
	_test_crafting()
	_test_loot()
	_test_tool_wear()
	_test_migration()


func _bag(size: int = 24) -> Inventory:
	var bag: Inventory = Inventory.new()
	bag.database = DATABASE
	bag.size = size
	root.add_child(bag)
	return bag


# ---------------------------------------------------------------- dữ liệu

func _test_data() -> void:
	check("database_valid", DATABASE.get_validation_errors().is_empty(), str(DATABASE.get_validation_errors()))
	check("recipe_book_valid", BOOK.get_validation_errors(DATABASE).is_empty(), str(BOOK.get_validation_errors(DATABASE)))
	var ids: Array[StringName] = []
	for recipe: RecipeDefinition in BOOK.recipes:
		ids.append(recipe.id)
	check("recipes_required", ids.has(&"stone_axe") and ids.has(&"stone_pickaxe") and ids.has(&"torch") and ids.has(&"bandage")
		and ids.has(&"campfire") and ids.has(&"tent") and ids.has(&"grilled_meat") and ids.has(&"roasted_berry"), str(ids))
	check("recipe_stations", BOOK.get_recipe(&"tent").station == RecipeDefinition.Station.WORKBENCH
		and BOOK.get_recipe(&"grilled_meat").station == RecipeDefinition.Station.CAMPFIRE
		and BOOK.get_recipe(&"stone_axe").station == RecipeDefinition.Station.NONE)
	check("recipes_for_hand_only", BOOK.recipes_for([]).size() == 5)
	check("recipes_for_campfire_mode", BOOK.recipes_for([RecipeDefinition.Station.CAMPFIRE], RecipeDefinition.Station.CAMPFIRE).size() == 2)
	for def_name: String in NODE_DEFS:
		var def: ResourceNodeDefinition = load("res://features/gathering/data/%s.tres" % def_name) as ResourceNodeDefinition
		check("node_def_valid_%s" % def_name, def != null and def.get_validation_errors(DATABASE).is_empty(),
			str(def.get_validation_errors(DATABASE)) if def != null else "null")
	var tree: ResourceNodeDefinition = load("res://features/gathering/data/tree.tres")
	var bush: ResourceNodeDefinition = load("res://features/gathering/data/berry_bush.tres")
	check("node_tools", tree.required_tool == &"axe" and (load("res://features/gathering/data/rock.tres") as ResourceNodeDefinition).required_tool == &"pickaxe"
		and not bush.needs_tool() and not bush.depletes and tree.depletes)
	var axe: ItemDefinition = DATABASE.get_item(&"stone_axe")
	var torch: ItemDefinition = DATABASE.get_item(&"torch")
	var lantern: ItemDefinition = DATABASE.get_item(&"lantern")
	check("axe_is_tool_weapon", axe.tool_type == &"axe" and axe.equip_slot == &"weapon" and axe.weapon.weapon_type_id == WeaponDefinition.TOOL_TYPE
		and axe.max_durability == 40)
	check("tool_low_damage", axe.weapon.combo.get_step(0).damage < 12, str(axe.weapon.combo.get_step(0).damage))
	check("torch_smaller_than_lantern", torch.equip_slot == &"offhand" and torch.light_radius > 0.0 and torch.light_radius < lantern.light_radius
		and torch.burn_minutes > 0.0)
	check("tools_allowed_for_every_class", FIGHTER.allows_weapon_type(WeaponDefinition.TOOL_TYPE) and CASTER.allows_weapon_type(WeaponDefinition.TOOL_TYPE)
		and not CASTER.allows_weapon_type(&"sword"))
	check("tent_limit_1_campfire_8", DATABASE.get_item(&"tent").max_per_map == 1 and DATABASE.get_item(&"campfire").max_per_map == 8)


# ---------------------------------------------------------------- chế tạo

func _test_crafting() -> void:
	var axe_recipe: RecipeDefinition = BOOK.get_recipe(&"stone_axe")
	var bag: Inventory = _bag()
	bag.add(&"branch", 2)
	bag.add(&"stone", 1)
	bag.add(&"fiber", 3)
	var missing: Dictionary[StringName, int] = Crafting.get_missing(axe_recipe, bag)
	check("missing_lists_lacking", missing == {&"stone": 1}, str(missing))
	var before: Dictionary = bag.to_dict()
	var reason: String = Crafting.craft(axe_recipe, bag, [])
	check("craft_missing_refused", reason == "Thiếu nguyên liệu", reason)
	check("craft_missing_no_deduction", bag.to_dict() == before)
	bag.add(&"stone", 2)
	reason = Crafting.craft(axe_recipe, bag, [])
	check("craft_ok", reason.is_empty() and bag.count_of(&"stone_axe") == 1 and bag.count_of(&"branch") == 0
		and bag.count_of(&"stone") == 1 and bag.count_of(&"fiber") == 0, reason)
	# Thiếu trạm: công thức bàn chế tạo / lửa trại.
	bag.clear()
	bag.add(&"wood", 4)
	bag.add(&"fiber", 8)
	bag.add(&"branch", 4)
	bag.add(&"raw_meat", 1)
	check("workbench_required", Crafting.craft(BOOK.get_recipe(&"tent"), bag, []).begins_with("Cần đứng gần bàn chế tạo") and bag.count_of(&"wood") == 4)
	check("campfire_required", Crafting.craft(BOOK.get_recipe(&"grilled_meat"), bag, [RecipeDefinition.Station.WORKBENCH]) == "Cần lửa trại đang cháy"
		and bag.has(&"raw_meat"))
	check("workbench_craft_tent", Crafting.craft(BOOK.get_recipe(&"tent"), bag, [RecipeDefinition.Station.WORKBENCH]).is_empty() and bag.has(&"tent")
		and not bag.has(&"wood") and not bag.has(&"fiber"))
	check("campfire_cook", Crafting.craft(BOOK.get_recipe(&"grilled_meat"), bag, [RecipeDefinition.Station.CAMPFIRE]).is_empty()
		and bag.has(&"grilled_meat") and not bag.has(&"raw_meat"))
	# Túi đầy: chặn, không trừ gì.
	var small: Inventory = _bag(3)
	small.add(&"fiber", 4)
	small.add(&"wood", 1)
	small.add(&"herb", 1)
	before = small.to_dict()
	reason = Crafting.craft(BOOK.get_recipe(&"bandage"), small, [])
	# Băng gạc dùng hết 4 sợi → ô sợi trống → vừa túi.
	check("craft_full_bag_ingredient_frees_slot", reason.is_empty() and small.has(&"bandage"), reason)
	small.clear()
	small.add(&"fiber", 9)
	small.add(&"wood", 1)
	small.add(&"herb", 1)
	before = small.to_dict()
	reason = Crafting.craft(BOOK.get_recipe(&"bandage"), small, [])
	check("craft_full_bag_blocked", reason.begins_with("Túi đầy") and small.to_dict() == before, reason)
	check("craft_full_bag_reason_before_craft", Crafting.get_block_reason(BOOK.get_recipe(&"bandage"), small, []).begins_with("Túi đầy"))
	small.free()
	bag.free()


# ---------------------------------------------------------------- bảng rơi đồ

func _test_loot() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var tree: ResourceNodeDefinition = load("res://features/gathering/data/tree.tres")
	var in_range: bool = true
	for i: int in 50:
		var stacks: Array[ItemStack] = tree.yield_table.roll(rng)
		var wood: int = 0
		var branch: int = 0
		for stack: ItemStack in stacks:
			wood += stack.count if stack.item_id == &"wood" else 0
			branch += stack.count if stack.item_id == &"branch" else 0
		in_range = in_range and wood >= 3 and wood <= 4 and branch >= 1 and branch <= 2
	check("tree_yield_ranges", in_range)
	for table_name: String in ENEMY_LOOT:
		var table: LootTable = load("res://entities/enemies/loot/%s.tres" % table_name) as LootTable
		check("enemy_loot_valid_%s" % table_name, table != null and table.get_validation_errors(DATABASE).is_empty()
			and table.entries[0].item_id == &"raw_meat")
	var chance: LootTable = load("res://entities/enemies/loot/ranged_enemy_loot.tres") as LootTable
	var drops: int = 0
	for i: int in 400:
		drops += 1 if not chance.roll(rng).is_empty() else 0
	check("loot_chance_respected", drops > 200 and drops < 280, "%d/400 (60 %%)" % drops)


# ---------------------------------------------------------------- độ bền

func _test_tool_wear() -> void:
	var bag: Inventory = _bag()
	var slots: EquipmentSlots = EquipmentSlots.new()
	slots.database = DATABASE
	slots.inventory = bag
	root.add_child(slots)
	var depleted: Array[StringName] = []
	slots.item_depleted.connect(func(item_id: StringName, _slot: StringName) -> void: depleted.append(item_id))
	bag.add(&"stone_axe", 1)
	check("equip_axe", slots.equip_from_inventory(0) and slots.get_tool() != null and slots.get_tool().id == &"stone_axe")
	var axe: ItemDefinition = DATABASE.get_item(&"stone_axe")
	check("fresh_axe_full", axe.durability_of(slots.get_stack(&"weapon")) == 40 and axe.describe_wear(slots.get_stack(&"weapon")) == "Độ bền 40/40")
	var broke_at: int = -1
	for i: int in 45:
		if slots.wear(&"weapon"):
			broke_at = i + 1
			break
	check("axe_breaks_on_40th_use", broke_at == 40 and slots.get_stack(&"weapon") == null and depleted == [&"stone_axe"], str(broke_at))
	# Độ bền lưu trong ItemStack.data → to_dict / load_dict giữ nguyên.
	bag.add(&"stone_pickaxe", 1)
	slots.equip_from_inventory(_find(bag, &"stone_pickaxe"))
	slots.wear(&"weapon", 3)
	var saved: Dictionary = slots.to_dict()
	slots.set_slot(&"weapon", null)
	slots.load_dict(saved)
	check("durability_saved", DATABASE.get_item(&"stone_pickaxe").durability_of(slots.get_stack(&"weapon")) == 37
		and saved["slots"]["weapon"]["data"]["durability"] == 37, JSON.stringify(saved))
	# Đuốc: cháy theo thời gian game khi đang mặc, hết thì biến mất.
	bag.add(&"torch", 1)
	slots.equip_from_inventory(_find(bag, &"torch"))
	slots.burn(100.0)
	var torch: ItemDefinition = DATABASE.get_item(&"torch")
	check("torch_burns", is_equal_approx(torch.fuel_of(slots.get_stack(&"offhand")), torch.burn_minutes - 100.0)
		and slots.get_light_radius() == torch.light_radius)
	slots.burn(torch.burn_minutes)
	check("torch_burns_out", slots.get_stack(&"offhand") == null and depleted.has(&"torch") and slots.get_light_radius() == 0.0)
	slots.free()
	bag.free()


func _find(bag: Inventory, item_id: StringName) -> int:
	for i: int in bag.get_size():
		var stack: ItemStack = bag.get_stack(i)
		if stack != null and stack.item_id == item_id:
			return i
	return -1


# ---------------------------------------------------------------- migration (dữ liệu)

func _test_migration() -> void:
	var v2: Dictionary = {"schema_version": 2, "global": {}, "maps": {"glade": {"world_items": {"version": 2, "collected": [],
		"dropped": [], "death_bags": [], "deployed": [{"item_id": "tent", "id": "tent_1", "position": [0, 0], "tier": 0}]}},
		"test_map": {}}}
	var v3: Dictionary = SaveMigrations.migrate_2_to_3(v2.duplicate(true))
	check("migrate_2_3_resource_nodes", v3["maps"]["glade"]["resource_nodes"] == {"version": 1, "nodes": {}}
		and v3["maps"]["test_map"]["resource_nodes"] == {"version": 1, "nodes": {}})
	check("migrate_2_3_deployed_state", v3["maps"]["glade"]["world_items"]["deployed"][0]["state"] == {}
		and v3["maps"]["glade"]["world_items"]["version"] == 3)
