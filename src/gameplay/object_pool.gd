## ObjectPool — generic pre-allocated node pool
## ADR-003: Object Pool Pattern
##
## Pre-allocates N nodes of a given scene. checkout()/return() replace
## instantiate()/queue_free() during gameplay. Zero allocations at runtime.
##
## Usage:
##   var _pool := ObjectPool.new()
##   _pool.setup(self, preload("res://src/gameplay/arrow.tscn"), 24)
##   var node = _pool.checkout()   # returns null if exhausted
##   _pool.return_node(node)       # return to pool (not queue_free)
class_name ObjectPool
extends RefCounted

var _available: Array[Node] = []
var _active: Array[Node] = []

## Pre-allocate [param count] instances of [param scene] as children of [param parent].
func setup(parent: Node, scene: PackedScene, count: int) -> void:
	for i in range(count):
		var node: Node = scene.instantiate()
		parent.add_child(node)
		_available.append(node)

## Pre-allocate from an existing array of already-created nodes.
## Use when nodes are constructed in code rather than from a .tscn.
func setup_from_nodes(nodes: Array[Node]) -> void:
	for node in nodes:
		_available.append(node)

## Borrow a node from the pool. Returns null if all nodes are in use.
func checkout() -> Node:
	if _available.is_empty():
		push_warning("ObjectPool: pool exhausted — returning null")
		return null
	var node: Node = _available.pop_back()
	_active.append(node)
	return node

## Return a node to the pool. Caller must call node.deactivate() before returning.
func return_node(node: Node) -> void:
	var idx := _active.find(node)
	if idx == -1:
		push_warning("ObjectPool: return_node called on node not in active list")
		return
	_active.remove_at(idx)
	_available.append(node)

## Returns a copy of the currently active node list. Safe to iterate and modify.
func all_active() -> Array[Node]:
	return _active.duplicate()

## Total pool size (active + available).
func size() -> int:
	return _available.size() + _active.size()

## Number of nodes currently available for checkout.
func available_count() -> int:
	return _available.size()
