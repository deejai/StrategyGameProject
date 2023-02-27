class_name ClickContext

var click_pos_start: Vector2
var click_time_start: float
var dragging: bool
var engaged: bool

func _init():
	reset()

func reset():
	self.click_pos_start = Vector2.ZERO
	self.click_time_start = 0.0
	self.dragging = false
	self.engaged = false
