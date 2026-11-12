extends Node2D
## Arena backdrop, player spawns, and projectile ownership.

signal return_to_menu_requested

const BACKGROUND_COLOR := Color("1e2029")
const ARENA_COLOR := Color("191b23")
const GRID_COLOR := Color("262936")
const WALL_COLOR := Color("111a27")
const NEON_COLOR := Color("38d9ff")
const NEON_HIGHLIGHT := Color("a5f2ff")

const ARENA_RECT := Rect2(120.0, 70.0, 1040.0, 580.0)
const OUTER_WALL_RECT := Rect2(108.0, 58.0, 1064.0, 604.0)
const INNER_WALL_RECT := Rect2(132.0, 82.0, 1016.0, 556.0)
const GRID_SPACING := 40

const GUN_SCENE := preload("res://scenes/player/Gun.tscn")
const BULLET_SCENE := preload("res://scenes/projectiles/Bullet.tscn")
const HIT_SPARK_SCENE := preload("res://scenes/effects/HitSpark.tscn")
const HEALTH_HUD_SCRIPT := preload("res://scripts/systems/HealthHUD.gd")
const CPU_CONTROLLER_SCRIPT := preload("res://scripts/ai/CPUController.gd")
const WEAPON_CATALOG := preload("res://scripts/systems/WeaponCatalog.gd")
const GUN_FIRE_SOUND := preload("res://assets/audio/gun_fire.wav")
const WALL_BOUNCE_SOUND := preload("res://assets/audio/wall_bounce.wav")
const HIT_IMPACT_SOUND := preload("res://assets/audio/hit_impact.wav")
const ELIMINATION_SOUND := preload("res://assets/audio/elimination.wav")
const EXPLOSION_SOUND := preload("res://assets/audio/explosion.wav")

var _projectiles: Node2D
var _health_hud: HealthHUD
var _camera: Camera2D
var _guns: Array[ArenaGun] = []
## Set before adding this Arena to the scene tree to replace Player 2 with the CPU.
@export var single_player_mode := false
@export_range(0, 2, 1) var cpu_difficulty := CPUController.DIFFICULTY_NORMAL
@export var selected_weapon_id := WEAPON_CATALOG.PULSE
@export var selected_arena_id := "nexus_facility"
var _cpu_controller: CPUController
var _round_over := false
var _round_transitioning := false
var _shake_time := 0.0
var _shake_duration := 0.0
var _shake_intensity := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_camera = Camera2D.new()
	_camera.name = "ArenaCamera"
	_camera.position = Vector2(640.0, 360.0)
	_camera.enabled = true
	add_child(_camera)
	_camera.make_current()
	get_viewport().size_changed.connect(_update_camera_zoom)
	_update_camera_zoom()
	_projectiles = Node2D.new()
	_projectiles.name = "Projectiles"
	add_child(_projectiles)
	_health_hud = HEALTH_HUD_SCRIPT.new() as HealthHUD
	add_child(_health_hud)
	_health_hud.play_again_requested.connect(_on_play_again_requested)
	_health_hud.return_to_menu_requested.connect(func() -> void: return_to_menu_requested.emit())
	_spawn_player(1, Vector2(360.0, 360.0), 0.0, Color("3b82f6"), &"player_1_shoot")
	_spawn_player(2, Vector2(920.0, 360.0), 180.0, Color("ef4444"), &"player_2_shoot")
	if single_player_mode:
		_start_cpu_opponent()


func _unhandled_input(event: InputEvent) -> void:
	if _round_over or _round_transitioning:
		return
	if event is InputEventScreenTouch and event.pressed:
		var viewport_width := get_viewport_rect().size.x
		var player_id := 1 if event.position.x < viewport_width * 0.5 else 2
		for gun in _guns:
			if is_instance_valid(gun) and gun.player_id == player_id:
				gun.request_touch_fire()
				break
		get_viewport().set_input_as_handled()


func _update_camera_zoom() -> void:
	if not is_instance_valid(_camera):
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	# Fit the actual combat frame, not the decorative 1280x720 backdrop. Camera2D
	# zoom is the world-to-screen scale, so smaller screens need a smaller value.
	# Reserve a little more room above the arena for the pause control than below it.
	var available_size := viewport_size - Vector2(40.0, 80.0)
	var fit_scale := maxf(minf(
		available_size.x / OUTER_WALL_RECT.size.x,
		available_size.y / OUTER_WALL_RECT.size.y
	), 0.01)
	_camera.zoom = Vector2.ONE * fit_scale
	_camera.position = Vector2(640.0, 360.0 - 16.0 / fit_scale)
	queue_redraw()


func _process(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time = maxf(0.0, _shake_time - delta)
	var fade := _shake_time / maxf(_shake_duration, 0.001)
	_camera.offset = Vector2(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)
	) * _shake_intensity * fade
	if _shake_time <= 0.0:
		_camera.offset = Vector2.ZERO
		_shake_intensity = 0.0
		_shake_duration = 0.0


func _trigger_screen_shake(intensity: float, duration: float) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_duration = maxf(_shake_duration, duration)
	_shake_time = maxf(_shake_time, duration)


func _play_sound(stream: AudioStream, world_position: Vector2, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = world_position
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.max_distance = 1800.0
	player.attenuation = 0.8
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _on_gun_collision(impact_strength: float, impact_position: Vector2) -> void:
	var intensity := clampf(impact_strength / 360.0, 0.0, 1.0)
	# Layer a weighty impact thump with the existing ricochet's short metallic tail.
	# These are real project samples, not the artificial oscillator used previously.
	var pitch_variation := _rng.randf_range(0.96, 1.04)
	_play_sound(HIT_IMPACT_SOUND, impact_position, lerpf(-10.0, -3.5, intensity), 0.82 * pitch_variation)
	_play_sound(WALL_BOUNCE_SOUND, impact_position, lerpf(-13.0, -7.0, intensity), 0.74 * pitch_variation)


func _spawn_player(
	player_id: int,
	spawn_position: Vector2,
	start_angle: float,
	player_color: Color,
	action: StringName
) -> void:
	var gun := GUN_SCENE.instantiate() as ArenaGun
	gun.name = "Player%dGun" % player_id
	gun.player_id = player_id
	gun.fire_action = action
	gun.gun_color = player_color
	gun.configure_weapon(selected_weapon_id)
	gun.starting_rotation_degrees = start_angle
	gun.position = spawn_position
	gun.shot_requested.connect(_on_shot_requested)
	gun.eliminated.connect(_on_player_eliminated)
	gun.gun_collision.connect(_on_gun_collision)
	add_child(gun)
	_guns.append(gun)


func _start_cpu_opponent() -> void:
	var human_gun := _get_gun_by_player_id(1)
	var cpu_gun := _get_gun_by_player_id(2)
	if not is_instance_valid(human_gun) or not is_instance_valid(cpu_gun):
		push_error("Cannot start CPU opponent: both player guns must be spawned first.")
		return

	cpu_gun.human_input_enabled = false
	_cpu_controller = CPU_CONTROLLER_SCRIPT.new() as CPUController
	_cpu_controller.name = "CPUController"
	add_child(_cpu_controller)
	_cpu_controller.set_difficulty(cpu_difficulty)
	_cpu_controller.setup(cpu_gun, human_gun, _projectiles)


func _get_gun_by_player_id(player_id: int) -> ArenaGun:
	for gun in _guns:
		if is_instance_valid(gun) and gun.player_id == player_id:
			return gun
	return null


func _on_shot_requested(gun: ArenaGun, muzzle_position: Vector2, shot_direction: Vector2) -> void:
	var weapon_stats := WEAPON_CATALOG.get_definition(gun.weapon_id)
	var pitch := 1.0
	var volume := -2.0
	match gun.weapon_id:
		WEAPON_CATALOG.HEAVY:
			pitch = 0.72
			volume = 0.0
		WEAPON_CATALOG.RAPID:
			pitch = 1.28
			volume = -6.0
		WEAPON_CATALOG.RAIL:
			pitch = 0.58
			volume = 1.0
	_play_sound(GUN_FIRE_SOUND, muzzle_position, volume, pitch)
	var bullet := BULLET_SCENE.instantiate() as ArenaBullet
	bullet.bullet_color = gun.gun_color
	bullet.speed = float(weapon_stats["projectile_speed"])
	bullet.projectile_radius = float(weapon_stats["projectile_radius"])
	bullet.projectile_style = gun.weapon_id
	bullet.scale = Vector2.ONE * (bullet.projectile_radius / 5.0)
	bullet.target_hit.connect(_on_bullet_hit)
	bullet.wall_bounced.connect(_on_bullet_wall_bounced)
	_projectiles.add_child(bullet)
	bullet.setup(gun, muzzle_position, shot_direction)


func _on_bullet_wall_bounced(bullet_position: Vector2) -> void:
	_play_sound(WALL_BOUNCE_SOUND, bullet_position, 4.0)


func _on_bullet_hit(
	target: ArenaGun,
	shooter: ArenaGun,
	impact_direction: Vector2,
	_impact_position: Vector2
) -> void:
	if _round_over or not is_instance_valid(target) or not is_instance_valid(shooter):
		return
	target.receive_hit(impact_direction)
	_health_hud.update_health(target.player_id, target.hit_count, target.gun_color)
	_play_sound(HIT_IMPACT_SOUND, _impact_position, -1.5, _rng.randf_range(0.92, 1.08))
	_trigger_screen_shake(5.5, 0.18)
	var spark := HIT_SPARK_SCENE.instantiate() as HitSpark
	spark.effect_color = target.gun_color
	# The reference prototype bursts particles from the gun's center, not the bullet tip.
	spark.global_position = target.global_position
	add_child(spark)
	print("Player %d hit by Player %d (%d/%d)" % [
		target.player_id,
		shooter.player_id,
		target.hit_count,
		ArenaGun.HITS_TO_ELIMINATE
	])


func _on_player_eliminated(gun: ArenaGun) -> void:
	if _round_over:
		return
	var burst := HIT_SPARK_SCENE.instantiate() as HitSpark
	burst.effect_color = gun.gun_color
	burst.is_elimination = true
	burst.global_position = gun.global_position
	add_child(burst)
	_play_sound(ELIMINATION_SOUND, gun.global_position, -1.0, _rng.randf_range(0.96, 1.04))
	_play_sound(EXPLOSION_SOUND, gun.global_position, -5.0, _rng.randf_range(0.94, 1.06))
	_trigger_screen_shake(14.0, 0.42)
	gun.visible = false
	gun.collision_layer = 0
	gun.collision_mask = 0
	var winner_id := 2 if gun.player_id == 1 else 1
	_end_round(winner_id)


func _end_round(winner_id: int) -> void:
	if _round_over:
		return
	_round_over = true
	if is_instance_valid(_cpu_controller):
		_cpu_controller.set_controller_active(false)
	for gun in _guns:
		if is_instance_valid(gun):
			gun.set_round_locked(true)
	for projectile in _projectiles.get_children():
		if projectile is ArenaBullet:
			projectile.cancel()
	_health_hud.announce_winner(winner_id)
	print("ROUND OVER: Player %d wins" % winner_id)


func _on_play_again_requested() -> void:
	if _round_over and not _round_transitioning:
		_start_next_round()


func _start_next_round() -> void:
	_round_transitioning = true
	for count in [3, 2, 1]:
		_health_hud.show_countdown(str(count))
		await get_tree().create_timer(0.8).timeout
	_health_hud.show_countdown("GO!")
	await get_tree().create_timer(0.35).timeout

	for projectile in _projectiles.get_children():
		if projectile is ArenaBullet:
			projectile.cancel()
	for gun in _guns:
		if not is_instance_valid(gun):
			continue
		if gun.player_id == 1:
			gun.reset_for_round(Vector2(360.0, 360.0), 0.0)
		else:
			gun.reset_for_round(Vector2(920.0, 360.0), 180.0)
	_health_hud.reset_health()
	_round_over = false
	_round_transitioning = false
	if is_instance_valid(_cpu_controller):
		_cpu_controller.reset_controller()
	_health_hud.hide_round_overlay()
	print("ROUND START")


func _draw() -> void:
	var arena_accent := Color("f07845") if selected_arena_id == "reactor_core" else Color("55baff") if selected_arena_id == "orbital_station" else NEON_COLOR
	var arena_highlight := Color("ffc078") if selected_arena_id == "reactor_core" else Color("b7e8ff") if selected_arena_id == "orbital_station" else NEON_HIGHLIGHT
	# Extend the backdrop into any extra world area exposed by wide phone screens.
	var visible_size := get_viewport_rect().size / _camera.zoom
	var visible_rect := Rect2(_camera.global_position - visible_size * 0.5, visible_size)
	draw_rect(visible_rect, BACKGROUND_COLOR)
	# Base 16:9 arena backdrop.
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), BACKGROUND_COLOR)
	# Soft cyan glow around the full 24 px wall frame.
	draw_rect(OUTER_WALL_RECT.grow(7.0), Color(arena_accent, 0.07), false, 18.0)
	draw_rect(OUTER_WALL_RECT.grow(3.0), Color(arena_accent, 0.12), false, 12.0)
	draw_rect(OUTER_WALL_RECT, Color(arena_accent, 0.22), false, 6.0)
	# Original 2D wall frame and floor treatment.
	draw_rect(OUTER_WALL_RECT, WALL_COLOR)
	draw_rect(INNER_WALL_RECT, ARENA_COLOR)
	# Keep the original grid visible in the gaps between raised floor plates.
	for x in range(int(ARENA_RECT.position.x) + GRID_SPACING, int(ARENA_RECT.end.x), GRID_SPACING):
		draw_line(Vector2(x, ARENA_RECT.position.y), Vector2(x, ARENA_RECT.end.y), GRID_COLOR, 1.0)
	for y in range(int(ARENA_RECT.position.y) + GRID_SPACING, int(ARENA_RECT.end.y), GRID_SPACING):
		draw_line(Vector2(ARENA_RECT.position.x, y), Vector2(ARENA_RECT.end.x, y), GRID_COLOR, 1.0)
	_draw_arena_floor_details(arena_accent, arena_highlight)
	draw_rect(OUTER_WALL_RECT, arena_accent, false, 2.0)
	draw_rect(INNER_WALL_RECT, Color(arena_accent, 0.8), false, 2.0)
	draw_rect(OUTER_WALL_RECT.grow(-3.0), Color(arena_highlight, 0.42), false, 1.0)


func _draw_arena_floor_details(accent: Color, highlight: Color) -> void:
	var floor_rect := ARENA_RECT.grow(-8.0)
	var panel_dark := Color("080e18", 0.92)
	var panel_body := Color("202d3c", 1.0)
	var panel_light := Color("52677a", 0.34)
	var seam := Color(accent, 0.42)
	var edge := Color(highlight, 0.72)
	# The arena is designed like a recessed equipment case viewed from above:
	# dark cavity, thick metal lip, then individually raised and bevelled plates.
	draw_rect(floor_rect.grow(5.0), Color("050912", 0.95))
	draw_rect(floor_rect, Color("080f19"))
	draw_rect(floor_rect, Color("34485b", 0.9), false, 3.0)
	draw_line(floor_rect.position + Vector2(4.0, 4.0), Vector2(floor_rect.end.x - 4.0, floor_rect.position.y + 4.0), Color(highlight, 0.58), 2.0)
	draw_line(floor_rect.position + Vector2(4.0, 4.0), Vector2(floor_rect.position.x + 4.0, floor_rect.end.y - 4.0), Color(highlight, 0.32), 2.0)
	draw_line(Vector2(floor_rect.position.x + 4.0, floor_rect.end.y - 3.0), floor_rect.end - Vector2(4.0, 3.0), Color("02060c", 0.95), 3.0)
	for row in range(5):
		for column in range(9):
			var tile := Rect2(Vector2(ARENA_RECT.position.x + 12.0 + column * 112.0, ARENA_RECT.position.y + 12.0 + row * 112.0), Vector2(104.0, 104.0))
			var face := tile.grow(-5.0)
			var alternating := (row + column) % 2 == 0
			# Offset shadow and dark side walls create visible plate thickness.
			draw_rect(Rect2(tile.position + Vector2(2.0, 4.0), tile.size), Color("02060c", 0.96))
			draw_rect(tile, Color("40566b", 0.92))
			draw_rect(tile.grow(-2.0), Color("111c29", 1.0))
			draw_rect(face, panel_body if alternating else Color("263849"))
			# Top/left bevel catches the arena light; bottom/right bevel falls into shadow.
			draw_line(face.position, Vector2(face.end.x, face.position.y), Color(highlight, 0.54), 2.0)
			draw_line(face.position, Vector2(face.position.x, face.end.y), Color(highlight, 0.28), 2.0)
			draw_line(Vector2(face.position.x, face.end.y), face.end, Color("050a12", 0.96), 2.0)
			draw_line(Vector2(face.end.x, face.position.y), face.end, Color("050a12", 0.96), 2.0)
			# Recessed center plate with a narrow illuminated service seam.
			var inset := face.grow(-8.0)
			draw_rect(inset, Color("0b1420", 0.62))
			draw_rect(inset, Color(seam, 0.78), false, 1.0)
			draw_line(inset.position + Vector2(5.0, 5.0), Vector2(inset.end.x - 5.0, inset.position.y + 5.0), Color(panel_light, 0.9), 1.0)
			# Four recessed fasteners, each with a tiny metallic highlight.
			for corner in [tile.position + Vector2(7.0, 7.0), tile.position + Vector2(97.0, 7.0), tile.position + Vector2(7.0, 97.0), tile.position + Vector2(97.0, 97.0)]:
				draw_circle(corner + Vector2(0.8, 1.0), 2.7, Color("03070d", 0.95))
				draw_circle(corner, 2.0, Color("9aafc1", 0.9))
				draw_circle(corner - Vector2(0.6, 0.6), 0.8, edge)
	# Recessed side rails and short illuminated markers make the case feel assembled.
	for side in [-1.0, 1.0]:
		var rail_x := ARENA_RECT.position.x + 18.0 if side < 0.0 else ARENA_RECT.end.x - 24.0
		var rail := Rect2(Vector2(rail_x, ARENA_RECT.position.y + 24.0), Vector2(6.0, ARENA_RECT.size.y - 48.0))
		draw_rect(rail.grow(3.0), Color("030810", 0.95))
		draw_rect(rail, Color("52697d", 0.75))
		draw_line(rail.position, Vector2(rail.position.x, rail.end.y), Color(accent, 0.8), 2.0)
		for marker in range(7):
			var marker_y := rail.position.y + 18.0 + marker * 76.0
			draw_rect(Rect2(Vector2(rail.position.x + 1.0, marker_y), Vector2(4.0, 18.0)), Color(highlight, 0.8))
	# Theme-specific hardware gives every battleground its own identity.
	match selected_arena_id:
		"orbital_station":
			var pad := Rect2(ARENA_RECT.get_center() - Vector2(146.0, 104.0), Vector2(292.0, 208.0))
			draw_rect(pad.grow(8.0), Color("030a13", 0.95))
			draw_rect(pad, Color("263b50"))
			draw_rect(pad.grow(-5.0), Color("0d1b2a"), false, 3.0)
			draw_rect(pad.grow(-18.0), Color(accent, 0.12), false, 2.0)
			for side in [-1.0, 1.0]:
				for marker in range(8):
					var light_pos := Vector2(ARENA_RECT.get_center().x + side * 174.0, ARENA_RECT.position.y + 36.0 + marker * 72.0)
					draw_rect(Rect2(light_pos, Vector2(10.0, 24.0)), Color(highlight, 0.92))
			for dash in range(5):
				var dash_y := ARENA_RECT.position.y + 78.0 + dash * 108.0
				draw_rect(Rect2(Vector2(ARENA_RECT.get_center().x - 2.0, dash_y), Vector2(4.0, 34.0)), Color(accent, 0.7))
		"reactor_core":
			for side in [-1.0, 1.0]:
				var lane := Rect2(Vector2(ARENA_RECT.get_center().x + side * 426.0 - 18.0, ARENA_RECT.position.y + 18.0), Vector2(36.0, ARENA_RECT.size.y - 36.0))
				draw_rect(lane.grow(7.0), Color("03070b", 0.98))
				draw_rect(lane, Color("111b24"))
				draw_rect(lane, Color(accent, 0.75), false, 2.0)
				for stripe in range(11):
					var stripe_rect := Rect2(Vector2(lane.position.x + 4.0, lane.position.y + 8.0 + stripe * 48.0), Vector2(28.0, 7.0))
					draw_rect(stripe_rect, Color("ffb34d", 0.9))
			for vent in range(7):
				var vent_x := ARENA_RECT.position.x + 218.0 + vent * 100.0
				var vent_rect := Rect2(Vector2(vent_x, ARENA_RECT.position.y + 28.0), Vector2(9.0, ARENA_RECT.size.y - 56.0))
				draw_rect(vent_rect.grow(3.0), Color("02060b", 0.95))
				draw_rect(vent_rect, Color("070d13"))
				draw_line(vent_rect.position, Vector2(vent_rect.position.x, vent_rect.end.y), Color(accent, 0.7), 2.0)
		_:
			# Nexus facility: a restrained central power coupler and paired service strips.
			var core := Rect2(ARENA_RECT.get_center() - Vector2(104.0, 72.0), Vector2(208.0, 144.0))
			draw_rect(core.grow(9.0), Color("030a12", 0.95))
			draw_rect(core, Color("30475a"))
			draw_rect(core.grow(-5.0), Color("0d1b29"), false, 2.0)
			draw_rect(core.grow(-18.0), Color(accent, 0.10), false, 2.0)
			for side in [-1.0, 1.0]:
				var strip := Rect2(Vector2(ARENA_RECT.get_center().x + side * 250.0 - 3.0, ARENA_RECT.position.y + 34.0), Vector2(6.0, ARENA_RECT.size.y - 68.0))
				draw_rect(strip, Color("050b14", 0.95))
				draw_rect(strip.grow(-2.0), Color(accent, 0.8))
