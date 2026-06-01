# 2D 塞尔达风格 — 攻击动画系统实现计划

---

## 一、Context（背景）

### 当前状态
- 项目是 2D 塞尔达传说的动作冒险游戏（Godot 4.6）
- 玩家脚本 `res://player11/player.gd` 已实现 WASD 移动 + 精灵表帧动画
- 代码通过直接设置 `sprite.frame` 控制精灵表显示（8列 × 8行）
- AnimationPlayer 中已创建 3 个攻击动画：`attakdown`、`attakleft`、`attakup`
- 攻击按键 `attak` 映射到 J 键
- 向右攻击：复用 `attakleft` + `sprite.flip_h = true`

### 核心问题
- 代码手动控制 `sprite.frame` 和 AnimationPlayer 同时操作同一属性，会产生帧控制冲突
- 需要引入状态机来切换控制权

### 设计决策（已与用户确认）
1. **3 方向攻击**：下/左/上，向右 = AttackLeft + 水平翻转
2. **攻击时锁定移动**：经典塞尔达手感
3. **有冷却时间**：防止无限制连击
4. **所有参数 @export**：可在编辑器属性面板直接修改
5. **保留一切现有参数**

---

## 二、技术架构

### 2.1 状态机

```
                按攻击键
  ┌─────────┐  ───────→  ┌────────────┐
  │ NORMAL  │            │ ATTACKING  │
  │ 移动/待机│  ←───────  │ 锁定移动    │
  └─────────┘  动画结束   └────────────┘
                  +冷却
```

- **NORMAL**：`_update_animation()` 控制 `sprite.frame`（现有逻辑）
- **ATTACKING**：AnimationPlayer 控制 `sprite.frame`，移动输入被忽略

### 2.2 方向 → 动画映射

| `last_direction` | 播放动画 | `sprite.flip_h` |
|:---|:---|:---:|
| 向下 (0, 1) | `attakdown` | false |
| 向上 (0, -1) | `attakup` | false |
| 向左 (-1, 0) | `attakleft` | false |
| 向右 (1, 0) | `attakleft` | **true** |
| 无方向（首次） | `attakdown` | false |

### 2.3 时序图

```
帧 1:  玩家按J → 检查状态(NORMAL✓) → 进入ATTACKING → 播放动画
帧 2~N: 动画播放中 → 忽略移动输入 → 忽略攻击输入
帧 N:   动画结束 → animation_finished信号 → 开始冷却计时
帧 N+M: 冷却结束 → 回到NORMAL
```

---

## 三、修改文件清单

### 唯一修改文件：`res://player11/player.gd`

将现有代码重构为以下结构（注释中文，面向国内开发者）：

```
第一部分：状态枚举
第二部分：攻击参数 (@export)
第三部分：移动参数 (@export) — 保留不动
第四部分：精灵表参数 (@export) — 保留不动
第五部分：内部变量 & @onready
第六部分：_ready() — 连接信号
第七部分：_physics_process() — 修改，增加状态判断
第八部分：_update_animation() — 保留不动
第九部分：攻击处理 — 新增
第十部分：攻击结束回调 — 新增
```

---

## 四、具体代码设计

### 4.1 新增枚举和参数

```gdscript
# 玩家状态枚举：决定当前由谁控制 sprite.frame
enum PlayerState { NORMAL, ATTACKING }

# 攻击冷却时间（秒）：动画结束后等待此时间才能再次攻击
@export var attack_cooldown_time: float = 0.3
```

### 4.2 新增内部变量

```gdscript
var player_state: PlayerState = PlayerState.NORMAL
var attack_cooldown_timer: float = 0.0
@onready var animation_player: AnimationPlayer = $AnimationPlayer
```

### 4.3 _ready() — 信号连接

```gdscript
func _ready() -> void:
    animation_player.animation_finished.connect(_on_attack_finished)
```

使用代码连接信号（不需要在编辑器中手动操作）。

### 4.4 _physics_process() 修改

在现有逻辑前插入状态判断：

```gdscript
func _physics_process(delta: float) -> void:
    # --- 冷却计时 ---
    if attack_cooldown_timer > 0.0:
        attack_cooldown_timer -= delta

    # --- 处理攻击输入（优先级高于移动）---
    if Input.is_action_just_pressed("attak"):
        _try_attack()

    # --- 如果在攻击状态，跳过移动和动画更新 ---
    if player_state == PlayerState.ATTACKING:
        move_and_slide()
        return

    # ... 原有移动和动画代码保持不变 ...
```

### 4.5 _try_attack() — 攻击尝试

```gdscript
func _try_attack() -> void:
    # 检查：不在冷却中，不在攻击中
    if attack_cooldown_timer > 0.0:
        return
    if player_state == PlayerState.ATTACKING:
        return

    # 进入攻击状态
    player_state = PlayerState.ATTACKING

    # 停止移动（将速度归零，防止惯性滑行）
    velocity = Vector2.ZERO

    # 根据朝向选择动画
    var anim_name: String
    if abs(last_direction.x) > abs(last_direction.y):
        # 水平方向：左右共用 attakleft，向右时翻转
        anim_name = "attakleft"
        sprite.flip_h = last_direction.x > 0
    else:
        # 垂直方向
        if last_direction.y > 0:
            anim_name = "attakdown"
        else:
            anim_name = "attakup"
        sprite.flip_h = false

    animation_player.play(anim_name)
```

### 4.6 _on_attack_finished() — 攻击结束

```gdscript
func _on_attack_finished(anim_name: String) -> void:
    # 重置翻转（防止残留到下次移动动画）
    sprite.flip_h = false

    # 重置动画计时器，让移动动画从干净状态开始
    animation_timer = 0.0

    # 启动冷却
    attack_cooldown_timer = attack_cooldown_time

    # 回到正常状态
    player_state = PlayerState.NORMAL
```

---

## 五、Bug 预判与规避

| # | 潜在 Bug | 规避方式 |
|:--|:---|:---|
| 1 | 攻击期间连按 J 导致重复触发 | `player_state == ATTACKING` 时 `_try_attack()` 直接 return |
| 2 | 冷却期间按 J 触发攻击 | `attack_cooldown_timer > 0` 时拒绝 |
| 3 | 代码和 AnimationPlayer 同时写 `sprite.frame` | ATTACKING 状态下跳过 `_update_animation()`，完全隔离 |
| 4 | 向右攻击后 flip_h 残留 | `_on_attack_finished` 中强制 `flip_h = false` |
| 5 | 进入游戏未移动就攻击 | `last_direction` 初始值为 `Vector2.DOWN`，默认向下攻击 |
| 6 | 攻击时角色有残余速度导致滑行 | 攻击前 `velocity = Vector2.ZERO` |

---

## 六、你需要做的事情（手动操作清单）

### 必须做的

1. **验证动画名称** — 在 AnimationPlayer 面板中确认 3 个动画名称与代码一致：
   - `attakdown`
   - `attakleft`
   - `attakup`
   - 如果名称不同（如 `AttackDown`），请告诉我，我会调整代码

### 不需要做的（代码自动处理）

- 在编辑器中连接信号 → 代码中 `_ready()` 已自动连接
- 修改 AnimationPlayer 配置 → 无需改动
- 修改输入映射 → 保持现有的 `attak` → J 键
- 创建 AttackRight 动画 → 代码通过 flip_h 复用 AttackLeft

### 建议做的（优化体验）

- 在编辑器中选中 player 节点后，可在右侧属性面板调整 `attack_cooldown_time`（默认 0.3 秒）
- 如果觉得攻击手感偏硬/偏软，调整此数值即可

---

## 七、验证方法

1. 在 Godot 编辑器中按 F5 运行游戏
2. 按 WASD 移动角色 → 确认移动正常
3. 面向不同方向按 J 键攻击 → 确认播放正确的攻击动画
4. 攻击过程中按 WASD → 确认角色不移动
5. 攻击动画结束后立即再按 J → 确认有冷却（不能立即攻击）
6. 面向右方攻击 → 确认精灵翻转且动画结束后恢复
7. 确认攻击结束后移动动画恢复正常

---

## 八、完整代码预览

见下页（实际写入 player.gd 的内容）。代码中每一行都带中文注释。

### 代码结构总览

```
extends CharacterBody2D

第一部分：玩家状态枚举（新增 1 行 enum）

第二部分：攻击参数（新增 1 个 @export var）

第三部分：移动参数（保留原有 3 个 @export var）

第四部分：精灵表动画参数（保留原有 8 个 @export var）

第五部分：内部变量 & @onready（新增 3 行，保留 4 行）

第六部分：_ready()（新增 3 行）

第七部分：_physics_process()（新增 10 行，保留 20 行）

第八部分：_update_animation()（完整保留 35 行）

第九部分：_try_attack()（新增 25 行）

第十部分：_on_attack_finished()（新增 12 行）
```
