# test1 - 2D 动作冒险游戏

基于 Godot 4.6 开发的类塞尔达风格 2D 俯视角动作冒险游戏。

---

## 项目概要

- **引擎**：Godot 4.6（Forward Plus 渲染）
- **语言**：GDScript
- **分辨率**：1920×1080
- **视角**：2D 俯视角
- **物理**：CharacterBody2D

---

## 目录结构

```
test-1/
├── project.godot              # 项目配置文件
├── icon.svg                   # 项目图标
├── implementation-plan.md     # 实施计划
├── player11/                  # 玩家相关
│   ├── player.tscn            #   玩家场景
│   ├── player.gd              #   玩家移动与动画脚本
│   └── player-config-guide.md #   玩家参数配置指南（中文）
├── scene11/                   # 场景
│   └── scene0.tscn            #   主场景
└── tool/                      # 资源文件
    ├── ueisukun_sprite.png    #   玩家精灵图（8×8 精灵表）
    ├── field_128_128.png      #   野外地图瓦片
    ├── Dungeon_128_128.png    #   地下城地图瓦片
    ├── sky.png                #   天空背景
    └── slime_HD_128.png       #   怪物精灵图
```

---

## 快速开始

1. 用 Godot 4.6 打开项目
2. 给玩家添加碰撞体（见下方注意事项）
3. 按 `F5` 运行游戏
4. 使用 `WASD` 操控角色移动

---

## 操作按键

| 按键 | 动作 |
|------|------|
| W | 向上移动 |
| S | 向下移动 |
| A | 向左移动 |
| D | 向右移动 |

按键映射位置：项目设置 → 输入映射（`project.godot` 的 `[input]` 段）

---

## 注意事项

### 新玩家首次配置

玩家节点缺少 `CollisionShape2D`（碰撞体）。首次运行前请按以下步骤添加：

1. 打开 `player11/player.tscn`
2. 右键 `player` 节点 → 添加子节点 → `CollisionShape2D`
3. Shape 选择 `CircleShape2D`，Radius 设为 `32`

不添加碰撞体角色也能移动，但无法与其他物体发生碰撞。

### 精灵图方向调整

默认假设精灵表中 0-3 行依次为下/左/右/上方向的动画。如果你的精灵图布局不同：

1. 选中 `player` 节点
2. 在右侧属性面板找到"脚本变量"
3. 调整 `row_down`、`row_left`、`row_right`、`row_up` 的参数值
4. 也可以在运行中实时调整，立即看到效果

详细说明见 `player11/player-config-guide.md`。

### 帧动画参数

走路动画的帧范围和播放速度也是可调的：

- `walk_frame_start` / `walk_frame_end`：控制动画循环用第几列到第几列
- `idle_frame`：站着不动时用第几列
- `animation_frame_duration`：每帧持续秒数，越小越快

### 参数实时调试

Godot 支持运行中调参：按 F5 运行 → 切回编辑器 → 选中 player 节点 → 修改属性 → 游戏中立即生效。无需反复启停游戏。

### 文件编码

项目中的 `.gd` 脚本文件和 `.md` 文档均使用 UTF-8 编码，中文注释可正常显示。

---

## 项目约定

- **沟通语言**：与 AI 助手交流统一使用中文
- **文件命名**：所有文件名与目录路径使用英文，避免编码兼容问题

---

## 后续开发方向

- [ ] 墙壁碰撞与地图边界
- [ ] 敌人 AI 与战斗系统
- [ ] 道具收集与背包系统
- [ ] NPC 交互与对话系统
- [ ] 场景切换（房间/野外/地下城）
- [ ] 冲刺、翻滚等进阶操作
- [ ] 音效与背景音乐
- [ ] UI 界面（血条、道具栏）

---

## 开发环境

- **引擎版本**：Godot 4.6
- **物理引擎**：Jolt Physics（3D 物理后端）
- **渲染驱动**：Direct3D 12（Windows）
- **平台**：Windows 11

---

## 参考资料

- [Godot 官方文档](https://docs.godotengine.org/)
- [GDScript 语法参考](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/)
- [CharacterBody2D 文档](https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html)
