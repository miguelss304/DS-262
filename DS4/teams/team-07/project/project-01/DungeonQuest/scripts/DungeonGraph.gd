class_name DungeonGraph
extends RefCounted

# Lista de adyacencia: cada habitación -> sus vecinas
var adjacency: Dictionary = {}

func add_room(id: int) -> void:
	if not adjacency.has(id):
		adjacency[id] = []

func add_edge(a: int, b: int) -> void:
	add_room(a)
	add_room(b)
	if not adjacency[a].has(b):
		adjacency[a].append(b)
	if not adjacency[b].has(a):
		adjacency[b].append(a)

func get_neighbors(id: int) -> Array:
	return adjacency.get(id, [])

func are_neighbors(a: int, b: int) -> bool:
	return get_neighbors(a).has(b)

func build_default() -> void:
	add_edge(1, 2)
	add_edge(2, 3)
	add_edge(2, 4)
	add_edge(3, 5)
	add_edge(4, 5)
	add_edge(5, 7)
	add_edge(4, 6)
	add_edge(6, 7)
	add_edge(7, 8)
	add_edge(8, 0)
	
func bfs_path(start: int, goal: int) -> Array:
	if not adjacency.has(start) or not adjacency.has(goal):
		return []
	var queue: Array = [start]
	var visited: Dictionary = {start: true}
	var parent: Dictionary = {}
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current == goal:
			break
		for n in get_neighbors(current):
			if not visited.has(n):
				visited[n] = true
				parent[n] = current
				queue.append(n)
	if not visited.has(goal):
		return []
	var path: Array = [goal]
	while path[0] != start:
		path.push_front(parent[path[0]])
	return path

# --- Generación procedural ---
const MAX_DEGREE := 4

func generate(n: int, extra_edges: int, seed_value: int) -> void:
	adjacency.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	for i in range(1, n + 1):
		add_room(i)

	# Aristas candidatas entre salas intermedias (2..n-1)
	var candidates: Array = []
	for a in range(2, n):
		for b in range(a + 1, n):
			candidates.append(Vector2i(a, b))
	_shuffle(candidates, rng)

	# Union-Find
	var parent := {}
	for i in range(2, n):
		parent[i] = i

	# Árbol de expansión aleatorio entre las intermedias
	for e in candidates:
		var ra := _find(parent, e.x)
		var rb := _find(parent, e.y)
		if ra != rb and get_neighbors(e.x).size() < MAX_DEGREE \
				and get_neighbors(e.y).size() < MAX_DEGREE:
			parent[ra] = rb
			add_edge(e.x, e.y)

	# Aristas extra para crear ciclos
	var added := 0
	for e in candidates:
		if added >= extra_edges:
			break
		if not are_neighbors(e.x, e.y) \
				and get_neighbors(e.x).size() < MAX_DEGREE \
				and get_neighbors(e.y).size() < MAX_DEGREE:
			add_edge(e.x, e.y)
			added += 1

	# Entrada (1) conectada a una intermedia; salida (n) a la más lejana
	add_edge(1, 2 + rng.randi() % (n - 2))
	var start_room: int = get_neighbors(1)[0]
	var far := start_room
	var best := -1
	for i in range(2, n):
		var d := bfs_path(start_room, i).size()
		if d > best and get_neighbors(i).size() < MAX_DEGREE:
			best = d
			far = i
	add_edge(n, far)

func _find(parent: Dictionary, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]  # compresión de caminos
		x = parent[x]
	return x

func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
