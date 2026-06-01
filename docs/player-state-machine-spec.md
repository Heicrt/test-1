# 玩家状态机解耦 — 技术栈设计文档

> 项目：test1（类2D塞尔达动作冒险游戏）
> Godot 版本：4.6.stable
> 日期：2026-06-01
> 状态：已审批，待实现

---

## 1. 架构总览

### 1.1 设计目标

将玩家控制器从单一 309 行单体脚本重构为基于子节点的分层状态机架构，同时修复向右移动动画不匹配的问题。

### 1.2 架构模式

采用 **子节点状态机模式（Child Node State Machine）**：每个状态作为独立的 `Node` 子节点挂载在 `StateMachine` 管理节点下，各状态拥有独立的 `.gd` 脚本文件。

```
player (CharacterBody2D)          ← player.gd — 状态调度 + 共享数据持有
├── StateMachine (Node)           ← state_machine.gd — 状态切换 + 输入路由
│   ├── StateIdle (Node)          ← idle_state.gd
│   ├── StateWalk (Node)          ← walk_state.gd
│   └── StateAttack (Node)        ← attack_state.gd
├── Sprite2D                      ← [不动]
├── CollisionShape2D              ← [不动]
└── AnimationPlayer               ← [不动]
```

### 1.3 设计原则

- **单一职责**：每个状态脚本只负责该状态内的逻辑，不跨责任边界
- **开闭原则**：新增状态只需添加新的子节点和脚本，无需修改现有代码
- **依赖倒置**：所有状态依赖 `BaseState` 抽象，不依赖具体实现
- **显式优于隐式**：状态转移路径在代码中明确可见，不隐藏于配置或信号链

---

## 2. 组件详细设计

### 2.1 BaseState（抽象基类）

**文件**：`res://player11/states/base_state.gd`

**职责**：定义所有状态的统一接口契约。

```gdscript
class_name BaseState
extends Node

## 进入状态。由 StateMachine 在切换到此状态时调用。
## 参数 host: player 节点引用，提供对 sprite/animation_player/velocity 等共享资源的访问
func enter(host: CharacterBody2D) -> void:
    pass

## 退出状态。由 StateMachine 在离开此状态时调用。
## 子类必须在此重置本状态产生的副作用（如 flip_h、计时器）
func exit(host: CharacterBody2D) -> void:
    pass

## 每物理帧调用
func physics_update(host: CharacterBody2D, delta: float) -> void:
    pass

## 处理输入事件。返回要转移到的目标状态名（如 "Walk"），空字符串表示不转移。
## 注意：此方法不应产生副作用——只做判断，不修改状态
func handle_input(host: CharacterBody2D, event: String) -> String:
    return ""
```

**接口契约（必须遵守）**：
- `enter()` 必须初始化本状态所需的所有变量
- `exit()` 必须清理本状态产生的所有副作用
- `physics_update()` 调用时，host 的 `velocity` 已由上一帧的 `move_and_slide()` 更新
- `handle_input()` 不得修改 host 的任何属性，只做路由判断

### 2.2 StateMachine（状态管理器）

**文件**：`res://player11/states/state_machine.gd`

**职责**：
- 持有当前活跃状态引用
- 提供 `switch_state(name: String)` 方法，原子性地切换状态
- 将 `_physics_process` 和 `_unhandled_input` 代理给当前活跃状态

**关键实现细节**：
- 使用 `_transition_lock: bool` 防止状态在 `exit()`/`enter()` 期间被再次切换
- `switch_state()` 流程：`old_state.exit()` → 禁用旧节点 → 启用新节点 → `new_state.enter()`
- 每个子节点默认 `process_mode = PROCESS_MODE_DISABLED`，由 StateMachine 控制在 `enter/exit` 时启用/禁用

### 2.3 StateIdle（待机状态）

**文件**：`res://player11/states/idle_state.gd`

**行为规范**：

| 项目 | 说明 |
|------|------|
| 进入 | 设置 sprite.frame 为当前朝向的静止帧（基于 `last_direction`），重置 animation_timer |
| 持续 | 不做任何帧更新，保持静止画面 |
| 输入响应 | 检测移动键 → 转移 "Walk"；检测攻击键 → 转移 "Attack" |
| 退出 | 不需要清理（无副作用） |

**朝向 → 帧计算规则**：
- 上下方向使用各自的 row（`row_down`、`row_up`），显示 `idle_frame` 列
- 左右方向共用 `row_left` 行 + `sprite.flip_h` 区分左右
- 主方向判定沿用 `abs(x) > abs(y)` 规则

### 2.4 StateWalk（走路状态）

**文件**：`res://player11/states/walk_state.gd`

**行为规范**：

| 项目 | 说明 |
|------|------|
| 进入 | 从 host 读取 `last_direction` 确定初始动画行 |
| 持续 | 读取输入 → 计算加速度/摩擦力 → 更新 velocity → 更新动画帧 |
| 动画更新 | 累计 `animation_timer`，满 `animation_frame_duration` 后切换到下一帧 |
| 输入响应 | 松开所有方向键 → 转移 "Idle"；检测攻击键 → 转移 "Attack" |
| 退出 | 更新 host 的 `last_direction`；重置 `animation_timer = 0.0`；重置 `sprite.flip_h = false` |

**向右动画修复（核心变更）**：

```gdscript
# ❌ 旧逻辑（错误）：
# target_row = row_right  (行2，精灵图数据不正确)

# ✅ 新逻辑（修复）：
if abs(last_direction.x) > abs(last_direction.y):
    target_row = row_left                    # 使用左行动画的行数据
    sprite.flip_h = last_direction.x > 0     # 向右时水平翻转
```

**动画帧循环**：

```
walk_frame_start → walk_frame_start+1 → ... → walk_frame_end → 回到 walk_frame_start
```

使用 `wrapf()` 约束帧索引，防止溢出：

```gdscript
current_frame = wrapf(current_frame, walk_frame_start, walk_frame_end + 1)
```

### 2.5 StateAttack（攻击状态）

**文件**：`res://player11/states/attack_state.gd`

**行为规范**：

| 项目 | 说明 |
|------|------|
| 进入 | velocity 归零；根据 `last_direction` 选择动画名；设置 `sprite.flip_h`（若向右）；播放攻击动画；连接 `animation_finished` 信号 |
| 持续 | 仅调用 `move_and_slide()` 保持碰撞检测，不更新速度 |
| 输入响应 | 攻击期间忽略所有输入（不转移到任何状态） |
| 退出 | 清理 `sprite.flip_h`；断开信号；重置 `animation_timer`；设置 `attack_cooldown_timer`；恢复 `player_state = NORMAL`（如果 host 仍需要该字段） |

**攻击动画选择逻辑**：
```
垂直优先 → attakdown / attakup（不翻转）
水平优先 → attakleft（向左不翻转，向右时 sprite.flip_h = true）
```

**冷却机制**：
- `attack_cooldown_timer` 在 `exit()` 中设置为 `attack_cooldown_time`
- 在 `enter()` 中检查冷却计时器，若 > 0 则拒绝进入，直接返回 "Idle"
- 冷却在 Idle 和 Walk 状态中持续递减

---

## 3. 编码规范

### 3.1 文件组织

```
res://player11/
├── player.gd                       # 精简后的主控制器
├── player.tscn                     # 场景文件（增 StateMachine 子树）
└── states/
    ├── base_state.gd               # 抽象基类
    ├── state_machine.gd            # 状态管理器
    ├── idle_state.gd               # 待机状态
    ├── walk_state.gd               # 走路状态
    └── attack_state.gd             # 攻击状态
```

### 3.2 命名规范

| 元素 | 规范 | 示例 |
|------|------|------|
| 类名 | PascalCase | `BaseState`、`StateMachine` |
| 方法名 | snake_case | `enter()`、`physics_update()` |
| 变量名 | snake_case | `attack_cooldown_timer` |
| 常量 | UPPER_SNAKE_CASE | `PlayerState.NORMAL` |
| 导出变量 | snake_case + 中文注释 | `@export var move_speed: float` |
| 私有变量 | 前缀 `_` | `_active_state`、`_transition_lock` |
| 信号 | snake_case（过去式） | `state_changed` |
| 节点名 | PascalCase | `StateMachine`、`StateIdle` |

### 3.3 注释规范

- **文件头**：每个 `.gd` 文件开头包含一行用途说明
- **公开方法**：使用 `## ` 文档注释（Godot 会解析为文档）
- **关键逻辑**：在非显而易见的逻辑上方添加单行注释说明"为什么"而非"是什么"
- **参数含义**：`@export` 变量必须包含中文注释说明用途和推荐范围
- **魔法数字**：所有数字常量必须通过 `@export` 暴露或定义为命名常量

### 3.4 类型标注

- 所有方法参数和返回值必须标注类型
- 所有 `@onready` 变量必须标注类型
- 禁止使用 `Variant` 作为显式类型（特殊情况除外）

---

## 4. 玩家操作体验优化

### 4.1 输入响应优先级

```
攻击键（attak）> 移动键（left/right/up/down）
```

攻击键在 `_unhandled_input` 中处理，不等待 `_physics_process`，确保零帧延迟。

### 4.2 移动手感保持

- 加速度/摩擦力数值不变（`acceleration = 7000`, `friction = 7000`）
- `move_speed` 保持为 `@export` 参数，编辑器可调
- 斜向移动无速度加成（Godot 的 `Input.get_vector` 已归一化）

### 4.3 面向记忆

- 松开所有移动键后，`last_direction` 不被清除
- Idle 状态据此显示对应方向的静止帧
- 攻击方向也基于 `last_direction`

### 4.4 攻击手感

- 攻击期间移动锁定（velocity 归零），防止惯性滑行
- 冷却时间可视化（通过 `attack_cooldown_timer` 可扩展 UI 指示器）
- 冷却期间按键无响应但不吞事件（透传给下层，备用于未来 combo 系统）

---

## 5. 常见 Bug 预判与规避

### 5.1 翻转残留（严重）

**场景**：向右攻击/行走 → 动画中断 → 切换到 Idle → 画面镜像异常

**根因**：`sprite.flip_h` 在状态退出时未被重置

**规避**：
- 每个可能设置 `flip_h` 的状态必须在 `exit()` 中执行 `sprite.flip_h = false`
- `StateMachine.switch_state()` 中 `exit()` 调用必须发生在下一个 `enter()` 之前
- 添加 `assert(sprite.flip_h == false)` 在 Idle 状态的 `enter()` 中（开发期调试用，发布时移除）

### 5.2 动画帧索引溢出（中等）

**场景**：修改精灵表行/列参数后未同步更新 `walk_frame_end`，导致 `current_frame` 超出范围

**根因**：帧索引计算依赖多个松散耦合的参数

**规避**：
- `current_frame` 使用 `wrapf()` 在有效范围内循环
- 帧范围在 `enter()` 时做一次边界校验：`walk_frame_end` 必须 ≥ `walk_frame_start`
- 若精灵表列数变更但 `walk_frame_end` 未更新，`wrapf` 可兜底防止崩溃

### 5.3 状态转移竞态（严重）

**场景**：攻击动画结束回调触发的转移和输入触发的转移同时发生

**根因**：Godot 的信号回调在主线程同步执行，可能在 `_physics_process` 和 `_input` 之间交错

**规避**：
- `switch_state()` 加转移锁，若已在转移中则排队，下一帧处理
- 攻击动画结束不直接调用 `switch_state()`，而是设置 `_pending_transition` 变量，由下一帧的 `physics_update()` 处理
- 所有输入事件也先记录到 pending，统一下帧处理

### 5.4 冷却计时器漂移（低）

**场景**：`attack_cooldown_timer` 在 Attack 状态 `exit()` 中设置，但 Idle 状态才真正开始递减，导致冷却时间不精确

**根因**：计时器设置和递减不在同一状态

**规避**：
- 冷却计时器始终在 `player.gd` 统一管理，各状态只读取和检查
- 在 `player.gd` 的 `_physics_process` 中递减计时器（状态无关）

### 5.5 斜向移动方向抖动（中等）

**场景**：玩家按左上方向时，`last_direction` 的 x 和 y 分量各约 -0.707，两者绝对值相等时 `abs(x) > abs(y)` 判定不稳定

**根因**：浮点比较边界条件

**规避**：
- 沿用现有的 `abs(x) > abs(y)` 判定，Godot 的 `Input.get_vector` 返回精确值
- 当 x 和 y 绝对值差异小于 `0.001` 时，优先选择垂直方向（符合 2D 塞尔达传统）

### 5.6 内存/引用泄漏（低）

**场景**：Attack 状态中 `animation_finished` 信号连接后未正确断开

**规避**：
- 在 `enter()` 中连接信号前先断开旧连接（防止重复连接）
- 在 `exit()` 中断开所有本状态建立的信号连接
- 使用 `signal_name.connect(method, CONNECT_ONE_SHOT)` 对于只需触发一次的回调

---

## 6. 其他注意事项

### 6.1 编辑器兼容性

- 新增的状态子节点在编辑器中默认可见，方便调试（不用 `visible = false`，用 `process_mode = DISABLED`）
- 所有 `@export` 参数保持原有变量名不变，确保已经在编辑器中调整过的值不丢失
- `player.tscn` 中的 `[ext_resource]` 和 `[sub_resource]` 引用路径保持不变

### 6.2 性能考量

- 子节点在非活跃状态时 `process_mode = DISABLED`，Godot 不会调用其 `_process`/`_physics_process`，零 CPU 开销
- 状态切换只涉及节点 `process_mode` 切换和一次方法调用，单帧开销远低于 1ms
- 避免在 `physics_update` 中分配新对象（如 `Vector2` 临时变量可复用）

### 6.3 扩展性预留

- `handle_input` 返回 `String`（状态名），未来可扩展为返回自定义 Action 枚举
- `BaseState` 预留了 `event: String` 参数，未来可按需改为 `Variant` 以传递更复杂的事件数据
- StateMachine 结构支持无限新增子节点，新状态只需继承 `BaseState` 并注册为子节点即可

### 6.4 调试支持

- 每个状态在 `enter()` 和 `exit()` 中输出 `print("[StateMachine] → %s (from: %s)" % [new_state, old_state])`（开发环境开启，发布时用 `OS.is_debug_build()` 开关）
- `player.gd` 保留所有原有 `@export` 参数，编辑器面板体验不变
- 状态转移日志可通过项目设置 `debug/state_machine_logging` 控制开启/关闭

---

## 7. 实施检查清单

在代码合并前，逐项验证：

- [ ] 所有 5 个新文件创建完毕
- [ ] `player.gd` 已精简为状态调度器
- [ ] `player.tscn` 中新增 StateMachine 子树
- [ ] 所有原有 `@export` 参数值在 tscn 中保持不变
- [ ] 向右移动使用 `row_left` + `flip_h`，画面正确
- [ ] Idle 状态下面向正确
- [ ] 攻击后翻转不残留到 Idle/Walk
- [ ] 连续按攻击键不触发多次攻击（冷却正常）
- [ ] 攻击期间按移动键无效（攻击结束才恢复移动）
- [ ] 斜向移动无方向抖动
- [ ] 编辑器重启后状态机正常工作
- [ ] 主场景 `scene0.tscn` 中的 player 实例正常工作

---

*文档版本 1.0 — 待实现*
