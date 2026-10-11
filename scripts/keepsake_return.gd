extends Node2D

const ITEM_IDS := ["math_test", "chess_medal", "knight_keychain", "mother_photo", "minh_thanks", "chess_club_sketch"]
const ITEM_NAMES := ["BÀI KIỂM TRA 100 ĐIỂM", "HUY CHƯƠNG CỜ VUA", "MÓC KHÓA QUÂN MÃ", "ẢNH CHỤP CÙNG MẸ", "LỜI CẢM ƠN CỦA MINH", "PHÁC THẢO CÂU LẠC BỘ"]
var selected := 0
var placed: Array[bool] = [false, false, false, false, false, false]
var title: Label
var status: Label
var instruction: Label

func _ready() -> void:
	_build_ui()
	for index in range(ITEM_IDS.size()):
		placed[index] = bool(GameState.flags.get("returned_" + ITEM_IDS[index], false))
	GameState.set_checkpoint("scene_12", "return_memories")
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif event.keycode == KEY_LEFT:
		selected = posmod(selected - 1, ITEM_IDS.size())
	elif event.keycode == KEY_RIGHT:
		selected = posmod(selected + 1, ITEM_IDS.size())
	elif event.keycode == KEY_E:
		if _all_placed():
			GameState.set_checkpoint("scene_13", "chess_challenge")
			get_tree().change_scene_to_file("res://scenes/13_ban_co_boss.tscn")
		elif GameState.inventory.has(ITEM_IDS[selected]):
			placed[selected] = true
			GameState.set_flag("returned_" + ITEM_IDS[selected])
			_refresh()
		else:
			status.text = "Kỷ vật này chưa có trong hành trang. Hãy hoàn tất chương trước."
	elif event.keycode == KEY_R:
		status.text = "Mỗi kỷ vật được đặt lại đúng một lần; tiến trình đã lưu tự động."
	_refresh()

func _all_placed() -> bool:
	for value in placed:
		if not value: return false
	return true

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	title = Label.new()
	title.position = Vector2(42, 24)
	title.add_theme_color_override("font_color", Color("#f3e6cc"))
	title.add_theme_font_size_override("font_size", 25)
	layer.add_child(title)
	status = Label.new()
	status.position = Vector2(42, 442)
	status.size = Vector2(875, 46)
	status.add_theme_color_override("font_color", Color("#e2c58e"))
	status.add_theme_font_size_override("font_size", 16)
	layer.add_child(status)
	instruction = Label.new()
	instruction.position = Vector2(42, 494)
	instruction.add_theme_color_override("font_color", Color("#c7c0b4"))
	instruction.add_theme_font_size_override("font_size", 15)
	layer.add_child(instruction)

func _refresh() -> void:
	if title == null: return
	var count := 0
	for value in placed:
		if value: count += 1
	title.text = "12 — NHỮNG ĐIỀU AN ĐỂ LẠI  ·  %d/6 KỶ VẬT ĐƯỢC TRẢ VỀ" % count
	status.text = "Đã đặt: %s" % ITEM_NAMES[selected] if placed[selected] else "Chọn kỷ vật bằng ←/→ rồi nhấn E để đặt lên bàn cờ."
	instruction.text = "← / → chọn  ·  E đặt hoặc bắt đầu ván cờ khi đủ 6 món  ·  Tiến trình lưu tự động"
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 540)), Color("#17191d"))
	draw_rect(Rect2(64, 102, 832, 298), Color("#303238"))
	draw_rect(Rect2(86, 124, 788, 254), Color("#49443e"))
	draw_rect(Rect2(192, 160, 576, 170), Color("#332b25"))
	for index in range(6):
		var x := 222.0 + float(index % 3) * 178.0
		var y := 184.0 + float(index / 3) * 72.0
		var rect := Rect2(x, y, 150, 58)
		draw_rect(rect, Color("#756047") if placed[index] else Color("#242326"))
		draw_rect(rect, Color("#e5bf75") if index == selected else Color("#60564c"), false, 2.0)
		var color := Color("#f2e8d3") if placed[index] else Color("#77716a")
		draw_string(ThemeDB.fallback_font, Vector2(x + 8, y + 34), ITEM_NAMES[index], HORIZONTAL_ALIGNMENT_CENTER, 134, 11, color)
	draw_rect(Rect2(690, 164, 54, 54), Color("#aa916c"))
	draw_colored_polygon(PackedVector2Array([Vector2(716, 164), Vector2(744, 196), Vector2(716, 228), Vector2(690, 196)]), Color("#453c34"))
