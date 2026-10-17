extends Control

const GAME_SCENE := "res://scenes/01_hanh_lang.tscn"

var continue_button: Button
var new_game_button: Button
var quit_button: Button
var replace_save_dialog: ConfirmationDialog

func _ready() -> void:
	_build_menu()
	_refresh_continue_button()

func _build_menu() -> void:
	var background := ColorRect.new()
	background.color = Color("#090e17")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "AN — Tiếng Gậy Trong Đêm"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#eee7d9"))
	title.add_theme_font_size_override("font_size", 30)
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Chọn cách tiếp tục"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("#aab3c0"))
	subtitle.add_theme_font_size_override("font_size", 16)
	layout.add_child(subtitle)

	continue_button = _make_button("Tiếp tục")
	continue_button.pressed.connect(_continue_game)
	layout.add_child(continue_button)

	new_game_button = _make_button("Trò chơi mới")
	new_game_button.pressed.connect(_on_new_game_pressed)
	layout.add_child(new_game_button)

	quit_button = _make_button("Thoát")
	quit_button.pressed.connect(_quit_game)
	layout.add_child(quit_button)

	replace_save_dialog = ConfirmationDialog.new()
	replace_save_dialog.title = "Bắt đầu trò chơi mới?"
	replace_save_dialog.dialog_text = "Tiến trình hiện có sẽ bị thay thế. Bạn có muốn tiếp tục không?"
	replace_save_dialog.ok_button_text = "Bắt đầu mới"
	replace_save_dialog.cancel_button_text = "Quay lại"
	replace_save_dialog.confirmed.connect(_start_new_game)
	add_child(replace_save_dialog)

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#121b27")
	style.border_color = Color("#364250")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	return style

func _make_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("#eee7d9"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_disabled_color", Color("#68717d"))
	button.add_theme_stylebox_override("normal", _make_button_style(Color("#1b2937"), "#405365"))
	button.add_theme_stylebox_override("hover", _make_button_style(Color("#26394a"), "#9b7852"))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color("#324556"), "#c09562"))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color("#151c25"), "#29323d"))
	return button

func _make_button_style(fill: Color, border_hex: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(border_hex)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _refresh_continue_button() -> void:
	continue_button.disabled = not GameState.has_valid_loaded_save()
	if continue_button.disabled:
		new_game_button.grab_focus()
	else:
		continue_button.grab_focus()

func _continue_game() -> void:
	if not GameState.has_valid_loaded_save():
		_refresh_continue_button()
		return
	_change_to_game()

func _on_new_game_pressed() -> void:
	if GameState.has_existing_save_file():
		replace_save_dialog.popup_centered()
	else:
		_start_new_game()

func _start_new_game() -> void:
	GameState.reset_for_new_game()
	_change_to_game()

func _change_to_game() -> void:
	GameState.mark_title_menu_route()
	var error_code := get_tree().change_scene_to_file(GAME_SCENE)
	if error_code != OK:
		GameState.clear_title_menu_route()
		push_error("Unable to open gameplay scene: " + error_string(error_code))
		GameState.load_game()
		_refresh_continue_button()

func _quit_game() -> void:
	get_tree().quit()
