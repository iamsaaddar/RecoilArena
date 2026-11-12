extends Node2D
## Owns the main menu, pause flow, and lifetime of the active arena.

const ARENA_SCENE := preload("res://scenes/arena/Arena.tscn")
const WEAPON_CATALOG := preload("res://scripts/systems/WeaponCatalog.gd")
const MENU_BACKGROUND := preload("res://assets/textures/icons/background.jpg")
const MENU_ICON_TEXTURES := {
	"play": preload("res://assets/textures/icons/play.png"),
	"controls": preload("res://assets/textures/icons/controls.png"),
	"settings": preload("res://assets/textures/icons/settings.png"),
	"quit": preload("res://assets/textures/icons/exit.png"),
	"cpu": preload("res://assets/textures/icons/singleplayer.png"),
	"duel": preload("res://assets/textures/icons/multiplayer.png"),
	"difficulty_easy": preload("res://assets/textures/icons/easy.png"),
	"difficulty_normal": preload("res://assets/textures/icons/normal.png"),
	"difficulty_hard": preload("res://assets/textures/icons/hard.png"),
	"back": preload("res://assets/textures/icons/back.png"),
}

const ACCENT_COLOR := Color("38d9ff")
const TEXT_COLOR := Color("f1f5f9")
const MUTED_COLOR := Color("9aa8ba")

var _arena: Node2D
var _ui_layer: CanvasLayer
var _active_overlay: Control
var _is_paused := false
var _panel_return := "main"
var _volume_value: Label
var _pause_button: Button
var _active_single_player := false
var _selected_weapon_id := WEAPON_CATALOG.PULSE
var _selected_difficulty := CPUController.DIFFICULTY_NORMAL
var _selected_arena_id := "nexus_facility"


func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "MenuUI"
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)
	_create_gameplay_pause_button()
	_show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(_arena):
		if _is_paused:
			_resume_game()
		else:
			_show_pause_menu()
		get_viewport().set_input_as_handled()


func _create_gameplay_pause_button() -> void:
	_pause_button = Button.new()
	_pause_button.name = "GameplayPauseButton"
	_pause_button.text = "Ⅱ"
	_pause_button.tooltip_text = "Pause game"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.custom_minimum_size = Vector2(58.0, 36.0)
	_pause_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pause_button.position = Vector2(-29.0, 12.0)
	_pause_button.size = Vector2(58.0, 36.0)
	_pause_button.add_theme_font_size_override("font_size", 19)
	_pause_button.add_theme_color_override("font_color", ACCENT_COLOR)
	_pause_button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("071522", 0.82)
	normal.border_color = Color(ACCENT_COLOR, 0.92)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(11)
	normal.shadow_color = Color(ACCENT_COLOR, 0.24)
	normal.shadow_size = 7
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("123348", 0.96)
	hover.border_color = Color(ACCENT_COLOR, 1.0)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(ACCENT_COLOR, 0.18)
	_pause_button.add_theme_stylebox_override("normal", normal)
	_pause_button.add_theme_stylebox_override("hover", hover)
	_pause_button.add_theme_stylebox_override("pressed", pressed)
	_pause_button.pressed.connect(_show_pause_menu)
	_ui_layer.add_child(_pause_button)
	_pause_button.hide()

func _start_game(single_player: bool = false) -> void:
	_clear_overlay()
	_pause_button.show()
	get_tree().paused = false
	_is_paused = false
	_active_single_player = single_player
	_arena = ARENA_SCENE.instantiate() as Node2D
	_arena.name = "Arena"
	_arena.set("single_player_mode", single_player)
	_arena.set("selected_weapon_id", _selected_weapon_id)
	_arena.set("selected_arena_id", _selected_arena_id)
	if single_player:
		_arena.set("cpu_difficulty", _selected_difficulty)
	# Main must always process input so Esc can resume, but the game itself
	# must remain pausable. Otherwise the arena inherits ALWAYS from Main.
	_arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	_arena.return_to_menu_requested.connect(_return_to_main_menu)
	add_child(_arena)


func _return_to_main_menu() -> void:
	_pause_button.hide()
	get_tree().paused = false
	_is_paused = false
	if is_instance_valid(_arena):
		_arena.queue_free()
	_arena = null
	_show_main_menu()


func _show_main_menu() -> void:
	_clear_overlay()
	var panel := _create_panel("RECOIL ARENA", "A DUEL OF AIM, ANGLES & RECOIL")
	_add_visual_menu_option(panel, "PLAY", "", "play", _show_mode_select, true)
	_add_visual_menu_option(panel, "CONTROLS", "", "controls", _show_controls_from_main)
	_add_visual_menu_option(panel, "SETTINGS", "", "settings", _show_settings_from_main)
	_add_visual_menu_option(panel, "QUIT GAME", "", "quit", _quit_game)


func _show_mode_select() -> void:
	_clear_overlay()
	var panel := _create_panel("CHOOSE YOUR MODE", "ONE PLAYER OR TWO. THE RECOIL DOESN'T CARE.")
	_add_visual_menu_option(panel, "SINGLE PLAYER", "", "cpu", _show_difficulty_select, true)
	_add_visual_menu_option(panel, "2 PLAYERS", "", "duel", _show_weapon_select.bind(false))
	_add_menu_button(panel, "BACK", _show_main_menu)


func _show_difficulty_select() -> void:
	_clear_overlay()
	var panel := _create_panel("CPU DIFFICULTY", "CHOOSE HOW HARD THE RED GUN FIGHTS BACK.")
	_add_visual_menu_option(panel, "EASY", "", "difficulty_easy", _show_weapon_select.bind(true, CPUController.DIFFICULTY_EASY), true)
	_add_visual_menu_option(panel, "NORMAL", "", "difficulty_normal", _show_weapon_select.bind(true, CPUController.DIFFICULTY_NORMAL))
	_add_visual_menu_option(panel, "HARD", "", "difficulty_hard", _show_weapon_select.bind(true, CPUController.DIFFICULTY_HARD))
	_add_menu_button(panel, "BACK", _show_mode_select)


func _show_weapon_select(single_player: bool, difficulty: int = CPUController.DIFFICULTY_NORMAL) -> void:
	_active_single_player = single_player
	_selected_difficulty = difficulty
	_clear_overlay()
	var panel := _create_panel("CHOOSE YOUR WEAPON", "FOUR CLASSES. DIFFERENT WAYS TO CAUSE A PROBLEM.")
	for weapon_id in WEAPON_CATALOG.get_ids():
		var stats := WEAPON_CATALOG.get_definition(weapon_id)
		_add_visual_menu_option(
			panel,
			str(stats["name"]),
			"",
			"weapon_" + weapon_id,
			_show_arena_select.bind(single_player, difficulty, weapon_id),
			weapon_id == _selected_weapon_id
		)
	_add_menu_button(panel, "BACK", _show_difficulty_select if single_player else _show_mode_select)

func _show_arena_select(single_player: bool, difficulty: int, weapon_id: String) -> void:
	_selected_weapon_id = weapon_id
	_active_single_player = single_player
	_selected_difficulty = difficulty
	_clear_overlay()
	var panel := _create_panel("CHOOSE YOUR ARENA", "SELECT THE BATTLEFIELD.")
	_add_visual_menu_option(panel, "NEXUS FACILITY", "", "arena_nexus", _select_arena.bind("nexus_facility"), _selected_arena_id == "nexus_facility")
	_add_visual_menu_option(panel, "ORBITAL STATION", "", "arena_orbital", _select_arena.bind("orbital_station"), _selected_arena_id == "orbital_station")
	_add_visual_menu_option(panel, "REACTOR CORE", "", "arena_reactor", _select_arena.bind("reactor_core"), _selected_arena_id == "reactor_core")
	_add_menu_button(panel, "ENTER ARENA", _start_selected_match, true)
	_add_menu_button(panel, "BACK", _show_weapon_select.bind(single_player, difficulty))


func _select_arena(arena_id: String) -> void:
	_selected_arena_id = arena_id
	_show_arena_select(_active_single_player, _selected_difficulty, _selected_weapon_id)


func _start_selected_match() -> void:
	_start_game(_active_single_player)


func _show_pause_menu() -> void:
	if not is_instance_valid(_arena):
		return
	_pause_button.hide()
	_is_paused = true
	get_tree().paused = true
	_clear_overlay()
	var panel := _create_panel("PAUSED", "MATCH SUSPENDED  /  COMBAT SYSTEMS ON HOLD")
	_add_pause_menu_button(panel, "RESUME MATCH", "Continue the current battle", _resume_game, true)
	_add_pause_menu_button(panel, "CONTROLS", "View movement and firing controls", _show_controls_from_pause)
	_add_pause_menu_button(panel, "SETTINGS", "Adjust audio settings", _show_settings_from_pause)
	_add_pause_menu_button(panel, "RETURN TO MAIN MENU", "Exit this match", _return_to_main_menu)


func _add_pause_menu_button(parent: VBoxContainer, title: String, detail: String, callback: Callable, primary := false) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(360.0, 58.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.text = title + "\n" + detail
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("eafaff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", ACCENT_COLOR)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("102638", 0.92) if primary else Color("091725", 0.88)
	normal.border_color = Color(ACCENT_COLOR, 0.9 if primary else 0.48)
	normal.set_border_width_all(1 if not primary else 2)
	normal.set_corner_radius_all(8)
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("17415a", 0.98)
	hover.border_color = Color(ACCENT_COLOR, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(callback)
	parent.add_child(button)


func _resume_game() -> void:
	_clear_overlay()
	_pause_button.show()
	_is_paused = false
	get_tree().paused = false


func _show_controls_from_main() -> void:
	_panel_return = "main"
	_show_controls()


func _show_controls_from_pause() -> void:
	_panel_return = "pause"
	_show_controls()


func _show_controls() -> void:
	_clear_overlay()
	var is_single_player_match := _panel_return == "pause" and _active_single_player
	var subtitle := "PLAYER VS CPU. ONE VERY UNSTABLE ARENA." if is_single_player_match else "TWO PLAYERS. ONE VERY UNSTABLE ARENA."
	var panel := _create_panel("CONTROLS", subtitle)
	_add_control_row(panel, "PLAYER 1", "A", Color("60a5fa"))
	if is_single_player_match:
		_add_control_row(panel, "CPU OPPONENT", "AUTOMATIC", Color("f87171"))
	else:
		_add_control_row(panel, "PLAYER 2", "L  /  LEFT ARROW", Color("f87171"))
	_add_control_row(panel, "PAUSE / RESUME", "ESC", ACCENT_COLOR)
	_add_body_label(panel, "Firing launches a bullet and kicks your gun in the opposite direction.")
	if is_single_player_match:
		_add_body_label(panel, "Mobile: tap anywhere on the left half to fire. The CPU controls the red gun automatically.")
	else:
		_add_body_label(panel, "Mobile: tap anywhere on the left half to fire Player 1, or the right half to fire Player 2. Both sides support simultaneous touches.")
	_add_body_label(panel, "Land three hits to eliminate your opponent. Your own bullets can never hurt you.")
	var back_action: Callable = Callable(self, "_show_main_menu") if _panel_return == "main" else Callable(self, "_show_pause_menu")
	_add_menu_button(panel, "BACK", back_action, true)


func _show_settings_from_main() -> void:
	_panel_return = "main"
	_show_settings()


func _show_settings_from_pause() -> void:
	_panel_return = "pause"
	_show_settings()


func _show_settings() -> void:
	_clear_overlay()
	var panel := _create_panel("SETTINGS", "A FEW KNOBS. NO UNNECESSARY COMPLICATIONS.")
	var volume_heading := Label.new()
	volume_heading.text = "MASTER VOLUME"
	volume_heading.add_theme_font_size_override("font_size", 14)
	volume_heading.add_theme_color_override("font_color", TEXT_COLOR)
	panel.add_child(volume_heading)

	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 12)
	panel.add_child(volume_row)
	var slider := HSlider.new()
	slider.name = "MasterVolumeSlider"
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(250.0, 28.0)
	slider.value = AudioServer.get_bus_volume_linear(0)
	slider.value_changed.connect(_on_master_volume_changed)
	volume_row.add_child(slider)
	_volume_value = Label.new()
	_volume_value.custom_minimum_size = Vector2(48.0, 0.0)
	_volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_volume_value.add_theme_color_override("font_color", ACCENT_COLOR)
	volume_row.add_child(_volume_value)
	_update_volume_label(slider.value)

	_add_body_label(panel, "Volume changes apply immediately to all game audio.")
	var back_action: Callable = Callable(self, "_show_main_menu") if _panel_return == "main" else Callable(self, "_show_pause_menu")
	_add_menu_button(panel, "BACK", back_action, true)


func _on_master_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(0, value)
	_update_volume_label(value)


func _update_volume_label(value: float) -> void:
	if is_instance_valid(_volume_value):
		_volume_value.text = "%d%%" % roundi(value * 100.0)


func _create_panel(heading: String, subtitle: String) -> VBoxContainer:
	var overlay := Control.new()
	overlay.name = "MenuOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS

	var backdrop := Control.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.draw.connect(_draw_menu_backdrop.bind(backdrop))
	var background_texture := TextureRect.new()
	background_texture.name = "MenuBackgroundTexture"
	background_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_texture.texture = MENU_BACKGROUND
	background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(background_texture)
	overlay.add_child(backdrop)

	var panel := VBoxContainer.new()
	panel.name = "MenuPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 42.0
	panel.offset_top = 28.0
	panel.offset_right = -42.0
	panel.offset_bottom = -28.0
	var viewport_size := get_viewport_rect().size
	var fit_scale := minf(1.0, minf((viewport_size.x - 24.0) / 1196.0, (viewport_size.y - 20.0) / 680.0))
	panel.pivot_offset = viewport_size * 0.5
	panel.scale = Vector2.ONE * maxf(fit_scale, 0.1)
	panel.add_theme_constant_override("separation", 14)
	overlay.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(content)
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 22)
	content.add_child(title_row)
	var left_rule := Control.new()
	left_rule.custom_minimum_size = Vector2(100.0, 12.0)
	left_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_rule.draw.connect(_draw_title_rule.bind(left_rule, true))
	title_row.add_child(left_rule)
	var title := Label.new()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48 if heading == "RECOIL ARENA" else 32)
	title.add_theme_color_override("font_color", Color("d8faff"))
	title.add_theme_color_override("font_shadow_color", Color(ACCENT_COLOR, 1.0))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 14)
	title_row.add_child(title)
	var right_rule := Control.new()
	right_rule.custom_minimum_size = Vector2(100.0, 12.0)
	right_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_rule.draw.connect(_draw_title_rule.bind(right_rule, false))
	title_row.add_child(right_rule)
	var sub := Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color("c4d0dd"))
	content.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 38.0 if heading == "RECOIL ARENA" else 20.0)
	content.add_child(spacer)
	_active_overlay = overlay
	_ui_layer.add_child(overlay)
	return content


func _add_menu_button(parent: VBoxContainer, label_text: String, callback: Callable, primary := false) -> void:
	var icon_kind := "back" if label_text == "BACK" else "play" if label_text == "ENTER ARENA" else "quit"
	_add_visual_menu_option(parent, label_text, "Return to previous screen" if label_text == "BACK" else "Continue" if icon_kind == "play" else "Return to the main menu", icon_kind, callback, primary)


func _add_visual_menu_option(
	parent: VBoxContainer,
	label_text: String,
	description: String,
	icon_kind: String,
	callback: Callable,
	primary := false
) -> void:
	var row_container := parent.get_node_or_null("OptionCardRow") as HBoxContainer
	if row_container == null:
		row_container = HBoxContainer.new()
		row_container.name = "OptionCardRow"
		row_container.alignment = BoxContainer.ALIGNMENT_CENTER
		row_container.add_theme_constant_override("separation", 18)
		row_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(row_container)
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(218.0, 218.0)
	button.custom_maximum_size = Vector2(238.0, 238.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	_style_menu_button(button, primary)
	button.pressed.connect(callback)
	if primary:
		button.call_deferred("grab_focus")
	row_container.add_child(button)

	var frame := Control.new()
	frame.name = "CyberneticFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(_draw_card_frame.bind(frame, primary))
	button.add_child(frame)
	button.mouse_entered.connect(_set_card_hover.bind(frame, true))
	button.mouse_exited.connect(_set_card_hover.bind(frame, false))
	var card_content := VBoxContainer.new()
	card_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_content.offset_left = 14.0
	card_content.offset_top = 14.0
	card_content.offset_right = -14.0
	card_content.offset_bottom = -14.0
	card_content.alignment = BoxContainer.ALIGNMENT_END
	card_content.add_theme_constant_override("separation", 7)
	card_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(card_content)

	var art: Control
	if MENU_ICON_TEXTURES.has(icon_kind):
		var icon_texture := TextureRect.new()
		icon_texture.texture = MENU_ICON_TEXTURES[icon_kind]
		icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art = icon_texture
	else:
		art = Control.new()
		art.draw.connect(_draw_menu_art.bind(art, icon_kind))
	art.name = "OptionArtwork"
	var is_weapon_card := icon_kind.begins_with("weapon_")
	var is_difficulty_card := icon_kind.begins_with("difficulty_")
	var title_only_card := is_weapon_card or is_difficulty_card
	art.custom_minimum_size = Vector2(142.0, 132.0)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_content.add_child(art)

	var title := Label.new()
	title.text = label_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	var bold_font := FontVariation.new()
	bold_font.base_font = ThemeDB.fallback_font
	bold_font.variation_embolden = 0.7
	title.add_theme_font_override("font", bold_font)
	title.add_theme_color_override("font_color", Color("e9fcff"))
	title.add_theme_color_override("font_outline_color", Color(ACCENT_COLOR, 0.82 if primary else 0.48))
	title.add_theme_constant_override("outline_size", 2 if primary else 1)
	title.add_theme_color_override("font_shadow_color", Color(ACCENT_COLOR, 0.95 if primary else 0.52))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 8 if primary else 4)
	card_content.add_child(title)
	if primary:
		var active_mark := Control.new()
		active_mark.custom_minimum_size = Vector2(62.0, 5.0)
		active_mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		active_mark.draw.connect(_draw_active_card_mark.bind(active_mark))
		card_content.add_child(active_mark)

	if not title_only_card:
		var detail := Label.new()
		detail.text = description
		detail.visible = not description.is_empty()
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.add_theme_font_size_override("font_size", 12)
		detail.add_theme_color_override("font_color", Color("c0cbd8"))
		card_content.add_child(detail)
func _style_menu_button(button: Button, primary: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("061522", 0.90)
	normal.border_color = Color(ACCENT_COLOR, 0.0)
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(5)
	normal.shadow_color = Color(ACCENT_COLOR, 0.62 if primary else 0.13)
	normal.shadow_size = 20 if primary else 7
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("0b2939", 0.98)
	hover.shadow_size = 22
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("0d2635")
	var focused := hover.duplicate() as StyleBoxFlat
	focused.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focused)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _draw_title_rule(rule: Control, left_side: bool) -> void:
	var y := rule.size.y * 0.5
	var start := Vector2(0.0, y) if left_side else Vector2(8.0, y)
	var finish := Vector2(rule.size.x - 8.0, y) if left_side else Vector2(rule.size.x, y)
	rule.draw_line(start, finish, Color(ACCENT_COLOR, 0.48), 1.0, true)
	rule.draw_line(Vector2(rule.size.x * 0.48, y - 3.0), Vector2(rule.size.x, y - 3.0), Color(ACCENT_COLOR, 0.22), 1.0, true)
	rule.draw_circle(Vector2(rule.size.x if left_side else 0.0, y), 2.0, Color("9af1ff", 0.9))


func _draw_card_frame(frame: Control, primary: bool) -> void:
	var rect := Rect2(Vector2(5.0, 5.0), frame.size - Vector2(10.0, 10.0))
	var highlighted := primary or bool(frame.get_meta("hovered", false))
	var glow := Color(ACCENT_COLOR, 0.92 if highlighted else 0.30)
	var inner := Color("c8faff", 0.88 if highlighted else 0.24)
	frame.draw_rect(Rect2(rect.position + Vector2(0.0, 7.0), rect.size), Color("010711", 0.94), true)
	frame.draw_rect(rect, Color("061522", 0.20 if highlighted else 0.42), true)
	frame.draw_rect(rect, Color(ACCENT_COLOR, 0.07 if highlighted else 0.025), false, 2.0)
	frame.draw_rect(rect.grow(-5.0), inner, false, 1.0)
	frame.draw_line(rect.position + Vector2(12.0, 1.0), rect.end + Vector2(-12.0, 1.0), Color("e4fcff", 0.38 if highlighted else 0.12), 1.0, true)
	var corner := 22.0
	for point in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		var sx := 1.0 if point.x < frame.size.x * 0.5 else -1.0
		var sy := 1.0 if point.y < frame.size.y * 0.5 else -1.0
		frame.draw_line(point + Vector2(sx * 2.0, sy * 2.0), point + Vector2(sx * corner, sy * 2.0), glow, 2.0, true)
		frame.draw_line(point + Vector2(sx * 2.0, sy * 2.0), point + Vector2(sx * 2.0, sy * corner), glow, 2.0, true)
	frame.draw_line(Vector2(frame.size.x * 0.35, frame.size.y - 9.0), Vector2(frame.size.x * 0.65, frame.size.y - 9.0), Color(glow, 0.72), 1.0)


func _set_card_hover(frame: Control, hovered: bool) -> void:
	if is_instance_valid(frame):
		frame.set_meta("hovered", hovered)
		frame.queue_redraw()


func _draw_active_card_mark(mark: Control) -> void:
	mark.draw_rect(Rect2(0.0, 1.0, mark.size.x, 2.0), Color(ACCENT_COLOR, 0.22), true)
	mark.draw_rect(Rect2(9.0, 1.0, mark.size.x - 18.0, 3.0), Color("b7f8ff"), true)


func _draw_menu_art(art: Control, kind: String) -> void:
	# Draw in a 64x64 design space, scaled and offset to the exact center.
	art.draw_set_transform(Vector2(8.0, 8.0), 0.0, Vector2(1.5, 1.5))
	var center := Vector2(32.0, 32.0)
	# A dark machined medallion gives the vector illustrations depth and a metal rim.
	art.draw_circle(center + Vector2(0.0, 2.0), 29.0, Color("020812", 0.82))
	art.draw_circle(center, 28.0, Color("102638", 0.94))
	art.draw_circle(center, 25.0, Color("071522", 0.98))
	art.draw_arc(center, 27.0, -2.85, 0.95, 48, Color("c4f8ff", 0.54), 1.5, true)
	art.draw_arc(center, 27.0, 0.3, 2.55, 48, Color(ACCENT_COLOR, 0.62), 2.0, true)
	art.draw_circle(Vector2(13.0, 13.0), 1.3, Color("e6fbff", 0.9))
	art.draw_circle(Vector2(51.0, 51.0), 1.3, Color("e6fbff", 0.72))
	if kind.begins_with("arena_"):
		match kind:
			"arena_nexus":
				art.draw_colored_polygon(PackedVector2Array([Vector2(7, 25), Vector2(18, 12), Vector2(47, 12), Vector2(58, 25), Vector2(58, 53), Vector2(7, 53)]), Color("12384b"))
				art.draw_colored_polygon(PackedVector2Array([Vector2(13, 27), Vector2(22, 17), Vector2(43, 17), Vector2(52, 27), Vector2(52, 48), Vector2(13, 48)]), Color("0a1b2a"))
				art.draw_rect(Rect2(25, 29, 14, 19), Color("38d9ff", 0.18), true)
				art.draw_rect(Rect2(25, 29, 14, 19), Color("72e8ff"), false, 2.0)
				for x in [17.0, 23.0, 41.0, 47.0]:
					art.draw_line(Vector2(x, 29), Vector2(x, 45), Color("38d9ff", 0.8), 2.0)
				art.draw_line(Vector2(5, 55), Vector2(59, 55), Color("38d9ff"), 2.0)
			"arena_orbital":
				art.draw_circle(center, 16.0, Color("1a5a83"))
				art.draw_arc(center, 16.0, 0.3, 2.7, 40, Color("9beaff"), 2.0, true)
				art.draw_arc(center, 25.0, -0.55, 2.35, 48, Color("38d9ff"), 2.5, true)
				art.draw_circle(Vector2(25, 26), 3.0, Color("b9f5ff"))
				art.draw_circle(Vector2(40, 39), 2.0, Color("b9f5ff"))
				art.draw_colored_polygon(PackedVector2Array([Vector2(49, 12), Vector2(61, 8), Vector2(56, 20)]), Color("f4fbff"))
				for star in [Vector2(8, 15), Vector2(12, 49), Vector2(53, 53)]:
					art.draw_line(star + Vector2(-3, 0), star + Vector2(3, 0), Color.WHITE, 1.5)
					art.draw_line(star + Vector2(0, -3), star + Vector2(0, 3), Color.WHITE, 1.5)
			"arena_reactor":
				art.draw_colored_polygon(PackedVector2Array([Vector2(32, 4), Vector2(53, 16), Vector2(53, 45), Vector2(32, 59), Vector2(11, 45), Vector2(11, 16)]), Color("55252b"))
				art.draw_colored_polygon(PackedVector2Array([Vector2(32, 9), Vector2(48, 19), Vector2(48, 42), Vector2(32, 53), Vector2(16, 42), Vector2(16, 19)]), Color("ff7546"))
				art.draw_circle(center, 13.0, Color("8f2d2a"))
				art.draw_circle(center, 8.0, Color("ffb45f"))
				art.draw_circle(center, 3.0, Color("fff0b8"))
				for index in range(6):
					var direction := Vector2.RIGHT.rotated(TAU * float(index) / 6.0)
					art.draw_line(center + direction * 22.0, center + direction * 29.0, Color("ffc078"), 2.5)
		return
	if kind.begins_with("weapon_"):
		var weapon_type := kind.trim_prefix("weapon_")
		var weapon_color := Color("38d9ff")
		match weapon_type:
			"heavy_cannon": weapon_color = Color("ffb547")
			"rapid_blaster": weapon_color = Color("b69aff")
			"railgun": weapon_color = Color("ff77bd")
		if weapon_type == "heavy_cannon":
				# Armored receiver, oversized reinforced barrel and heavy grip.
				art.draw_colored_polygon(PackedVector2Array([Vector2(5, 23), Vector2(14, 13), Vector2(43, 13), Vector2(51, 20), Vector2(56, 23), Vector2(56, 39), Vector2(14, 41), Vector2(5, 34)]), Color("5c3d20"))
				art.draw_colored_polygon(PackedVector2Array([Vector2(8, 23), Vector2(17, 17), Vector2(43, 17), Vector2(49, 23), Vector2(49, 35), Vector2(13, 36)]), weapon_color)
				art.draw_rect(Rect2(43, 18, 17, 19), Color("26394b"), true)
				art.draw_rect(Rect2(48, 21, 13, 12), Color("d9f6ff"), false, 2.0)
				art.draw_rect(Rect2(51, 24, 8, 6), Color("fff0c7"), true)
				art.draw_colored_polygon(PackedVector2Array([Vector2(18, 37), Vector2(33, 37), Vector2(29, 56), Vector2(15, 53)]), Color("23374a"))
				art.draw_line(Vector2(17, 18), Vector2(40, 18), Color("fff0c7"), 2.0)
				art.draw_line(Vector2(14, 23), Vector2(14, 33), Color("ffe0a3"), 2.0)
				for x in [21.0, 27.0, 33.0]:
					art.draw_line(Vector2(x, 21), Vector2(x, 30), Color("3b2c22"), 2.0)
				art.draw_circle(Vector2(20, 36), 2.0, Color("fff0c7"))
				art.draw_circle(Vector2(38, 36), 2.0, Color("fff0c7"))
				art.draw_line(Vector2(18, 44), Vector2(27, 46), Color("91a8b9"), 1.5)
		elif weapon_type == "rapid_blaster":
				# Twin emitter barrels, exposed energy rails and a compact frame.
				art.draw_colored_polygon(PackedVector2Array([Vector2(8, 22), Vector2(42, 19), Vector2(49, 24), Vector2(53, 28), Vector2(53, 39), Vector2(8, 40)]), Color("342d52"))
				art.draw_colored_polygon(PackedVector2Array([Vector2(9, 24), Vector2(43, 22), Vector2(48, 27), Vector2(48, 37), Vector2(9, 37)]), weapon_color)
				art.draw_rect(Rect2(42, 23, 19, 6), Color("e9e1ff"), true)
				art.draw_rect(Rect2(42, 33, 19, 6), Color("e9e1ff"), true)
				art.draw_rect(Rect2(48, 24, 10, 4), Color("ffffff"), true)
				art.draw_rect(Rect2(48, 34, 10, 4), Color("ffffff"), true)
				art.draw_colored_polygon(PackedVector2Array([Vector2(18, 38), Vector2(31, 38), Vector2(28, 54), Vector2(15, 52)]), Color("26374c"))
				art.draw_line(Vector2(10, 21), Vector2(37, 18), Color("e7ddff"), 2.0)
				art.draw_line(Vector2(10, 40), Vector2(38, 43), Color("a78bfa"), 2.0)
				for x in [15.0, 21.0, 27.0, 33.0]:
					art.draw_line(Vector2(x, 25), Vector2(x, 35), Color("4a3c70"), 1.5)
				art.draw_circle(Vector2(18, 46), 2.0, Color("e9e1ff"))
		elif weapon_type == "railgun":
				# Long precision chassis with magnetic accelerator coils and charge core.
				art.draw_colored_polygon(PackedVector2Array([Vector2(4, 25), Vector2(52, 18), Vector2(61, 23), Vector2(61, 31), Vector2(53, 37), Vector2(4, 34)]), Color("482c42"))
				art.draw_colored_polygon(PackedVector2Array([Vector2(5, 25), Vector2(53, 21), Vector2(58, 24), Vector2(58, 30), Vector2(52, 33), Vector2(5, 33)]), weapon_color)
				art.draw_line(Vector2(9, 22), Vector2(52, 16), Color.WHITE, 2.0)
				art.draw_line(Vector2(9, 37), Vector2(52, 34), Color("ffd5ec"), 2.0)
				art.draw_rect(Rect2(18, 15, 28, 4), Color("33253b"), true)
				art.draw_line(Vector2(20, 16), Vector2(44, 16), Color("ffe6f4"), 1.5)
				for x in [19.0, 27.0, 35.0, 43.0]:
					art.draw_arc(Vector2(x, 28), 10.0, -1.0, 1.0, 16, Color("ffe6f4"), 2.0, true)
					art.draw_line(Vector2(x, 19), Vector2(x, 37), Color("8b416e"), 1.0)
				art.draw_circle(Vector2(31, 28), 4.0, Color("fff0fb"))
				art.draw_circle(Vector2(31, 28), 2.0, weapon_color)
				art.draw_colored_polygon(PackedVector2Array([Vector2(20, 34), Vector2(32, 33), Vector2(27, 51), Vector2(17, 51)]), Color("26374c"))
				art.draw_line(Vector2(21, 39), Vector2(28, 39), Color("ffd5ec"), 1.5)
		else:
				# Balanced sidearm with a faceted slide, energy chamber and grip plates.
				art.draw_colored_polygon(PackedVector2Array([Vector2(7, 22), Vector2(42, 20), Vector2(55, 25), Vector2(58, 30), Vector2(55, 36), Vector2(11, 36)]), Color("164b5d"))
				art.draw_colored_polygon(PackedVector2Array([Vector2(8, 23), Vector2(42, 22), Vector2(53, 26), Vector2(53, 32), Vector2(11, 33)]), weapon_color)
				art.draw_colored_polygon(PackedVector2Array([Vector2(18, 34), Vector2(31, 34), Vector2(27, 53), Vector2(15, 50)]), Color("26374c"))
				art.draw_colored_polygon(PackedVector2Array([Vector2(19, 38), Vector2(27, 39), Vector2(24, 49), Vector2(17, 47)]), Color("39566b"))
				art.draw_rect(Rect2(45, 26, 14, 6), Color("e5fbff"), true)
				art.draw_rect(Rect2(49, 27, 8, 4), Color("ffffff"), true)
				art.draw_line(Vector2(12, 23), Vector2(39, 21), Color("c8faff"), 2.0)
				art.draw_line(Vector2(15, 35), Vector2(42, 35), Color("0a2638"), 1.5)
				art.draw_rect(Rect2(24, 25, 12, 6), Color("0b2638"), true)
				art.draw_circle(Vector2(30, 28), 4.0, Color("d9fbff"))
				art.draw_circle(Vector2(30, 28), 2.0, weapon_color)
				art.draw_arc(Vector2(30, 28), 9.0, -0.8, 2.8, 24, Color.WHITE, 1.5, true)
				art.draw_circle(Vector2(16, 30), 1.5, Color("e5fbff"))
				art.draw_circle(Vector2(40, 30), 1.5, Color("e5fbff"))
	art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_menu_backdrop(backdrop: Control) -> void:
	var size := backdrop.size
	backdrop.draw_rect(Rect2(Vector2.ZERO, size), Color("050a13", 0.48), true)
	backdrop.draw_rect(Rect2(Vector2.ZERO, size), Color("071522", 0.20), true)
	backdrop.draw_circle(Vector2(size.x * 0.5, size.y * 0.52), size.y * 0.56, Color("0b2333", 0.20))
	# Long diagonal beams create the split cyan/red atmosphere from the reference.
	backdrop.draw_line(Vector2(size.x * 0.06, size.y * 0.04), Vector2(size.x * 0.43, size.y * 0.55), Color("087fbd", 0.055), 38.0, true)
	backdrop.draw_line(Vector2(size.x * 0.08, size.y * 0.10), Vector2(size.x * 0.39, size.y * 0.52), Color("087fbd", 0.17), 18.0, true)
	backdrop.draw_line(Vector2(size.x * 0.08, size.y * 0.10), Vector2(size.x * 0.39, size.y * 0.52), Color("36cfff", 0.42), 2.0, true)
	backdrop.draw_line(Vector2(size.x * 0.08, size.y * 0.91), Vector2(size.x * 0.40, size.y * 0.52), Color("087fbd", 0.14), 14.0, true)
	backdrop.draw_line(Vector2(size.x * 0.94, size.y * 0.04), Vector2(size.x * 0.57, size.y * 0.55), Color("a51e38", 0.05), 38.0, true)
	backdrop.draw_line(Vector2(size.x * 0.92, size.y * 0.10), Vector2(size.x * 0.61, size.y * 0.52), Color("a51e38", 0.15), 18.0, true)
	backdrop.draw_line(Vector2(size.x * 0.92, size.y * 0.10), Vector2(size.x * 0.61, size.y * 0.52), Color("ff465c", 0.40), 2.0, true)
	backdrop.draw_line(Vector2(size.x * 0.92, size.y * 0.91), Vector2(size.x * 0.61, size.y * 0.52), Color("a51e38", 0.13), 14.0, true)
	# Angular perimeter frame, corner cuts, and HUD ticks stay outside the cards.
	var cyan := Color("38d9ff", 0.42)
	var red := Color("ef4444", 0.38)
	backdrop.draw_line(Vector2(18, 18), Vector2(size.x - 18, 18), Color("2a5369", 0.45), 1.0)
	backdrop.draw_line(Vector2(18, size.y - 18), Vector2(size.x - 18, size.y - 18), Color("2a5369", 0.45), 1.0)
	backdrop.draw_line(Vector2(18, 18), Vector2(18, size.y - 18), Color("2a5369", 0.45), 1.0)
	backdrop.draw_line(Vector2(size.x - 18, 18), Vector2(size.x - 18, size.y - 18), Color("2a5369", 0.45), 1.0)
	for side in [0, 1]:
		var x := 30.0 if side == 0 else size.x - 30.0
		var tint := cyan if side == 0 else red
		for index in range(10):
			var y := size.y * 0.30 + index * 19.0
			backdrop.draw_rect(Rect2(x - 5.0, y, 10.0, 5.0), Color(tint, 0.48 - float(index) * 0.025), true)
		backdrop.draw_line(Vector2(x, size.y * 0.24), Vector2(x, size.y * 0.76), Color(tint, 0.22), 1.0)
	for corner in [Vector2(18, 18), Vector2(size.x - 18, 18), Vector2(18, size.y - 18), Vector2(size.x - 18, size.y - 18)]:
		var horizontal := 42.0 if corner.x < size.x * 0.5 else -42.0
		var vertical := 42.0 if corner.y < size.y * 0.5 else -42.0
		backdrop.draw_line(corner, corner + Vector2(horizontal, 0.0), cyan, 2.0)
		backdrop.draw_line(corner, corner + Vector2(0.0, vertical), cyan, 2.0)


func _add_control_row(parent: VBoxContainer, action_name: String, key_text: String, tint: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var action_label := Label.new()
	action_label.text = action_name
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_label.add_theme_font_size_override("font_size", 14)
	action_label.add_theme_color_override("font_color", TEXT_COLOR)
	row.add_child(action_label)
	var key_label := Label.new()
	key_label.text = key_text
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key_label.add_theme_font_size_override("font_size", 14)
	key_label.add_theme_color_override("font_color", tint)
	row.add_child(key_label)


func _add_body_label(parent: VBoxContainer, text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", MUTED_COLOR)
	parent.add_child(label)


func _clear_overlay() -> void:
	_volume_value = null
	if is_instance_valid(_active_overlay):
		# Release the child name immediately so the next screen can consistently
		# create a fresh MenuOverlay while the old one is queued for deletion.
		_ui_layer.remove_child(_active_overlay)
		_active_overlay.queue_free()
	_active_overlay = null


func _quit_game() -> void:
	get_tree().quit()
