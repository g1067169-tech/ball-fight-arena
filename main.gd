extends Node2D

const ARENA := Rect2(24, 90, 850, 610)
const PANEL_X := 900.0
const TEAM_COLORS := [
	Color("#ff5f7a"),
	Color("#4ca3ff"),
	Color("#ae7cff"),
	Color("#ffc857"),
	Color("#53d68c"),
	Color("#ff9f43")
]
const TEAM_NAMES := ["RED", "BLUE", "PURPLE", "GOLD", "GREEN", "ORANGE"]
const EVENT_LABELS := ["ON_HIT", "ON_WALL", "EVERY_3S", "ON_DAMAGE", "ON_DESTROY"]
const ACTIONS := [
	"SHOOT",
	"DROP_BOMB",
	"RANDOM_BLAST",
	"SPLIT",
	"CREATE_SHIELD",
	"SPEED_UP",
	"SUMMON_MINION",
	"TELEPORT",
	"HEAL",
	"PUSH_AWAY",
	"SET_RANDOM_VELOCITY",
	"RAIN_EFFECT"
]

var balls: Array = []
var projectiles: Array = []
var effects: Array = []
var running := false
var time_scale := 1.0
var next_id := 1
var selected_id := -1
var background := Color("#0d1422")
var outline := Color("#425578")
var project_file := "user://bounceforge_project.json"

var roster_label: Label
var selected_label: Label
var status_label: Label
var speed_label: Label
var script_label: Label

func _ready() -> void:
	randomize()
	_build_ui()
	_seed_demo()
	if not balls.is_empty():
		_select_ball(balls[0].id)
	_update_roster()
	queue_redraw()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var title := Label.new()
	title.position = Vector2(24, 16)
	title.text = "BounceForge Arena"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#edf5ff"))
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.position = Vector2(275, 28)
	subtitle.text = "physics sandbox • programmable characters • chaotic battles"
	subtitle.add_theme_color_override("font_color", Color("#8da7d5"))
	root.add_child(subtitle)

	var panel := Panel.new()
	panel.position = Vector2(PANEL_X, 14)
	panel.size = Vector2(270, 720)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#171e2f"), Color("#2a3860"), 12))
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(14, 18)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var sim_title := Label.new(); sim_title.text = "SIMULATION"; sim_title.add_theme_color_override("font_color", Color("#79d6ff")); vbox.add_child(sim_title)
	var start_btn := Button.new(); start_btn.text = "START"; start_btn.pressed.connect(_start_simulation); vbox.add_child(start_btn)
	var pause_btn := Button.new(); pause_btn.text = "PAUSE"; pause_btn.pressed.connect(_pause_simulation); vbox.add_child(pause_btn)
	var stop_btn := Button.new(); stop_btn.text = "STOP"; stop_btn.pressed.connect(_stop_simulation); vbox.add_child(stop_btn)
	var restart_btn := Button.new(); restart_btn.text = "RESTART"; restart_btn.pressed.connect(_restart_simulation); vbox.add_child(restart_btn)
	var save_btn := Button.new(); save_btn.text = "SAVE PROJECT"; save_btn.pressed.connect(_save_project); vbox.add_child(save_btn)
	var load_btn := Button.new(); load_btn.text = "LOAD PROJECT"; load_btn.pressed.connect(_load_project); vbox.add_child(load_btn)
	status_label = Label.new(); status_label.text = "READY"; status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status_label.add_theme_color_override("font_color", Color("#d4def8")); vbox.add_child(status_label)

	var sep1 := HSeparator.new(); vbox.add_child(sep1)
	var speed_title := Label.new(); speed_title.text = "SIMULATION SPEED"; vbox.add_child(speed_title)
	var speed_box := HBoxContainer.new(); speed_box.add_theme_constant_override("separation", 5); vbox.add_child(speed_box)
	for s in [0.25, 0.5, 1.0, 2.0]:
		var b := Button.new(); b.text = str(s) + "x"; b.custom_minimum_size.x = 56; b.pressed.connect(func(): _set_speed(s)); speed_box.add_child(b)
	speed_label = Label.new(); speed_label.text = "Speed: 1.0x"; speed_label.add_theme_color_override("font_color", Color("#79d6ff")); vbox.add_child(speed_label)

	var sep2 := HSeparator.new(); vbox.add_child(sep2)
	var creator_title := Label.new(); creator_title.text = "CHARACTER CREATOR"; creator_title.add_theme_color_override("font_color", Color("#79d6ff")); vbox.add_child(creator_title)
	var name_edit := LineEdit.new(); name_edit.placeholder_text = "Character name"; vbox.add_child(name_edit)
	var team_box := OptionButton.new(); for n in TEAM_NAMES: team_box.add_item(n); team_box.select(0); vbox.add_child(team_box)
	var template_box := OptionButton.new(); template_box.add_item("Bouncer"); template_box.add_item("Shooter"); template_box.add_item("Bomber"); template_box.add_item("Splitter"); template_box.add_item("Randomizer"); template_box.add_item("Guardian"); vbox.add_child(template_box)
	var add_ball_btn := Button.new(); add_ball_btn.text = "+ ADD BALL"; add_ball_btn.pressed.connect(func(): _add_character_from_ui(name_edit.text, team_box.selected, template_box.get_item_text(template_box.selected))); vbox.add_child(add_ball_btn)
	var bg_picker := ColorPickerButton.new(); bg_picker.text = "Background"; bg_picker.color = background; bg_picker.color_changed.connect(func(c): background = c; queue_redraw()); vbox.add_child(bg_picker)
	var outline_picker := ColorPickerButton.new(); outline_picker.text = "Arena outline"; outline_picker.color = outline; outline_picker.color_changed.connect(func(c): outline = c; queue_redraw()); vbox.add_child(outline_picker)

	var sep3 := HSeparator.new(); vbox.add_child(sep3)
	var block_title := Label.new(); block_title.text = "BLOCK EDITOR"; block_title.add_theme_color_override("font_color", Color("#79d6ff")); vbox.add_child(block_title)
	var event_menu := OptionButton.new(); for label in EVENT_LABELS: event_menu.add_item(label); event_menu.select(0); vbox.add_child(event_menu)
	var action_menu := OptionButton.new(); for label in ACTIONS: action_menu.add_item(label); action_menu.select(0); vbox.add_child(action_menu)
	var add_block_btn := Button.new(); add_block_btn.text = "ADD BEHAVIOR BLOCK"; add_block_btn.pressed.connect(func(): _attach_behavior(event_menu.get_item_text(event_menu.selected), action_menu.get_item_text(action_menu.selected))); vbox.add_child(add_block_btn)
	script_label = Label.new(); script_label.text = "Selected script: none"; script_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; script_label.add_theme_color_override("font_color", Color("#ccd8f1")); vbox.add_child(script_label)

	roster_label = Label.new(); roster_label.position = Vector2(30, 110); roster_label.add_theme_color_override("font_color", Color("#b9c9eb")); root.add_child(roster_label)
	selected_label = Label.new(); selected_label.position = Vector2(30, 70); selected_label.add_theme_color_override("font_color", Color("#ffe39b")); root.add_child(selected_label)

func _panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box

func _seed_demo() -> void:
	_add_character("Red Rocket", 0, "Shooter")
	_add_character("Blue Bomber", 1, "Bomber")
	_add_character("Purple Splitter", 2, "Splitter")
	_add_character("Gold Randomizer", 3, "Randomizer")
	_add_character("Green Guardian", 4, "Guardian")

func _add_character_from_ui(name_text: String, team_index: int, template_text: String) -> void:
	var name_value := name_text.strip_edges()
	if name_value.is_empty():
		name_value = "Contestant " + str(next_id)
	_add_character(name_value, team_index, template_text)
	_select_ball(balls[-1].id)
	_update_roster()
	_update_script_panel()
	queue_redraw()

func _add_character(name_value: String, team_index: int, template_text: String) -> void:
	var pos := Vector2(
		randf_range(ARENA.position.x + 70, ARENA.end.x - 70),
		randf_range(ARENA.position.y + 70, ARENA.end.y - 70)
	)
	var vel := Vector2(randf_range(90.0, 180.0), randf_range(-120.0, 120.0))
	if randf() < 0.5:
		vel.x *= -1.0
	var ball := {
		"id": next_id,
		"name": name_value,
		"team": clampi(team_index, 0, TEAM_NAMES.size() - 1),
		"pos": pos,
		"vel": vel,
		"radius": 18.0,
		"mass": 1.0,
		"health": 100.0,
		"max_health": 100.0,
		"shield": 0.0,
		"cooldown": 0.0,
		"age": 0.0,
		"weapon_damage": 12.0,
		"weapon_speed": 340.0,
		"variables": {"rage": 0.0, "ammo": 8.0},
		"script": {"ON_HIT": [], "ON_WALL": [], "EVERY_3S": [], "ON_DAMAGE": [], "ON_DESTROY": []}
	}
	_apply_preset(ball, template_text)
	balls.append(ball)
	next_id += 1
	if selected_id == -1:
		selected_id = ball.id

func _apply_preset(ball: Dictionary, template_text: String) -> void:
	match template_text:
		"Shooter":
			ball.script["ON_HIT"] = ["SHOOT"]
			ball.script["EVERY_3S"] = ["SHOOT"]
		"Bomber":
			ball.script["EVERY_3S"] = ["DROP_BOMB"]
			ball.script["ON_WALL"] = ["SPEED_UP"]
		"Splitter":
			ball.script["ON_WALL"] = ["SPLIT"]
			ball.script["ON_HIT"] = ["SPEED_UP"]
		"Randomizer":
			ball.script["EVERY_3S"] = ["RANDOM_BLAST"]
			ball.script["ON_HIT"] = ["RANDOM_BLAST"]
		"Guardian":
			ball.script["EVERY_3S"] = ["CREATE_SHIELD"]
			ball.script["ON_DAMAGE"] = ["CREATE_SHIELD"]
		_:
			ball.script["ON_HIT"] = ["SPEED_UP"]
			ball.script["ON_WALL"] = ["SPEED_UP"]

func _select_ball(id: int) -> void:
	selected_id = id
	_update_roster()
	_update_script_panel()

func _attach_behavior(event_name: String, action_name: String) -> void:
	var ball := _get_selected_ball()
	if ball.is_empty():
		status_label.text = "Select a ball first"
		return
	if not ball.script.has(event_name):
		ball.script[event_name] = []
	ball.script[event_name].append(action_name)
	status_label.text = "Added %s -> %s" % [event_name, action_name]
	_update_script_panel()
	_update_roster()

func _get_selected_ball() -> Dictionary:
	for ball in balls:
		if ball.id == selected_id:
			return ball
	return {}

func _update_roster() -> void:
	var lines := ["ROSTER"]
	for ball in balls:
		var marker := "  "
		if ball.id == selected_id:
			marker = "> "
		lines.append(marker + str(ball.id) + "  " + ball.name + "  [" + TEAM_NAMES[ball.team] + "]  HP " + str(int(ball.health)))
	roster_label.text = "\n".join(lines)
	var selected := _get_selected_ball()
	if selected.is_empty():
		selected_label.text = "No selection"
		script_label.text = "Selected script: none"
	else:
		selected_label.text = selected.name + " • " + TEAM_NAMES[selected.team] + " • HP " + str(int(selected.health)) + " • Dmg " + str(int(selected.weapon_damage))
		_update_script_panel()

func _update_script_panel() -> void:
	var ball := _get_selected_ball()
	if ball.is_empty():
		script_label.text = "Selected script: none"
		return
	var parts: Array[String] = []
	for event_name in EVENT_LABELS:
		if ball.script.has(event_name) and ball.script[event_name].size() > 0:
			parts.append(event_name + ": " + ", ".join(ball.script[event_name]))
	script_label.text = "Selected script: " + (" | ".join(parts) if not parts.is_empty() else "empty")

func _start_simulation() -> void:
	running = true
	status_label.text = "Simulation running"

func _pause_simulation() -> void:
	running = not running
	status_label.text = "Simulation paused" if not running else "Simulation running"

func _stop_simulation() -> void:
	running = false
	for ball in balls:
		ball.vel = Vector2.ZERO
	status_label.text = "Simulation stopped"

func _restart_simulation() -> void:
	for ball in balls:
		ball.pos = Vector2(randf_range(ARENA.position.x + 60, ARENA.end.x - 60), randf_range(ARENA.position.y + 60, ARENA.end.y - 60))
		ball.vel = Vector2(randf_range(90.0, 180.0), randf_range(-120.0, 120.0))
		if randf() < 0.5:
			ball.vel.x *= -1.0
		ball.health = ball.max_health
		ball.shield = 0.0
		ball.cooldown = 0.0
		ball.age = 0.0
	projectiles.clear()
	effects.clear()
	running = false
	status_label.text = "Simulation reset"
	_update_roster()
	queue_redraw()

func _set_speed(s: float) -> void:
	time_scale = s
	speed_label.text = "Speed: " + str(s) + "x"

func _save_project() -> void:
	var payload := {"background": background.to_html(), "outline": outline.to_html(), "balls": []}
	for ball in balls:
		payload["balls"].append({
			"name": ball.name,
			"team": ball.team,
			"pos": [ball.pos.x, ball.pos.y],
			"vel": [ball.vel.x, ball.vel.y],
			"radius": ball.radius,
			"health": ball.health,
			"max_health": ball.max_health,
			"weapon_damage": ball.weapon_damage,
			"weapon_speed": ball.weapon_speed,
			"script": ball.script,
			"variables": ball.variables
		})
	var file := FileAccess.open(project_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))
		status_label.text = "Project saved to user://bounceforge_project.json"
	else:
		status_label.text = "Could not save project"

func _load_project() -> void:
	if not FileAccess.file_exists(project_file):
		status_label.text = "No saved project found"; return
	var file := FileAccess.open(project_file, FileAccess.READ)
	if not file:
		status_label.text = "Could not open saved project"; return
	var payload = JSON.parse_string(file.get_as_text())
	if typeof(payload) != TYPE_DICTIONARY:
		status_label.text = "Saved project invalid"; return
	if payload.has("background"):
		background = Color(payload["background"])
	if payload.has("outline"):
		outline = Color(payload["outline"])
	balls.clear(); projectiles.clear(); effects.clear();
	for entry in payload.get("balls", []):
		var ball := {
			"id": next_id,
			"name": str(entry.get("name", "Contestant " + str(next_id))),
			"team": int(entry.get("team", 0)),
			"pos": Vector2(float(entry.get("pos", [0.0, 0.0])[0]), float(entry.get("pos", [0.0, 0.0])[1])),
			"vel": Vector2(float(entry.get("vel", [0.0, 0.0])[0]), float(entry.get("vel", [0.0, 0.0])[1])),
			"radius": float(entry.get("radius", 18.0)),
			"mass": 1.0,
			"health": float(entry.get("health", 100.0)),
			"max_health": float(entry.get("max_health", 100.0)),
			"shield": 0.0,
			"cooldown": 0.0,
			"age": 0.0,
			"weapon_damage": float(entry.get("weapon_damage", 12.0)),
			"weapon_speed": float(entry.get("weapon_speed", 340.0)),
			"variables": entry.get("variables", {"rage": 0.0, "ammo": 8.0}),
			"script": entry.get("script", {"ON_HIT": [], "ON_WALL": [], "EVERY_3S": [], "ON_DAMAGE": [], "ON_DESTROY": []})
		}
		balls.append(ball)
		next_id += 1
	selected_id = balls[0].id if not balls.is_empty() else -1
	status_label.text = "Project loaded"
	_update_roster()
	_update_script_panel()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos := event.position
		for ball in balls:
			if ball.pos.distance_to(click_pos) <= ball.radius + 2.0:
				_select_ball(ball.id)
				return

func _process(delta: float) -> void:
	if running:
		_simulate(delta * time_scale)
	queue_redraw()

func _simulate(dt: float) -> void:
	for ball in balls:
		ball.age += dt
		ball.cooldown = max(0.0, ball.cooldown - dt)
		ball.shield = max(0.0, ball.shield - dt)
		ball.pos += ball.vel * dt
		if ball.pos.x - ball.radius < ARENA.position.x:
			ball.pos.x = ARENA.position.x + ball.radius
			ball.vel.x = abs(ball.vel.x)
			_trigger_behavior(ball, "ON_WALL")
		if ball.pos.x + ball.radius > ARENA.end.x:
			ball.pos.x = ARENA.end.x - ball.radius
			ball.vel.x = -abs(ball.vel.x)
			_trigger_behavior(ball, "ON_WALL")
		if ball.pos.y - ball.radius < ARENA.position.y:
			ball.pos.y = ARENA.position.y + ball.radius
			ball.vel.y = abs(ball.vel.y)
			_trigger_behavior(ball, "ON_WALL")
		if ball.pos.y + ball.radius > ARENA.end.y:
			ball.pos.y = ARENA.end.y - ball.radius
			ball.vel.y = -abs(ball.vel.y)
			_trigger_behavior(ball, "ON_WALL")
		if fmod(ball.age, 3.0) < dt:
			_trigger_behavior(ball, "EVERY_3S")

	for i in range(balls.size()):
		for j in range(i + 1, balls.size()):
			_resolve_ball_collision(balls[i], balls[j])

	for projectile in projectiles:
		projectile.pos += projectile.vel * dt
		projectile.life -= dt
		if projectile.pos.x < ARENA.position.x or projectile.pos.x > ARENA.end.x:
			projectile.vel.x *= -1.0
		if projectile.pos.y < ARENA.position.y or projectile.pos.y > ARENA.end.y:
			projectile.vel.y *= -1.0
		for ball in balls:
			if ball.id == projectile.owner_id:
				continue
			if ball.team == projectile.team:
				continue
			if projectile.pos.distance_to(ball.pos) <= projectile.radius + ball.radius:
				_apply_damage(ball, projectile.damage, projectile.owner_id)
				projectile.life = 0.0
				break
		if projectile.life <= 0.0:
			_effect(projectile.pos, "blast", Color("#ffd06e"), 0.25)
	projectiles = projectiles.filter(func(item): return item.life > 0.0)
	for effect in effects:
		effect.life -= dt
	effects = effects.filter(func(item): return item.life > 0.0)
	for ball in balls:
		if ball.health <= 0.0:
			_trigger_behavior(ball, "ON_DESTROY")
	balls = balls.filter(func(item): return item.health > 0.0)
	if selected_id != -1 and _get_selected_ball().is_empty():
		selected_id = balls[0].id if not balls.is_empty() else -1
	_update_roster()
	_update_script_panel()

func _resolve_ball_collision(a: Dictionary, b: Dictionary) -> void:
	var diff := a.pos - b.pos
	var dist_sq := diff.length_squared()
	var min_dist := a.radius + b.radius
	if dist_sq <= 0.0 or dist_sq >= min_dist * min_dist:
		return
	var dist := sqrt(dist_sq)
	var normal := diff.normalized() if dist > 0.0 else Vector2.RIGHT
	var overlap := min_dist - dist
	a.pos += normal * overlap * 0.5
	b.pos -= normal * overlap * 0.5
	var relative_velocity := b.vel - a.vel
	var impulse := relative_velocity.dot(normal)
	if impulse > 0.0:
		return
	var restitution := 0.9
	var correction := -(1.0 + restitution) * impulse / (1.0 / a.mass + 1.0 / b.mass)
	var impulse_vector := correction * normal
	a.vel -= impulse_vector / a.mass
	b.vel += impulse_vector / b.mass
	_trigger_behavior(a, "ON_HIT")
	_trigger_behavior(b, "ON_HIT")

func _trigger_behavior(ball: Dictionary, event_name: String) -> void:
	if ball.is_empty():
		return
	for action in ball.script.get(event_name, []):
		_execute_action(ball, action)

func _execute_action(ball: Dictionary, action_name: String) -> void:
	match action_name:
		"SHOOT":
			_spawn_projectile(ball, ball.weapon_speed, 18.0)
		"DROP_BOMB":
			_effect(ball.pos + Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0)), "bomb", Color("#ffb14c"), 0.45)
			for other in balls:
				if other.id == ball.id: continue
				if other.team == ball.team: continue
				if ball.pos.distance_to(other.pos) <= 75.0:
					_apply_damage(other, 16.0, ball.id)
		"RANDOM_BLAST":
			_random_blast(ball)
		"SPLIT":
			_split_ball(ball)
		"CREATE_SHIELD":
			ball.shield = 2.0
		"SPEED_UP":
			ball.vel *= 1.12
		"SUMMON_MINION":
			_add_character(ball.name + " Minion", ball.team, "Shooter")
			balls[-1].pos = ball.pos + Vector2(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0))
			balls[-1].vel = ball.vel * 1.15
		"TELEPORT":
			ball.pos = Vector2(randf_range(ARENA.position.x + 40, ARENA.end.x - 40), randf_range(ARENA.position.y + 40, ARENA.end.y - 40))
		"HEAL":
			ball.health = min(ball.max_health, ball.health + 20.0)
		"PUSH_AWAY":
			for other in balls:
				if other.id == ball.id: continue
				if other.team == ball.team: continue
				var dir := (other.pos - ball.pos).normalized()
				other.vel += dir * 90.0
		"SET_RANDOM_VELOCITY":
			ball.vel = Vector2(randf_range(-220.0, 220.0), randf_range(-220.0, 220.0))
		"RAIN_EFFECT":
			for i in range(5):
				var p := Vector2(randf_range(ARENA.position.x, ARENA.end.x), randf_range(ARENA.position.y, ARENA.end.y))
				_effect(p, "rain", Color("#82d8ff"), 0.3)
		_:
			pass

func _spawn_projectile(ball: Dictionary, speed: float, radius: float) -> void:
	var direction := ball.vel.normalized();
	if direction.length() < 0.1:
		direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	projectiles.append({
		"pos": ball.pos + direction * (ball.radius + radius + 6.0),
		"vel": direction * speed,
		"radius": radius,
		"damage": ball.weapon_damage,
		"owner_id": ball.id,
		"team": ball.team,
		"life": 3.5
	})
	_effect(ball.pos, "muzzle", Color("#dfeaff"), 0.12)

func _random_blast(ball: Dictionary) -> void:
	var target := Vector2(randf_range(ARENA.position.x + 20.0, ARENA.end.x - 20.0), randf_range(ARENA.position.y + 20.0, ARENA.end.y - 20.0))
	_effect(target, "blast", Color("#ff8a5c"), 0.5)
	for other in balls:
		if other.team == ball.team:
			continue
		if other.pos.distance_to(target) <= 90.0:
			_apply_damage(other, 18.0, ball.id)

func _split_ball(ball: Dictionary) -> void:
	if balls.size() >= 40:
		return
	var clone := {
		"id": next_id,
		"name": ball.name + " mini",
		"team": ball.team,
		"pos": ball.pos + Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0)),
		"vel": ball.vel * 1.25 + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0)),
		"radius": max(8.0, ball.radius * 0.68),
		"mass": 0.7,
		"health": 40.0,
		"max_health": 40.0,
		"shield": 0.0,
		"cooldown": 0.0,
		"age": 0.0,
		"weapon_damage": 8.0,
		"weapon_speed": 280.0,
		"variables": {"rage": 0.0, "ammo": 2.0},
		"script": {
			"ON_HIT": ["SPEED_UP"],
			"ON_WALL": ["SPEED_UP"],
			"EVERY_3S": ["SHOOT"],
			"ON_DAMAGE": [],
			"ON_DESTROY": []
		}
	}
	balls.append(clone)
	next_id += 1
	ball.health = max(0.0, ball.health - 15.0)

func _effect(pos: Vector2, kind: String, color: Color, duration: float) -> void:
	effects.append({"pos": pos, "kind": kind, "color": color, "life": duration})

func _apply_damage(ball: Dictionary, amount: float, attacker_id: int = -1) -> void:
	if ball.is_empty():
		return
	if ball.shield > 0.0:
		ball.shield = 0.0
		_trigger_behavior(ball, "ON_DAMAGE")
		return
	ball.health -= amount
	ball.vel *= 1.07
	if attacker_id != -1:
		ball.variables["rage"] = float(ball.variables.get("rage", 0.0)) + 1.0
		_trigger_behavior(ball, "ON_DAMAGE")
	if ball.health <= 0.0:
		_trigger_behavior(ball, "ON_DESTROY")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1180, 760)), Color("#0a101c"))
	draw_rect(ARENA, background, true)
	draw_rect(Rect2(ARENA.position + Vector2(2, 2), Vector2(ARENA.size.x - 4, ARENA.size.y - 4)), color_with_alpha(outline, 0.25), false)

	for ball in balls:
		var base_color := TEAM_COLORS[ball.team % TEAM_COLORS.size()]
		draw_circle(ball.pos, ball.radius + 3.0, color_with_alpha(base_color, 0.18))
		draw_circle(ball.pos, ball.radius, base_color)
		draw_arc(ball.pos, ball.radius + 2.0, 0.0, TAU, 18, Color("#f6fbff"), 1.2)
		if ball.shield > 0.0:
			draw_arc(ball.pos, ball.radius + 8.0, 0.0, TAU, 24, Color("#7fe7ff"), 2.0)
		var hp_ratio := clamp(ball.health / max(ball.max_health, 1.0), 0.0, 1.0)
		draw_rect(Rect2(ball.pos.x - 18.0, ball.pos.y - ball.radius - 14.0, 36.0, 4.0), Color("#2d3a59"))
		draw_rect(Rect2(ball.pos.x - 18.0, ball.pos.y - ball.radius - 14.0, 36.0 * hp_ratio, 4.0), Color("#7ee5a7"))
		draw_string(ThemeDB.fallback_font, ball.pos + Vector2(-ball.radius, ball.radius + 16.0), ball.name, HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color("#edf2ff"))

	for projectile in projectiles:
		draw_circle(projectile.pos, projectile.radius, TEAM_COLORS[projectile.team % TEAM_COLORS.size()])
		draw_line(projectile.pos, projectile.pos - projectile.vel.normalized() * 10.0, Color("#f6ffb3"), 1.5)

	for effect in effects:
		var radius := 12.0 + (1.0 - effect.life / 0.8) * 26.0
		draw_arc(effect.pos, radius, 0.0, TAU, 18, color_with_alpha(effect.color, 0.8), 2.5)

func color_with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
