extends Area2D

@onready var collision_radius = $CollisionShape2D.shape.radius
var counter: int = 0
var astar_ref: WeakRef
var node_id: int

func init(astar_ref, node_id):
	self.astar_ref = weakref(astar_ref)
	self.node_id = node_id

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_body_entered(body):
	counter += 1
	queue_redraw()

	if counter == 1:
		var astar2d: AStar2D = astar_ref.get_ref()
		astar2d.set_point_disabled(node_id, false)

func _on_body_exited(body):
	counter -= 1
	queue_redraw()

	if counter == 0:
		var astar2d: AStar2D = astar_ref.get_ref()
		astar2d.set_point_disabled(node_id, true)

func _draw():
	pass
#	draw_circle(Vector2.ZERO, collision_radius, Color.RED if counter > 0 else Color.WHITE)
