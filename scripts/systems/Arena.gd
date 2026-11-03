extends Node2D
## Arena backdrop, player spawns, and projectile ownership.

signal player_hit(target: ArenaGun, shooter: ArenaGun)

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

var _projectiles: Node2D
var _health_hud: HealthHUD
var _guns: Array[ArenaGun] = []
var _round_over := false
var _round_transitioning := false


func _ready() -> void:
	_projectiles = Node2D.new()
	_projectiles.name = "Projectiles"
	add_child(_projectiles)
	_health_hud = HEALTH_HUD_SCRIPT.new() as HealthHUD
	add_child(_health_hud)
	_health_hud.play_again_requested.connect(_on_play_again_requested)
	_spawn_player(1, Vector2(360.0, 360.0), 0.0, Color("3b82f6"), &"player_1_shoot")
	_spawn_player(2, Vector2(920.0, 360.0), 180.0, Color("ef4444"), &"player_2_shoot")


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
	gun.starting_rotation_degrees = start_angle
	gun.position = spawn_position
	gun.shot_requested.connect(_on_shot_requested)
	gun.eliminated.connect(_on_player_eliminated)
	add_child(gun)
	_guns.append(gun)


func _on_shot_requested(gun: ArenaGun, muzzle_position: Vector2, shot_direction: Vector2) -> void:
	var bullet := BULLET_SCENE.instantiate() as ArenaBullet
	bullet.bullet_color = gun.gun_color
	bullet.finished.connect(_on_bullet_finished)
	bullet.target_hit.connect(_on_bullet_hit)
	_projectiles.add_child(bullet)
	bullet.setup(gun, muzzle_position, shot_direction)
	gun.set_active_bullet(bullet)


func _on_bullet_finished(bullet: ArenaBullet, shooter: ArenaGun) -> void:
	if is_instance_valid(shooter):
		shooter.clear_active_bullet(bullet)


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
	var spark := HIT_SPARK_SCENE.instantiate() as HitSpark
	spark.effect_color = target.gun_color
	# The reference prototype bursts particles from the gun's center, not the bullet tip.
	spark.global_position = target.global_position
	add_child(spark)
	player_hit.emit(target, shooter)
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
	gun.visible = false
	gun.collision_layer = 0
	gun.collision_mask = 0
	var winner_id := 2 if gun.player_id == 1 else 1
	_end_round(winner_id)


func _end_round(winner_id: int) -> void:
	if _round_over:
		return
	_round_over = true
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
	_health_hud.hide_round_overlay()
	print("ROUND START")


func _draw() -> void:
	# Full-window backdrop.
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), BACKGROUND_COLOR)
	# Soft cyan glow around the full 24 px wall frame.
	draw_rect(OUTER_WALL_RECT.grow(7.0), Color(0.10, 0.78, 1.0, 0.07), false, 18.0)
	draw_rect(OUTER_WALL_RECT.grow(3.0), Color(0.10, 0.78, 1.0, 0.12), false, 12.0)
	draw_rect(OUTER_WALL_RECT, Color(0.10, 0.78, 1.0, 0.22), false, 6.0)
	# Solid wall frame and dark arena floor.
	draw_rect(OUTER_WALL_RECT, WALL_COLOR)
	draw_rect(INNER_WALL_RECT, ARENA_COLOR)
	draw_rect(OUTER_WALL_RECT, NEON_COLOR, false, 2.0)
	draw_rect(INNER_WALL_RECT, Color(NEON_COLOR, 0.8), false, 2.0)
	draw_rect(OUTER_WALL_RECT.grow(-3.0), Color(NEON_HIGHLIGHT, 0.42), false, 1.0)
	for x in range(int(ARENA_RECT.position.x) + GRID_SPACING, int(ARENA_RECT.end.x), GRID_SPACING):
		draw_line(Vector2(x, ARENA_RECT.position.y), Vector2(x, ARENA_RECT.end.y), GRID_COLOR, 1.0)
	for y in range(int(ARENA_RECT.position.y) + GRID_SPACING, int(ARENA_RECT.end.y), GRID_SPACING):
		draw_line(Vector2(ARENA_RECT.position.x, y), Vector2(ARENA_RECT.end.x, y), GRID_COLOR, 1.0)
