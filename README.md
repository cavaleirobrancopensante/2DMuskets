# 2D Muskets

A top-down mobile arena shooter for Godot 4.7. You are a lone musketeer; waves of lizard warriors close in from the treeline. One ball, one shot, then a long reload.

## How to play

- **Left thumb** (anywhere on the left half): march.
- **Right thumb** (anywhere on the right half): drag to level the musket, **let go to fire**. The aim cone narrows the longer you hold; it turns red when the shot is dead steady.
- After firing you must reload (about 1.5s). You can shuffle slowly while ramming the ball home.
- The ball punches through up to three lizards. Lining them up scores double and triple.
- Lizards raise their axe before swinging (a red ring fills over their head). Step out of reach and the swing whiffs; shooting one mid wind-up interrupts it.
- Lizard kinds: warriors, fast pale **runners** (wave 2+), and big blue-tinted **brutes** that take three shots (wave 3+).
- You heal one heart each time you hold a wave. Your best score is saved.

Desktop testing: WASD/arrows to march, mouse drag on the right half to aim (the mouse acts as a touch), or hold Space to aim forward and release to fire.

## Project layout

| Path | What |
| --- | --- |
| `scenes/main.tscn` | Entry scene; everything else is built in code |
| `scripts/main.gd` | Waves, scoring, HUD, game over, save |
| `scripts/player.gd` | Musketeer: march / aim / fire / reload states |
| `scripts/lizard.gd` | Lizard AI: march / wind-up / swing / recover, three kinds |
| `scripts/bullet.gd` | Piercing musket ball |
| `scripts/touch_controls.gd` | Two floating thumbsticks |
| `scripts/sprites.gd` | Builds `SpriteFrames` from the sliced sheets |
| `scripts/fx.gd`, `scripts/field_decor.gd` | Smoke, splats, score popups; field scenery |
| `assets/musketeer`, `assets/lizard` | Frames sliced from the sprite sheets, named `<state>_<dir>.png` |
| `assets/audio` | Generated sound effects |
| `assets/source` | The original sprite sheets |

Sprite states map to the sheet rows: `aim`, `fire`, `reload`, `march`; directions are `front`, `back`, `left`, `right`. Every frame of a character sits on the same canvas with the feet at a fixed point, so swapping animations never jitters. Both lizard side columns face right, so the game mirrors `right` for left-facing lizards.

To add more frames later (e.g. a real walk cycle), drop extra PNGs in and add them with `sf.add_frame()` in `sprites.gd`.

## Exporting to Android

1. *Editor → Editor Settings → Export → Android*: set the Java SDK and Android SDK paths.
2. *Project → Export → Add… → Android*, then export or one-click deploy.

The project uses the Compatibility renderer and landscape (sensor) orientation for the widest device support.
