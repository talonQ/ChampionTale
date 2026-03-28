# 战斗行动描边：实现复盘

本文记录战斗原型中「当前行动单位描边」功能的迭代过程：**尝试过但未达预期的方案**、**失败原因**，以及**当前与 MonsterTale 对齐的可行方案**。

---

## 需求简述

- 轮到某只宝可梦行动时要有**明显高亮**。
- 早期需求：去掉「缩放」式反馈，改为**描边**；建议考虑后处理。
- 最终可见效果：**第二台相机 + SubViewport + 全屏合成**，己方绿 / 敌方红（颜色在逻辑里切换）。

---

## 方案一：缩放 `Visual`（最初实现）

**做法**

- 在 `battle_creature_slot.gd` 的 `set_highlight` 里，把 `Visual` 的 `scale` 在 1.0 与约 1.08 之间切换。

**为何被弃用**

- 产品反馈：不需要这种「胀一下」的反馈，希望改为描边类效果。

**结论**

- 与描边需求无关，仅作为历史起点记录。

---

## 方案二：`BaseMaterial3D.grow` + `next_pass`（按网格描边）

**做法**

- 为每个表面的材质 `duplicate()` 一份，在 `next_pass` 上挂纯色、`grow_enabled`、前向剔除等，用引擎内置的「挤出轮廓」画第二层几何。

**相对全屏深度后处理的优势**

- 只勾角色网格，不会把地板、场景深度断裂误当成边。

**为何未作为最终方案**

- 用户更希望**后处理管线**（多 Pass / 独立相机），与参考工程一致。
- GLB 若带 **ShaderMaterial** 等非 `BaseMaterial3D` 表面，该路径要额外分支，维护成本高。

**结论**

- 技术上可行，但与「Outline Camera + 后处理」的目标不一致，故未保留。

---

## 方案三：SubViewport + 白色剪影副本 + 自定义全屏着色器（采样 `.r`）

**做法概要**

1. **渲染层分工**  
   - 主相机 `cull_mask` 仅第 1 层。  
   - 描边专用相机只照第 2 层。  
2. **剪影**  
   - 为每个 `MeshInstance3D` 再挂一份子节点（或兄弟节点），白模 / 无光照材质，**仅第 2 层**，与骨骼同步。  
3. **合成**  
   - `ColorRect` + `ShaderMaterial`，`uniform sampler2D silhouette_tex` 采样 SubViewport，用 **亮度/红色通道** 做邻域差分得到边。  
4. **额外尝试的修复**  
   - `ViewportTexture.viewport_path` 绑定场景路径；激活描边时**立刻**同步 Outline 相机（避免晚于 `_process` 导致首帧空 RT）；剪影改为 `mi` 子节点 + `Transform3D.IDENTITY 等。

**为何仍经常「完全看不见」**

1. **与 MonsterTale 的管线不一致**  
   - 参考实现用的是 **`TextureRect.texture = SubViewport.get_texture()`**，片元里用内置 **`TEXTURE` + `TEXTURE_PIXEL_SIZE`**，并按 **alpha** 做 `max_neighbor - center`。  
   - 本方案用 **自定义 uniform** 绑 RT + **`.r` 勾边**，在部分驱动/色调映射/透明清屏组合下，RT 内容或与 UV 映射更容易出现「整屏近似常数 → 差分为 0」。
2. **双份网格**  
   - 剪影与骨骼、`skeleton` 的 `NodePath` 解析、父子关系任一出错，第 2 层就可能不画或画错。  
3. **调试成本高**  
   - 问题分散在层掩码、剪影材质、RT、着色器采样四块，不如「单层网格开关第 2 层 + 标准 TextureRect 流程」直观。

**结论**

- 属于「自研后处理」变体，理论上可继续修，但与已验证的参考工程偏差大，**整体弃用**，改对齐 MonsterTale。

---

## 方案四（当前）：对齐 MonsterTale — 同网格开关第 2 层 + TextureRect + alpha 描边

**做法概要**（与 `D:\Godot\Projects\MonsterTale` 中 `outline_hover_demo` / `outline_postprocess.gdshader` 一致）

1. **场景内建**  
   - `OutlineMaskViewport`（`transparent_bg`）  
   - 子节点 `OutlineCamera`：`cull_mask = 2`（只渲染第 2 渲染层）  
   - `CanvasLayer` + `TextureRect`：  
     - `texture = OutlineMaskViewport.get_texture()`  
     - `material` 使用 `outline_postprocess.gdshader`（`TEXTURE` alpha 邻域差分）  
2. **主相机**  
   - `cull_mask` 仅第 1 层（如 `0x1`），地板等只在第 1 层。  
3. **单位网格**  
   - 常态：`layers` 保证含第 1 层，**关闭**第 2 层。  
   - 当前行动者：`set_layer_mask_value(2, true)`，**同一网格**既进主视图，又进描边 RT。  
4. **脚本**（`CombatOutlinePost`）  
   - 每帧（或激活时）同步 Outline 相机与 `BattleCamera`；按敌我设置 `outline_color`；无描边时 `SubViewport.UPDATE_DISABLED` 省性能。

**与方案三的核心区别（对照表）**

| 维度 | 方案三（剪影 + 自定义 RT uniform） | 方案四（当前，MonsterTale） |
|------|-------------------------------------|-----------------------------|
| 第 2 层内容 | 额外白模网格 | **原网格**，仅开关层掩码 |
| 合成控件 | `ColorRect` + 自定义 `silhouette_tex` | **`TextureRect` + `texture` 直连 Viewport** |
| 着色器 | 采样 uniform，多依赖 `.r` | 内置 **`TEXTURE` / `TEXTURE_PIXEL_SIZE`，alpha 勾边** |
| 场景结构 | 运行时动态创建较多节点 | **编辑器内摆好** SubViewport / 相机 / Canvas |
| 与参考工程 | 不一致 | **一致**，便于对照与排错 |

**结论**

- 这是当前仓库采用的方案，也是用户反馈「能看见描边」的版本。

---

## 经验小结

1. **先对齐已跑通的参考管线**（节点类型、纹理绑定方式、着色器输入），再谈扩展，比在同一框架里换多种采样与几何技巧更高效。  
2. **Viewport → UI**：Godot 4 下用 **`TextureRect.texture = get_texture()`** + 材质里用 **`TEXTURE`**，比手写 `ViewportTexture` + 自定义 uniform 更贴近引擎惯例。  
3. **描边掩码**：在「专用层 + 专用相机」模型里，**同一 `MeshInstance3D` 打开第 2 层**比维护剪影副本更简单、更不易与骨骼路径打架。  
4. **时序**：描边相机须在**启用描边的同一逻辑帧**内与主相机对齐，否则首帧 RT 可能为空（该问题在方案三中已单独修过，方案四仍保留「`set_active` 时立刻同步」的习惯）。

---

## 相关文件（当前工程）

| 路径 | 作用 |
|------|------|
| `battle/shaders/outline_postprocess.gdshader` | 全屏描边片元（alpha 差分） |
| `scenes/combat/scripts/combat_outline_post.gd` | 同步相机、开关 SubViewport 更新、设置颜色 |
| `scenes/combat/scripts/battle_creature_slot.gd` | `set_turn_highlight` → `set_layer_mask_value(2, …)`，加载后强制主层为 1 |
| `scenes/combat/combat_prototype_demo.tscn` | `OutlineMaskViewport` / `OutlineCamera` / `OutlinePostCanvas` / `OutlineOverlay` |

---

## 参考项目

- `D:\Godot\Projects\MonsterTale`  
  - `scripts/demo/outline_hover_demo.gd`  
  - `shaders/outline_postprocess.gdshader`  
  - `scenes/outline_hover_demo.tscn`  

（战斗场景里是「行动高亮」而非鼠标悬停，但**渲染管线与着色器**与上述 Demo 一致。）
