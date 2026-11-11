# Controls

- **A / D:** Move and steer in the air.
- **Space:** Jump from the ground. Holding it briefly adds an impulse for a higher, longer jump.
- **E:** Grab a nearby climbable surface or release from it.
- **W / ↑ and S / ↓:** Climb up and down.
- **Space while climbing:** Perform a directional jump. Combine Space with A/D and W/S to jump in eight directions. With no direction held, the character pushes away from the surface and slightly upward.
- While airborne, move back near a climbable area and press **E** to grab it again. The indicator only appears when a nearby surface is reachable and visible.

`piedra_1` has two climbable side zones that follow its outer contour. Only the top and bottom surfaces are excluded; the stone's physical collision remains in place.

## Player node parameters

These can be edited in the Inspector. Speeds and impulses are measured in pixels per second; acceleration and gravity are measured in pixels per second squared.

| Property | Default | Description |
|---|---:|---|
| `speed` | 320 | Horizontal speed on the ground. |
| `jump_velocity` | -600 | Initial vertical impulse for a normal jump. |
| `ascent_gravity` | 900 | Gravity while rising. |
| `descent_gravity` | 1150 | Gravity while falling, slightly faster. |
| `jump_hold_duration` | 0.1 s | Maximum duration of the extra impulse while holding Space. |
| `jump_hold_gravity_scale` | 0.55 | Gravity multiplier while Space is held during ascent. |
| `air_acceleration` | 1800 | Air acceleration when pressing A or D. |
| `air_deceleration` | 300 | Gradual slowdown when no direction is held in the air. |
| `air_braking` | 2200 | Force applied when reversing direction in the air. |
| `max_air_horizontal_speed` | 440 | Maximum horizontal speed in the air. |
| `climb_speed` | 100 | Speed while climbing up or down. |
| `climb_jump_horizontal_impulse` | 420 | Initial horizontal impulse when jumping from a climb. |
| `climb_jump_vertical_impulse` | 460 | Initial vertical impulse when jumping from a climb. |
| `climb_jump_air_control` | 1.0 | Air-control multiplier after jumping from a climb. |

Normal jumps use a different impulse from jumps off a climbable surface. Diagonal climb jumps are normalized so they do not exceed the impulse of the main axes. Ground movement does not use air acceleration.

## Adding another climbable surface

Each surface should be a `Node2D` with a `StaticBody2D` child named `Body`, one or more `Area2D` nodes in the `climbable_areas` group, and four marker children: `TopAnchor`, `BottomAnchor`, `LeftClimbAnchor`, and `RightClimbAnchor`. Each area defines its detection range, and the physical body should block movement through the surface.

The reusable stone scene is `scenes/objects/PiedraEscalable.tscn`; it can be dragged from the FileSystem dock and duplicated. Its root node exposes `climb_enabled`, `interaction_margin`, `top_non_climbable_margin`, `bottom_non_climbable_margin`, `climb_speed`, `top_clearance`, and the player's collision half-extents to keep the two side areas and markers aligned. Scaling and rotation transform the sprite, collision, areas, and markers together. At the upper limit, press A/D toward the stone to move onto its top physically; from there, you can jump to the other side.
