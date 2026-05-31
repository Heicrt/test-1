extends CharacterBody2D


# ============================================================
# 第一部分：移动参数
# 以下参数可以在编辑器右侧属性面板中直接修改，无需改动代码
# ============================================================

## 角色最大移动速度，单位是"像素/秒"。数值越大跑得越快
## 推荐范围：100 ~ 400
@export var move_speed: float = 200.0

## 加速度，控制角色从静止到全速需要多长时间
## 数值越大，按下按键后角色启动越快、手感越"硬"
## 推荐范围：500 ~ 2000
@export var acceleration: float = 1200.0

## 摩擦力，控制松开按键后角色多久停下来
## 数值越大，松开按键后角色停得越快、手感越"干脆"
## 推荐范围：500 ~ 2000
@export var friction: float = 1000.0


# ============================================================
# 第二部分：精灵表动画参数
# 你的精灵图 ueisukun_sprite.png 是一个 8列 x 8行 的精灵表
# 不同行代表不同方向的动画，不同列代表该方向的不同帧
# 请观察你的精灵图，把正确的行号填入下方参数
# ============================================================

## 向下移动时，使用精灵表的第几行（从0开始数）
@export var row_down: int = 0

## 向左移动时，使用精灵表的第几行（从0开始数）
@export var row_left: int = 1

## 向右移动时，使用精灵表的第几行（从0开始数）
@export var row_right: int = 2

## 向上移动时，使用精灵表的第几行（从0开始数）
@export var row_up: int = 3

## 走路动画的起始帧，即该行走动画从第几列开始（从0开始数）
@export var walk_frame_start: int = 0

## 走路动画的结束帧，即该行走动画到第几列结束（从0开始数）
## 动画会在这两列之间循环播放：起始帧 → 起始帧+1 → ... → 结束帧 → 回到起始帧
@export var walk_frame_end: int = 2

## 待机（站立不动）时显示该方向的第几列帧（从0开始数）
@export var idle_frame: int = 0

## 动画播放速度，即每帧画面持续多少秒
## 数值越小动画切换越快，例如 0.1 很快，0.2 较慢
## 推荐范围：0.08 ~ 0.2
@export var animation_frame_duration: float = 0.15


# ============================================================
# 第三部分：内部变量
# 以下变量由代码自动维护，不需要手动修改
# ============================================================

## 获取 Sprite2D 节点引用，用于后面控制画面显示
@onready var sprite: Sprite2D = $Sprite2D

## 动画计时器，累加时间来判断是否该切换到下一帧
var animation_timer: float = 0.0

## 当前正在显示的动画帧列号
var current_frame: int = 0

## 上一次的移动方向，松开按键后角色保持面向这个方向
var last_direction: Vector2 = Vector2.DOWN


# ============================================================
# 第四部分：物理帧处理
# _physics_process 每秒自动运行约60次，负责移动和物理计算
# ============================================================

func _physics_process(delta: float) -> void:
	# --- 步骤1：读取玩家按键 ---
	# Input.get_vector 会读取你配好的四个按键（up/down/left/right）
	# 返回值是一个方向向量，比如按D键返回 (1, 0)，按W键返回 (0, -1)
	# 同时按W和D会返回对角方向 (0.707, -0.707)，支持斜向移动
	var input_vector: Vector2 = Input.get_vector("left", "right", "up", "down")

	# --- 步骤2：根据输入计算速度 ---
	if input_vector != Vector2.ZERO:
		# 有按键按下：将速度向目标方向加速
		# target_velocity = 输入方向 × 最大速度
		var target_velocity: Vector2 = input_vector * move_speed
		# move_toward 让速度从当前值平滑过渡到目标值
		# 每帧最多变化 acceleration * delta 这么多
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		# 没有按键：摩擦力让速度逐渐减小到零
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	# --- 步骤3：执行移动 ---
	# move_and_slide 是 CharacterBody2D 内置方法
	# 它会用计算好的速度移动角色，并自动处理碰撞
	move_and_slide()

	# --- 步骤4：更新精灵动画 ---
	_update_animation(delta, input_vector)


# ============================================================
# 第五部分：动画更新
# 根据移动状态自动切换精灵表上的帧
# ============================================================

func _update_animation(delta: float, input_vector: Vector2) -> void:
	# --- 判断是否正在移动 ---
	var is_moving: bool = input_vector != Vector2.ZERO

	# --- 更新朝向 ---
	# 只有按下按键时才更新朝向，这样松开按键后角色保持最后面对的方向
	if is_moving:
		last_direction = input_vector

	# --- 根据朝向选择精灵表的行号 ---
	# 比较水平和垂直分量的绝对值，哪个大就以哪个为主方向
	# 这样斜向移动时不会在两个方向之间来回闪烁
	var target_row: int
	if abs(last_direction.x) > abs(last_direction.y):
		# 水平方向为主：判断左右
		if last_direction.x > 0:
			target_row = row_right   # 向右
		else:
			target_row = row_left    # 向左
	else:
		# 垂直方向为主：判断上下
		if last_direction.y > 0:
			target_row = row_down    # 向下
		else:
			target_row = row_up      # 向上

	# --- 更新动画帧 ---
	if is_moving:
		# 移动中：累加计时器，到时间就切到下一帧
		animation_timer += delta
		if animation_timer >= animation_frame_duration:
			animation_timer -= animation_frame_duration  # 减去间隔时间（而非归零，避免帧丢失）
			current_frame += 1
			# 到达结束帧后，回到起始帧形成循环
			if current_frame > walk_frame_end:
				current_frame = walk_frame_start
	else:
		# 静止时：显示待机帧，重置计时器
		current_frame = idle_frame
		animation_timer = 0.0

	# --- 将计算结果应用到精灵图上 ---
	# 计算线性帧索引：行号 × 总列数 + 列号
	# 例如精灵表有8列，第2行第3帧 → 2 × 8 + 3 = 19
	sprite.frame = target_row * sprite.hframes + current_frame
