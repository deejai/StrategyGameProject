extends Node2D

var arena_unit = load("res://Main/ArenaUnit.tscn")

@onready var unit_layer = $UnitLayer
@onready var selection_rect = $HUDLayer/SelectionRect
@onready var viewport = $WireFrame/Viewport

var viewport_input_ctx = InputContext.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in range(4):
		print(i)
		var new_unit = arena_unit.instantiate()
		new_unit.position = Vector2(200 + 100 * (i%2) + 50 * (i/2), 400 + 100 * (i/2))
		unit_layer.add_child(new_unit)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_viewport_gui_input(event):
	var ctx = viewport_input_ctx

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				viewport_input_ctx.engaged = true
				viewport_input_ctx.click_pos_start = event.position
				viewport_input_ctx.click_time_start = Time.get_ticks_msec()

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed == false:
			if viewport_input_ctx.engaged:
				if viewport_input_ctx.dragging:
					print("drew rect")
					box_select()
				else:
					print("clicked")

				viewport_input_ctx.reset()

	if event is InputEventMouseMotion:
		if viewport_input_ctx.engaged:
			if !viewport_input_ctx.dragging:
				if Time.get_ticks_msec() - viewport_input_ctx.click_time_start > 75:
					selection_rect.set_start_point(viewport_input_ctx.click_pos_start)
					viewport_input_ctx.dragging = true

			if viewport_input_ctx.dragging:
				var clamped_x = clamp(event.position.x, viewport.position.x, viewport.position.x + viewport.size.x)
				var clamped_y = clamp(event.position.y, viewport.position.y, viewport.position.y + viewport.size.y)
				selection_rect.set_end_point(Vector2(clamped_x, clamped_y))

func box_select():
	var space = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.set_shape(selection_rect.collision_shape.shape)
	query.transform = Transform2D(0, (selection_rect.start_point + selection_rect.end_point) / 2)
	var selected = space.intersect_shape(query)
	print(selected)
	selection_rect.visible = false
