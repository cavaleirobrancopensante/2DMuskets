class_name Bullet
extends Node2D
## A musket ball. Fast, heavy, and it punches through the first lizard it hits,
## so lining them up pays off.

signal hit_lizard(lizard: Lizard, pierce_index: int)

const SPEED := 1500.0
const LIFE := 0.6
const PIERCE := 2   # lizards it can pass through

var direction := Vector2.RIGHT
var life := LIFE
var hits := 0
var _hit_set: Dictionary = {}
var _trail: Array[Vector2] = []


func _ready() -> void:
	z_index = 3


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	# Sub-step so a fast ball can't skip over a lizard between frames.
	var step := SPEED * delta
	var steps := int(ceil(step / 12.0))
	for i in steps:
		position += direction * (step / steps)
		for node in get_tree().get_nodes_in_group("lizards"):
			var liz := node as Lizard
			if liz == null or _hit_set.has(liz):
				continue
			if global_position.distance_to(liz.body_center()) < liz.body_radius():
				_hit_set[liz] = true
				hits += 1
				hit_lizard.emit(liz, hits)
				liz.hit(direction, hits)
				if hits > PIERCE:
					queue_free()
					return
	_trail.push_front(position)
	if _trail.size() > 5:
		_trail.pop_back()
	queue_redraw()


func _draw() -> void:
	var prev := Vector2.ZERO
	for i in _trail.size():
		var p := _trail[i] - position
		draw_line(prev, p, Color(0.95, 0.85, 0.6, 0.5 - i * 0.09), 3.0 - i * 0.4)
		prev = p
	draw_circle(Vector2.ZERO, 4.0, Color(0.15, 0.13, 0.12))
	draw_circle(Vector2(-1, -1), 1.5, Color(0.7, 0.7, 0.7))
