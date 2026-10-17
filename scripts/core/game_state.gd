extends Node

## Persistent chapter state shared across scene changes.
const SAVE_PATH := "user://an_tieng_gay_trong_dem_save.json"
const SAVE_VERSION := 1
const VALID_CHECKPOINTS := {
	"scene_01": ["scene_01_start", "hallway_letter"],
	"scene_02": ["classroom_0715", "classroom_letters", "afternoon_exit", "night_school_transition"],
	"scene_03": ["night_school_yard", "night_school_ground_hall", "restroom_approach", "restroom_threat", "toilet_retry", "toilet_hide"],
	"scene_04": ["mirror", "mirror_search", "notice_board"],
	"scene_05": ["board_portrait", "board_reverse", "notice_board"],
	"scene_06": ["locker_a17", "diary_reward"],
	"scene_07": ["circuit_start", "circuit_reward"],
	"scene_08": ["patrol_start", "chase_start"],
	"scene_09": ["camera_recovery", "photo_reward"],
	"scene_10": ["choice_recorded"],
	"scene_11": ["deduction_complete"],
	"scene_12": ["return_memories"],
	"scene_13": ["chess_challenge", "checkmate_won", "chess_resigned"],
	"scene_14": ["morning_confrontation"],
	"scene_15": ["ending"],
}

var chapter := "night_1"
var scene_id := "scene_01"
var checkpoint_id := "scene_01_start"
## Story time is an in-game clock; it is never derived from the OS clock.
var story_time := "17:10"
var current_objective := ""
var inventory: Array[String] = []
var evidence: Dictionary = {}
var flags: Dictionary = {}
var choices: Dictionary = {}
var ending := "none"
var persistence_enabled := true
var save_writes_suppressed := false
var _valid_loaded_save := false
var _title_menu_route_pending := false

func _ready() -> void:
	load_game()

func add_item_once(item_id: String) -> bool:
	if item_id.is_empty() or inventory.has(item_id):
		return false
	inventory.append(item_id)
	_persist_if_enabled()
	return true

func record_letter_collected() -> bool:
	var added := add_item_once("mysterious_letter")
	var changed := not bool(flags.get("letter_collected", false)) or not bool(flags.get("letter_picked_up", false))
	if changed:
		flags["letter_collected"] = true
		flags["letter_picked_up"] = true
		_persist_if_enabled()
	return added or changed

func mark_scene_01_completed() -> bool:
	return _set_flags_once({"scene_01_completed": true})

func mark_mirror_message_seen() -> bool:
	return set_flag_once("mirror_message_seen")

func mark_ghost_revealed() -> bool:
	return set_flag_once("ghost_revealed")

func unlock_notice_board_objective() -> bool:
	var changed := _set_flags_once({
		"scene_04_completed": true,
		"mirror_message_seen": true,
		"ghost_revealed": true,
		"notice_board_objective_unlocked": true,
	})
	if current_objective != "notice_board":
		current_objective = "notice_board"
		changed = true
		_persist_if_enabled()
	return changed

func set_story_time(clock_text: String) -> bool:
	if not _is_valid_story_time(clock_text) or story_time == clock_text:
		return false
	story_time = clock_text
	_persist_if_enabled()
	return true

func set_objective(objective_id: String) -> bool:
	if current_objective == objective_id:
		return false
	current_objective = objective_id
	_persist_if_enabled()
	return true

func set_flag_once(flag_id: String) -> bool:
	if flag_id.is_empty() or bool(flags.get(flag_id, false)):
		return false
	set_flag(flag_id, true)
	return true

func set_flag(flag_id: String, value: Variant = true) -> void:
	if flags.has(flag_id) and flags[flag_id] == value:
		return
	flags[flag_id] = value
	_persist_if_enabled()

func set_evidence(evidence_id: String, value: Variant = true) -> void:
	evidence[evidence_id] = value
	_persist_if_enabled()

func set_checkpoint(next_scene: String, next_checkpoint: String) -> void:
	scene_id = next_scene
	checkpoint_id = next_checkpoint
	_persist_if_enabled()

func set_choice(choice_id: String, value: String) -> bool:
	if choices.has(choice_id):
		return false
	choices[choice_id] = value
	_persist_if_enabled()
	return true

func to_dictionary() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"chapter": chapter,
		"scene_id": scene_id,
		"checkpoint_id": checkpoint_id,
		"story_time": story_time,
		"current_objective": current_objective,
		"inventory": inventory.duplicate(),
		"evidence": evidence.duplicate(true),
		"flags": flags.duplicate(true),
		"choices": choices.duplicate(true),
		"ending": ending,
	}

## True only after a supported save file has been loaded successfully.
func has_valid_loaded_save() -> bool:
	return _valid_loaded_save

## Used by the title menu to confirm before replacing any existing save file,
## including one that is malformed or from an unsupported version.
func has_existing_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## One-shot handoff used to distinguish a menu launch from direct editor preview.
func mark_title_menu_route() -> void:
	_title_menu_route_pending = true

func consume_title_menu_route() -> bool:
	var pending := _title_menu_route_pending
	_title_menu_route_pending = false
	return pending

func clear_title_menu_route() -> void:
	_title_menu_route_pending = false

## Reset story data in memory for a fresh run. This deliberately does not save
## or delete anything; gameplay persists the new starting checkpoint on entry.
func reset_for_new_game() -> void:
	_reset_story_state_to_defaults()
	persistence_enabled = true
	save_writes_suppressed = false

func save_game(path: String = SAVE_PATH) -> bool:
	if save_writes_suppressed:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write save file: " + error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(to_dictionary(), "\t"))
	return true

func load_game(path: String = SAVE_PATH) -> bool:
	_reset_story_state_to_defaults()
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Save file could not be opened; keeping safe defaults.")
		return false
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		push_warning("Save file is invalid; keeping safe defaults.")
		return false
	var saved: Dictionary = parser.data
	if int(saved.get("version", -1)) != SAVE_VERSION:
		push_warning("Save version is unsupported; keeping safe defaults.")
		return false
	if not _is_valid_saved_route(saved):
		push_warning("Save scene or checkpoint is unsupported; keeping safe defaults.")
		return false
	if not _has_valid_saved_fields(saved):
		push_warning("Save progress data is invalid; keeping safe defaults.")
		return false
	chapter = str(saved.get("chapter", "night_1"))
	scene_id = str(saved["scene_id"])
	checkpoint_id = str(saved["checkpoint_id"])
	var saved_story_time := str(saved.get("story_time", "17:10"))
	story_time = saved_story_time
	current_objective = str(saved.get("current_objective", ""))
	ending = str(saved.get("ending", "none"))
	inventory.clear()
	for item in saved["inventory"]:
		if item is String and not inventory.has(item):
			inventory.append(item)
	evidence = _dictionary_or_empty(saved["evidence"])
	flags = _dictionary_or_empty(saved["flags"])
	choices = _dictionary_or_empty(saved["choices"])
	_valid_loaded_save = true
	return true

func _reset_story_state_to_defaults() -> void:
	chapter = "night_1"
	scene_id = "scene_01"
	checkpoint_id = "scene_01_start"
	story_time = "17:10"
	current_objective = ""
	inventory.clear()
	evidence.clear()
	flags.clear()
	choices.clear()
	ending = "none"
	_valid_loaded_save = false
	_title_menu_route_pending = false

func _is_valid_saved_route(saved: Dictionary) -> bool:
	if not saved.has("scene_id") or not saved.has("checkpoint_id"):
		return false
	var saved_scene: Variant = saved["scene_id"]
	var saved_checkpoint: Variant = saved["checkpoint_id"]
	if not saved_scene is String or not saved_checkpoint is String:
		return false
	if not VALID_CHECKPOINTS.has(saved_scene):
		return false
	return saved_checkpoint in VALID_CHECKPOINTS[saved_scene]

func _has_valid_saved_fields(saved: Dictionary) -> bool:
	if saved.has("chapter") and not saved["chapter"] is String:
		return false
	if saved.has("ending") and not saved["ending"] is String:
		return false
	if not saved.has("inventory") or not saved["inventory"] is Array:
		return false
	for item in saved["inventory"]:
		if not item is String:
			return false
	for field in ["evidence", "flags", "choices"]:
		if not saved.has(field) or not saved[field] is Dictionary:
			return false
	if saved.has("story_time"):
		var saved_story_time: Variant = saved["story_time"]
		if not saved_story_time is String or not _is_valid_story_time(str(saved_story_time)):
			return false
	if saved.has("current_objective") and not saved["current_objective"] is String:
		return false
	return true

func _dictionary_or_empty(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _set_flags_once(next_flags: Dictionary) -> bool:
	var changed := false
	for key in next_flags:
		if not flags.has(key) or flags[key] != next_flags[key]:
			flags[key] = next_flags[key]
			changed = true
	if changed:
		_persist_if_enabled()
	return changed

func _is_valid_story_time(clock_text: String) -> bool:
	if clock_text.length() != 5 or clock_text[2] != ":":
		return false
	var hours_text := clock_text.substr(0, 2)
	var minutes_text := clock_text.substr(3, 2)
	if not hours_text.is_valid_int() or not minutes_text.is_valid_int():
		return false
	var hours := int(hours_text)
	var minutes := int(minutes_text)
	return hours >= 0 and hours <= 23 and minutes >= 0 and minutes <= 59

func _persist_if_enabled() -> void:
	if persistence_enabled:
		save_game()
