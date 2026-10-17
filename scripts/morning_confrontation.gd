extends Node2D

const MEMORY_TEXTS := [
	"Ký ức 1 — An bị vu cáo và bôi nhọ; lời cầu cứu của cô không được lắng nghe.",
	"Ký ức 2 — An cầu cứu nhưng không nhận được sự giúp đỡ kịp thời.",
	"Ký ức 3 — An bị truy đuổi tới cầu thang và gặp nạn.",
]

var title: Label
var body: Label
var memory_status: Label
var cue: Label
var light_buttons: Array[Button] = []
var visited_memories: Array[bool] = [false, false, false]

func _ready() -> void:
	_build_ui()
	GameState.set_checkpoint("scene_14", "morning_confrontation")
	for index in range(visited_memories.size()):
		visited_memories[index] = bool(GameState.flags.get("final_memory_%d_seen" % (index + 1), false))
	_refresh()
	if _all_memories_seen():
		_deliver_black_king()

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif event.keycode in [KEY_1, KEY_2, KEY_3]:
		_activate_memory(event.keycode - KEY_1)
	elif event.keycode == KEY_E or event.keycode == KEY_ENTER:
		for index in range(visited_memories.size()):
			if not visited_memories[index]:
				_activate_memory(index)
		GameState.set_checkpoint("scene_15", "ending")
		get_tree().change_scene_to_file("res://scenes/15_ending.tscn")

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	title = Label.new()
	title.position = Vector2(54, 30)
	title.size = Vector2(850, 45)
	title.add_theme_color_override("font_color", Color("#efe3d0"))
	title.add_theme_font_size_override("font_size", 26)
	layer.add_child(title)
	body = Label.new()
	body.position = Vector2(80, 100)
	body.size = Vector2(800, 245)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_theme_color_override("font_color", Color("#ded7cc"))
	body.add_theme_font_size_override("font_size", 19)
	layer.add_child(body)
	var lights_row := HBoxContainer.new()
	lights_row.position = Vector2(60, 370)
	lights_row.size = Vector2(840, 58)
	lights_row.add_theme_constant_override("separation", 16)
	layer.add_child(lights_row)
	var button_texts := ["1 · LỜI VU CÁO", "2 · TIẾNG CẦU CỨU", "3 · CẦU THANG"]
	for index in range(3):
		var button := Button.new()
		button.text = button_texts[index]
		button.custom_minimum_size = Vector2(250, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_activate_memory.bind(index))
		lights_row.add_child(button)
		light_buttons.append(button)
	memory_status = Label.new()
	memory_status.position = Vector2(70, 439)
	memory_status.size = Vector2(820, 32)
	memory_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	memory_status.add_theme_color_override("font_color", Color("#e2c58e"))
	memory_status.add_theme_font_size_override("font_size", 15)
	layer.add_child(memory_status)
	cue = Label.new()
	cue.position = Vector2(54, 492)
	cue.add_theme_color_override("font_color", Color("#c7c0b4"))
	cue.add_theme_font_size_override("font_size", 15)
	layer.add_child(cue)

func _refresh() -> void:
	title.text = "14 — KÝ ỨC CUỐI CÙNG"
	body.text = "Ba đốm sáng giữ lại những điều An không kịp nói. Ký ức đầu tiên: An bị vu cáo và bôi nhọ. Ký ức thứ hai: cô cầu cứu nhưng không được giúp đỡ kịp thời. Ký ức cuối: An bị truy đuổi tới cầu thang và gặp nạn. Sau đó, An trao Hoàng quân vua đen; dưới đế khắc “Trần Nhật Minh — lớp 11A2”. An cảm ơn nhóm bạn rồi biến mất."
	memory_status.text = "Ba điểm sáng đang chờ được chạm vào."
	for index in range(light_buttons.size()):
		light_buttons[index].disabled = visited_memories[index]
		if visited_memories[index]:
			light_buttons[index].text = "✓  " + ["LỜI VU CÁO", "TIẾNG CẦU CỨU", "CẦU THANG"][index]
	cue.text = "Khám phá từng ký ức bằng nút bên trên hoặc phím 1–3 · E nghe trọn lời An và sang 07:10"

func _activate_memory(index: int) -> void:
	if index < 0 or index >= visited_memories.size() or visited_memories[index]:
		return
	visited_memories[index] = true
	GameState.set_flag("final_memory_%d_seen" % (index + 1))
	GameState.set_evidence("final_memory_%d" % (index + 1), MEMORY_TEXTS[index])
	memory_status.text = MEMORY_TEXTS[index]
	_refresh_lights()
	if _all_memories_seen():
		_deliver_black_king()

func _refresh_lights() -> void:
	for index in range(light_buttons.size()):
		light_buttons[index].disabled = visited_memories[index]
		if visited_memories[index]:
			light_buttons[index].text = "✓  " + ["LỜI VU CÁO", "TIẾNG CẦU CỨU", "CẦU THANG"][index]
	if _all_memories_seen():
		cue.text = "Ba ký ức đã nối liền · Nhấn E để tới buổi sáng 07:10."
	else:
		var count := 0
		for seen in visited_memories:
			if seen:
				count += 1
		cue.text = "Ký ức đã chạm: %d/3 · Có thể chọn theo thứ tự bất kỳ."
		cue.text = cue.text % count
	queue_redraw()

func _all_memories_seen() -> bool:
	for seen in visited_memories:
		if not seen:
			return false
	return true

func _deliver_black_king() -> void:
	GameState.add_item_once("black_king")
	GameState.set_flag("black_king_received")
	GameState.set_evidence("black_king_inscription", "Trần Nhật Minh — lớp 11A2")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 540)), Color("#141923"))
	draw_rect(Rect2(78, 78, 804, 278), Color("#242a32"))
	draw_rect(Rect2(92, 91, 776, 250), Color("#1c222a"))
	for index in range(3):
		var center := Vector2(260 + index * 220, 360)
		var glow := Color("#dfbf84", 0.19 if not visited_memories[index] else 0.38)
		draw_circle(center, 29, glow)
		draw_circle(center, 10, Color("#e3c583" if not visited_memories[index] else "#b8d0ae"))
