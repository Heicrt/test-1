# BaseState — 所有玩家状态的抽象基类
class_name BaseState
extends Node


## 进入此状态时调用一次
func enter(host: CharacterBody2D) -> void:
	pass


## 退出此状态时调用一次。子类必须在此清理本状态产生的副作用
func exit(host: CharacterBody2D) -> void:
	pass


## 每物理帧由 StateMachine 调用
func physics_update(host: CharacterBody2D, delta: float) -> void:
	pass


## 处理输入动作名，返回要转移到的目标状态名，空字符串表示不转移
## 此方法不应产生副作用——只做判断，不修改状态
func handle_input(host: CharacterBody2D, action: String) -> String:
	return ""
