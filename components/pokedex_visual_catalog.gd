class_name PokedexVisualCatalog
extends RefCounted
## 图鉴与战斗共用的「视觉 id → 头像 / 3D avatar」表；与 `BattleUnitDefinition.visual_id`（否则 `unit_id`）对齐。


const _PORTRAIT_BY_VISUAL_ID: Dictionary = {
	1: preload("res://assets/pokemon/khazix/portrait.png"),
	2: preload("res://assets/pokemon/malphite/portrait.png"),
	3: preload("res://assets/pokemon/hecarim/portrait.png"),
	4: preload("res://assets/pokemon/fizz/portrait.png"),
	5: preload("res://assets/pokemon/renekton/portrait.png"),
	6: preload("res://assets/pokemon/trundle/portrait.png"),
	7: preload("res://assets/pokemon/volibear/portrait.png"),
	8: preload("res://assets/pokemon/wukong/portrait.png"),
}
const _AVATAR_BY_VISUAL_ID: Dictionary = {
	1: preload("res://assets/pokemon/khazix/avatar.tscn"),
	2: preload("res://assets/pokemon/malphite/avatar.tscn"),
	3: preload("res://assets/pokemon/hecarim/avatar.tscn"),
	4: preload("res://assets/pokemon/fizz/avatar.tscn"),
	5: preload("res://assets/pokemon/renekton/avatar.tscn"),
	6: preload("res://assets/pokemon/trundle/avatar.tscn"),
	7: preload("res://assets/pokemon/volibear/avatar.tscn"),
	8: preload("res://assets/pokemon/wukong/avatar.tscn"),
}


static func visual_lookup_id(def: BattleUnitDefinition) -> int:
	return def.visual_id if def.visual_id > 0 else def.unit_id


static func portrait_texture(visual_id: int) -> Texture2D:
	return _PORTRAIT_BY_VISUAL_ID.get(visual_id, null) as Texture2D


static func avatar_scene(visual_id: int) -> PackedScene:
	return _AVATAR_BY_VISUAL_ID.get(visual_id, null) as PackedScene
