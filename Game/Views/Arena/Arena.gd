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

# Called when the node enters the scene tree for the first time.
func _ready():
	click_query_shape.radius = 5.0

	for i in range(4):
		print(i)
		var new_unit = arena_unit.instantiate()
		new_unit.position = viewport.position + Vector2(200 + 100 * (i%2) + 50 * (i/2), 64 + 100 * (i/2))
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
					if selected_units[0].alliance == Definitions.Alliance.PLAYER:
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
	var selected_unit_dict = selected.reduce(
		func(selected_unit_dict, dict):
			var obj = dict.collider
			var selected_obj = selected_unit_dict.collider
			if obj is ArenaUnit:
				if obj.alliance == Definitions.Alliance.PLAYER:
					if selected_obj.alliance != Definitions.Alliance.PLAYER:
						return dict
					elif obj.global_position.distance_squared_to(query_pos) < selected_obj.global_position.distance_squared_to(query_pos):
						return dict
				elif obj.global_position.distance_squared_to(query_pos) < selected_obj.global_position.distance_squared_to(query_pos):
					return dict

			return selected_unit_dict
	, null)
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
		selected_unit.selected = true
		selected_units.append(selected_unit)

func command_selected_units(type: Command.Type, target=null):
	for selected_unit in selected_units:
		if is_instance_valid(selected_unit):
			selected_unit.set_task(Command.Type.MOVE_POINT, target)
