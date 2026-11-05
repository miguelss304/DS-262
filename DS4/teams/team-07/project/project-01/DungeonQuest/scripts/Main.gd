extends Node2D

const DOOR_SCENE := preload("res://scenes/objects/Door.tscn")
const ENTRY_SCENE := preload("res://scenes/rooms/EntryRoom.tscn")
const EXIT_SCENE := preload("res://scenes/rooms/ExitRoom.tscn")
const NORMAL_SCENES := [
	preload("res://scenes/rooms/RoomA.tscn"),
	preload("res://scenes/rooms/RoomB.tscn"),
]
const EXIT_LINK_SLOT := 6   # única entrada a la sala de salida
const EXIT_WIN_SLOT := 1    # puerta de victoria

const ROOM_COUNT := 8
const EXTRA_EDGES := 2
const ROOM_STEP := Vector2(700, 450)
const WORLD_ORIGIN := Vector2(4000, 0)
const ROOM_SIZE := Vector2(480, 270)

var rooms: Dictionary = {}
var graph := DungeonGraph.new()
var doors: Dictionary = {}
var current_room: int = 1
var exit_room: int = ROOM_COUNT
var transitioning: bool = false
var rng := RandomNumberGenerator.new()
var world: Node2D
var fade: ColorRect

func _ready() -> void:
	_create_fade()

	rng.randomize()
	var seed_value: int = rng.randi()
	print("Semilla: ", seed_value)
	rng.seed = seed_value

	graph.generate(ROOM_COUNT, EXTRA_EDGES, seed_value)
	print("Grafo: ", graph.adjacency)
	print("Ruta BFS: ", graph.bfs_path(1, exit_room))

	_build_world()
	_place_player_at_start()

# ---------- Fundido (creado por código) ----------

func _create_fade() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FadeLayerCode"
	layer.layer = 100
	add_child(layer)

	fade = ColorRect.new()
	fade.name = "Fade"
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.modulate.a = 0.0
	layer.add_child(fade)

# ---------- Construcción del mapa ----------

func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)

	var slots_by_room: Dictionary = {}
	var cols: int = ceili(sqrt(float(ROOM_COUNT)))

	for i in range(1, ROOM_COUNT + 1):
		var scene: PackedScene
		if i == 1:
			scene = ENTRY_SCENE
		elif i == ROOM_COUNT:
			scene = EXIT_SCENE
		else:
			scene = NORMAL_SCENES[rng.randi() % NORMAL_SCENES.size()]
		var room = scene.instantiate()
		room.name = "Room%d" % i
		var col: int = (i - 1) % cols
		var row: int = floori(float(i - 1) / cols)
		room.position = WORLD_ORIGIN + Vector2(col, row) * ROOM_STEP
		world.add_child(room)
		rooms[i] = room

		var slots: Array = room.get_free_slots()
		_shuffle(slots)
		slots_by_room[i] = slots

	for a in graph.adjacency:
		for b in graph.get_neighbors(a):
			if a < b:
				var slot_a
				var slot_b
				if b == exit_room:
					# La sala de salida solo se conecta por su slot fijo
					slot_b = rooms[b].get_slot(EXIT_LINK_SLOT)
					slot_a = _take_slot(slots_by_room[a], slot_b.view ^ 1)
				else:
					slot_a = _take_slot(slots_by_room[a])
					if slot_a != null:
						slot_b = _take_slot(slots_by_room[b], slot_a.view ^ 1)
				if slot_a == null or slot_b == null:
					push_error("Sin slots libres para la arista %d-%d" % [a, b])
					continue
				_make_door(a, b, slot_a)
				_make_door(b, a, slot_b)

	# Puerta de victoria en el slot fijo de la sala de salida
	_make_door(exit_room, 0, rooms[exit_room].get_slot(EXIT_WIN_SLOT), true)
	
	
func _take_slot(slots: Array, wanted_view: int = -1):
	if slots.is_empty():
		return null
	if wanted_view >= 0:
		for i in slots.size():
			if slots[i].view == wanted_view:
				return slots.pop_at(i)
	return slots.pop_back()

func _make_door(from_id: int, to_id: int, slot: Node, is_exit: bool = false) -> void:
	var door = DOOR_SCENE.instantiate()
	door.from_room = from_id
	door.to_room = to_id
	door.is_exit = is_exit
	door.view = slot.view
	slot.add_child(door)
	door.name = "Door_%d_%d" % [from_id, to_id]
	doors[Vector2i(from_id, to_id)] = door
	door.door_crossed.connect(_on_door_door_crossed)

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _place_player_at_start() -> void:
	var spawn = rooms[1].get_node_or_null("PlayerSpawn")
	if spawn == null:
		push_error("EntryRoom no tiene PlayerSpawn")
		return
	$Player.global_position = spawn.global_position
	current_room = 1
	_set_camera_limits(1)
	$Player/Camera2D.reset_smoothing()

# ---------- Cruce de puertas ----------

func _on_door_door_crossed(from_room: int, to_room: int, door: Node2D) -> void:
	if transitioning:
		return
	if door.is_exit:
		_win(door)
		return
	if not graph.are_neighbors(from_room, to_room):
		print("Conexión inválida: ", from_room, " -> ", to_room)
		return
	var twin = doors.get(Vector2i(to_room, from_room))
	if twin == null:
		print("Falta la puerta gemela: ", to_room, " -> ", from_room)
		return

	transitioning = true
	var player = $Player
	var cam: Camera2D = $Player/Camera2D
	player.can_move = false
	player.velocity = Vector2.ZERO

	var cam_pos := cam.global_position
	cam.position_smoothing_enabled = false
	cam.top_level = true
	cam.global_position = cam_pos

	var dir: Vector2 = door.get_walk_direction()
	var target: Vector2 = player.global_position + dir * door.get_walk_distance()
	player.play_walk(dir)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(player, "global_position", target, 1.0)
	tween.tween_property(player.animated_sprite, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tween.tween_property(fade, "modulate:a", 1.0, 1.0)
	await tween.finished
	await get_tree().create_timer(0.1).timeout

	player.global_position = twin.get_arrival_position()
	player.animated_sprite.modulate.a = 1.0
	current_room = to_room
	_set_camera_limits(to_room)
	cam.top_level = false
	cam.position = Vector2.ZERO
	cam.position_smoothing_enabled = true
	cam.reset_smoothing()

	player.play_walk(-twin.get_walk_direction())
	player.update_animation('idle')

	var t2 := create_tween()
	t2.tween_property(fade, "modulate:a", 0.0, 0.3)
	await t2.finished
	player.can_move = true
	transitioning = false

func _win(door: Node2D) -> void:
	transitioning = true
	var player = $Player
	player.can_move = false
	player.velocity = Vector2.ZERO
	var dir: Vector2 = door.get_walk_direction()
	var target: Vector2 = player.global_position + dir * door.get_walk_distance()
	player.play_walk(dir)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(player, "global_position", target, 1.0)
	tween.tween_property(player.animated_sprite, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tween.tween_property(fade, "modulate:a", 1.0, 1.0)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/Start.tscn")

# ---------- Pista con BFS ----------

func get_room_doors(room_id: int) -> Array:
	var result: Array = []
	for key in doors:
		if key.x == room_id:
			result.append(doors[key])
	return result

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("help") and not event.is_echo():
		generar_ayuda_puertas()

func generar_ayuda_puertas() -> void:
	if current_room == exit_room:
		for d in get_room_doors(current_room):
			if d.is_exit:
				d.door_glow()
		return
	var path: Array = graph.bfs_path(current_room, exit_room)
	if path.size() < 2:
		return
	var next_room: int = path[1]
	for d in get_room_doors(current_room):
		if d.to_room == next_room:
			d.door_glow()
			
# ----------- Colision de camara --------------

func _set_camera_limits(room_id: int) -> void:
	var room: Node2D = world.get_node("Room%d" % room_id)
	var cam: Camera2D = $Player/Camera2D
	cam.limit_left = int(room.position.x)
	cam.limit_top = int(room.position.y)
	cam.limit_right = int(room.position.x + ROOM_SIZE.x)
	cam.limit_bottom = int(room.position.y + ROOM_SIZE.y)
