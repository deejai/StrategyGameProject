extends Node2D

@onready var area = $Area2D
@onready var collision_shape = $Area2D/CollisionShape2D

var start_point: Vector2

# Called when the node enters the scene tree for the first time.
func _ready():
	visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func set_start_point(point: Vector2):
	start_point = point
	area.position = start_point
	collision_shape.shape.size = Vector2.ZERO
	visible = true
	queue_redraw()

func set_end_point(point: Vector2):
	var topleft = Vector2(min(start_point.x, point.x), min(start_point.y, point.y))
	var botright = Vector2(max(start_point.x, point.x), max(start_point.y, point.y))
	area.position = topleft
	collision_shape.shape.size = botright - topleft
	queue_redraw()

func release():
	visible = false

func _draw():
	draw_rect(Rect2(area.position, collision_shape.shape.size), Color(0.1, 0.4, 0.7, 0.3))
