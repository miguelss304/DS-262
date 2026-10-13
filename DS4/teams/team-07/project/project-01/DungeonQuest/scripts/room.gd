extends Node2D

@onready var door_slots = $DoorSlots

func get_free_slots() -> Array:
	return door_slots.get_free_slots()

func slot_count() -> int:
	return get_free_slots().size()
