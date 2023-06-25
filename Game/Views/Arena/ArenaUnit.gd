extends CharacterBody2D

class_name ArenaUnit

@export var max_speed: float = 100.0
var speed: float = 0.0
const turn_rate: float = 2 * PI

@export var alliance: Definitions.Alliance
var command: Command = Command.new()

@onready var process_timer: Timer = $ProcessTimer
@onready var sprite_direction_timer: Timer = $SpriteDirectionTimer
var ready_to_process: bool = false

var navray_angles: Array[float] = [0.0, -PI/8, PI/8, -PI/4, PI/4, -3*PI/8, 3*PI/8, -PI/2, PI/2, -5*PI/8, 5*PI/8, -3*PI/4, 3*PI/4]
@onready var navrays: Array[RayCast2D]
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var navrays_node: Node2D = $NavRays

@onready var char_sprite: AnimatedSprite2D = $CharacterSprite
@onready var selection_circle: AnimatedSprite2D = $SelectionCircle

@onready var voice_selected: AudioStreamPlayer2D = $VoiceSelected
@onready var voice_move: AudioStreamPlayer2D = $VoiceMove
var delay_queue: Array[Dictionary] = []

var arrival_direction: Variant = null
var nav_direction: Vector2 = Vector2.DOWN
var stopped: bool = true
var was_selected: bool = false
var selected: bool = false

var correction_rot: float = 0.0
var close_enough_modifier: float = 0.0
var closest_dist: float = 0.0

var last_pos: Vector2 = position

var displacements: Array = [100.0, 100.0, 100.0, 100.0, 100.0]

var astar_path: PackedVector2Array = []

var is_first_physics_frame_processed: bool = false

func _ready():
	for navray_angle in navray_angles:
		var navray: RayCast2D = RayCast2D.new()
		var target_position: Vector2 = (Vector2.RIGHT * 60.0).rotated(navray_angle)

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

	update_sprite_direction()
	char_sprite.play()
	nav_agent.target_position = position

func _process(delta):
	z_index = position.y
	queue_redraw()
	if was_selected != selected:
		selection_circle.visible = selected
		was_selected = selected

	for item in delay_queue:
		item.timer = max(0.0, item.timer - delta)
		if item.timer == 0.0:
			item.payload.call()

	while not delay_queue.is_empty() and delay_queue[0].timer == 0.0:
		delay_queue.pop_front()

func _physics_process(delta):
#	var next_pos = nav_agent.get_next_path_position()
	var next_pos = nav_agent.target_position
	var dist_to_next: float = position.distance_to(next_pos)
	var displacement: float = position.distance_to(last_pos)

	correction_rot *= pow(.01, delta)
	close_enough_modifier = max(0.0, close_enough_modifier - max_speed * delta * 0.2)

	speed = min(speed + max_speed * 2.0 * delta, max(20.0, dist_to_next * 2.0), max_speed, displacement/delta + max_speed * 2.0 * delta)

	if not stopped:
		if dist_to_next >= closest_dist - delta * max_speed * 0.2:
			if position.distance_to(last_pos) < max_speed * delta * 0.5:
				close_enough_modifier += 55.0 * delta
			else:
				close_enough_modifier += min(55.0, max_speed * 0.3) * delta
		else:
			closest_dist = dist_to_next

	var flock_members_ahead: Dictionary = {}

	if stopped or dist_to_next < 15.0 + close_enough_modifier:
		velocity = Vector2.ZERO

		if not stopped:
			stopped = true
			close_enough_modifier = 0.0
			if arrival_direction != null:
				set_nav_direction(arrival_direction)
				arrival_direction = null
	else:
		var flock_guided_nav_vec: Vector2 = position.direction_to(next_pos) * 3
		var something_in_front: bool = false
		var correction_rot_step: float = 0.0
		var correction_rot_mult: float = .37 * PI * delta
		for i in len(navrays):
			var navray = navrays[i]
			if navray.is_colliding():
				if navray_angles[i] > 0.0:
					correction_rot_step -= correction_rot_mult
				elif navray_angles[i] < 0.0:
					correction_rot_step += correction_rot_mult
				else:
					something_in_front = true
				var member_ahead = navray.get_collider()

				if member_ahead is ArenaUnit and \
					member_ahead.alliance==alliance and \
					member_ahead.nav_agent.target_position.distance_to(nav_agent.target_position) <= 10.0 and \
					member_ahead not in flock_members_ahead:

					flock_members_ahead[member_ahead] = true
					flock_guided_nav_vec += member_ahead.nav_direction.normalized()

				navray.modulate.g = 0.1
			else:
				navray.modulate.g = 1.0

		if something_in_front and abs(correction_rot_step) < correction_rot_mult * 0.5:
			correction_rot_step += 2 * correction_rot_mult

		correction_rot += correction_rot_step

		if velocity.length_squared() > 20.0:
			set_nav_direction(flock_guided_nav_vec.rotated(correction_rot))

		velocity = nav_direction * speed


	if sprite_direction_timer.is_stopped():
		sprite_direction_timer.start()
		update_sprite_direction()

	last_pos = position

	move_and_slide()

	is_first_physics_frame_processed = true

func _draw():
	pass
#	draw_dashed_line(Vector2(-50,-50), Vector2(50, 50), Color.WHITE)
#	draw_dashed_line(Vector2(-50,50), Vector2(50, -50), Color.WHITE)
#	if selected:
#		draw_arc(Vector2.ZERO, nav_agent.radius, 0, 2*PI, 50, Color.WHITE)

	if is_first_physics_frame_processed:
		draw_circle(nav_agent.get_next_path_position() - position, 15.0 + close_enough_modifier, Color(1,0,0,0.5))

func _on_process_timer_timeout():
	match command.type:
		Command.Type.MOVE_POINT:
			if command.is_new:
				queue_voice(voice_move)
				arrival_direction = position.direction_to(command.target_position)
				nav_agent.target_position = command.target_position
				command.is_new = false
				reset_nav_progress()

func set_task(type: Command.Type, target=null):
	command.set_task(type, target)

func _on_navigation_agent_2d_target_reached():
	set_task(Command.Type.NONE)

func update_sprite_direction():
	var above_motion_threshold: bool = speed > 10.0

	if abs(nav_direction.x) > abs(nav_direction.y):
		if nav_direction.x > 0:
			char_sprite.animation = "walk_right" if above_motion_threshold else "idle_right"
		else:
			char_sprite.animation = "walk_left" if above_motion_threshold else "idle_left"
	else:
		if nav_direction.y > 0:
			char_sprite.animation = "walk_down" if above_motion_threshold else "idle_down"
		else:
			char_sprite.animation = "walk_up" if above_motion_threshold else "idle_up"

func set_nav_direction(direction: Vector2):
	nav_direction = direction.normalized()
	navrays_node.rotation = nav_direction.angle()

func _on_navigation_agent_2d_path_changed():
#	print("path changed")
	pass

func _on_navigation_agent_2d_link_reached(details):
#	print("link reached")
	pass

func reset_nav_progress():
	closest_dist = position.distance_to(nav_agent.target_position)
	close_enough_modifier = 0.0
	stopped = false

func select(mute: bool = false):
	selected = true
	if not mute:
		queue_voice(voice_selected)

func queue_voice(voice: AudioStreamPlayer2D):
	delay_queue.push_back({"timer": randf() * 0.2, "payload": func(): voice.play()})


func _on_navigation_agent_2d_navigation_finished():
	print("arrived")
