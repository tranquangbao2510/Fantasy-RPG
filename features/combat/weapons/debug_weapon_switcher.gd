class_name DebugWeaponSwitcher
extends Node
## Công cụ debug: phím `debug_weapon_1..3` trang bị weapons[0..2]. Không phải quickbar/inventory chính thức.
## Xóa node này khi có quy trình trang bị chính thức.

const ACTIONS: Array[StringName] = [&"debug_weapon_1", &"debug_weapon_2", &"debug_weapon_3"]

@export var equipment: WeaponEquipment
@export var weapons: Array[WeaponDefinition] = []


func _unhandled_input(event: InputEvent) -> void:
	if equipment == null:
		return
	for i: int in ACTIONS.size():
		if event.is_action_pressed(ACTIONS[i]):
			if i < weapons.size():
				equipment.equip_weapon(weapons[i])
			get_viewport().set_input_as_handled()
			return
