class_name TouchControls
extends Control
## Two floating thumbsticks.
## Left half of the screen: march. Right half: aim — hold to level the musket,
## let go to fire. On desktop the mouse acts as a touch (project setting), and
## WASD / arrow keys also march.

signal aim_released
signal tapped

const RADIUS := 90.0
const DEADZONE := 0.22

var move_vector := Vector2.ZERO
var aim_vector := Vector2.ZERO

var _move_id := -1
var _move_origin := Vector2.ZERO
var _move_pos := Vector2.ZERO
var _aim_id := -1
var _aim_origin := Vector2.ZERO
var _aim_pos := Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			tapped.emit()
			if e.position.x < size.x * 0.5 and _move_id == -1:
				_move_id = e.index
				_move_origin = e.position
				_move_pos = e.position
			elif e.position.x >= size.x * 0.5 and _aim_id == -1:
				_aim_id = e.index
				_aim_origin = e.position
				_aim_pos = e.position
		else:
			if e.index == _move_id:
				_move_id = -1
				move_vector = Vector2.ZERO
			elif e.index == _aim_id:
				_aim_id = -1
				var had_aim := aim_vector != Vector2.ZERO
				aim_vector = Vector2.ZERO
				if had_aim:
					aim_released.emit()
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _move_id:
			_move_pos = d.position
			move_vector = _stick(_move_origin, _move_pos)
		elif d.index == _aim_id:
			_aim_pos = d.position
			var v := _stick(_aim_origin, _aim_pos)
			if v != Vector2.ZERO:
				aim_vector = v
		queue_redraw()


func _stick(origin: Vector2, pos: Vector2) -> Vector2:
	var v := (pos - origin) / RADIUS
	if v.length() < DEADZONE:
		return Vector2.ZERO
	return v.limit_length(1.0)


## Movement including keyboard, for desktop testing.
func get_move() -> Vector2:
	var k := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): k.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): k.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): k.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): k.y += 1
	if k != Vector2.ZERO:
		return k.normalized()
	return move_vector


func reset() -> void:
	_move_id = -1
	_aim_id = -1
	move_vector = Vector2.ZERO
	aim_vector = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	# Faint hints where the sticks are when idle; full sticks when touched.
	if _move_id == -1:
		_draw_hint(Vector2(170, size.y - 150), "MARCH")
	else:
		_draw_stick(_move_origin, _move_pos, Color(0.9, 0.9, 0.8))
	if _aim_id == -1:
		_draw_hint(Vector2(size.x - 170, size.y - 150), "AIM - RELEASE TO FIRE")
	else:
		_draw_stick(_aim_origin, _aim_pos, Color(1.0, 0.75, 0.4))


func _draw_hint(c: Vector2, label: String) -> void:
	draw_arc(c, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.12), 3.0)
	draw_circle(c, 34, Color(1, 1, 1, 0.08))
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, c + Vector2(-w * 0.5, RADIUS + 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.3))


func _draw_stick(origin: Vector2, pos: Vector2, col: Color) -> void:
	draw_circle(origin, RADIUS, Color(0, 0, 0, 0.22))
	draw_arc(origin, RADIUS, 0, TAU, 48, Color(col, 0.5), 3.0)
	var knob := origin + (pos - origin).limit_length(RADIUS)
	draw_circle(knob, 36, Color(col, 0.55))
