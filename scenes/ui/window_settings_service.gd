class_name ChampionWindowSettings
extends Node
## Autoload：启动时从 `user://` 恢复窗口模式 / 分辨率 / 垂直同步；设置页调用 `save_settings` 写入。
## 在工程 `项目 → Autoload` 中应命名为 `WindowSettings`。


const CFG_PATH := "user://champion_tale_settings.cfg"
const SECTION := "display"


func _ready() -> void:
	load_from_disk_and_apply()


func load_from_disk_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	var mode := int(cfg.get_value(SECTION, "window_mode", DisplayServer.WINDOW_MODE_WINDOWED))
	var w := int(cfg.get_value(SECTION, "width", 1280))
	var h := int(cfg.get_value(SECTION, "height", 720))
	var vs := int(cfg.get_value(SECTION, "vsync", int(DisplayServer.VSYNC_ENABLED)))
	_apply_mode_size_vsync(mode, Vector2i(w, h), vs)


func save_settings(window_mode: int, pixel_size: Vector2i, vsync_mode: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value(SECTION, "window_mode", window_mode)
	cfg.set_value(SECTION, "width", pixel_size.x)
	cfg.set_value(SECTION, "height", pixel_size.y)
	cfg.set_value(SECTION, "vsync", vsync_mode)
	cfg.save(CFG_PATH)


func _apply_mode_size_vsync(window_mode: int, pixel_size: Vector2i, vsync_mode: int) -> void:
	DisplayServer.window_set_vsync_mode(vsync_mode as DisplayServer.VSyncMode)
	if window_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var tree := get_tree()
		if tree != null:
			var win := tree.root.get_window()
			if win != null:
				win.min_size = Vector2i(640, 360)
				win.size = pixel_size
				win.move_to_center()
	else:
		DisplayServer.window_set_mode(window_mode)
