extends CharacterBody2D
class_name ArenaBullet
## Fast energy projectile with deterministic wall reflections.

signal finished(bullet: ArenaBullet, shooter: ArenaGun)
signal target_hit(target: ArenaGun, shooter: ArenaGun, impact_direction: Vector2, impact_position: Vector2)

@export var speed := 720.0
@export var max_bounces := 5
@export var bullet_color := Color("3b82f6")

const RADIUS := 5.0
const TRAIL_POINTS := 10
const TRAIL_WIDTH := RADIUS * 1.5

var shooter: ArenaGun
var bounce_count := 0
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
		return
	var collider := collision.get_collider()
	if collider is ArenaGun:
		if collider != shooter:
			target_hit.emit(collider, shooter, velocity.normalized(), collision.get_position())
			_finish()
		return
	if collider is StaticBody2D:
		if bounce_count >= max_bounces:
			_finish()
			return
		velocity = velocity.bounce(collision.get_normal())
		bounce_count += 1
		global_position += collision.get_normal() * 0.5
		queue_redraw()
		return
	_finish()


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
	finished.emit(self, shooter)
	queue_free()
