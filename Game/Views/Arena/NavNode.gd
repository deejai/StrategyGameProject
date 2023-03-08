extends Area2D

@onready var collision_radius = $CollisionShape2D.shape.radius
var counter: int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_body_entered(body):
	counter += 1
	queue_redraw()

func _on_body_exited(body):
	counter -= 1
	queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, collision_radius, Color.RED if counter > 0 else Color.WHITE)
