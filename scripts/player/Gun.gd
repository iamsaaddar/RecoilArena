extends RigidBody2D
class_name ArenaGun
## Custom-integrated gun motion copied from the HTML prototype's movement model.

signal shot_requested(gun: ArenaGun, muzzle_position: Vector2, shot_direction: Vector2)
signal hit_count_changed(gun: ArenaGun, hit_count: int, hits_to_eliminate: int)
signal eliminated(gun: ArenaGun)

@export var player_id: int = 1
@export var fire_action: StringName = &"player_1_shoot"
@export var gun_color: Color = Color("3b82f6")
@export_range(0.0, 360.0, 1.0) var starting_rotation_degrees: float = 0.0

const GRAVITY := 35.0
const AIR_DRAG := 0.995
const ANGULAR_DRAG := 0.985
const RECOIL_FORCE := 520.0
const HIT_RECOIL_FORCE := 340.0
const TORQUE_FORCE := 4.2
const HITS_TO_ELIMINATE := 3
const GUN_RADIUS := 28.0
const WALL_RESTITUTION := 0.8
const ARENA_MIN := Vector2(132.0, 82.0)
const ARENA_MAX := Vector2(1148.0, 638.0)
const MUZZLE_OFFSET := Vector2(40.0, -10.0)

var active_bullet: Node2D
var hit_count := 0
var is_eliminated := false
var _round_locked := false
var _velocity := Vector2.ZERO
var _angular_velocity := 0.0
var _base_spin := 0.8
var _rng := RandomNumberGenerator.new()
var _muzzle_flash_time := 0.0


func _ready() -> void:
	_ensure_fire_action()
	_rng.randomize()
	_base_spin = 0.8 if player_id == 1 else -0.8
	rotation = deg_to_rad(starting_rotation_degrees)
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	lock_rotation = false
	freeze = true
	add_to_group("guns")


func _process(delta: float) -> void:
	if _muzzle_flash_time > 0.0:
		_muzzle_flash_time = maxf(0.0, _muzzle_flash_time - delta)
		queue_redraw()
	if not is_eliminated and not _round_locked and not fire_action.is_empty() and Input.is_action_just_pressed(fire_action):
		_try_fire()


func _physics_process(delta: float) -> void:
	if _round_locked or is_eliminated:
		_velocity = Vector2.ZERO
		_angular_velocity = 0.0
		return
	var dt := minf(delta, 0.05)
	_velocity.y += GRAVITY * dt
	_velocity *= AIR_DRAG
	rotation += _angular_velocity * dt
	_angular_velocity *= ANGULAR_DRAG
	if absf(_angular_velocity) < 0.3:
		_angular_velocity += _base_spin * dt * 2.0
	global_position += _velocity * dt
	_resolve_arena_bounds()
	queue_redraw()


func _resolve_arena_bounds() -> void:
	if global_position.x < ARENA_MIN.x + GUN_RADIUS:
		global_position.x = ARENA_MIN.x + GUN_RADIUS
		_velocity.x = absf(_velocity.x) * WALL_RESTITUTION
		_angular_velocity *= -0.8
	elif global_position.x > ARENA_MAX.x - GUN_RADIUS:
		global_position.x = ARENA_MAX.x - GUN_RADIUS
		_velocity.x = -absf(_velocity.x) * WALL_RESTITUTION
		_angular_velocity *= -0.8
	if global_position.y < ARENA_MIN.y + GUN_RADIUS:
		global_position.y = ARENA_MIN.y + GUN_RADIUS
		_velocity.y = absf(_velocity.y) * WALL_RESTITUTION
		_angular_velocity *= -0.8
	elif global_position.y > ARENA_MAX.y - GUN_RADIUS:
		global_position.y = ARENA_MAX.y - GUN_RADIUS
		_velocity.y = -absf(_velocity.y) * WALL_RESTITUTION
		_angular_velocity *= -0.8


func _try_fire() -> void:
	if is_eliminated or is_instance_valid(active_bullet):
		return
	var shot_direction := Vector2.RIGHT.rotated(global_rotation)
	var muzzle_position := to_global(MUZZLE_OFFSET)
	_velocity -= shot_direction * RECOIL_FORCE
	var torque_direction := 1.0 if _rng.randf() > 0.5 else -1.0
	_angular_velocity += TORQUE_FORCE * (1.2 + _rng.randf_range(0.0, 0.6)) * torque_direction
	_muzzle_flash_time = 0.085
	queue_redraw()
	shot_requested.emit(self, muzzle_position, shot_direction)


func request_touch_fire() -> void:
	if _round_locked or is_eliminated:
		return
	_try_fire()


func receive_hit(impact_direction: Vector2) -> void:
	if is_eliminated:
		return
	hit_count += 1
	var knockback_direction := impact_direction.normalized()
	if knockback_direction.is_zero_approx():
		knockback_direction = Vector2.UP
	_velocity += knockback_direction * HIT_RECOIL_FORCE
	var torque_direction := -1.0 if _rng.randf() > 0.5 else 1.0
	_angular_velocity += torque_direction * _rng.randf_range(3.0, 4.5)
	hit_count_changed.emit(self, hit_count, HITS_TO_ELIMINATE)
	print("Player %d: %d/%d hits" % [player_id, hit_count, HITS_TO_ELIMINATE])
	if hit_count >= HITS_TO_ELIMINATE:
		is_eliminated = true
		eliminated.emit(self)


func set_active_bullet(bullet: Node2D) -> void:
	active_bullet = bullet


func clear_active_bullet(bullet: Node2D) -> void:
	if active_bullet == bullet:
		active_bullet = null


func set_round_locked(locked: bool) -> void:
	_round_locked = locked
	if locked:
		_velocity = Vector2.ZERO
		_angular_velocity = 0.0
		set_process(false)
		set_physics_process(false)
	else:
		set_process(true)
		set_physics_process(true)


func reset_for_round(spawn_position: Vector2, start_angle_degrees: float) -> void:
	hit_count = 0
	is_eliminated = false
	active_bullet = null
	_velocity = Vector2.ZERO
	_angular_velocity = 0.0
	global_position = spawn_position
	rotation = deg_to_rad(start_angle_degrees)
	visible = true
	collision_layer = 2
	collision_mask = 1
	_muzzle_flash_time = 0.0
	set_round_locked(false)
	queue_redraw()


func _ensure_fire_action() -> void:
	if InputMap.has_action(fire_action):
		return
	InputMap.add_action(fire_action)
	if player_id == 1:
		_add_key_binding(KEY_A)
	else:
		_add_key_binding(KEY_L)
		_add_key_binding(KEY_LEFT)


func _add_key_binding(keycode: Key) -> void:
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(fire_action, key_event)


func _draw() -> void:
	# Match the sample HTML's exact low-poly handgun silhouette.
	var dark_tone := Color("1d4ed8") if player_id == 1 else Color("b91c1c")
	var light_tone := Color("60a5fa") if player_id == 1 else Color("f87171")
	# Soft offset shadow, matching the sample's canvas shadow treatment.
	draw_set_transform(Vector2(0.0, 6.0), 0.0, Vector2.ONE)
	_draw_gun_silhouette(Color(0.0, 0.0, 0.0, 0.4), Color(0.0, 0.0, 0.0, 0.4), Color(0.0, 0.0, 0.0, 0.4), Color(0.0, 0.0, 0.0, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_gun_silhouette(gun_color, dark_tone, light_tone, Color.WHITE)
	if _muzzle_flash_time > 0.0:
		_draw_muzzle_flash()


func _draw_muzzle_flash() -> void:
	var progress := 1.0 - (_muzzle_flash_time / 0.085)
	var fade := 1.0 - progress
	var scale_factor := lerpf(0.72, 1.25, progress)
	var origin := Vector2(40.0, -8.0)
	draw_circle(origin, 17.0 * scale_factor, Color(gun_color, fade * 0.2))
	draw_circle(origin, 10.0 * scale_factor, Color(1.0, 0.78, 0.35, fade * 0.72))
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(0.0, -5.0 * scale_factor),
		origin + Vector2(12.0 * scale_factor, -3.0 * scale_factor),
		origin + Vector2(25.0 * scale_factor, 0.0),
		origin + Vector2(12.0 * scale_factor, 3.0 * scale_factor),
		origin + Vector2(0.0, 5.0 * scale_factor),
		origin + Vector2(5.0 * scale_factor, 0.0),
	]), Color(1.0, 0.9, 0.62, fade))
	draw_circle(origin + Vector2(3.0, 0.0), 4.0 * scale_factor, Color.WHITE)


func _draw_gun_silhouette(base_color: Color, grip_color: Color, light_tone: Color, sight_color: Color) -> void:
	# Grip / handle.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, 5), Vector2(-32, 35), Vector2(-14, 38), Vector2(-2, 10)
	]), grip_color)
	# Trigger guard.
	draw_line(Vector2(-2, 8), Vector2(8, 14), light_tone, 3.0, true)
	draw_line(Vector2(8, 14), Vector2(8, 4), light_tone, 3.0, true)
	# Main slide and barrel body.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-28, -14), Vector2(38, -14), Vector2(38, 0),
		Vector2(0, 6), Vector2(-28, 6)
	]), base_color)
	# Slide top highlight edge.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-28, -14), Vector2(38, -14), Vector2(36, -11), Vector2(-28, -11)
	]), light_tone)
	# Sight notch.
	draw_rect(Rect2(34, -17, 3, 3), sight_color)
