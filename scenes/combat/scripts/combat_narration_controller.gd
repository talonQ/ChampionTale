class_name CombatNarrationController
extends RefCounted
## 战斗台词：逐字、链式、阅读停顿。只操作传入的 RichTextLabel，与回合规则无关。


var chars_per_second: float = 18.0
var read_pause_after_line_sec: float = 1.5

var _label: RichTextLabel
var _narration_busy: bool = false
var _typing_active: bool = false
var _tw_total: int = 0
var _tw_chars_shown: int = 0
var _tw_carry: float = 0.0
var _tw_read_pause_remaining: float = 0.0
var _typing_on_done: Callable = Callable()
var _chain_lines: PackedStringArray = PackedStringArray()
var _chain_index: int = 0
var _chain_final: Callable = Callable()


func _init(label: RichTextLabel) -> void:
	_label = label


func is_narration_busy() -> bool:
	return _narration_busy


func process_frame(delta: float) -> void:
	if _typing_active:
		_tw_carry += delta * chars_per_second
		while _tw_carry >= 1.0 and _tw_chars_shown < _tw_total:
			_tw_carry -= 1.0
			_tw_chars_shown += 1
			_label.visible_characters = _tw_chars_shown
		if _tw_chars_shown >= _tw_total:
			_on_typewriter_chars_complete()
	if _tw_read_pause_remaining > 0.0:
		_tw_read_pause_remaining -= delta
		if _tw_read_pause_remaining <= 0.0:
			_tw_read_pause_remaining = 0.0
			_emit_typewriter_done()


func start_chain(lines: PackedStringArray, final_cb: Callable) -> void:
	var filtered := PackedStringArray()
	for s in lines:
		var t := s.strip_edges()
		if not t.is_empty():
			filtered.append(t)
	if filtered.is_empty():
		if final_cb.is_valid():
			final_cb.call()
		return
	_chain_lines = filtered
	_chain_index = 0
	_chain_final = final_cb
	_narrate_next_in_chain()


func _on_typewriter_chars_complete() -> void:
	_label.visible_characters = -1
	_typing_active = false
	if read_pause_after_line_sec > 0.0:
		_tw_read_pause_remaining = read_pause_after_line_sec
	else:
		_emit_typewriter_done()


func _emit_typewriter_done() -> void:
	_narration_busy = false
	var od := _typing_on_done
	_typing_on_done = Callable()
	if od.is_valid():
		od.call()


func _start_typewriter(plain_line: String, on_done: Callable) -> void:
	_narration_busy = true
	_typing_active = true
	_typing_on_done = on_done
	_tw_carry = 0.0
	_tw_read_pause_remaining = 0.0
	_label.clear()
	_label.append_text(plain_line)
	_tw_total = _label.get_total_character_count()
	if _tw_total <= 0:
		_typing_active = false
		_narration_busy = false
		if on_done.is_valid():
			on_done.call()
		return
	_tw_chars_shown = 0
	_label.visible_characters = 0


func _narrate_next_in_chain() -> void:
	if _chain_index >= _chain_lines.size():
		var fin := _chain_final
		_chain_final = Callable()
		if fin.is_valid():
			fin.call()
		return
	var line: String = _chain_lines[_chain_index]
	_chain_index += 1
	_start_typewriter(line, _narrate_next_in_chain)
