extends Node2D
## Draws the arena backdrop, subtle grid, and thick neon boundary walls.

const BACKGROUND_COLOR := Color("1e2029")
const ARENA_COLOR := Color("191b23")
const GRID_COLOR := Color("262936")
const WALL_COLOR := Color("111a27")
const NEON_COLOR := Color("38d9ff")
const NEON_HIGHLIGHT := Color("a5f2ff")

const ARENA_RECT := Rect2(120.0, 70.0, 1040.0, 580.0)
const WALL_THICKNESS := 24.0
const OUTER_WALL_RECT := Rect2(108.0, 58.0, 1064.0, 604.0)
const INNER_WALL_RECT := Rect2(132.0, 82.0, 1016.0, 556.0)
const GRID_SPACING := 40


func _draw() -> void:
	# Full-window backdrop.
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), BACKGROUND_COLOR)

	# Soft cyan glow around the full 24 px wall frame.
	draw_rect(OUTER_WALL_RECT.grow(7.0), Color(0.10, 0.78, 1.0, 0.07), false, 18.0)
	draw_rect(OUTER_WALL_RECT.grow(3.0), Color(0.10, 0.78, 1.0, 0.12), false, 12.0)
	draw_rect(OUTER_WALL_RECT, Color(0.10, 0.78, 1.0, 0.22), false, 6.0)

	# Solid, continuous wall frame. The inner cut-out leaves the arena floor.
	draw_rect(OUTER_WALL_RECT, WALL_COLOR)
	draw_rect(INNER_WALL_RECT, ARENA_COLOR)

	# Crisp neon edges make the wall thickness readable without overpowering play.
	draw_rect(OUTER_WALL_RECT, NEON_COLOR, false, 2.0)
	draw_rect(INNER_WALL_RECT, Color(NEON_COLOR, 0.8), false, 2.0)
	draw_rect(OUTER_WALL_RECT.grow(-3.0), Color(NEON_HIGHLIGHT, 0.42), false, 1.0)

	# Keep the grid subtle so bullets and player colors remain the focus.
	for x in range(int(ARENA_RECT.position.x) + GRID_SPACING, int(ARENA_RECT.end.x), GRID_SPACING):
		draw_line(
			Vector2(x, ARENA_RECT.position.y),
			Vector2(x, ARENA_RECT.end.y),
			GRID_COLOR,
			1.0
		)

	for y in range(int(ARENA_RECT.position.y) + GRID_SPACING, int(ARENA_RECT.end.y), GRID_SPACING):
		draw_line(
			Vector2(ARENA_RECT.position.x, y),
			Vector2(ARENA_RECT.end.x, y),
			GRID_COLOR,
			1.0
		)

