extends Node2D

var heading: Label
var story: Label
var unlock: Label

func _ready() -> void:
	_build_ui()
	GameState.set_checkpoint("scene_15", "ending")
	var verified := str(GameState.choices.get("minh_post", "verify_warn")) == "verify_warn"
	var chess_won := bool(GameState.flags.get("chess_boss_defeated", false))
	var chess_resigned := bool(GameState.flags.get("chess_resigned", false))
	var hopeful := verified and chess_won and not chess_resigned
	GameState.ending = "ending_dawn" if hopeful else "ending_echo"
	GameState.set_flag("night_2_unlocked")
	GameState.chapter = "night_1_complete"
	if chess_resigned:
		AudioDirector.play_sfx("night_stick_scrape")
		heading.text = "BAD ENDING  ·  NGƯỜI ĐÃ QUAY LƯNG"
		story.text = "Hoàng cúi đầu: “Xin lỗi. Mình không thể tiếp tục.” An nhìn những kỷ vật trên bàn. “Lần này... mình tưởng sẽ khác.” Đèn trong phòng tắt. Trong bóng tối, tiếng gậy sắt kéo lê vang lên: KÉÉÉÉT..."
	else:
		heading.text = "KẾT THÚC  ·  %s" % ("BÌNH MINH" if hopeful else "DƯ ÂM")
	if not chess_resigned and hopeful:
		story.text = "07:10 — Hoàng tỉnh dậy trong lớp học. Nhóm các bạn vẫn nhớ đêm qua; quân vua đen khắc tên Trần Nhật Minh — lớp 11A2 vẫn ở trong túi Hoàng. Lựa chọn kiểm chứng đã hạn chế lời đồn: Minh không đăng lời đồn. Cậu đang đứng ngoài hành lang.\n\nTin nhắn: “Các cậu đã giúp được An. Nhưng còn người tiếp theo? 11 giờ tối. Phòng 11A2.”"
	elif not chess_resigned:
		story.text = "07:10 — Hoàng tỉnh dậy trong lớp học. Nhóm các bạn vẫn nhớ đêm qua; Hoàng vẫn giữ quân vua đen mang tên Trần Nhật Minh — lớp 11A2. lựa chọn vội vàng đăng nguyên văn khiến lời bôi nhọ lan rộng; Minh đang chờ ngoài hành lang.\n\nTin nhắn: “Các cậu đã giúp được An. Nhưng còn người tiếp theo? 11 giờ tối. Phòng 11A2.”"
	unlock.text = "ĐÃ MỞ KHÓA  ·  ĐÊM THỨ HAI"
	if GameState.persistence_enabled:
		GameState.save_game()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	heading = Label.new()
	heading.position = Vector2(80, 76)
	heading.size = Vector2(800, 46)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color("#f0e4cb"))
	heading.add_theme_font_size_override("font_size", 30)
	layer.add_child(heading)
	story = Label.new()
	story.position = Vector2(142, 158)
	story.size = Vector2(676, 224)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.add_theme_color_override("font_color", Color("#ded7ca"))
	story.add_theme_font_size_override("font_size", 18)
	layer.add_child(story)
	unlock = Label.new()
	unlock.position = Vector2(200, 412)
	unlock.size = Vector2(560, 35)
	unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock.add_theme_color_override("font_color", Color("#e6be6c"))
	unlock.add_theme_font_size_override("font_size", 21)
	layer.add_child(unlock)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 540)), Color("#10151b"))
	for index in range(9):
		var x := float(index) * 120.0 - 30.0
		draw_rect(Rect2(x, 90, 54, 330), Color("#262b30"))
		draw_rect(Rect2(x + 4, 94, 46, 322), Color("#c6a36b", 0.1))
	draw_rect(Rect2(0, 420, 960, 120), Color("#262a2c"))
