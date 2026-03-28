---
name: champion-tale
description: >-
  Guides Godot development for ChampionTale, a solo-developed roguelike
  Pokémon-style tower-climbing game. Enforces concise maintainable extensible
  code and minimal blast radius when changing features. Use when writing or
  refactoring ChampionTale code, Godot scripts, game systems, or when the user
  mentions ChampionTale, 肉鸽, 宝可梦, or this project.
---

# ChampionTale 项目约定

## 项目背景

- **开发者**：独立游戏开发者，单人开发。
- **游戏**：**ChampionTale** — 肉鸽类、宝可梦风格、爬塔玩法。

## 代码原则

1. **简洁**：优先清晰、直接的实现；避免不必要的抽象层与重复逻辑。
2. **可维护**：命名与结构一眼能懂；模块边界清楚；复杂处用简短注释说明「为什么」而非复述代码。
3. **易扩展**：新功能优先通过新增小模块、信号/资源/接口接入，而不是到处改旧代码。

## 修改已有功能时

- **缩小影响范围**：能局部改就不扩散；能加钩子/扩展点就不重写整条链路。
- 改动前想清楚：哪些场景会受影响；能否用可选参数、子类、组合代替大面积替换。

## Godot 实践提示

- 用场景与脚本分层：数据（Resource）、逻辑（单职责脚本）、表现（节点树）分离，便于单独替换与测试。
- 全局单例仅放真正跨场景共享的状态；其余用依赖注入或分组查找，降低耦合。
