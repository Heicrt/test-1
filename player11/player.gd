# player.gd — 玩家主控制器（精简版）
# 职责：持有共享数据和导出参数，状态逻辑全部委托给 StateMachine 子节点
extends CharacterBody2D


# ============================================================
# 第一部分：玩家状态枚举
# ============================================================

## NORMAL  = 正常移动/待机状态
## ATTACKING = 攻击状态，由 AnimationPlayer 控制精灵帧
enum PlayerState { NORMAL, ATTACKING }


# ============================================================
# 第二部分：攻击参数
# ============================================================

## 攻击冷却时间（秒）
@export var attack_cooldown_time: float = 0.3


# ============================================================
# 第三部分：移动参数
# ============================================================

## 角色最大移动速度（像素/秒）
@export var move_speed: float = 200.0

## 加速度
@export var acceleration: float = 1200.0

## 摩擦力
@export var friction: float = 1000.0


# ============================================================
# 第四部分：精灵表动画参数
# ============================================================

## 向下移动使用的精灵表行号（从0开始）
@export var row_down: int = 0

## 向左移动使用的精灵表行号（从0开始）
@export var row_left: int = 1

## 向右移动使用的精灵表行号（从0开始）—— 已废弃，改用 row_left + flip_h
## 保留此参数仅为向后兼容，新逻辑不再使用
@export var row_right: int = 2

## 向上移动使用的精灵表行号（从0开始）
@export var row_up: int = 3

## 走路动画起始帧列号
@export var walk_frame_start: int = 0

## 走路动画结束帧列号
@export var walk_frame_end: int = 2

## 待机帧列号
@export var idle_frame: int = 0

## 动画帧间隔（秒）
@export var animation_frame_duration: float = 0.15


# ============================================================
# 第五部分：内部变量（由状态脚本读写）
# ============================================================

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var state_machine: Node = $StateMachine

## 动画计时器（Walk 状态中累加）
var animation_timer: float = 0.0

## 当前动画帧列号
var current_frame: int = 0

## 最后移动方向（Idle 保持朝向用）
var last_direction: Vector2 = Vector2.DOWN

## 当前玩家状态
var player_state: PlayerState = PlayerState.NORMAL

## 攻击冷却计时器（player.gd 统一管理，各状态只读）
var attack_cooldown_timer: float = 0.0


# ============================================================
# 第六部分：初始化
# ============================================================

func _ready() -> void:
	# StateMachine 在其 _ready 中自动初始化第一个状态
	pass
