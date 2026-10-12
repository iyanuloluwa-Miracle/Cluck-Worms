class_name WormPool
extends Node
## Preallocates Worm instances and recycles them to avoid hitching on free/instantiate.

signal pool_warmed(count: int)

@export var worm_scene: PackedScene
@export var initial_size: int = 48
@export var max_size: int = 160

var _available: Array[Worm] = []
var _in_use: int = 0


func _ready() -> void:
	if worm_scene == null:
		return
	warm(initial_size)


func warm(count: int) -> void:
	if worm_scene == null:
		push_error("WormPool: worm_scene is not set.")
		return
	var to_create: int = mini(count, max_size - _total_count())
	for i: int in range(to_create):
		var worm: Worm = worm_scene.instantiate() as Worm
		worm.visible = false
		worm.set_process(false)
		add_child(worm)
		worm.enter_pool()
		_available.append(worm)
	pool_warmed.emit(_available.size())


func acquire() -> Worm:
	if _available.is_empty():
		if _total_count() >= max_size:
			return null
		warm(maxi(8, initial_size / 4))
	if _available.is_empty():
		return null
	var worm: Worm = _available.pop_back()
	_in_use += 1
	worm.exit_pool()
	worm.set_process(true)
	worm.visible = true
	return worm


func release(worm: Worm) -> void:
	if worm == null or not is_instance_valid(worm):
		return
	if worm.get_parent() != self:
		if worm.get_parent() != null:
			worm.get_parent().remove_child(worm)
		add_child(worm)
	worm.enter_pool()
	worm.visible = false
	worm.set_process(false)
	_available.append(worm)
	_in_use = maxi(_in_use - 1, 0)


func get_in_use_count() -> int:
	return _in_use


func get_available_count() -> int:
	return _available.size()


func _total_count() -> int:
	return _available.size() + _in_use
