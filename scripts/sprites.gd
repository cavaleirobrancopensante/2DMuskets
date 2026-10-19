class_name Sprites
## Builds SpriteFrames from the sliced sprite sheets in res://assets/<character>/.
## Files are named <state>_<dir>.png, e.g. aim_front.png.

const STATES := ["aim", "fire", "reload", "march"]
const DIRS := ["front", "back", "left", "right"]

static var _cache: Dictionary = {}


static func frames_for(character: String) -> SpriteFrames:
	if _cache.has(character):
		return _cache[character]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for st in STATES:
		for dr in DIRS:
			var anim: String = "%s_%s" % [st, dr]
			sf.add_animation(anim)
			sf.set_animation_loop(anim, false)
			sf.add_frame(anim, load("res://assets/%s/%s.png" % [character, anim]))
	_cache[character] = sf
	return sf


## Offset that puts the feet on the node origin (sprites are centered).
## Every frame of a character shares one canvas; the feet sit 6px above its bottom.
const ANCHOR_OFFSET := {
	"musketeer": Vector2(0, -97.5),
	"lizard": Vector2(0, -96.5),
}


static func anchor_offset(character: String) -> Vector2:
	return ANCHOR_OFFSET[character]


## Maps an arbitrary direction to one of the four sprite directions.
static func dir_name(v: Vector2) -> String:
	if absf(v.x) >= absf(v.y):
		return "right" if v.x >= 0.0 else "left"
	return "front" if v.y >= 0.0 else "back"
