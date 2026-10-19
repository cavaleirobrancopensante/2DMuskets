class_name Fx
extends Node2D
## Tiny self-drawing effects: gunsmoke, lizard blood, and floating score text.

enum Kind { SMOKE, SPLAT, TEXT }

var kind := Kind.SMOKE
var life := 1.0
var max_life := 1.0
var text := ""
var color := Color.WHITE
var _parts: Array = []   # [pos, vel, radius]


static func smoke(at: Vector2, dir: Vector2) -> Fx:
	var f := Fx.new()
	f.kind = Kind.SMOKE
	f.position = at
	f.life = 1.4
	f.max_life = 1.4
	for i in 9:
		var v := dir.rotated(randf_range(-0.5, 0.5)) * randf_range(40.0, 160.0) + Vector2(0, -20)
		f._parts.append([dir * randf_range(0, 30), v, randf_range(8.0, 16.0)])
	return f


static func splat(at: Vector2, dir: Vector2) -> Fx:
	var f := Fx.new()
	f.kind = Kind.SPLAT
	f.position = at
	f.life = 0.5
	f.max_life = 0.5
	for i in 10:
		var v := dir.rotated(randf_range(-0.8, 0.8)) * randf_range(90.0, 320.0)
		f._parts.append([Vector2.ZERO, v, randf_range(2.0, 5.0)])
	return f


static func popup(at: Vector2, msg: String, col: Color) -> Fx:
	var f := Fx.new()
	f.kind = Kind.TEXT
	f.position = at
	f.text = msg
	f.color = col
	f.life = 0.9
	f.max_life = 0.9
	return f


func _ready() -> void:
	z_index = 4


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for p in _parts:
		p[0] += p[1] * delta
		p[1] *= 0.92 if kind == Kind.SMOKE else 0.88
		if kind == Kind.SMOKE:
			p[2] += delta * 14.0
	if kind == Kind.TEXT:
		position.y -= 50.0 * delta
	queue_redraw()


func _draw() -> void:
	var t := life / max_life
	match kind:
		Kind.SMOKE:
			for p in _parts:
				draw_circle(p[0], p[2], Color(0.78, 0.78, 0.76, 0.45 * t))
		Kind.SPLAT:
			for p in _parts:
				draw_circle(p[0], p[2] * t, Color(0.45, 0.7, 0.2, t))
		Kind.TEXT:
			var font := ThemeDB.fallback_font
			var size := 26
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			draw_string_outline(font, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, t))
			draw_string(font, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, t))
