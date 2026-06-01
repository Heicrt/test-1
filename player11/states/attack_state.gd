# StateAttack — 攻击状态
# 锁定移动，播放攻击动画，结束后自动返回 Idle
class_name StateAttack
extends BaseState


## 进入攻击：停止移动、选择动画、连接回调
func enter(host: CharacterBody2D) -> void:
	var sprite: Sprite2D = host.get_node("Sprite2D")
	var animation_player: AnimationPlayer = host.get_node("AnimationPlayer")

	# 立即停止移动，标记攻击中
	host.velocity = Vector2.ZERO
	host.player_state = host.PlayerState.ATTACKING

	# 选择攻击动画
	var anim_name: String
	if abs(host.last_direction.x) > abs(host.last_direction.y):
		anim_name = "attakleft"
		sprite.flip_h = host.last_direction.x > 0
	else:
		if host.last_direction.y > 0:
			anim_name = "attakdown"
		else:
			anim_name = "attakup"
		sprite.flip_h = false

	# 安全连接信号（先断开避免重复连接）
	if animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_finished)
	animation_player.animation_finished.connect(_on_animation_finished)

	animation_player.play(anim_name)


## 攻击中：只处理碰撞，不更新速度
func physics_update(host: CharacterBody2D, _delta: float) -> void:
	host.move_and_slide()


## 攻击中：忽略所有输入
func handle_input(_host: CharacterBody2D, _action: String) -> String:
	return ""


## 退出攻击：清理副作用，设置冷却
func exit(host: CharacterBody2D) -> void:
	var sprite: Sprite2D = host.get_node("Sprite2D")
	var animation_player: AnimationPlayer = host.get_node("AnimationPlayer")

	# 清理翻转
	sprite.flip_h = false

	# 断开信号
	if animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_finished)

	# 重置动画计时器
	host.animation_timer = 0.0
	host.current_frame = host.idle_frame

	# 启动冷却
	host.attack_cooldown_timer = host.attack_cooldown_time
	host.player_state = host.PlayerState.NORMAL


## 动画播放完毕回调 → 延迟到下一帧转移，避免在信号回调中直接切换状态
func _on_animation_finished(_anim_name: String) -> void:
	var sm := get_parent()
	if sm.has_method("request_transition"):
		sm.request_transition("StateIdle")
