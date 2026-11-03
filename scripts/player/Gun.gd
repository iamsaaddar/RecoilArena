extends RigidBody2D
class_name ArenaGun
## Recoil-driven player weapon. Projectile spawning is exposed as a signal so
## the arena can own bullet creation and combat rules.

signal shot_requested(gun: ArenaGun, muzzle_position: Vector2, shot_direction: Vector2)

@export var player_id: int = 1
@export var fire_action: StringName = &"player_1_shoot"
@export var gun_color: Color = Color("3b82f6")
@export_range(0.0, 360.0, 1.0) var starting_rotation_degrees: float = 0.0

const RECOIL_IMPULSE := 330.0
const RECOIL_OFFSET := Vector2(-24.0, 0.0)
const SHOT_COOLDOWN := 0.16
const BARREL_LENGTH := 94.0

var _shot_cooldown := 0.0


func _ready() -> void:
	_ensure_fire_action()
	mass = 1.0
	gravity_scale = 0.32
	linear_damp = 0.42
	angular_damp = 1.15
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.7
	rotation = deg_to_rad(starting_rotation_degrees + randf_range(-6.0, 6.0))
	add_to_group("guns")
	queue_redraw()


func _process(delta: float) -> void:
	if _shot_cooldown > 0.0:
		_shot_cooldown = maxf(_shot_cooldown - delta, 0.0)
	if not fire_action.is_empty() and Input.is_action_just_pressed(fire_action):
		_try_fire()


func _try_fire() -> void:
	if _shot_cooldown > 0.0 or sleeping:
		return
	_shot_cooldown = SHOT_COOLDOWN
	var shot_direction := Vector2.RIGHT.rotated(global_rotation)
	var muzzle_position := to_global(Vector2(BARREL_LENGTH * 0.5 + 5.0, 0.0))
	apply_impulse(-shot_direction * RECOIL_IMPULSE, RECOIL_OFFSET)
	apply_torque_impulse(randf_range(-15.0, 15.0))
	shot_requested.emit(self, muzzle_position, shot_direction)


func _ensure_fire_action() -> void:
	if InputMap.has_action(fire_action):
		return
	InputMap.add_action(fire_action)
	var keys: Array[int] = [KEY_A] if player_id == 1 else [KEY_L, KEY_LEFT]
	for keycode in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = keycode
		InputMap.action_add_event(fire_action, key_event)


func _draw() -> void:
	# Compact, geometric handgun silhouette, drawn facing local +X.
	var dark := gun_color.darkened(0.58)
	var highlight := gun_color.lightened(0.28)
	var body := PackedVector2Array([
		Vector2(-43, -10), Vector2(-32, -15), Vector2(24, -15),
		Vector2(35, -10), Vector2(35, 8), Vector2(22, 13),
		Vector2(-30, 13), Vector2(-43, 7)
	])
	draw_colored_polygon(body, dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-39, -9), Vector2(-30, -12), Vector2(25, -12),
		Vector2(31, -8), Vector2(31, 5), Vector2(22, 9),
		Vector2(-29, 9), Vector2(-39, 5)
	]), gun_color)
	# Barrel and muzzle block.
	draw_rect(Rect2(22, -8, 24, 16), dark)
	draw_rect(Rect2(26, -6, 18, 12), gun_color)
	draw_line(Vector2(28, -4), Vector2(41, -4), highlight, 2.0)
	# Raised top rail and restrained energy strip.
	draw_rect(Rect2(-20, -18, 38, 5), dark)
	draw_rect(Rect2(-15, -17, 27, 2), highlight)
	# Grip angled down and back.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-29, 9), Vector2(-8, 9), Vector2(-2, 17),
		Vector2(-8, 37), Vector2(-25, 37), Vector2(-35, 16)
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-27, 12), Vector2(-11, 12), Vector2(-7, 18),
		Vector2(-12, 33), Vector2(-22, 33), Vector2(-31, 16)
	]), gun_color)
	# Trigger guard and trigger.
	draw_arc(Vector2(-3, 11), 10.0, 0.0, PI, 20, dark, 3.0)
	draw_line(Vector2(-3, 11), Vector2(-3, 19), highlight, 2.0)
	# Small player-color core detail.
	draw_circle(Vector2(-30, -1), 3.0, highlight)

