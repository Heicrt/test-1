# StateWalk — 走路状态
# 处理八方向移动、加速度/摩擦力、动画帧循环
class_name StateWalk
extends BaseState


## 进入走路：重置动画计时器，确保从首帧开始
func enter(host: CharacterBody2D) -> void:
	host.animation_timer = 0.0
	host.current_frame = host.walk_frame_start


## 每物理帧：计算速度 + 更新动画
func physics_update(host: CharacterBody2D, delta: float) -> void:
	var sprite: Sprite2D = host.get_node("Sprite2D")
	var input_vector: Vector2 = Input.get_vector("left", "right", "up", "down")

	# 速度计算（加速度 / 摩擦力）
	if input_vector != Vector2.ZERO:
		var target_velocity: Vector2 = input_vector * host.move_speed
		host.velocity = host.velocity.move_toward(target_velocity, host.acceleration * delta)
	else:
		host.velocity = host.velocity.move_toward(Vector2.ZERO, host.friction * delta)

	host.move_and_slide()

	# 更新朝向
	if input_vector != Vector2.ZERO:
		host.last_direction = input_vector

	# 动画帧更新
	_update_walk_animation(host, delta, sprite)


## 输入处理：检测攻击（需过冷却检查，防止连按卡死）
func handle_input(host: CharacterBody2D, action: String) -> String:
	if action == "attack" and host.attack_cooldown_timer <= 0.0:
		return "StateAttack"
	return ""


## 每帧结束时检查：若无移动输入且速度接近零，转移回 Idle
func _check_idle_transition(host: CharacterBody2D) -> String:
	var input_vector: Vector2 = Input.get_vector("left", "right", "up", "down")
	if input_vector == Vector2.ZERO and host.velocity.length_squared() < 1.0:
		return "StateIdle"
	return ""


## 退出走路：清理翻转状态，避免残留到其他状态
func exit(host: CharacterBody2D) -> void:
	var sprite: Sprite2D = host.get_node("Sprite2D")
	sprite.flip_h = false
	host.animation_timer = 0.0


## 动画帧循环 + 向右翻转修复
## 核心修复：向右移动使用 row_left 行数据 + sprite.flip_h 水平翻转
func _update_walk_animation(host: CharacterBody2D, delta: float, sprite: Sprite2D) -> void:
	var is_moving: bool = host.velocity.length_squared() > 1.0

	if not is_moving:
		return

	# 主方向判定（避免斜向闪烁）
	var target_row: int
	if abs(host.last_direction.x) > abs(host.last_direction.y):
		# ✅ 水平方向：使用左行动画行 + flip_h 区分左右
		target_row = host.row_left
		sprite.flip_h = host.last_direction.x > 0
	else:
		# 垂直方向：不翻转
		if host.last_direction.y > 0:
			target_row = host.row_down
		else:
			target_row = host.row_up
		sprite.flip_h = false

	# 帧循环
	host.animation_timer += delta
	if host.animation_timer >= host.animation_frame_duration:
		host.animation_timer -= host.animation_frame_duration
		host.current_frame += 1
		if host.current_frame > host.walk_frame_end:
			host.current_frame = host.walk_frame_start

	sprite.frame = target_row * sprite.hframes + host.current_frame
