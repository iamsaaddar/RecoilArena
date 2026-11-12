extends Node
class_name CPUController
## Basic CPU opponent controller. It only chooses when and where to aim/fire;
## ArenaGun remains responsible for rotation, recoil, muzzle flash and projectiles.

@export_range(0.1, 2.0, 0.05) var reaction_delay := 0.35
@export_range(0.1, 4.0, 0.05) var minimum_fire_interval := 0.95
@export_range(0.1, 5.0, 0.05) var maximum_fire_interval := 1.45
@export_range(0.0, 25.0, 0.5) var aim_error_degrees := 7.0
@export_range(1.0, 35.0, 0.5) var fire_alignment_tolerance := 13.0
@export_range(0.1, 1.5, 0.05) var dodge_cooldown := 0.7
@export_range(0.1, 1.0, 0.05) var dodge_prediction_time := 0.7
@export_range(35.0, 120.0, 5.0) var dodge_detection_radius := 70.0
@export_range(100.0, 600.0, 10.0) var dodge_impulse := 380.0

var _cpu_gun: ArenaGun
var _target_gun: ArenaGun
var _projectile_container: Node2D
var _rng := RandomNumberGenerator.new()
var _reaction_timer := 0.0
var _fire_timer := 0.0
var _dodge_timer := 0.0
var _controller_active := true


func _ready() -> void:
	_rng.randomize()
	_fire_timer = _get_next_fire_interval()


## Connect this controller to the red CPU gun and the human-controlled gun.
func setup(cpu_gun: ArenaGun, target_gun: ArenaGun, projectile_container: Node2D) -> void:
	_cpu_gun = cpu_gun
	_target_gun = target_gun
	_projectile_container = projectile_container
	_controller_active = true
	_reaction_timer = 0.0
	_fire_timer = _get_next_fire_interval()
	_dodge_timer = 0.0
	if is_instance_valid(_cpu_gun) and is_instance_valid(_target_gun):
		_cpu_gun.set_external_aim_target(_target_gun.global_position)


func _process(delta: float) -> void:
	if not _controller_active or not _has_valid_opponents():
		return

	# Either gun being eliminated means the round has ended. Stop issuing commands.
	if _cpu_gun.is_eliminated or _target_gun.is_eliminated:
		_controller_active = false
		_cpu_gun.clear_external_aim_target()
		return

	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	if _dodge_timer <= 0.0:
		_try_dodge_incoming_projectiles()

	_reaction_timer -= delta
	if _reaction_timer <= 0.0:
		_update_aim_target()
		_reaction_timer = maxf(reaction_delay, 0.05)

	_fire_timer -= delta
	if _fire_timer <= 0.0 and _is_aim_aligned():
		_cpu_gun.request_fire()
		_fire_timer = _get_next_fire_interval()


func _has_valid_opponents() -> bool:
	return is_instance_valid(_cpu_gun) and is_instance_valid(_target_gun)


func _get_next_fire_interval() -> float:
	return _rng.randf_range(
		minimum_fire_interval,
		maxf(minimum_fire_interval, maximum_fire_interval)
	)


func _update_aim_target() -> void:
	var target_position := _target_gun.global_position
	var to_target := target_position - _cpu_gun.global_position
	if to_target.is_zero_approx():
		return

	# Apply a small angular miss rather than tracking the exact player position.
	# The offset is sampled at each reaction step, so the CPU does not perfectly
	# follow every movement frame or behave like an aimbot.
	var error_radians := deg_to_rad(_rng.randf_range(-aim_error_degrees, aim_error_degrees))
	var imperfect_direction := to_target.normalized().rotated(error_radians)
	var aim_point := _cpu_gun.global_position + imperfect_direction * to_target.length()
	_cpu_gun.set_external_aim_target(aim_point)


func _is_aim_aligned() -> bool:
	var target_direction := _target_gun.global_position - _cpu_gun.global_position
	if target_direction.is_zero_approx():
		return false
	var aim_direction := Vector2.RIGHT.rotated(_cpu_gun.global_rotation)
	var angle_error := absf(aim_direction.angle_to(target_direction.normalized()))
	return angle_error <= deg_to_rad(fire_alignment_tolerance)


## Predicts the closest approach of enemy projectiles and applies a short lateral
## impulse when one is on course to hit the CPU gun.
func _try_dodge_incoming_projectiles() -> void:
	if not is_instance_valid(_projectile_container):
		return

	var best_time := dodge_prediction_time + 1.0
	var best_dodge_direction := Vector2.ZERO
	var cpu_velocity := _cpu_gun.get_ai_motion_velocity()
	for projectile in _projectile_container.get_children():
		if not projectile is ArenaBullet:
			continue
		var bullet := projectile as ArenaBullet
		if bullet.is_queued_for_deletion() or bullet.shooter == _cpu_gun or bullet.velocity.is_zero_approx():
			continue

		# Relative motion accounts for the CPU gun already drifting from recoil.
		var relative_position := bullet.global_position - _cpu_gun.global_position
		var relative_velocity := bullet.velocity - cpu_velocity
		var velocity_squared := relative_velocity.length_squared()
		if velocity_squared < 1.0:
			continue
		var impact_time := -relative_position.dot(relative_velocity) / velocity_squared
		if impact_time <= 0.02 or impact_time > dodge_prediction_time or impact_time >= best_time:
			continue

		var closest_offset := relative_position + relative_velocity * impact_time
		if closest_offset.length() > dodge_detection_radius:
			continue

		var lateral_direction := relative_velocity.normalized().orthogonal()
		best_dodge_direction = _choose_safer_dodge_direction(lateral_direction)
		best_time = impact_time

	if not best_dodge_direction.is_zero_approx():
		_cpu_gun.apply_ai_dodge_impulse(best_dodge_direction, dodge_impulse)
		_dodge_timer = dodge_cooldown


func _choose_safer_dodge_direction(direction: Vector2) -> Vector2:
	var positive_score := _score_dodge_direction(direction)
	var negative_score := _score_dodge_direction(-direction)
	return direction if positive_score >= negative_score else -direction


func _score_dodge_direction(direction: Vector2) -> float:
	var predicted_position := _cpu_gun.global_position + direction * 115.0
	var arena_margin := minf(
		minf(predicted_position.x - 164.0, 1116.0 - predicted_position.x),
		minf(predicted_position.y - 114.0, 606.0 - predicted_position.y)
	)
	var opponent_distance := predicted_position.distance_to(_target_gun.global_position)
	return arena_margin + minf(opponent_distance, 300.0) * 0.2


## Stop AI commands without destroying the controller node.
func set_controller_active(active: bool) -> void:
	_controller_active = active
	if not active and is_instance_valid(_cpu_gun):
		_cpu_gun.clear_external_aim_target()


## Reset decision timers after a replay while retaining the same gun references.
func reset_controller() -> void:
	_controller_active = true
	_reaction_timer = 0.0
	_fire_timer = _get_next_fire_interval()
	_dodge_timer = 0.0
	if _has_valid_opponents():
		_cpu_gun.set_external_aim_target(_target_gun.global_position)
