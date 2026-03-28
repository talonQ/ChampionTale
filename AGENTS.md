# ChampionTale — AI / 协作者指南（AGENTS）

本文档总结战斗原型阶段形成的**项目规范与开发原则**，后续功能应优先对齐这些约定。

---

## 1. 架构：战斗逻辑与表现层分离

- **规则层**（`battle/` 等）：只操作数据类型（如 `BattleUnitRuntime`、`SkillData`）与纯函数/小型状态机；**不**引用具体 `Node`、**不**直接改 UI、**不**假设场景结构。
- **表现层**（`scenes/...`、子控制器）：负责 3D、2D UI、动画、音效、台词；通过 **Callable / 信号 / 显式回调** 响应「数值变更」「施法者已扣费」等事件，**不**自行决定回合顺序或偷偷结算伤害。
- **场景根脚本**只做编排：初始化模块、连接信号、转发输入；单文件不宜过长（目标约数百行内，复杂逻辑下沉到子模块）。

---

## 2. 「组件」形态（Godot）

- 无场景树依赖、不需要 `_ready` 挂节点的逻辑（如打字机、头顶条跟随、射线拾取），可用 **`RefCounted` 控制器**，由场景根在 `_process` 中调用 `process_frame` 等。
- 必须在编辑器中摆放、或强依赖子节点路径的，用 **`Node` / 子场景**。
- 可跨场景复用的 UI / 动画小件放在 **`components/`**（如 `SmoothDualStatBars`、`CreatureAnimationDriver`）。

---

## 3. 目录与命名（当前约定）

| 区域 | 用途 |
|------|------|
| `battle/` | 与具体战斗场景无关的规则、运行时单位、技能数据类型、回合状态等 |
| `scenes/combat/` | 本战斗场景专用的 **`.tscn` 场景文件**（与子场景入口） |
| `scenes/combat/scripts/` | 上述场景绑定的 **`.gd` 脚本**（含 `RefCounted` 子控制器）；**不要**与 `.tscn` 混放在 `scenes/combat/` 根目录 |
| `components/` | 与战斗流程解耦的可复用脚本/工具 |
| `docs/` | 玩法与系统设计文档（非代码规范） |

**战斗场景目录约定**：`scenes/combat/` 只放场景资源；同模块脚本统一放在 `scenes/combat/scripts/`。新增战斗子场景时沿用同一模式（例如 `foo.tscn` + `scripts/foo.gd`），`preload` / 场景 `ext_resource` 使用 `res://scenes/combat/...` 与 `res://scenes/combat/scripts/...` 区分路径即可。

---

## 4. Godot / UI 易错点（已验证）

- **底对齐 `VBox` + `visible = false`**：子控件会不占位，下方面板整体上移。需要隐藏交互但保留占位时，用 **`modulate.a` + `mouse_filter = IGNORE`**（或固定 `custom_minimum_size`），避免直接关 `visible`。
- **战斗台词 `RichTextLabel`**：逐字显示时建议 **`bbcode_enabled = false`**，避免可见字符数与 BBCode 不一致。固定消息区高度时关闭 **`fit_content`**，用固定高度 + 内部滚动，避免长文撑布局。
- **Tween（Godot 4）**：**`set_trans` / `set_ease` 链在 `tween_property` 的返回值上**，不要写在根 `Tween` 上。
- **3D 动画**：Idle 建议在驱动里**强制 `Animation.LOOP_LINEAR`**；攻击片段若为循环，`animation_finished` 可能永不触发，需在资源侧做成单次或另做超时回 Idle。

---

## 5. 参数与数据

- 手感相关数值（打字速度、播完停顿、条 tween 时长等）用 **`@export_group` + `@export_range`**，便于在检查器迭代，避免魔法数散落在脚本深处。
- 参战列表与单位数值使用 **`CombatEncounterDefinition` + `BattleUnitDefinition`（`.tres`）**，放在 `battle/definitions/`；`CombatDemoRoster.create_units(encounter)` 转为运行时单位。技能为独立 **`SkillData` .tres**，由单位资源引用复用。

---

## 6. 代码与工具链

- 优先使用全局 **`class_name`** 保持语义清晰；若静态分析/IDE 对 `class_name` 解析不稳定，可对关键脚本 **`preload` 常量** 再调用静态方法。
- 保持 **单文件职责单一**；新增系统时优先拆文件而非在场景根堆逻辑。

---

## 7. 战报文案（演进方向）

- 当前允许结算与中文战报写在同一模块（如 `CombatActionExecutor`）作为原型折中。
- 若引入多语言或剧情工具，应再抽 **事件 / ID → 文案** 层，避免规则模块堆积自然语言字符串。

---

## 8. 与现有用户规则的关系

- 实现时仍以仓库内 **用户规则、技能文档、设计文档** 为准；本文件侧重 **工程结构与 Godot 实践**，与之冲突时以用户明确指令为准。

---

*工程目标：Godot 4.x（见 `project.godot` 中 `config/features`）。文档随架构演进可修订。*
