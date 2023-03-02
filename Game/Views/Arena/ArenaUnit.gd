extends CharacterBody2D

class_name ArenaUnit

@export var max_speed: float = 100.0
var speed: float = 0.0
const turn_rate: float = 2 * PI

@export var alliance: Definitions.Alliance
var command: Command = Command.new()

@onready var process_timer: Timer = $ProcessTimer
var ready_to_process: bool = false

enum NavrayDir {FORWARD, CCW_NARROW, CW_NARROW, CCW_Wide, CW_Wide}
var navray_angles: Array[float] = [0.0, -PI/8, PI/8, -PI/4, PI/4]
@onready var navrays: Array[RayCast2D]
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var navrays_node: Node2D = $NavRays

@onready var char_sprite: AnimatedSprite2D = $CharacterSprite
@onready var selection_circle: AnimatedSprite2D = $SelectionCircle

var nav_direction: Vector2 = Vector2.DOWN
var sprite_direction: Vector2 = Vector2.DOWN
var stopped: bool = true
var was_selected: bool = false
var selected: bool = false

var correction_rot: float = 0.0

var last_pos: Vector2 = position
var stuck_timer: float = 0.0

func _ready():
	for i in NavrayDir.values():
		var navray: RayCast2D = RayCast2D.new()
		var target_position: Vector2 = (Vector2.RIGHT * 60.0).rotated(navray_angles[i])
		print(target_position)
	
		var poly: Polygon2D = Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2.ZERO,
			target_position.rotated(PI/128),
			target_position.rotated(-PI/128),
			])

		navray.target_position = target_position
		navray.add_child(poly)

		navrays.append(navray)
		navrays_node.add_child(navray)

	update_animation()
	char_sprite.play()
	nav_agent.target_position = position

func _process(delta):
	if was_selected != selected:
		selection_circle.visible = selected
		was_selected = selected

func _physics_process(delta):
	var next_pos = nav_agent.get_next_path_position()

	var should_update_animation: bool = false

	correction_rot *= pow(.01, delta)

	var force_stop: bool = false

	if next_pos != position:
		var movement = position.distance_to(last_pos)
		if movement > max_speed * delta * 0.35:
			stuck_timer = 0.0
		else:
			stuck_timer += delta

		if stuck_timer >= 1.0:
			force_stop = true

	last_pos = position

	if force_stop or position.distance_squared_to(next_pos) < 4.0:
		velocity = Vector2.ZERO

		if not stopped:
			should_update_animation = true
			stopped = true
			nav_agent.target_position = position
	else:
		if stopped:
			should_update_animation = true

		stopped = false

		for i in len(navrays):
			var navray = navrays[i]
			if navray.is_colliding():
				if navray_angles[i] > 0.0:
					correction_rot -= .5 * PI * delta
				elif navray_angles[i] < 0.0:
					correction_rot += .5 * PI * delta
				navray.modulate.g = 0.1
			else:
				navray.modulate.g = 1.0

		set_nav_direction(position.direction_to(next_pos).rotated(correction_rot) if velocity.length_squared() > 20.0 else sprite_direction)

		speed = min(speed + max_speed * delta, max(20.0, position.distance_to(next_pos) * 2.0), max_speed)
		velocity = nav_direction * speed

		if abs(velocity.x) > abs(velocity.y):
			if velocity.x > 0:
				if sprite_direction != Vector2.RIGHT:
					sprite_direction = Vector2.RIGHT
					should_update_animation = true
			else:
				if sprite_direction != Vector2.LEFT:
					sprite_direction = Vector2.LEFT
					should_update_animation = true
		else:
			if velocity.y > 0:
				if sprite_direction != Vector2.DOWN:
					sprite_direction = Vector2.DOWN
					should_update_animation = true
			else:
				if sprite_direction != Vector2.UP:
					sprite_direction = Vector2.UP
					should_update_animation = true

	if should_update_animation:
		update_animation()

	move_and_slide()

func _draw():
	pass
#	draw_dashed_line(Vector2(-50,-50), Vector2(50, 50), Color.WHITE)
#	draw_dashed_line(Vector2(-50,50), Vector2(50, -50), Color.WHITE)
#	if selected:
#		draw_arc(Vector2.ZERO, nav_agent.radius, 0, 2*PI, 50, Color.WHITE)
#
#	draw_circle(nav_agent.get_next_path_position() - position, 10.0, Color.RED)

func _on_process_timer_timeout():
	match command.type:
		Command.Type.MOVE_POINT:
			if command.is_new:
				nav_agent.target_position = command.target_position
				command.is_new = false

func set_task(type: Command.Type, target=null):
	command.set_task(type, target)

func _on_navigation_agent_2d_target_reached():
	update_animation()
	nav_agent.target_position = position
	set_task(Command.Type.NONE)

func update_animation():
	match(sprite_direction):
		Vector2.UP:
			char_sprite.animation = "walk_up" if velocity.length_squared() > 2.0 else "idle_up"
		Vector2.DOWN:
			char_sprite.animation = "walk_down" if velocity.length_squared() > 2.0 else "idle_down"
		Vector2.LEFT:
			char_sprite.animation = "walk_left" if velocity.length_squared() > 2.0 else "idle_left"
		Vector2.RIGHT:
			char_sprite.animation = "walk_right" if velocity.length_squared() > 2.0 else "idle_right"

func set_nav_direction(direction: Vector2):
	nav_direction = direction
	navrays_node.rotation = direction.angle()

func _on_navigation_agent_2d_path_changed():
	print("path changed")
	reset_nav_progress()

func _on_navigation_agent_2d_link_reached(details):
	print("link reached")
	reset_nav_progress()

func reset_nav_progress():
	print(str("reset at ", stuck_timer))
	stuck_timer = 0.0
