extends Node2D

var title: Label
var body: Label
var cue: Label

func _ready() -> void:
	_build_ui()
	GameState.set_checkpoint("scene_14", "morning_confrontation")
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_E or event.keycode == KEY_ENTER:
			GameState.set_checkpoint("scene_15", "ending")
			get_tree().change_scene_to_file("res://scenes/15_ending.tscn")

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	title = Label.new()
	title.position = Vector2(54, 44)
	title.size = Vector2(850, 45)
	title.add_theme_color_override("font_color", Color("#efe3d0"))
	title.add_theme_font_size_override("font_size", 26)
	layer.add_child(title)
	body = Label.new()
	body.position = Vector2(96, 145)
	body.size = Vector2(770, 245)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_theme_color_override("font_color", Color("#ded7cc"))
	body.add_theme_font_size_override("font_size", 21)
	layer.add_child(body)
	cue = Label.new()
	cue.position = Vector2(54, 470)
	cue.add_theme_color_override("font_color", Color("#ddb96e"))
	cue.add_theme_font_size_override("font_size", 16)
	layer.add_child(cue)

func _refresh() -> void:
	var truth_choice := str(GameState.choices.get("minh_post", "verify_warn")) == "verify_warn"
	var won := bool(GameState.flags.get("chess_boss_defeated", false))
	title.text = "14 — BÌNH MINH SAU CÁNH CỔNG"
	if truth_choice:
		body.text = "Minh bước ra giữa sân trường, không còn phải một mình đối diện với lời đồn. Những gì hai bạn tìm được đủ để đính chính câu chuyện — nhưng chưa đủ để kết tội bất kỳ ai. " + ("Trên bàn cờ, An đã thắng bằng một nước đi sáng rõ." if won else "Bàn cờ vẫn còn dang dở; sự thật cũng còn những khoảng trống.") + "\n\nKhi cổng trường mở, tiếng gõ khẽ vang lên từ tầng ba. Lần này, An không quay lưng."
	else:
		body.text = "Bài đăng lan nhanh hơn lời giải thích. Minh vẫn đứng cạnh An, nhưng cả hai hiểu rằng một lời đồn đã để lại vết xước. Bằng chứng trong tay họ không chỉ ra ai đã khởi đầu nó. " + ("Chiếu hết khép lại ván cờ, không khép lại câu hỏi." if won else "An rời bàn cờ trước khi ván đấu ngã ngũ.") + "\n\nNgoài sân, tiếng gõ khẽ vọng xuống — ba nhịp, rồi im bặt."
	cue.text = "Nhấn E để khép lại Đêm thứ nhất"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 540)), Color("#20252b"))
	draw_rect(Rect2(0, 330, 960, 210), Color("#45423c"))
	draw_rect(Rect2(70, 92, 820, 244), Color("#353b40"))
	for x in range(118, 870, 96):
		draw_rect(Rect2(x, 116, 44, 196), Color("#22282e"))
		draw_rect(Rect2(x + 5, 122, 34, 182), Color("#9b8060", 0.26))
	draw_rect(Rect2(0, 324, 960, 7), Color("#bea878"))
