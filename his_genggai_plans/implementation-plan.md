# 2D 玩家移动控制 - 实现计划

## 背景

当前项目是一个 Godot 2D 俯视角动作冒险游戏（类塞尔达）。
- 玩家场景 `player11/player.tscn` 已有一个 `CharacterBody2D` 节点和一个空的脚本 `player.gd`
- 输入映射已配好: W=上, S=下, A=左, D=右
- 主场景 `scene11/scene0.tscn` 已实例化了玩家节点在位置 (1384, 854)
- 精灵图 `tool/ueisukun_sprite.png` 是一个 8列x8行 的精灵表
- **缺失**: 玩家场景没有 `CollisionShape2D`，`move_and_slide()` 无法工作

## 需要做的工作

### 1. 编写 `player11/player.gd` 脚本

核心逻辑:
- 使用 `Input.get_vector("left", "right", "up", "down")` 获取玩家输入
- 使用 `velocity.move_toward()` 实现平滑加速/减速（非 `lerp`，避免手感粘滞）
- 使用 `move_and_slide()` 处理移动与碰撞
- 手动控制 Sprite2D 的帧切换实现方向动画（不引入 AnimatedSprite2D，降低复杂度）

所有可调参数用 `@export` 暴露到编辑器面板:

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `move_speed` | 200.0 | 最大移动速度（像素/秒） |
| `acceleration` | 1200.0 | 加速度（像素/秒²） |
| `friction` | 1000.0 | 摩擦力/减速度 |
| `row_down` | 0 | 向下走动画在精灵表的行号 |
| `row_left` | 1 | 向左走动画在精灵表的行号 |
| `row_right` | 2 | 向右走动画在精灵表的行号 |
| `row_up` | 3 | 向上走动画在精灵表的行号 |
| `walk_frame_start` | 0 | 行走动画起始帧（列号） |
| `walk_frame_end` | 2 | 行走动画结束帧（列号） |
| `idle_frame` | 0 | 待机时显示的帧（列号） |
| `animation_frame_duration` | 0.15 | 每帧持续时间（秒） |

### 2. 用户需手动添加 CollisionShape2D

`move_and_slide()` 必须有碰撞体才能工作。用户需要在编辑器中:
- 给 `player` 节点添加子节点 `CollisionShape2D`
- 设置形状为 `CircleShape2D`，半径约 32 像素
- 调整 Sprite2D 的位置使碰撞体位于角色脚部

### 3. 创建中文说明文档 `player11/玩家配置说明.md`

包含: 文件结构说明 → 参数配置指南 → 精灵表布局说明 → 碰撞体配置步骤 → 常见问题排查

### 4. 代码注释

脚本内每段代码都附带详细中文注释，解释每一行在做什么。

## 关键文件

| 文件 | 操作 |
|------|------|
| `D:\Godotdata11\test-1\player11\player.gd` | **重写** - 完整移动脚本 |
| `D:\Godotdata11\test-1\player11\玩家配置说明.md` | **新建** - 中文配置文档 |
| `D:\Godotdata11\test-1\player11\player.tscn` | 告知用户手动添加 CollisionShape2D |
| `D:\Godotdata11\test-1\project.godot` | 无需修改（输入映射已就绪） |

## 技术决策

- **不使用 `lerp()`**：`lerp` 产生渐近运动，角色永远无法达到目标速度。使用 `move_toward()` 以固定速率加减速，手感更清脆。
- **不引入 AnimatedSprite2D**：保持所有配置在脚本的 `@export` 变量中，初学者无需在多个编辑器面板间切换。后续可平滑升级。
- **方向判断逻辑**：比较 `abs(x)` 和 `abs(y)` 的大小，选主导轴作为朝向。松开所有按键后保持最终朝向不变。

## 验证方式

1. 在 Godot 编辑器中打开项目
2. 给 player 节点添加 CollisionShape2D（CircleShape2D，半径32）
3. 运行场景（F5）
4. 按 WASD 键确认角色能四方向移动
5. 确认松开按键后角色平滑停止
6. 确认移动时精灵图有帧动画，停止时显示待机帧
7. 在运行中选中 player 节点，修改 Inspector 中的参数，确认参数即时生效
