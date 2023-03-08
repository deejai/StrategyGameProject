extends Node2D

var arena_unit = load("res://Game/Views/Arena/ArenaUnit.tscn")

@onready var selection_rect = $HUDLayer/SelectionRect
@onready var viewport = $WireFrame/Viewport
@onready var arena_layer = $ArenaLayer

var viewport_leftclick_ctx = ClickContext.new()

@onready var arena_space = $ArenaLayer/Arena.get_world_2d().direct_space_state
var physics_query = PhysicsShapeQueryParameters2D.new()
var click_query_shape: CircleShape2D = CircleShape2D.new()

var selected_units: Array[ArenaUnit] = []

@export var point_select_collider: CollisionShape2D

@onready var nav_area: ReferenceRect = $WireFrame/NavArea
var nav_node_scene: PackedScene = load("res://Game/Views/Arena/NavNode.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	click_query_shape.radius = 5.0

	var nav_rect: Rect2 = nav_area.get_global_rect()
	var nav_rect_size: Vector2 = nav_rect.size
	var nav_origin: Vector2 = nav_area.global_position
	var n_astar_node_cols: int = 40
	var n_astar_node_rows: int = roundi(n_astar_node_cols * 1.0  * (nav_rect_size.y/nav_rect_size.x))
	var astar_node_h_spacing: float = nav_rect_size.x / (1.0 * n_astar_node_cols)
	var astar_node_v_spacing: float = nav_rect_size.y / (1.0 * n_astar_node_rows - 1.0)
	print(n_astar_node_cols)
	print(n_astar_node_rows)
	for row_n in n_astar_node_rows:
		var v_pos: float = astar_node_v_spacing * row_n
		var h_offset: float = 0.5 * astar_node_h_spacing * (row_n % 2)
		for col_n in n_astar_node_cols:
			var node_pos: Vector2 = nav_origin + Vector2(
				h_offset + astar_node_h_spacing * col_n,
				v_pos
			)

			var new_node: Node2D = nav_node_scene.instantiate()
			arena_layer.add_child(new_node)
			new_node.global_position = node_pos

	for i in range(6):
		print(i)
		var new_unit = arena_unit.instantiate()
		new_unit.position = viewport.position + Vector2(200 + 100 * (i%2) + 50 * (i/2), 64 + 50 * (i/2))
		arena_layer.add_child(new_unit)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_viewport_gui_input(event):
	var ctx = viewport_leftclick_ctx

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				viewport_leftclick_ctx.engaged = true
				viewport_leftclick_ctx.click_pos_start = event.global_position
				viewport_leftclick_ctx.click_time_start = Time.get_ticks_msec()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if not selected_units.is_empty():
					for i in len(selected_units):
						if is_instance_valid(selected_units[i]) and selected_units[i].alliance == Definitions.Alliance.PLAYER:
							command_selected_units(Command.Type.MOVE_POINT, event.global_position)

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed == false:
			if viewport_leftclick_ctx.engaged:
				if viewport_leftclick_ctx.dragging:
					set_selected_units(box_select())
				else:
					set_selected_units(click_select())

				viewport_leftclick_ctx.reset()

	if event is InputEventMouseMotion:
		if viewport_leftclick_ctx.engaged:
			if !viewport_leftclick_ctx.dragging:
				if Time.get_ticks_msec() - viewport_leftclick_ctx.click_time_start > 75:
					selection_rect.set_start_point(viewport_leftclick_ctx.click_pos_start)
					viewport_leftclick_ctx.dragging = true

			if viewport_leftclick_ctx.dragging:
				var clamped_x = clamp(event.position.x, viewport.position.x, viewport.position.x + viewport.size.x)
				var clamped_y = clamp(event.position.y, viewport.position.y, viewport.position.y + viewport.size.y)
				selection_rect.set_end_point(Vector2(clamped_x, clamped_y))

func box_select():
	selection_rect.visible = false
	physics_query.set_shape(selection_rect.collision_shape.shape)
	physics_query.transform = Transform2D(0, (selection_rect.start_point + selection_rect.end_point) / 2)
	var selected: Array[Dictionary] = arena_space.intersect_shape(physics_query)
	var allies_selected: Array[ArenaUnit] = []
	allies_selected = selected.reduce(
		func(arr, dict):
			var obj = dict.collider
			if obj is ArenaUnit and obj.alliance == Definitions.Alliance.PLAYER:
				arr.append(obj)
			return arr
	, allies_selected)
	return allies_selected

func click_select():
	var query_pos: Vector2 = get_global_mouse_position()
	physics_query.set_shape(click_query_shape)
	physics_query.transform = Transform2D(0, query_pos)
	var selected: Array = arena_space.intersect_shape(physics_query)
	var selected_unit_dict: Variant = null

	for dict in selected:
		var obj = dict.collider
		if obj is ArenaUnit:
			var selected_obj = null if selected_unit_dict == null else selected_unit_dict.collider
			if selected_obj == null:
				selected_unit_dict = dict
				continue

			if obj.alliance == Definitions.Alliance.PLAYER:
				if selected_obj.alliance != Definitions.Alliance.PLAYER:
					selected_unit_dict = dict
				elif obj.global_position.distance_squared_to(query_pos) < selected_obj.global_position.distance_squared_to(query_pos):
					selected_unit_dict = dict
			elif obj.global_position.distance_squared_to(query_pos) < selected_obj.global_position.distance_squared_to(query_pos):
				selected_unit_dict = dict

	var selected_unit_arr: Array[ArenaUnit] = []
	if selected_unit_dict != null:
		selected_unit_arr.append(selected_unit_dict.collider)
	return selected_unit_arr

func set_selected_units(new_selected_units: Array[ArenaUnit]):
	for selected_unit in selected_units:
		if is_instance_valid(selected_unit):
			selected_unit.selected = false

	selected_units = []

	for selected_unit in new_selected_units:
		selected_unit.select()
		selected_units.append(selected_unit)

func command_selected_units(type: Command.Type, target=null):
	var valid_units: Array[ArenaUnit] = selected_units.filter(func(u): return is_instance_valid(u))
	var n_valid_units: int = len(valid_units)

	# spread out target positions
	if type in [Command.Type.MOVE_POINT, Command.Type.ATTACK_MOVE]:
		var avg_pos_vec: Vector2 = Vector2.ZERO
		for selected_unit in valid_units:
			avg_pos_vec += target - selected_unit.position

		avg_pos_vec = avg_pos_vec / n_valid_units
		var orthog_vec = avg_pos_vec.orthogonal().normalized()
		valid_units.sort_custom(func(a, b): return a.position.distance_to(orthog_vec * 99999.0) > b.position.distance_to(orthog_vec * 99999.0))

		var x: int = 0
		for selected_unit in valid_units:
			if is_instance_valid(selected_unit):
				selected_unit.set_task(type, target + orthog_vec * (min(40.0, 0.2 * avg_pos_vec.length())) * (-n_valid_units/2.0 + x))
				x += 1
	else:
		for selected_unit in valid_units:
			if is_instance_valid(selected_unit):
				selected_unit.set_task(type, target)
