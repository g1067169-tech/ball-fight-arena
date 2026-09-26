class_name BlockRuntime
extends RefCounted

# Block runtime for executing block scripts
# Each ball has a script composed of event handlers (event -> block chain)
# This executes those chains in response to events

class BlockContext:
	var ball: Dictionary
	var simulation: Node
	var variables: Dictionary = {}
	var execution_stack: Array = []
	
	func _init(p_ball: Dictionary, p_simulation: Node) -> void:
		ball = p_ball
		simulation = p_simulation
		variables = ball.get("variables", {})

# Block definitions by category
const BLOCK_LIBRARY = {
	"events": {
		"ON_HIT": {"type": "event", "color": "#ff6b6b"},
		"ON_WALL": {"type": "event", "color": "#ff6b6b"},
		"ON_DAMAGE": {"type": "event", "color": "#ff6b6b"},
		"ON_DESTROY": {"type": "event", "color": "#ff6b6b"},
		"ON_SPAWN": {"type": "event", "color": "#ff6b6b"},
		"TIMER": {"type": "event", "color": "#ff6b6b", "params": {"interval": 1.0}},
		"RANDOM": {"type": "event", "color": "#ff6b6b", "params": {"chance": 0.5}},
	},
	"control": {
		"IF": {"type": "control", "color": "#ffd93d", "params": {"condition": "true"}, "has_branches": true},
		"REPEAT": {"type": "control", "color": "#ffd93d", "params": {"count": 5}},
		"FOREVER": {"type": "control", "color": "#ffd93d"},
		"WAIT": {"type": "control", "color": "#ffd93d", "params": {"duration": 1.0}},
	},
	"variables": {
		"SET_VAR": {"type": "variable", "color": "#a4d65e", "params": {"name": "var1", "value": 0}},
		"CHANGE_VAR": {"type": "variable", "color": "#a4d65e", "params": {"name": "var1", "change": 1}},
		"CREATE_VAR": {"type": "variable", "color": "#a4d65e", "params": {"name": "new_var", "value": 0}},
	},
	"physics": {
		"SET_VELOCITY": {"type": "physics", "color": "#6bcf7f", "params": {"x": 100, "y": 0}},
		"CHANGE_VELOCITY": {"type": "physics", "color": "#6bcf7f", "params": {"x": 0, "y": 0}},
		"APPLY_FORCE": {"type": "physics", "color": "#6bcf7f", "params": {"x": 0, "y": 0}},
		"SET_SPEED": {"type": "physics", "color": "#6bcf7f", "params": {"speed": 100}},
		"CHANGE_SPEED": {"type": "physics", "color": "#6bcf7f", "params": {"factor": 1.1}},
		"TELEPORT": {"type": "physics", "color": "#6bcf7f", "params": {"x": 0, "y": 0}},
		"SET_POSITION": {"type": "physics", "color": "#6bcf7f", "params": {"x": 0, "y": 0}},
		"SET_MASS": {"type": "physics", "color": "#6bcf7f", "params": {"mass": 1.0}},
	},
	"weapons": {
		"SHOOT": {"type": "weapon", "color": "#ff8c42", "params": {"speed": 340, "damage": 12}},
		"DROP_BOMB": {"type": "weapon", "color": "#ff8c42", "params": {"radius": 75, "damage": 16}},
		"RANDOM_BLAST": {"type": "weapon", "color": "#ff8c42", "params": {"radius": 90, "damage": 18}},
	},
	"objects": {
		"SPAWN": {"type": "object", "color": "#5dade2", "params": {"object_type": "ball", "count": 1}},
		"SPAWN_PROJECTILE": {"type": "object", "color": "#5dade2", "params": {"speed": 340, "damage": 12}},
		"SPAWN_EFFECT": {"type": "object", "color": "#5dade2", "params": {"effect_type": "blast", "duration": 0.5}},
		"CLONE": {"type": "object", "color": "#5dade2", "params": {}},
		"DESTROY": {"type": "object", "color": "#5dade2", "params": {}},
	},
	"combat": {
		"DAMAGE": {"type": "combat", "color": "#d981b7", "params": {"amount": 10}},
		"HEAL": {"type": "combat", "color": "#d981b7", "params": {"amount": 20}},
		"SHIELD": {"type": "combat", "color": "#d981b7", "params": {"duration": 2.0}},
		"KNOCKBACK": {"type": "combat", "color": "#d981b7", "params": {"force": 90}},
	},
	"visual": {
		"CHANGE_SIZE": {"type": "visual", "color": "#f794ff", "params": {"size": 18}},
		"CHANGE_OPACITY": {"type": "visual", "color": "#f794ff", "params": {"opacity": 1.0}},
		"ROTATE": {"type": "visual", "color": "#f794ff", "params": {"angle": 0}},
	},
}

static func get_block_def(block_type: String) -> Dictionary:
	for category in BLOCK_LIBRARY.values():
		if category.has(block_type):
			return category[block_type].duplicate()
	return {}

static func is_valid_block(block_type: String) -> bool:
	for category in BLOCK_LIBRARY.values():
		if category.has(block_type):
			return true
	return false

static func execute_block(context: BlockContext, block: Dictionary) -> void:
	if not block.has("type"):
		return
	
	var block_type = block.type
	
	# Physics blocks
	if block_type == "SET_VELOCITY":
		var x = block.get("params", {}).get("x", 0.0)
		var y = block.get("params", {}).get("y", 0.0)
		context.ball.vel = Vector2(x, y)
	
	elif block_type == "CHANGE_VELOCITY":
		var x = block.get("params", {}).get("x", 0.0)
		var y = block.get("params", {}).get("y", 0.0)
		context.ball.vel += Vector2(x, y)
	
	elif block_type == "APPLY_FORCE":
		var x = block.get("params", {}).get("x", 0.0)
		var y = block.get("params", {}).get("y", 0.0)
		context.ball.vel += Vector2(x, y) * 0.1
	
	elif block_type == "SET_SPEED":
		var speed = block.get("params", {}).get("speed", 100.0)
		var current_vel = context.ball.vel.normalized()
		if current_vel.length() < 0.1:
			current_vel = Vector2.RIGHT
		context.ball.vel = current_vel * speed
	
	elif block_type == "CHANGE_SPEED":
		var factor = block.get("params", {}).get("factor", 1.1)
		context.ball.vel *= factor
	
	elif block_type == "TELEPORT":
		var x = block.get("params", {}).get("x", 0.0)
		var y = block.get("params", {}).get("y", 0.0)
		context.ball.pos = Vector2(x, y)
	
	elif block_type == "SET_POSITION":
		var x = block.get("params", {}).get("x", 0.0)
		var y = block.get("params", {}).get("y", 0.0)
		context.ball.pos = Vector2(x, y)
	
	elif block_type == "SET_MASS":
		var mass = block.get("params", {}).get("mass", 1.0)
		context.ball.mass = mass
	
	# Weapon blocks
	elif block_type == "SHOOT":
		var speed = block.get("params", {}).get("speed", 340.0)
		var damage = block.get("params", {}).get("damage", 12.0)
		context.simulation._spawn_projectile(context.ball, speed, 18.0, damage)
	
	elif block_type == "DROP_BOMB":
		var radius = block.get("params", {}).get("radius", 75.0)
		var damage = block.get("params", {}).get("damage", 16.0)
		context.simulation._effect(context.ball.pos + Vector2(randf_range(-30, 30), randf_range(-30, 30)), "bomb", Color("#ffb14c"), 0.45)
		for other in context.simulation.balls:
			if other.id == context.ball.id: continue
			if other.team == context.ball.team: continue
			if context.ball.pos.distance_to(other.pos) <= radius:
				context.simulation._apply_damage(other, damage, context.ball.id)
	
	elif block_type == "RANDOM_BLAST":
		var radius = block.get("params", {}).get("radius", 90.0)
		var damage = block.get("params", {}).get("damage", 18.0)
		var target := Vector2(randf_range(context.simulation.ARENA.position.x, context.simulation.ARENA.end.x), 
							 randf_range(context.simulation.ARENA.position.y, context.simulation.ARENA.end.y))
		context.simulation._effect(target, "blast", Color("#ff8a5c"), 0.5)
		for other in context.simulation.balls:
			if other.team == context.ball.team: continue
			if other.pos.distance_to(target) <= radius:
				context.simulation._apply_damage(other, damage, context.ball.id)
	
	# Combat blocks
	elif block_type == "DAMAGE":
		var amount = block.get("params", {}).get("amount", 10.0)
		context.ball.health -= amount
	
	elif block_type == "HEAL":
		var amount = block.get("params", {}).get("amount", 20.0)
		context.ball.health = min(context.ball.max_health, context.ball.health + amount)
	
	elif block_type == "SHIELD":
		var duration = block.get("params", {}).get("duration", 2.0)
		context.ball.shield = duration
	
	elif block_type == "KNOCKBACK":
		var force = block.get("params", {}).get("force", 90.0)
		for other in context.simulation.balls:
			if other.id == context.ball.id: continue
			if other.team == context.ball.team: continue
			var dir = (other.pos - context.ball.pos).normalized()
			other.vel += dir * force
	
	# Variable blocks
	elif block_type == "SET_VAR":
		var name = block.get("params", {}).get("name", "var1")
		var value = block.get("params", {}).get("value", 0)
		context.variables[name] = value
	
	elif block_type == "CHANGE_VAR":
		var name = block.get("params", {}).get("name", "var1")
		var change = block.get("params", {}).get("change", 1)
		context.variables[name] = context.variables.get(name, 0) + change
	
	elif block_type == "CREATE_VAR":
		var name = block.get("params", {}).get("name", "new_var")
		var value = block.get("params", {}).get("value", 0)
		context.variables[name] = value
	
	# Object blocks
	elif block_type == "SPAWN":
		var object_type = block.get("params", {}).get("object_type", "ball")
		var count = block.get("params", {}).get("count", 1)
		for i in range(count):
			context.simulation._add_character("Spawned " + object_type, context.ball.team, "Bouncer")
			context.simulation.balls[-1].pos = context.ball.pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	
	elif block_type == "DESTROY":
		context.ball.health = -1.0
	
	# Visual blocks
	elif block_type == "CHANGE_SIZE":
		var size = block.get("params", {}).get("size", 18.0)
		context.ball.radius = size
	
	elif block_type == "CHANGE_OPACITY":
		var opacity = block.get("params", {}).get("opacity", 1.0)
		context.ball["opacity"] = opacity

static func execute_block_chain(context: BlockContext, blocks: Array) -> void:
	if blocks.is_empty():
		return
	
	for block in blocks:
		if block is Dictionary:
			execute_block(context, block)
			# Handle nested blocks (control flow)
			if block.has("blocks"):
				execute_block_chain(context, block.blocks)
