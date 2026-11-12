extends CharacterBody2D
class_name ArenaBullet
## Fast projectile that disappears after its second wall contact.

signal target_hit(target: ArenaGun, shooter: ArenaGun, impact_direction: Vector2, impact_position: Vector2)
signal wall_bounced(impact_position: Vector2)

@export var speed := 720.0
@export var bullet_color := Color("3b82f6")
@export var projectile_radius := 5.0
@export var projectile_style := "pulse_blaster"

const TRAIL_POINTS := 10
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
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if is_instance_valid(collision_shape) and collision_shape.shape is CircleShape2D:
		var circle := (collision_shape.shape as CircleShape2D).duplicate() as CircleShape2D
		circle.radius = projectile_radius
		collision_shape.shape = circle
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
	var min_position := ARENA_MIN + Vector2.ONE * projectile_radius
	var max_position := ARENA_MAX - Vector2.ONE * projectile_radius
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
		draw_polyline(trail_points, Color(bullet_color, 0.4), projectile_radius * 1.5, true)

	# Keep each class recognizable even when projectiles cross at high speed.
	draw_circle(Vector2.ZERO, projectile_radius + 6.0, Color(bullet_color, 0.12))
	match projectile_style:
		"heavy_cannon":
			draw_colored_polygon(PackedVector2Array([Vector2(-projectile_radius, -projectile_radius * 0.65), Vector2(projectile_radius, -projectile_radius * 0.65), Vector2(projectile_radius * 1.3, 0.0), Vector2(projectile_radius, projectile_radius * 0.65), Vector2(-projectile_radius, projectile_radius * 0.65)]), Color.WHITE)
			draw_circle(Vector2.ZERO, projectile_radius * 0.58, bullet_color)
		"rapid_blaster":
			draw_rect(Rect2(-projectile_radius * 1.5, -projectile_radius * 0.5, projectile_radius * 3.0, projectile_radius), Color.WHITE)
			draw_rect(Rect2(-projectile_radius, -projectile_radius * 0.28, projectile_radius * 2.0, projectile_radius * 0.56), bullet_color)
		"railgun":
			draw_colored_polygon(PackedVector2Array([Vector2(-projectile_radius * 2.0, -projectile_radius * 0.5), Vector2(projectile_radius, -projectile_radius * 0.5), Vector2(projectile_radius * 2.0, 0.0), Vector2(projectile_radius, projectile_radius * 0.5), Vector2(-projectile_radius * 2.0, projectile_radius * 0.5)]), Color.WHITE)
			draw_line(Vector2(-projectile_radius, 0.0), Vector2(projectile_radius, 0.0), bullet_color, 2.0)
		_:
			draw_circle(Vector2.ZERO, projectile_radius, Color.WHITE)
			draw_circle(Vector2.ZERO, projectile_radius * 0.7, bullet_color)


func _finish() -> void:
	if _is_finished:
		return
	_is_finished = true
	queue_free()


func cancel() -> void:
	_finish()
