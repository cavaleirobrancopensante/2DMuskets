class_name Lizard
extends Node2D
## A lizard warrior. Marches at the musketeer, winds up its axe ("aim"),
## swings ("fire"), then needs a moment to recover ("reload").
## Step out of reach during the wind-up and the swing whiffs.

signal killed(lizard: Lizard, by_pierce: int)
signal swung

enum Kind { WARRIOR, RUNNER, BRUTE }

const BASE_SCALE := 0.55
const REACH := 70.0        # starts a swing when this close
const HIT_RANGE := 105.0   # swing connects if the target is still this close
const WINDUP := 0.5
const SWING := 0.2
const RECOVER := 0.75

var kind := Kind.WARRIOR
var target: Player
var speed := 85.0
var hp := 1
var points := 10
var size := 1.0
var tint := Color.WHITE

var state := "march"
var timer := 0.0
var facing := Vector2.DOWN
var knockback := Vector2.ZERO
var dead := false
var _bob := 0.0
var _flash := 0.0

var sprite: AnimatedSprite2D


func setup(k: Kind, wave: int) -> void:
	kind = k
	match k:
		Kind.WARRIOR:
			speed = 95.0 + wave * 6.0
		Kind.RUNNER:
			speed = 150.0 + wave * 7.0
			size = 0.88
			tint = Color(1.0, 1.08, 0.75)
			points = 15
		Kind.BRUTE:
			speed = 58.0 + wave * 3.0
			hp = 3
			size = 1.3
			tint = Color(0.75, 0.85, 1.0)
			points = 40
	speed *= randf_range(0.9, 1.1)


func _ready() -> void:
	add_to_group("lizards")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.frames_for("lizard")
	sprite.offset = Sprites.anchor_offset("lizard")
	sprite.scale = Vector2.ONE * BASE_SCALE * size
	sprite.self_modulate = tint
	add_child(sprite)
	_bob = randf() * TAU
	_play()


func body_center() -> Vector2:
	return global_position + Vector2(0, -52.0 * size)


func body_radius() -> float:
	return 30.0 * size


func hit(direction: Vector2, pierce_index: int) -> void:
	if dead:
		return
	hp -= 1
	_flash = 0.12
	knockback = direction.normalized() * (260.0 if kind == Kind.BRUTE else 520.0)
	if hp <= 0:
		_die(direction, pierce_index)
	elif state == "aim":
		state = "march"   # interrupts the wind-up


func _die(direction: Vector2, pierce_index: int) -> void:
	dead = true
	remove_from_group("lizards")
	killed.emit(self, pierce_index)
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", deg_to_rad(80.0 if direction.x >= 0 else -80.0), 0.25)
	tw.parallel().tween_property(sprite, "modulate", Color(1, 0.4, 0.35), 0.15)
	tw.tween_interval(0.5)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	sprite.self_modulate = Color(3, 3, 3) if _flash > 0.0 else tint
	position += knockback * delta
	knockback = knockback.move_toward(Vector2.ZERO, 2400.0 * delta)
	if dead:
		return
	queue_redraw()
	if target == null or target.is_dead():
		_wander(delta)
		return

	var to_target := target.global_position - global_position
	var dist := to_target.length()
	match state:
		"march":
			facing = to_target.normalized()
			var move := facing * speed + _separation() * 140.0
			position += move * delta
			_bob += delta * (8.0 + speed * 0.03)
			sprite.position.y = -absf(sin(_bob)) * 6.0 * size
			sprite.rotation = sin(_bob) * 0.05
			if dist < REACH * size:
				state = "aim"
				timer = WINDUP
		"aim":
			facing = to_target.normalized()
			_settle()
			timer -= delta
			if timer <= 0.0:
				state = "fire"
				timer = SWING
				swung.emit()
				if dist < HIT_RANGE * size:
					target.take_hit(global_position)
		"fire":
			timer -= delta
			if timer <= 0.0:
				state = "reload"
				timer = RECOVER
		"reload":
			position += _separation() * 80.0 * delta
			timer -= delta
			if timer <= 0.0:
				state = "march"
	_play()


func _wander(delta: float) -> void:
	state = "march"
	_bob += delta * 4.0
	sprite.position.y = -absf(sin(_bob)) * 3.0
	_play()


func _settle() -> void:
	sprite.position.y = lerpf(sprite.position.y, 0.0, 0.3)
	sprite.rotation = lerpf(sprite.rotation, 0.0, 0.3)


func _separation() -> Vector2:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("lizards"):
		if other == self:
			continue
		var d: Vector2 = global_position - (other as Node2D).global_position
		var l := d.length()
		var min_d := 48.0 * size
		if l < min_d and l > 0.01:
			push += d / l * (1.0 - l / min_d)
	return push


func _play() -> void:
	var dn := Sprites.dir_name(facing)
	# The sheet's LEFT and RIGHT columns both face right, so mirror for left.
	sprite.flip_h = dn == "left"
	if dn == "left":
		dn = "right"
	var anim: String = state + "_" + dn
	if sprite.animation != anim:
		sprite.play(anim)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 34.0 * size, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO)
	if state == "aim":
		# Wind-up tell: a red arc that closes as the swing approaches.
		var t := 1.0 - timer / WINDUP
		draw_arc(Vector2(0, -130.0 * size), 9.0, -PI / 2, -PI / 2 + TAU * t, 16, Color(1, 0.3, 0.2, 0.9), 3.0)
