# 导出构建与图鉴 / 战斗加载 — 问题记录与处理说明

本文记录一次「导出 `.exe` 后图鉴空白、无法进入战斗」及「编辑器内预加载失败」的排查结论与工程侧修复，便于日后遇到类似现象时对照。

---

## 1. 现象

### 1.1 导出游戏（Windows `.exe`）

- 进入**图鉴**后：左侧头像列表为空，右侧 2～5 区无数据；界面框架（标题、返回、面板边框）仍在。
- 主菜单**开始游戏**无法正常进入战斗（表现为无响应或流程异常）。

### 1.2 Godot 编辑器内运行

- 报错示例：**Parser Error: Could not preload resource file `res://battle/definitions/demo_encounter.tres`.**

---

## 2. 原因分析

### 2.1 图鉴单位列表依赖 `DirAccess` 扫描目录（导出环境不可靠）

图鉴原先通过 `DirAccess.open("res://battle/definitions/units/")` 枚举目录下的 `.tres` 来收集 `BattleUnitDefinition`。

在**已打包的 PCK** 中，对 `res://` 子目录做**目录枚举**的行为与编辑器中**不一致**：常见结果是**列不出任何文件**，导致单位数组为空，进而没有头像按钮与后续 UI 填充。

> 说明：即便导出预设为「包含全部资源」，资源仍可能已在包内；**失败点在于「枚举目录」这一 API 在导出形态下不可靠**，而非单纯「文件没打进包」。

### 2.2 主菜单场景切换未 `await` 异步过渡

主菜单通过 `SceneTransition.fade_to_scene(...)` 做淡入淡出切换。该函数内部使用 `await`（协程）。

若仅从按钮回调中**调用** `fade_to_scene` 而**不** `await`，在部分运行环境（尤其导出构建）下，协程衔接与遮罩状态可能出现边缘问题（例如过渡未完整执行、输入被遮罩长时间拦截等）。工程上更稳妥的做法是：**在信号回调里对 `fade_to_scene` 使用 `await`**，并保留无 Autoload 时的 `change_scene_to_file` 分支及错误码日志。

### 2.3 `demo_encounter.tres` 引用已删除资源（预加载链断裂）

`battle/combat_demo_roster.gd` 中存在：

```gdscript
const DEFAULT_ENCOUNTER := preload("res://battle/definitions/demo_encounter.tres")
```

而 `demo_encounter.tres` 的 `roster` 引用了 **`res://battle/definitions/units/volibear_ally.tres`**。该文件若已从磁盘移除，则 **整个 `demo_encounter.tres` 无法在解析阶段完成加载**，表现为：

- 编辑器：**Parser Error: Could not preload resource … demo_encounter.tres**（根因是其依赖的子资源缺失）。
- 任何依赖该预加载的脚本 / 场景在加载时都可能失败，与「开始游戏」异常现象一致。

---

## 3. 已采取的修复措施（工程现状）

### 3.1 图鉴：显式 `preload` 单位列表 + 保留目录扫描作补充

- 在 `scenes/ui/pokedex_screen.gd` 中维护 **`_UNIT_DEFINITION_PRELOADS`**：对已知单位 `.tres` 使用 **`preload`**，保证：
  - 编辑器与导出包均能稳定拿到单位数据；
  - 导出器将单位资源纳入**静态依赖**，避免仅依赖运行时目录枚举。
- 仍保留对 `res://battle/definitions/units/` 的 `DirAccess` 扫描：用于在开发时自动纳入**尚未写入 preload 数组**的新 `.tres`（需注意**新增单位后应同步更新 preload 列表**，以免导出环境仍漏列）。

### 3.2 主菜单：`await` 场景过渡并记录加载失败

- `scenes/ui/main_menu.gd` 中，对「开始游戏 / 图鉴 / 设置」在存在 `SceneTransition` 时改为 **`await _scene_transition.fade_to_scene(...)`**。
- 无过渡时分支对 `change_scene_to_file` 检查返回值，**`push_error` 输出路径与 `error_string(err)`**，便于带控制台的导出版本排查。

### 3.3 恢复缺失的 `volibear_ally.tres`

- 重新提供 **`battle/definitions/units/volibear_ally.tres`**，与 `demo_encounter.tres` 中的引用一致；内容与敌方沃利贝尔共用同一视觉与技能配置思路，**`is_player_side = true`** 以符合遭遇中友方槽位需求。
- 将该资源同时加入图鉴的 **`_UNIT_DEFINITION_PRELOADS`**，与导出图鉴策略一致。

---

## 4. 维护备忘

| 事项 | 建议 |
|------|------|
| 新增可参战单位 `.tres` | 除放入 `battle/definitions/units/` 外，将路径加入 `pokedex_screen.gd` 的 `_UNIT_DEFINITION_PRELOADS`。 |
| 删除或重命名单位资源 | 全局搜索 `.tres` 引用（遭遇、随机池、图鉴 preload），避免残留路径导致预加载失败。 |
| 导出后图鉴仍异常 | 优先确认 preload 列表是否包含该单位；再用带控制台的导出查看是否有资源加载错误。 |
| 遭遇 / 默认战斗无法加载 | 检查 `demo_encounter.tres` 及 `CombatDemoRoster` 的 `preload` 链上每一层 `ext_resource` 是否仍存在。 |

---

## 5. 修订记录

| 日期 | 说明 |
|------|------|
| 2026-03-30 | 初稿：导出图鉴空、主菜单切换、`demo_encounter` 预加载失败的原因与修复汇总。 |
