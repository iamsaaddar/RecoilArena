extends Node2D
## Owns the main menu, pause flow, and lifetime of the active arena.

const ARENA_SCENE := preload("res://scenes/arena/Arena.tscn")

const BG_COLOR := Color("0b0f18")
const PANEL_COLOR := Color("111925")
const ACCENT_COLOR := Color("38d9ff")
const TEXT_COLOR := Color("f1f5f9")
const MUTED_COLOR := Color("9aa8ba")

var _arena: Node2D
var _ui_layer: CanvasLayer
var _active_overlay: Control
var _is_paused := false
var _panel_return := "main"
var _volume_value: Label


func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "MenuUI"
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)
	_show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(_arena):
		if _is_paused:
			_resume_game()
		else:
			_show_pause_menu()
		get_viewport().set_input_as_handled()


func _start_game() -> void:
	_clear_overlay()
	get_tree().paused = false
	_is_paused = false
	_arena = ARENA_SCENE.instantiate() as Node2D
	_arena.name = "Arena"
	# Main must always process input so Esc can resume, but the game itself
	# must remain pausable. Otherwise the arena inherits ALWAYS from Main.
	_arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_arena)


func _return_to_main_menu() -> void:
	get_tree().paused = false
	_is_paused = false
	if is_instance_valid(_arena):
		_arena.queue_free()
	_arena = null
	_show_main_menu()


func _show_main_menu() -> void:
	_clear_overlay()
	var panel := _create_panel("RECOIL ARENA", "A DUEL OF AIM, ANGLES & RECOIL")
	_add_menu_button(panel, "PLAY", _start_game, true)
	_add_menu_button(panel, "CONTROLS", _show_controls_from_main)
	_add_menu_button(panel, "SETTINGS", _show_settings_from_main)
	_add_menu_button(panel, "QUIT GAME", _quit_game)
	_set_overlay(panel)


func _show_pause_menu() -> void:
	if not is_instance_valid(_arena):
		return
	_is_paused = true
	get_tree().paused = true
	_clear_overlay()
	var panel := _create_panel("PAUSED", "TAKE A BREATHER. THE GUNS CAN WAIT.")
	_add_menu_button(panel, "RESUME", _resume_game, true)
	_add_menu_button(panel, "CONTROLS", _show_controls_from_pause)
	_add_menu_button(panel, "SETTINGS", _show_settings_from_pause)
	_add_menu_button(panel, "MAIN MENU", _return_to_main_menu)
	_set_overlay(panel)


func _resume_game() -> void:
	_clear_overlay()
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
	var panel := _create_panel("CONTROLS", "TWO PLAYERS. ONE VERY UNSTABLE ARENA.")
	_add_control_row(panel, "PLAYER 1", "A", Color("60a5fa"))
	_add_control_row(panel, "PLAYER 2", "L  /  LEFT ARROW", Color("f87171"))
	_add_control_row(panel, "PAUSE / RESUME", "ESC", ACCENT_COLOR)
	_add_body_label(panel, "Firing launches a bullet and kicks your gun in the opposite direction.")
	_add_body_label(panel, "Mobile: tap anywhere on the left half to fire Player 1, or the right half to fire Player 2. Both sides support simultaneous touches.")
	_add_body_label(panel, "Land three hits to eliminate your opponent. Your own bullets can never hurt you.")
	var back_action: Callable = Callable(self, "_show_main_menu") if _panel_return == "main" else Callable(self, "_show_pause_menu")
	_add_menu_button(panel, "BACK", back_action, true)
	_set_overlay(panel)


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
	_set_overlay(panel)


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

	var backdrop := ColorRect.new()
	backdrop.color = Color(BG_COLOR, 0.96)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -220.0
	panel.offset_top = -250.0
	panel.offset_right = 220.0
	panel.offset_bottom = 250.0
	panel.custom_minimum_size = Vector2(440.0, 0.0)
	var viewport_size := get_viewport_rect().size
	var fit_scale := minf(1.0, minf((viewport_size.x - 24.0) / 440.0, (viewport_size.y - 24.0) / 500.0))
	panel.pivot_offset = Vector2(220.0, 250.0)
	panel.scale = Vector2.ONE * maxf(fit_scale, 0.1)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_COLOR
	panel_style.border_color = Color(ACCENT_COLOR, 0.5)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 34.0
	panel_style.content_margin_right = 34.0
	panel_style.content_margin_top = 32.0
	panel_style.content_margin_bottom = 32.0
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	var title := Label.new()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	content.add_child(title)
	var sub := Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", MUTED_COLOR)
	content.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 8.0)
	content.add_child(spacer)
	return _register_overlay(overlay, content)


func _register_overlay(overlay: Control, content: VBoxContainer) -> VBoxContainer:
	_active_overlay = overlay
	_ui_layer.add_child(overlay)
	return content


func _set_overlay(_content: VBoxContainer) -> void:
	if is_instance_valid(_active_overlay):
		_active_overlay.show()


func _add_menu_button(parent: VBoxContainer, label_text: String, callback: Callable, primary := false) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("123044") if primary else Color("1a2635")
	normal.border_color = Color(ACCENT_COLOR, 0.8 if primary else 0.25)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("17445b") if primary else Color("26384b")
	hover.border_color = ACCENT_COLOR
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("0d2635")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.pressed.connect(callback)
	parent.add_child(button)


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
		_active_overlay.queue_free()
	_active_overlay = null


func _quit_game() -> void:
	get_tree().quit()
