# StateMachine — 玩家状态管理器
# 负责状态切换、输入路由、物理帧代理
class_name StateMachine
extends Node


## 当前活跃状态引用
var _active_state: BaseState = null

## 转移锁：防止嵌套切换
var _transition_lock: bool = false

## 待处理转移（从信号回调中延迟到下一帧处理）
var _pending_transition: String = ""

## 状态节点名 → 节点引用的映射
var _state_map: Dictionary = {}

## player 根节点引用
var _host: CharacterBody2D = null


func _ready() -> void:
	_host = get_parent() as CharacterBody2D
	_build_state_map()
	_enter_initial_state()


## 扫描子节点构建状态映射
func _build_state_map() -> void:
	for child in get_children():
		if child is BaseState:
			_state_map[child.name] = child
			child.process_mode = PROCESS_MODE_DISABLED


## 进入初始状态（Idle）
func _enter_initial_state() -> void:
	switch_state("StateIdle")


## 原子性状态切换
func switch_state(state_name: String) -> void:
	if _transition_lock:
		# 若已在切换中，排队到下一帧处理
		_pending_transition = state_name
		return

	if not _state_map.has(state_name):
		push_error("[StateMachine] 未知状态: " + state_name)
		return

	var new_state: BaseState = _state_map[state_name]
	if new_state == _active_state:
		return

	_transition_lock = true

	# 退出旧状态
	if _active_state != null:
		if OS.is_debug_build():
			print("[StateMachine] " + _active_state.name + " → " + state_name)
		_active_state.exit(_host)
		_active_state.process_mode = PROCESS_MODE_DISABLED

	# 进入新状态
	new_state.process_mode = PROCESS_MODE_INHERIT
	new_state.enter(_host)
	_active_state = new_state

	_transition_lock = false

	# 处理排队中的转移
	if _pending_transition != "":
		var pending := _pending_transition
		_pending_transition = ""
		switch_state(pending)


## 由 StateAttack 的动画回调间接调用，延迟到下一帧处理
func request_transition(state_name: String) -> void:
	_pending_transition = state_name


func _physics_process(delta: float) -> void:
	if _active_state == null:
		return

	# 冷却计时器统一在 host 管理
	if _host.attack_cooldown_timer > 0.0:
		_host.attack_cooldown_timer -= delta

	# 代理给当前状态
	_active_state.physics_update(_host, delta)

	# 残留按键检测：Idle 状态下若有方向键被按住，自动转到 Walk
	_check_idle_input()

	# Walk 状态的自动回 Idle 检测
	_check_walk_to_idle()

	# 处理延迟转移
	_process_pending()


## 残留按键检测：解决进入 Idle 时方向键已被按住但 _unhandled_input 不会再次触发的问题
func _check_idle_input() -> void:
	if not _active_state is StateIdle:
		return
	var input_vector: Vector2 = Input.get_vector("left", "right", "up", "down")
	if input_vector != Vector2.ZERO:
		switch_state("StateWalk")


## 检测 Walk → Idle 的自动转移
func _check_walk_to_idle() -> void:
	if not _active_state is StateWalk:
		return
	var walk_state := _active_state as StateWalk
	var next := walk_state._check_idle_transition(_host)
	if next != "":
		switch_state(next)


## 处理排队的转移请求
func _process_pending() -> void:
	if _pending_transition != "":
		var pending := _pending_transition
		_pending_transition = ""
		switch_state(pending)


## 输入路由：检测移动和攻击输入
func _unhandled_input(event: InputEvent) -> void:
	if _active_state == null or _host == null:
		return

	# 攻击键优先级最高（零帧响应）
	if event.is_action_pressed("attak"):
		var next := _active_state.handle_input(_host, "attack")
		if next != "":
			switch_state(next)
		get_viewport().set_input_as_handled()
		return

	# 移动键按下 → 通知状态
	if event.is_action_pressed("left") or event.is_action_pressed("right") or \
	   event.is_action_pressed("up") or event.is_action_pressed("down"):
		var next := _active_state.handle_input(_host, "move")
		if next != "":
			switch_state(next)
		get_viewport().set_input_as_handled()
		return
