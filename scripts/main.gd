extends Node2D
## Game controller: builds the field, spawns waves of lizards, keeps score,
## and runs the HUD and game-over screen.

const ARENA := Rect2(0, 0, 2400, 1600)
const SAVE_PATH := "user://best.save"

var version: String = ProjectSettings.get_setting("application/config/version", "dev")
var _went_fullscreen := false

var world: Node2D
var player: Player
var camera: Camera2D
var controls: TouchControls
var hud: Control

var wave := 0
var to_spawn := 0
var spawn_timer := 0.0
var spawn_interval := 1.2
var between_waves := 0.0
var score := 0
var best := 0
var kills := 0
var started := false
var game_over := false
var game_over_time := 0.0
var banner := ""
var banner_time := 0.0
var shake := 0.0

var _sounds: Dictionary = {}


func _ready() -> void:
	randomize()
	best = _load_best()
	_build_field()
	_build_sounds()

	player = Player.new()
	player.arena = ARENA
	player.position = ARENA.get_center()
	player.fired.connect(_on_player_fired)
	player.hurt.connect(_on_player_hurt)
	player.died.connect(_on_player_died)
	player.reloaded.connect(func() -> void: _sfx("reload", -6.0))
	world.add_child(player)

	camera = Camera2D.new()
	camera.limit_left = int(ARENA.position.x)
	camera.limit_top = int(ARENA.position.y)
	camera.limit_right = int(ARENA.end.x)
	camera.limit_bottom = int(ARENA.end.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.position = player.position
	add_child(camera)
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	layer.add_child(hud)
	controls = TouchControls.new()
	controls.aim_released.connect(func() -> void: player.release_aim())
	controls.tapped.connect(_on_tap)
	layer.add_child(controls)

	between_waves = 1.5


func _build_field() -> void:
	var ground := Sprite2D.new()
	ground.texture = load("res://assets/ui/grass.png")
	ground.centered = false
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.region_enabled = true
	ground.region_rect = ARENA
	ground.z_index = -10
	add_child(ground)

	var decor := Node2D.new()
	decor.z_index = -9
	decor.set_script(preload("res://scripts/field_decor.gd"))
	decor.set("arena", ARENA)
	add_child(decor)

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)


func _build_sounds() -> void:
	for n in ["shot", "hit", "reload", "swing", "hurt", "wave"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/%s.wav" % n)
		p.max_polyphony = 4
		add_child(p)
		_sounds[n] = p


func _sfx(name: String, db := 0.0) -> void:
	var p: AudioStreamPlayer = _sounds[name]
	p.volume_db = db
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()


func _process(delta: float) -> void:
	if not started:
		pass
	elif not game_over:
		player.move_input = controls.get_move()
		player.aim_input = controls.aim_vector
		if Input.is_key_pressed(KEY_SPACE) and controls.aim_vector == Vector2.ZERO:
			player.aim_input = player.facing   # keyboard: hold space to aim forward
		_run_waves(delta)
	else:
		game_over_time += delta

	camera.position = player.position + Vector2(0, -40)
	shake = maxf(shake - delta * 30.0, 0.0)
	camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	banner_time = maxf(banner_time - delta, 0.0)
	hud.queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.keycode == KEY_SPACE and not k.pressed:
		player.release_aim()
	if k and k.pressed and not started:
		_start_game()
	if k and k.pressed and game_over and game_over_time > 1.0:
		get_tree().reload_current_scene()


# ---------------------------------------------------------------- waves

func _run_waves(delta: float) -> void:
	if between_waves > 0.0:
		between_waves -= delta
		if between_waves <= 0.0:
			_start_wave()
		return
	if to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = spawn_interval * randf_range(0.6, 1.3)
			_spawn_lizard()
	elif get_tree().get_nodes_in_group("lizards").is_empty():
		between_waves = 2.5
		player.heal(1)
		_show_banner("Wave %d held!" % wave)


func _start_wave() -> void:
	wave += 1
	to_spawn = 4 + wave * 3
	spawn_interval = maxf(0.35, 1.5 - wave * 0.11)
	spawn_timer = 0.3
	_show_banner("Wave %d" % wave)
	_sfx("wave", -4.0)


func _spawn_lizard() -> void:
	to_spawn -= 1
	var liz := Lizard.new()
	var r := randf()
	var kind := Lizard.Kind.WARRIOR
	if wave >= 3 and r < minf(0.08 + wave * 0.02, 0.25):
		kind = Lizard.Kind.BRUTE
	elif wave >= 2 and r > 1.0 - minf(0.15 + wave * 0.03, 0.4):
		kind = Lizard.Kind.RUNNER
	liz.setup(kind, wave)
	liz.target = player
	liz.position = _spawn_point()
	liz.killed.connect(_on_lizard_killed)
	liz.swung.connect(func() -> void: _sfx("swing", -8.0))
	world.add_child(liz)


func _spawn_point() -> Vector2:
	# Somewhere on the arena edge, preferably just off-screen from the musketeer.
	for i in 40:
		var p: Vector2
		match randi() % 4:
			0: p = Vector2(randf_range(ARENA.position.x, ARENA.end.x), ARENA.position.y + 40)
			1: p = Vector2(randf_range(ARENA.position.x, ARENA.end.x), ARENA.end.y - 10)
			2: p = Vector2(ARENA.position.x + 30, randf_range(ARENA.position.y, ARENA.end.y))
			_: p = Vector2(ARENA.end.x - 30, randf_range(ARENA.position.y, ARENA.end.y))
		if p.distance_to(player.position) > 700.0 and p.distance_to(player.position) < 1100.0:
			return p
	return player.position + Vector2.from_angle(randf() * TAU) * 800.0


# ---------------------------------------------------------------- events

func _on_player_fired(origin: Vector2, dir: Vector2) -> void:
	var b := Bullet.new()
	b.position = origin
	b.direction = dir
	b.hit_lizard.connect(func(liz: Lizard, _i: int) -> void:
		world.add_child(Fx.splat(liz.body_center(), dir))
		_sfx("hit", -2.0))
	world.add_child(b)
	world.add_child(Fx.smoke(origin + dir * 30.0, dir))
	shake = 9.0
	_sfx("shot")


func _on_lizard_killed(liz: Lizard, pierce_index: int) -> void:
	if game_over:
		return
	kills += 1
	var mult := pierce_index   # 2nd lizard in one shot scores double, 3rd triple
	var pts := liz.points * mult
	score += pts
	var msg := "+%d" % pts
	var col := Color(1, 0.9, 0.5)
	if mult == 2:
		msg = "DOUBLE! +%d" % pts
		col = Color(1, 0.6, 0.3)
	elif mult >= 3:
		msg = "TRIPLE!! +%d" % pts
		col = Color(1, 0.35, 0.3)
		shake = 14.0
	world.add_child(Fx.popup(liz.body_center() + Vector2(0, -50), msg, col))


func _on_player_hurt(_hp: int) -> void:
	shake = 12.0
	_sfx("hurt")


func _on_player_died() -> void:
	game_over = true
	controls.reset()
	if score > best:
		best = score
		_save_best()


func _on_tap() -> void:
	_web_fullscreen()
	if not started:
		_start_game()
		return
	if game_over and game_over_time > 1.0:
		get_tree().reload_current_scene()


func _start_game() -> void:
	started = true
	controls.reset()


## In a phone browser, the first tap goes fullscreen and locks landscape,
## so the address bar doesn't eat the screen. Desktop browsers are left alone.
func _web_fullscreen() -> void:
	if _went_fullscreen or not OS.has_feature("web") or not DisplayServer.is_touchscreen_available():
		return
	_went_fullscreen = true
	JavaScriptBridge.eval("""
		(function(){
			var el = document.documentElement;
			var req = el.requestFullscreen || el.webkitRequestFullscreen;
			if (!req) return;
			var p = req.call(el);
			if (p && p.then) p.then(function(){
				if (screen.orientation && screen.orientation.lock) screen.orientation.lock('landscape').catch(function(){});
			}).catch(function(){});
		})();
	""", true)


func _show_banner(text: String) -> void:
	banner = text
	banner_time = 2.0


# ---------------------------------------------------------------- HUD

func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	var vs := hud.size
	# Hearts
	for i in player.max_hp:
		var c := Vector2(36 + i * 40, 38)
		var full := i < player.hp
		_draw_heart(c, Color(0.85, 0.15, 0.15) if full else Color(0.2, 0.1, 0.1, 0.6))
	# Musket status
	var status := "LOADED" if player.loaded else "RELOADING"
	var scol := Color(0.95, 0.85, 0.4) if player.loaded else Color(0.7, 0.7, 0.7)
	_text(font, Vector2(20, 84), status, 18, scol)
	# Score / wave
	_text_right(font, Vector2(vs.x - 20, 42), "SCORE %d" % score, 28, Color.WHITE)
	_text_right(font, Vector2(vs.x - 20, 72), "WAVE %d   BEST %d" % [wave, best], 18, Color(1, 1, 1, 0.7))

	_draw_lizard_arrows(vs)
	_text_center(font, Vector2(vs.x * 0.5, 24), "v" + version, 14, Color(1, 1, 1, 0.35))

	if banner_time > 0.0:
		var a := clampf(banner_time, 0.0, 1.0)
		_text_center(font, Vector2(vs.x * 0.5, vs.y * 0.3), banner, 56, Color(1, 0.92, 0.7, a))

	if not started:
		hud.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
		_text_center(font, Vector2(vs.x * 0.5, vs.y * 0.34), "2D MUSKETS", 72, Color(0.95, 0.85, 0.7))
		_text_center(font, Vector2(vs.x * 0.5, vs.y * 0.44), "Hold the line against the lizards", 26, Color.WHITE)
		_text_center(font, Vector2(vs.x * 0.5, vs.y * 0.56), "Left thumb: march      Right thumb: hold to aim, release to fire", 20, Color(1, 1, 1, 0.75))
		_text_center(font, Vector2(vs.x * 0.5, vs.y * 0.72), "Tap to begin", 30, Color(1, 0.85, 0.4, 0.6 + 0.4 * sin(Time.get_ticks_msec() / 250.0)))
		return

	if game_over:
		hud.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, minf(game_over_time, 0.6)))
		_text_center(font, Vector2(vs.x * 0.5, vs.y * 0.38), "THE LINE HAS FALLEN", 60, Color(0.95, 0.85, 0.7))
		_text_center(font, Vector2(vs.x * 0.5, vs.y * 0.5), "Score %d  -  %d lizards  -  wave %d" % [score, kills, wave], 28, Color.WHITE)
		_text_center(font, Vector2(vs.x * 0.5, vs.y * 0.57), "Best %d" % best, 24, Color(1, 0.85, 0.4))
		if game_over_time > 1.0:
			_text_center(font, Vector2(vs.x * 0.5, vs.y * 0.7), "Tap to march again", 26, Color(1, 1, 1, 0.6 + 0.4 * sin(game_over_time * 4.0)))


## Little red arrows on the screen edge pointing at lizards you can't see yet.
func _draw_lizard_arrows(vs: Vector2) -> void:
	if game_over:
		return
	var xf := get_viewport().get_canvas_transform()
	var screen := Rect2(Vector2.ZERO, vs)
	var inner := screen.grow(-28)
	for node in get_tree().get_nodes_in_group("lizards"):
		var liz := node as Lizard
		var sp: Vector2 = xf * liz.body_center()
		if screen.grow(20).has_point(sp):
			continue
		var c := vs * 0.5
		var d := (sp - c).normalized()
		# Push from the centre to the inner rect edge along d.
		var tx := (inner.size.x * 0.5) / maxf(absf(d.x), 0.001)
		var ty := (inner.size.y * 0.5) / maxf(absf(d.y), 0.001)
		var at := c + d * minf(tx, ty)
		var col := Color(1, 0.3, 0.2, 0.85) if liz.kind != Lizard.Kind.BRUTE else Color(1, 0.6, 0.1, 0.95)
		hud.draw_colored_polygon(PackedVector2Array([
			at + d * 14.0, at + d.rotated(2.5) * 10.0, at + d.rotated(-2.5) * 10.0]), col)


func _draw_heart(c: Vector2, col: Color) -> void:
	hud.draw_circle(c + Vector2(-7, -4), 9, col)
	hud.draw_circle(c + Vector2(7, -4), 9, col)
	hud.draw_colored_polygon(PackedVector2Array([c + Vector2(-15.5, -1), c + Vector2(15.5, -1), c + Vector2(0, 16)]), col)


func _text(font: Font, p: Vector2, s: String, size: int, col: Color) -> void:
	hud.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, col.a * 0.8))
	hud.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _text_right(font: Font, p: Vector2, s: String, size: int, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(font, p - Vector2(w, 0), s, size, col)


func _text_center(font: Font, p: Vector2, s: String, size: int, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(font, p - Vector2(w * 0.5, 0), s, size, col)


# ---------------------------------------------------------------- save

func _load_best() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	return f.get_32() if f else 0


func _save_best() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_32(best)
