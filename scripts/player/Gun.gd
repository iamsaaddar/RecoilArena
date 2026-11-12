extends RigidBody2D
class_name ArenaGun
## Recoil-driven movement, collisions and firing for one player.

signal shot_requested(gun: ArenaGun, muzzle_position: Vector2, shot_direction: Vector2)
signal eliminated(gun: ArenaGun)
signal gun_collision(impact_strength: float, impact_position: Vector2)

@export var player_id: int = 1
@export var fire_action: StringName = &"player_1_shoot"
@export var gun_color: Color = Color("3b82f6")
@export_range(0.0, 360.0, 1.0) var starting_rotation_degrees: float = 0.0
@export var human_input_enabled := true
@export var weapon_id := "pulse_blaster"

const GRAVITY := 35.0
const AIR_DRAG := 0.995
const ANGULAR_DRAG := 0.985
const RECOIL_FORCE := 520.0
const HIT_RECOIL_FORCE := 340.0
const TORQUE_FORCE := 4.2
const HITS_TO_ELIMINATE := 3
const GUN_RADIUS := 32.0
const WALL_RESTITUTION := 0.8
const GUN_RESTITUTION := 0.32
const GUN_COLLISION_SOUND_THRESHOLD := 38.0
const ARENA_MIN := Vector2(132.0, 82.0)
const ARENA_MAX := Vector2(1148.0, 638.0)
const MUZZLE_OFFSET := Vector2(40.0, -10.0)
const WEAPON_CATALOG := preload("res://scripts/systems/WeaponCatalog.gd")

var hit_count := 0
var is_eliminated := false
var _round_locked := false
var _velocity := Vector2.ZERO
var _angular_velocity := 0.0
var _base_spin := 0.8
var _rng := RandomNumberGenerator.new()
var _muzzle_flash_time := 0.0
var _collision_sound_cooldown := 0.0
var _external_aim_target := Vector2.ZERO
var _has_external_aim_target := false
var _weapon_stats: Dictionary = {}
var _fire_cooldown := 0.0
var _charge_time := 0.0
var _is_charging := false
var _charge_auto_fire := false


func _ready() -> void:
	_ensure_fire_action()
	_rng.randomize()
	_weapon_stats = WEAPON_CATALOG.get_definition(weapon_id)
	_base_spin = 0.8 if player_id == 1 else -0.8
	rotation = deg_to_rad(starting_rotation_degrees)
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	lock_rotation = false
	freeze = true
	add_to_group("guns")


func _process(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if _muzzle_flash_time > 0.0:
		_muzzle_flash_time = maxf(0.0, _muzzle_flash_time - delta)
		queue_redraw()
	if human_input_enabled and not is_eliminated and not _round_locked and not fire_action.is_empty():
		if weapon_id == WEAPON_CATALOG.RAIL:
			if Input.is_action_just_pressed(fire_action):
				_is_charging = true
				_charge_time = 0.0
				_charge_auto_fire = false
			if _is_charging and Input.is_action_pressed(fire_action):
				_charge_time = minf(float(_weapon_stats["charge_time"]), _charge_time + delta)
			if _is_charging and Input.is_action_just_released(fire_action):
				_is_charging = false
				if _charge_time >= float(_weapon_stats["charge_time"]) and _fire_cooldown <= 0.0:
					_try_fire()
				_charge_time = 0.0
		elif weapon_id == WEAPON_CATALOG.RAPID and Input.is_action_pressed(fire_action):
			_try_fire()
		elif Input.is_action_just_pressed(fire_action):
			_try_fire()
	if _is_charging and _charge_auto_fire:
		_charge_time = minf(float(_weapon_stats.get("charge_time", 0.0)), _charge_time + delta)
		if _charge_time >= float(_weapon_stats.get("charge_time", 0.0)):
			_is_charging = false
			_charge_auto_fire = false
			_try_fire()
	if _is_charging:
		queue_redraw()


func _physics_process(delta: float) -> void:
	_collision_sound_cooldown = maxf(0.0, _collision_sound_cooldown - delta)
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
	if _has_external_aim_target:
		var desired_angle := global_position.direction_to(_external_aim_target).angle()
		var angle_error := wrapf(desired_angle - global_rotation, -PI, PI)
		var desired_angular_velocity := clampf(angle_error * 6.0, -7.0, 7.0)
		_angular_velocity = move_toward(_angular_velocity, desired_angular_velocity, 14.0 * dt)
	global_position += _velocity * dt
	_resolve_arena_bounds()
	# Player 2 is spawned after Player 1, so both guns have completed their
	# movement step before this single shared collision pass runs.
	if player_id == 2:
		_resolve_opponent_collision()
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


func _resolve_opponent_collision() -> void:
	for other in get_tree().get_nodes_in_group("guns"):
		if other == self or not other is ArenaGun:
			continue
		var opponent := other as ArenaGun
		if opponent.is_eliminated or opponent._round_locked:
			continue
		var separation := opponent.global_position - global_position
		var distance_squared := separation.length_squared()
		var minimum_distance := GUN_RADIUS * 2.0
		if distance_squared >= minimum_distance * minimum_distance:
			continue
		var distance := sqrt(distance_squared)
		var collision_normal := separation / distance if distance > 0.001 else Vector2.RIGHT
		var overlap := minimum_distance - distance
		# Split positional correction evenly so neither player gets priority.
		global_position -= collision_normal * (overlap * 0.5)
		opponent.global_position += collision_normal * (overlap * 0.5)
		var relative_velocity := opponent._velocity - _velocity
		var closing_speed := relative_velocity.dot(collision_normal)
		if closing_speed >= 0.0:
			continue
		# Equal-mass impulse with restrained bounce keeps collisions weighty.
		var impulse_strength := -(1.0 + GUN_RESTITUTION) * closing_speed * 0.5
		var impulse := collision_normal * impulse_strength
		_velocity -= impulse
		opponent._velocity += impulse
		# A small angular kick makes off-center-looking impacts feel less rigid.
		var tangential_speed := relative_velocity.dot(collision_normal.rotated(PI * 0.5))
		var angular_kick := clampf(tangential_speed * 0.006, -1.4, 1.4)
		_angular_velocity += angular_kick
		opponent._angular_velocity += angular_kick
		var impact_strength := -closing_speed
		if impact_strength >= GUN_COLLISION_SOUND_THRESHOLD and _collision_sound_cooldown <= 0.0:
			_collision_sound_cooldown = 0.16
			gun_collision.emit(impact_strength, global_position + collision_normal * GUN_RADIUS)


func _try_fire() -> void:
	if is_eliminated or _round_locked or _fire_cooldown > 0.0:
		return
	var shot_direction := Vector2.RIGHT.rotated(global_rotation)
	var muzzle_position := to_global(MUZZLE_OFFSET)
	_velocity -= shot_direction * float(_weapon_stats.get("recoil", RECOIL_FORCE))
	var torque_direction := 1.0 if _rng.randf() > 0.5 else -1.0
	_angular_velocity += TORQUE_FORCE * (1.2 + _rng.randf_range(0.0, 0.6)) * torque_direction
	_muzzle_flash_time = 0.085
	_fire_cooldown = float(_weapon_stats.get("cooldown", 0.0))
	queue_redraw()
	shot_requested.emit(self, muzzle_position, shot_direction)


func request_touch_fire() -> void:
	if not human_input_enabled:
		return
	if weapon_id == WEAPON_CATALOG.RAIL:
		_is_charging = true
		_charge_time = 0.0
		_charge_auto_fire = true
	else:
		request_fire()


## Public firing entry point for non-keyboard controllers such as the CPU.
## It deliberately uses the same recoil, muzzle flash, and projectile signal as player input.
func request_fire() -> void:
	if _round_locked or is_eliminated:
		return
	if weapon_id == WEAPON_CATALOG.RAIL:
		if not _is_charging:
			_is_charging = true
			_charge_time = 0.0
			_charge_auto_fire = true
		return
	_try_fire()


func configure_weapon(selected_weapon_id: String) -> void:
	weapon_id = selected_weapon_id
	_weapon_stats = WEAPON_CATALOG.get_definition(weapon_id)
	_fire_cooldown = 0.0
	_charge_time = 0.0
	_is_charging = false
	_charge_auto_fire = false


## Let an external controller steer the gun toward a world-space position.
## The existing angular inertia and spin remain active, so aiming still feels physical.
func set_external_aim_target(target_position: Vector2) -> void:
	_external_aim_target = target_position
	_has_external_aim_target = true


func clear_external_aim_target() -> void:
	_has_external_aim_target = false


## Expose current recoil-driven movement to the CPU's projectile prediction.
func get_ai_motion_velocity() -> Vector2:
	return _velocity


## Apply a bounded lateral impulse without bypassing the gun's existing physics.
func apply_ai_dodge_impulse(direction: Vector2, impulse_strength: float) -> void:
	if is_eliminated or _round_locked or direction.is_zero_approx():
		return
	_velocity += direction.normalized() * impulse_strength
	_velocity = _velocity.limit_length(560.0)


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
	print("Player %d: %d/%d hits" % [player_id, hit_count, HITS_TO_ELIMINATE])
	if hit_count >= HITS_TO_ELIMINATE:
		is_eliminated = true
		eliminated.emit(self)


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
	_has_external_aim_target = false
	_velocity = Vector2.ZERO
	_angular_velocity = 0.0
	global_position = spawn_position
	rotation = deg_to_rad(start_angle_degrees)
	visible = true
	collision_layer = 2
	collision_mask = 1
	_muzzle_flash_time = 0.0
	_fire_cooldown = 0.0
	_charge_time = 0.0
	_is_charging = false
	_charge_auto_fire = false
	_collision_sound_cooldown = 0.0
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
	_draw_gun_depth(dark_tone)
	_draw_gun_silhouette(gun_color, dark_tone, light_tone, Color.WHITE)
	_draw_gun_surface(light_tone, dark_tone)
	_draw_weapon_details(light_tone)
	if _muzzle_flash_time > 0.0:
		_draw_muzzle_flash()
	if _is_charging:
		var charge_progress := clampf(_charge_time / maxf(float(_weapon_stats.get("charge_time", 1.0)), 0.001), 0.0, 1.0)
		draw_arc(Vector2.ZERO, 48.0, -PI * 0.75, -PI * 0.75 + TAU * charge_progress, 36, Color(_weapon_stats.get("accent", gun_color), 0.95), 3.0, true)


func _draw_gun_depth(shadow_color: Color) -> void:
	# Dark lower extrusion makes the flat sprite read like a compact 2.5D prop.
	var deep := shadow_color.darkened(0.48)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-27.0, 5.0), Vector2(-18.0, 9.0), Vector2(-5.0, 12.0),
		Vector2(5.0, 7.0), Vector2(38.0, 2.0), Vector2(42.0, 6.0),
		Vector2(4.0, 15.0), Vector2(-15.0, 43.0), Vector2(-36.0, 40.0),
		Vector2(-23.0, 10.0)
	]), deep)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-29.0, -13.0), Vector2(39.0, -13.0), Vector2(43.0, -8.0),
		Vector2(43.0, 3.0), Vector2(1.0, 10.0), Vector2(-29.0, 8.0)
	]), Color("080f19"))


func _draw_gun_surface(highlight: Color, shadow: Color) -> void:
	var metal := Color("a9bdcc")
	var dark_metal := Color("101c2a")
	var accent := Color(_weapon_stats.get("accent", gun_color))
	# Raised slide plates, chamfered edges and a recessed central armor panel.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-25.0, -13.0), Vector2(35.0, -13.0), Vector2(31.0, -9.0),
		Vector2(-22.0, -9.0)
	]), highlight.lightened(0.2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-23.0, -7.0), Vector2(29.0, -7.0), Vector2(33.0, -3.0),
		Vector2(1.0, 2.0), Vector2(-23.0, 2.0)
	]), shadow.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18.0, -6.0), Vector2(21.0, -6.0), Vector2(17.0, -2.0),
		Vector2(-16.0, -2.0)
	]), gun_color.lightened(0.22))
	draw_line(Vector2(-20.0, 4.0), Vector2(20.0, 4.0), Color("07111c", 0.9), 1.5, true)
	# A bright, narrow energy rail and recessed glowing core sell the layered material.
	draw_line(Vector2(-12.0, -10.0), Vector2(25.0, -10.0), Color(highlight, 0.9), 1.4, true)
	draw_line(Vector2(-10.0, -8.0), Vector2(13.0, -8.0), Color(accent, 0.95), 2.0, true)
	draw_rect(Rect2(0.0, -3.0, 13.0, 4.0), dark_metal, true)
	draw_rect(Rect2(2.0, -2.0, 9.0, 2.0), Color(accent, 0.95), true)
	draw_line(Vector2(3.0, -1.0), Vector2(10.0, -1.0), Color.WHITE, 0.8, true)
	# Machined panel seams and metallic fasteners.
	draw_line(Vector2(-24.0, -4.0), Vector2(-24.0, 3.0), Color(metal, 0.72), 1.2, true)
	draw_line(Vector2(25.0, -5.0), Vector2(25.0, 0.0), Color("d9e7f0", 0.75), 1.2, true)
	_draw_gun_bolt(Vector2(-17.0, -3.0), metal)
	_draw_gun_bolt(Vector2(19.0, -3.0), metal)
	# Grip gets its own bevel, rubber inset and diagonal traction cuts.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17.0, 10.0), Vector2(-29.0, 34.0), Vector2(-16.0, 36.0),
		Vector2(-6.0, 13.0)
	]), Color("0b1723"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-19.0, 14.0), Vector2(-27.0, 32.0), Vector2(-18.0, 33.0),
		Vector2(-11.0, 15.0)
	]), Color(gun_color.darkened(0.42), 0.95))
	for index in range(4):
		var grip_y := 17.0 + index * 4.0
		draw_line(Vector2(-23.0 + index * 1.1, grip_y), Vector2(-15.0 + index * 0.8, grip_y + 2.0), Color(highlight, 0.55), 1.0, true)
	# Rear trigger assembly and lower frame edge.
	draw_arc(Vector2(3.0, 7.0), 8.0, 0.05, PI * 0.88, 12, Color("d5e3ed", 0.85), 1.7, true)
	draw_line(Vector2(-5.0, 12.0), Vector2(12.0, 9.0), Color("d5e3ed", 0.6), 1.0, true)


func _draw_gun_bolt(position: Vector2, bolt_color: Color) -> void:
	draw_circle(position + Vector2(0.8, 1.0), 2.2, Color("050b12", 0.9))
	draw_circle(position, 1.8, bolt_color.darkened(0.28))
	draw_line(position + Vector2(-0.9, 0.0), position + Vector2(0.9, 0.0), Color("101a25"), 0.8, true)
	draw_circle(position + Vector2(-0.55, -0.55), 0.55, Color.WHITE)


func _draw_weapon_details(detail_color: Color) -> void:
	match weapon_id:
		WEAPON_CATALOG.HEAVY:
			draw_colored_polygon(PackedVector2Array([Vector2(22.0, -14.0), Vector2(47.0, -13.0), Vector2(53.0, -8.0), Vector2(53.0, 1.0), Vector2(43.0, 3.0), Vector2(22.0, 0.0)]), Color("172638"))
			draw_rect(Rect2(28.0, -11.0, 20.0, 8.0), Color("080f18"), true)
			draw_rect(Rect2(46.0, -10.0, 6.0, 6.0), detail_color, true)
			draw_rect(Rect2(48.0, -9.0, 3.0, 4.0), Color.WHITE, true)
			draw_line(Vector2(-20.0, -17.0), Vector2(22.0, -17.0), Color.WHITE, 2.0)
			for index in range(4):
				draw_line(Vector2(-15.0 + index * 10.0, 8.0), Vector2(-10.0 + index * 10.0, 15.0), detail_color, 2.0)
			draw_rect(Rect2(-4.0, -21.0, 22.0, 3.0), Color("283b4e"), true)
		WEAPON_CATALOG.RAPID:
			draw_colored_polygon(PackedVector2Array([Vector2(2.0, -20.0), Vector2(39.0, -20.0), Vector2(47.0, -15.0), Vector2(39.0, -11.0), Vector2(2.0, -13.0)]), Color("1a2b40"))
			draw_colored_polygon(PackedVector2Array([Vector2(2.0, 3.0), Vector2(39.0, 3.0), Vector2(47.0, 8.0), Vector2(39.0, 12.0), Vector2(2.0, 10.0)]), Color("1a2b40"))
			draw_rect(Rect2(4.0, -17.0, 34.0, 3.0), detail_color, true)
			draw_rect(Rect2(4.0, 5.0, 34.0, 3.0), detail_color, true)
			draw_rect(Rect2(38.0, -10.0, 12.0, 5.0), Color("080f18"), true)
			draw_circle(Vector2(14.0, -17.0), 2.5, Color.WHITE)
			draw_circle(Vector2(14.0, 6.0), 2.5, Color.WHITE)
			draw_line(Vector2(5.0, -1.0), Vector2(34.0, -1.0), Color("d8caff", 0.8), 1.0, true)
		WEAPON_CATALOG.RAIL:
			draw_colored_polygon(PackedVector2Array([Vector2(-9.0, -19.0), Vector2(43.0, -19.0), Vector2(51.0, -13.0), Vector2(43.0, -9.0), Vector2(-9.0, -11.0)]), Color("172338"))
			draw_colored_polygon(PackedVector2Array([Vector2(-9.0, 7.0), Vector2(43.0, 7.0), Vector2(51.0, 13.0), Vector2(43.0, 17.0), Vector2(-9.0, 15.0)]), Color("172338"))
			draw_rect(Rect2(-4.0, -17.0, 43.0, 3.0), Color("080f18"), true)
			draw_rect(Rect2(-4.0, 9.0, 43.0, 3.0), Color("080f18"), true)
			for index in range(5):
				var x := -2.0 + index * 9.0
				draw_line(Vector2(x, -19.0), Vector2(x, -12.0), detail_color, 2.0)
				draw_line(Vector2(x, 8.0), Vector2(x, 15.0), detail_color, 2.0)
			draw_line(Vector2(8.0, -22.0), Vector2(35.0, -22.0), Color.WHITE, 1.5)
			draw_circle(Vector2(10.0, 0.0), 4.0, Color("111a2b"))
			draw_circle(Vector2(10.0, 0.0), 2.0, Color(detail_color, 0.95))
			for index in range(3):
				draw_line(Vector2(15.0 + index * 5.0, -2.0), Vector2(18.0 + index * 5.0, 2.0), Color("e4c6f2", 0.7), 1.0)
		_:
			# Pulse sidearm: compact muzzle shroud and twin cooling slots.
			draw_colored_polygon(PackedVector2Array([Vector2(24.0, -12.0), Vector2(43.0, -11.0), Vector2(48.0, -7.0), Vector2(43.0, -2.0), Vector2(24.0, -4.0)]), Color("17283a"))
			draw_rect(Rect2(31.0, -10.0, 13.0, 4.0), Color("0a111c"), true)
			draw_rect(Rect2(34.0, -9.0, 8.0, 2.0), detail_color, true)
			draw_line(Vector2(-11.0, 8.0), Vector2(19.0, 5.0), Color(detail_color, 0.8), 1.4, true)
			draw_line(Vector2(-8.0, 11.0), Vector2(14.0, 9.0), Color("0a111c"), 1.2, true)


func _draw_muzzle_flash() -> void:
	var progress := 1.0 - (_muzzle_flash_time / 0.085)
	var fade := 1.0 - progress
	var scale_factor := lerpf(0.72, 1.25, progress)
	var origin := Vector2(40.0, -8.0)
	var weapon_accent: Color = _weapon_stats.get("accent", gun_color)
	draw_circle(origin, 19.0 * scale_factor, Color(weapon_accent, fade * 0.26))
	draw_circle(origin, 13.0 * scale_factor, Color(gun_color, fade * 0.22))
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
