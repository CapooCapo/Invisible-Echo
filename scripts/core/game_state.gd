extends Node

## Persistent chapter state shared across scene changes.
const SAVE_PATH := "user://an_tieng_gay_trong_dem_save.json"
const SAVE_VERSION := 1

var chapter := "night_1"
var scene_id := "scene_01"
var checkpoint_id := "scene_01_start"
var inventory: Array[String] = []
var evidence: Dictionary = {}
var flags: Dictionary = {}
var choices: Dictionary = {}
var ending := "none"
var persistence_enabled := true

func _ready() -> void:
	load_game()

func add_item_once(item_id: String) -> bool:
	if item_id.is_empty() or inventory.has(item_id):
		return false
	inventory.append(item_id)
	_persist_if_enabled()
	return true

func set_flag(flag_id: String, value: Variant = true) -> void:
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
		"inventory": inventory.duplicate(),
		"evidence": evidence.duplicate(true),
		"flags": flags.duplicate(true),
		"choices": choices.duplicate(true),
		"ending": ending,
	}

func save_game(path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write save file: " + error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(to_dictionary(), "\t"))
	return true

func load_game(path: String = SAVE_PATH) -> bool:
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
	chapter = str(saved.get("chapter", "night_1"))
	scene_id = str(saved.get("scene_id", "scene_01"))
	checkpoint_id = str(saved.get("checkpoint_id", "scene_01_start"))
	ending = str(saved.get("ending", "none"))
	inventory.clear()
	var saved_inventory: Variant = saved.get("inventory", [])
	if saved_inventory is Array:
		for item in saved_inventory:
			if item is String and not inventory.has(item):
				inventory.append(item)
	evidence = _dictionary_or_empty(saved.get("evidence", {}))
	flags = _dictionary_or_empty(saved.get("flags", {}))
	choices = _dictionary_or_empty(saved.get("choices", {}))
	return true

func _dictionary_or_empty(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _persist_if_enabled() -> void:
	if persistence_enabled:
		save_game()
