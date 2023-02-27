class_name Command

enum Type {MOVE_POINT, ATTACK_UNIT, ATTACK_MOVE, FOLLOW_UNIT, CAST_SELF, CAST_POINT, CAST_UNIT, NONE}

var type = Type.NONE
var target_position: Vector2 = Vector2.ZERO
var target_unit: WeakRef = null
var is_new: bool = false
var is_complete: bool = false

func _init():
	pass

func set_task(type: Type, target=null):
	self.type = type

	match type:
		Type.MOVE_POINT, Type.CAST_POINT, Type.ATTACK_MOVE:
			assert(target is Vector2)
			target_position = target

		Type.ATTACK_UNIT, Type.FOLLOW_UNIT, Type.CAST_UNIT:
			assert(target is ArenaUnit)
			target_unit = target

		Type.CAST_SELF:
			if target != null:
				printerr("Command.set_task called with unnecessary target set")

	is_new = true
	is_complete = false

func complete():
	is_complete = true
