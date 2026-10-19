class_name Player
extends Node2D
## The musketeer. Hold the aim stick to level the musket (the longer you hold,
## the steadier the shot), release to fire, then wait out the reload.

signal fired(origin: Vector2, direction: Vector2)
signal hurt(hp: int)
signal died
signal reloaded

const SCALE := 0.55
const SPEED := 270.0
const AIM_MOVE_FACTOR := 0.0      # planted feet while aiming
const RELOAD_MOVE_FACTOR := 0.45  # shuffle while ramming the ball home
const RELOAD_TIME := 1.45
const FIRE_TIME := 0.25
const MIN_AIM_TIME := 0.12
const STEADY_TIME := 0.6          # full accuracy after this long
const MAX_SPREAD := 0.16          # radians, for a snap shot
const BODY_RADIUS := 26.0
const CHEST_HEIGHT := 62.0

var max_hp := 5
var hp := 5
var arena := Rect2(0, 0, 2400, 1600)

var move_input := Vector2.ZERO
var aim_input := Vector2.ZERO

var state := "march"   # march | aim | fire | reload | dead
var facing := Vector2.DOWN
var timer := 0.0
var aim_time := 0.0
var loaded := true
var invuln := 0.0
var knockback := Vector2.ZERO
var _bob := 0.0

var sprite: AnimatedSprite2D
var overlay: Node2D


func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.frames_for("musketeer")
	sprite.offset = Sprites.anchor_offset("musketeer")
	sprite.scale = Vector2.ONE * SCALE
	add_child(sprite)
	overlay = Node2D.new()
	overlay.z_index = 5
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	_play()


func chest() -> Vector2:
	return global_position + Vector2(0, -CHEST_HEIGHT)


func is_dead() -> bool:
	return state == "dead"


func steadiness() -> float:
	return clampf(aim_time / STEADY_TIME, 0.0, 1.0)


func release_aim() -> void:
	if state != "aim":
		return
	if aim_time < MIN_AIM_TIME:
		state = "march"
		_play()
		return
	var spread := MAX_SPREAD * (1.0 - steadiness())
	var dir := facing.rotated(randf_range(-spread, spread))
	state = "fire"
	timer = FIRE_TIME
	loaded = false
	_play()
	fired.emit(chest() + facing * 34.0, dir)


func take_hit(from: Vector2) -> void:
	if state == "dead" or invuln > 0.0:
		return
	hp -= 1
	invuln = 1.1
	knockback = (global_position - from).normalized() * 420.0
	if state == "aim":
		state = "march"   # a blow spoils your aim
	hurt.emit(hp)
	if hp <= 0:
		_die()


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)


func _die() -> void:
	state = "dead"
	sprite.play("reload_" + Sprites.dir_name(facing))
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", deg_to_rad(-90.0 if facing.x < 0 else 90.0), 0.4)
	tw.parallel().tween_property(sprite, "modulate", Color(0.6, 0.5, 0.5), 0.4)
	died.emit()


func _process(delta: float) -> void:
	overlay.queue_redraw()
	queue_redraw()
	if state == "dead":
		return

	invuln = maxf(invuln - delta, 0.0)
	sprite.modulate = Color(1, 0.55, 0.55) if invuln > 0.0 and int(invuln * 14.0) % 2 == 0 else Color.WHITE

	var speed_factor := 1.0
	match state:
		"march":
			if aim_input.length() > 0.0 and loaded:
				state = "aim"
				aim_time = 0.0
		"aim":
			speed_factor = AIM_MOVE_FACTOR
			if aim_input.length() > 0.0:
				facing = aim_input.normalized()
			aim_time += delta
		"fire":
			speed_factor = 0.0
			timer -= delta
			if timer <= 0.0:
				state = "reload"
				timer = RELOAD_TIME
		"reload":
			speed_factor = RELOAD_MOVE_FACTOR
			timer -= delta
			if timer <= 0.0:
				loaded = true
				state = "march"
				reloaded.emit()

	var move := move_input.limit_length(1.0) * SPEED * speed_factor
	if state == "march" and move.length() > 10.0:
		facing = move.normalized()
	position += (move + knockback) * delta
	knockback = knockback.move_toward(Vector2.ZERO, 2200.0 * delta)
	position = position.clamp(arena.position + Vector2(30, 60), arena.end - Vector2(30, 10))

	# Only one marching frame per direction, so fake the stride with a bob and sway.
	if move.length() > 10.0:
		_bob += delta * 11.0
		sprite.position.y = -absf(sin(_bob)) * 7.0
		sprite.rotation = sin(_bob) * 0.04
	else:
		_bob = 0.0
		sprite.position.y = lerpf(sprite.position.y, 0.0, 0.3)
		sprite.rotation = lerpf(sprite.rotation, 0.0, 0.3)
	_play()


func _play() -> void:
	var anim: String = state + "_" + Sprites.dir_name(facing)
	if sprite.animation != anim:
		sprite.play(anim)


func _draw() -> void:
	# Shadow and aim line live under the sprite.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 34.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO)
	if state == "aim":
		var s := steadiness()
		var spread := MAX_SPREAD * (1.0 - s)
		var o := Vector2(0, -CHEST_HEIGHT) + facing * 40.0
		var col := Color(1, 0.92, 0.6, 0.25 + 0.5 * s)
		if s >= 1.0:
			col = Color(1, 0.35, 0.25, 0.85)
		for side in [-1.0, 1.0]:
			var d := facing.rotated(spread * side)
			var dist := 0.0
			while dist < 520.0:
				draw_line(o + d * dist, o + d * (dist + 14.0), col, 2.0)
				dist += 26.0
		if s >= 1.0:
			draw_line(o, o + facing * 520.0, Color(1, 0.35, 0.25, 0.35), 1.0)


func _draw_overlay() -> void:
	if state == "reload":
		var w := 56.0
		var p := Vector2(-w * 0.5, -128.0)
		overlay.draw_rect(Rect2(p, Vector2(w, 7)), Color(0, 0, 0, 0.6))
		overlay.draw_rect(Rect2(p + Vector2(1, 1), Vector2((w - 2) * (1.0 - timer / RELOAD_TIME), 5)), Color(0.95, 0.8, 0.35))
