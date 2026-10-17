extends Node2D

const CLUB_VISUAL: PackedScene = preload("res://scenes/visual/chess_club_3d.tscn")
const ITEM_IDS := ["math_test", "chess_medal", "knight_keychain", "mother_photo", "minh_thanks", "chess_club_sketch"]
const ITEM_NAMES := ["BÀI KIỂM TRA 100 ĐIỂM", "HUY CHƯƠNG CỜ VUA", "MÓC KHÓA QUÂN MÃ", "ẢNH CHỤP CÙNG MẸ", "LỜI CẢM ƠN CỦA MINH", "PHÁC THẢO CÂU LẠC BỘ"]
const MEMORY_TEXTS := [
	"hồi ức: An muốn khoe bài Toán 100 điểm với mẹ.",
	"hồi ức: An nhận huy chương và muốn mở một câu lạc bộ cờ vua.",
	"hồi ức: Chiếc móc khóa quân mã nhắc An về lời chỉ đường trong hành lang.",
	"hồi ức: Tấm ảnh cùng mẹ và buổi đi chơi đã hứa với em gái.",
	"hồi ức: Minh từng gửi lời cảm ơn An vì đã giúp cậu.",
	"hồi ức: An phác thảo câu lạc bộ cờ vua cùng bạn bè.",
]
var selected := 0
var placed: Array[bool] = [false, false, false, false, false, false]
var club_visual: Node
var item_labels: Array[Label] = []
var feedback := ""
var title: Label
var status: Label
var instruction: Label

func _ready() -> void:
	club_visual = CLUB_VISUAL.instantiate()
	add_child(club_visual)
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
		feedback = ""
	elif event.keycode == KEY_RIGHT:
		selected = posmod(selected + 1, ITEM_IDS.size())
		feedback = ""
	elif event.keycode == KEY_E:
		if _all_placed():
			GameState.set_checkpoint("scene_13", "chess_challenge")
			get_tree().change_scene_to_file("res://scenes/13_ban_co_boss.tscn")
		elif GameState.inventory.has(ITEM_IDS[selected]):
			placed[selected] = true
			GameState.set_flag("returned_" + ITEM_IDS[selected])
			GameState.set_evidence("keepsake_memory_" + ITEM_IDS[selected], MEMORY_TEXTS[selected])
			feedback = MEMORY_TEXTS[selected]
		else:
			feedback = "Kỷ vật này chưa có trong hành trang. Hãy hoàn tất chương trước."
	elif event.keycode == KEY_R:
		feedback = "Mỗi kỷ vật được đặt lại đúng một lần; tiến trình đã lưu tự động."
	_refresh()

func _all_placed() -> bool:
	for value in placed:
		if not value: return false
	return true

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var header := ColorRect.new()
	header.position = Vector2.ZERO
	header.size = Vector2(960, 66)
	header.color = Color(0.045, 0.05, 0.07, 0.82)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(header)
	var hud_back := ColorRect.new()
	hud_back.position = Vector2(0, 374)
	hud_back.size = Vector2(960, 166)
	hud_back.color = Color(0.045, 0.05, 0.07, 0.88)
	hud_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_back)
	title = Label.new()
	title.position = Vector2(30, 18)
	title.add_theme_color_override("font_color", Color("#f3e6cc"))
	title.add_theme_font_size_override("font_size", 25)
	layer.add_child(title)
	for index in range(ITEM_IDS.size()):
		var item := Label.new()
		item.position = Vector2(30 + (index % 3) * 306, 386 + int(index / 3) * 28)
		item.size = Vector2(296, 25)
		item.add_theme_font_size_override("font_size", 12)
		layer.add_child(item)
		item_labels.append(item)
	status = Label.new()
	status.position = Vector2(30, 445)
	status.size = Vector2(900, 54)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("#e2c58e"))
	status.add_theme_font_size_override("font_size", 16)
	layer.add_child(status)
	instruction = Label.new()
	instruction.position = Vector2(30, 506)
	instruction.add_theme_color_override("font_color", Color("#c7c0b4"))
	instruction.add_theme_font_size_override("font_size", 15)
	layer.add_child(instruction)

func _refresh() -> void:
	if title == null: return
	var count := 0
	for value in placed:
		if value: count += 1
	club_visual.call("set_returned_count", count)
	title.text = "12 — NHỮNG ĐIỀU AN ĐỂ LẠI  ·  %d/6 KỶ VẬT ĐƯỢC TRẢ VỀ" % count
	for index in range(ITEM_IDS.size()):
		var marker := "▶" if index == selected else "✓" if placed[index] else "·"
		item_labels[index].text = "%s %s" % [marker, ITEM_NAMES[index]]
		item_labels[index].add_theme_color_override("font_color", Color("#f1cb83") if index == selected else Color("#d8ccb5") if placed[index] else Color("#92908b"))
	if feedback != "":
		status.text = feedback
	elif placed[selected]:
		status.text = MEMORY_TEXTS[selected]
	else:
		status.text = "ĐANG CHỌN — %s  ·  Nhấn E để đặt lên bàn cờ" % ITEM_NAMES[selected]
	instruction.text = "← / → chọn  ·  E đặt hoặc bắt đầu ván cờ khi đủ 6 món  ·  Tiến trình lưu tự động"
