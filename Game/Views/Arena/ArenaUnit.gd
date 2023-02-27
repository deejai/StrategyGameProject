extends CharacterBody2D

class_name ArenaUnit

@export var speed: float = 100.0

@export var alliance: Definitions.Alliance
var command: Command = Command.new()

@onready var process_timer: Timer = $ProcessTimer
var ready_to_process: bool = false

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var was_selected: bool = false
var selected: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	nav_agent.target_position = position + Vector2(0.0001, 0.0001)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if was_selected != selected:
		was_selected = selected
		queue_redraw()

func _physics_process(delta):
	var nav_speed = min(speed, nav_agent.distance_to_target() * 2)
	print(nav_speed)
	var nav_velocity: Vector2 = position.direction_to(nav_agent.get_next_path_position()) * nav_speed
	nav_agent.set_velocity(nav_velocity)
	move_and_slide()

func _draw():
	if selected:
		draw_arc(Vector2.ZERO, nav_agent.radius, 0, 2*PI, 50, Color.WHITE)

func _on_process_timer_timeout():
	match command.type:
		Command.Type.MOVE_POINT:
			if command.is_new:
				nav_agent.target_position = command.target_position

func set_task(type: Command.Type, target=null):
	command.set_task(type, target)

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity

func _on_navigation_agent_2d_target_reached():
	nav_agent.target_position = position
