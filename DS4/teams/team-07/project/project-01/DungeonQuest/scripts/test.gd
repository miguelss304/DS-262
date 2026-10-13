extends Node2D

func _ready() -> void:
	for room in get_children():
		print(room.name, ": ", room.slot_count(), " slots libres")
