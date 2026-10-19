extends Node2D
## Scatters rocks, bushes and dirt patches over the grass, and rings the field
## with a dark treeline so the arena edge reads clearly.

var arena := Rect2(0, 0, 2400, 1600)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1648
	# Trampled dirt patches
	for i in 26:
		var p := Vector2(rng.randf_range(arena.position.x, arena.end.x), rng.randf_range(arena.position.y, arena.end.y))
		var r := rng.randf_range(30, 90)
		draw_set_transform(p, rng.randf() * PI, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, r, Color(0.42, 0.36, 0.22, 0.35))
		draw_circle(Vector2(r * 0.2, 0), r * 0.6, Color(0.46, 0.39, 0.24, 0.35))
	draw_set_transform(Vector2.ZERO)
	# Rocks
	for i in 40:
		var p := Vector2(rng.randf_range(arena.position.x, arena.end.x), rng.randf_range(arena.position.y, arena.end.y))
		var s := rng.randf_range(5, 13)
		draw_circle(p + Vector2(2, 3), s, Color(0, 0, 0, 0.25))
		draw_circle(p, s, Color(0.5, 0.5, 0.47))
		draw_circle(p + Vector2(-s * 0.3, -s * 0.3), s * 0.45, Color(0.64, 0.63, 0.58))
	# Bushes
	for i in 22:
		var p := Vector2(rng.randf_range(arena.position.x, arena.end.x), rng.randf_range(arena.position.y, arena.end.y))
		var s := rng.randf_range(14, 24)
		draw_circle(p + Vector2(0, s * 0.5), s * 1.2, Color(0, 0, 0, 0.2))
		for j in 4:
			draw_circle(p + Vector2(rng.randf_range(-s, s), rng.randf_range(-s * 0.5, s * 0.3)), s * 0.75, Color(0.2, 0.36, 0.17))
		draw_circle(p + Vector2(-s * 0.2, -s * 0.4), s * 0.5, Color(0.3, 0.48, 0.22))
	# Treeline border
	var step := 46.0
	var x := arena.position.x
	while x <= arena.end.x:
		_tree(Vector2(x, arena.position.y + rng.randf_range(-6, 14)), rng)
		_tree(Vector2(x, arena.end.y + rng.randf_range(10, 30)), rng)
		x += step
	var y := arena.position.y
	while y <= arena.end.y:
		_tree(Vector2(arena.position.x + rng.randf_range(-12, 6), y), rng)
		_tree(Vector2(arena.end.x + rng.randf_range(-6, 12), y), rng)
		y += step


func _tree(p: Vector2, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(30, 42)
	draw_circle(p, s, Color(0.1, 0.18, 0.09))
	draw_circle(p + Vector2(-s * 0.25, -s * 0.3), s * 0.6, Color(0.15, 0.26, 0.12))
