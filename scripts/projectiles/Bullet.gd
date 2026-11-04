extends CharacterBody2D
class_name ArenaBullet
## Fast energy projectile that disappears after its first wall bounce.

signal target_hit(target: ArenaGun, shooter: ArenaGun, impact_direction: Vector2, impact_position: Vector2)
signal wall_bounced(impact_position: Vector2)

@export var speed := 720.0
@export var bullet_color := Color("3b82f6")

const RADIUS := 5.0
const TRAIL_POINTS := 10
const TRAIL_WIDTH := RADIUS * 1.5
const ARENA_MIN := Vector2(132.0, 82.0)
const ARENA_MAX := Vector2(1148.0, 638.0)

var shooter: ArenaGun
var _has_bounced := false
var _is_finished := false
var _trail_positions: Array[Vector2] = []


func setup(owner_gun: ArenaGun, spawn_position: Vector2, direction: Vector2) -> void:
	shooter = owner_gun
	global_position = spawn_position
	velocity = direction.normalized() * speed
	if is_instance_valid(shooter):
		add_collision_exception_with(shooter)


func _physics_process(delta: float) -> void:
	if _is_finished:
		return
	_trail_positions.push_front(global_position)
	if _trail_positions.size() > TRAIL_POINTS:
		_trail_positions.pop_back()
	var collision := move_and_collide(velocity * delta)
	queue_redraw()
	if collision == null:
		_resolve_arena_bounds()
		return
	var collider := collision.get_collider()
	if collider is ArenaGun:
		if collider != shooter:
			target_hit.emit(collider, shooter, velocity.normalized(), collision.get_position())
			_finish()
		return
	if collider is StaticBody2D:
		if _has_bounced:
			_finish()
			return
		velocity = velocity.bounce(collision.get_normal())
		_has_bounced = true
		global_position += collision.get_normal() * 0.5
		wall_bounced.emit(global_position)
		queue_redraw()
		return
	_finish()


func _resolve_arena_bounds() -> void:
	# Keep the projectile's full collision circle inside the arena's inner wall edges.
	var min_position := ARENA_MIN + Vector2.ONE * RADIUS
	var max_position := ARENA_MAX - Vector2.ONE * RADIUS
	var hit_horizontal_bound := global_position.x < min_position.x or global_position.x > max_position.x
	var hit_vertical_bound := global_position.y < min_position.y or global_position.y > max_position.y
	if not hit_horizontal_bound and not hit_vertical_bound:
		return
	if _has_bounced:
		_finish()
		return

	# Clamp the missed collision to the wall and reflect the matching velocity axis.
	if global_position.x < min_position.x:
		global_position.x = min_position.x
		velocity.x = absf(velocity.x)
	elif global_position.x > max_position.x:
		global_position.x = max_position.x
		velocity.x = -absf(velocity.x)
	if global_position.y < min_position.y:
		global_position.y = min_position.y
		velocity.y = absf(velocity.y)
	elif global_position.y > max_position.y:
		global_position.y = max_position.y
		velocity.y = -absf(velocity.y)

	_has_bounced = true
	wall_bounced.emit(global_position)
	queue_redraw()


func _draw() -> void:
	# The sample uses a short, rounded laser ribbon made from recent positions.
	# Store world positions so the trail remains behind the moving projectile.
	if _trail_positions.size() > 1:
		var trail_points := PackedVector2Array()
		for world_position in _trail_positions:
			trail_points.append(to_local(world_position))
		draw_polyline(trail_points, Color(bullet_color, 0.4), TRAIL_WIDTH, true)

	# Bright white-hot core with the player's color inside, like the HTML glow.
	draw_circle(Vector2.ZERO, RADIUS + 6.0, Color(bullet_color, 0.12))
	draw_circle(Vector2.ZERO, RADIUS, Color.WHITE)
	draw_circle(Vector2.ZERO, RADIUS * 0.7, bullet_color)


func _finish() -> void:
	if _is_finished:
		return
	_is_finished = true
	queue_free()


func cancel() -> void:
	_finish()
