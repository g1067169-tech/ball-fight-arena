extends Node2D
## BounceForge Arena - a small, playable foundation for programmable physics battles.
## Entities are intentionally simple: position + velocity + event-driven behavior blocks.

const ARENA := Rect2(24, 86, 842, 650)
const PANEL_X := 886.0
const COLORS := [Color("#ff5572"), Color("#55a7ff"), Color("#a877ff"), Color("#ffc857"), Color("#55d69a")]
const TEAM_NAMES := ["RED", "BLUE", "PURPLE", "GOLD", "GREEN"]

var balls: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var running := false
var time_scale := 1.0
var elapsed := 0.0
var next_id := 1
var selected_id := -1
var background := Color("#101522")
var outline := Color("#41516e")
var status_label: Label
var roster_label: Label
var selected_label: Label
var speed_label: Label
var behavior_label: Label
var team_option: OptionButton
var behavior_option: OptionButton
var name_edit: LineEdit
var add_button: Button
var pause_button: Button
var start_button: Button
var color_bg: ColorPickerButton
var color_outline: ColorPickerButton

func _ready() -> void:
	_build_ui()
	_add_ball(0, "Red Rocket", "SHOOT_ON_HIT")
	_add_ball(1, "Blue Bomber", "DROP_BOMBS")
	_add_ball(2, "Purple Splitter", "SPLIT_ON_WALL")
	_add_ball(3, "Gold Randomizer", "RANDOM_BLAST")
	_select_ball(1)
	queue_redraw()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var title := Label.new()
	title.position = Vector2(24, 18)
	title.text = "BOUNCEFORGE  /  ARENA"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#e9f0ff"))
	root.add_child(title)
	var sub := Label.new()
	sub.position = Vector2(315, 25)
	sub.text = "Physics sandbox  •  programmable objects  •  no pathfinding"
	sub.add_theme_color_override("font_color", Color("#8998b7"))
	root.add_child(sub)
	var panel := Panel.new()
	panel.position = Vector2(PANEL_X, 14)
	panel.size = Vector2(280, 722)
	panel.add_theme_stylebox_override("panel", _box(Color("#171f30"), Color("#2b3954"), 12))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.position = Vector2(18, 16)
	v.size = Vector2(244, 690)
	v.add_theme_constant_override("separation", 9)
	panel.add_child(v)
	var ptitle := Label.new()
	ptitle.text = "SIMULATION CONTROL"
	ptitle.add_theme_font_size_override("font_size", 15)
	ptitle.add_theme_color_override("font_color", Color("#79d7ff"))
	v.add_child(ptitle)
	start_button = _button("START SIMULATION", _start)
	v.add_child(start_button)
	pause_button = _button("PAUSE", _pause)
	v.add_child(pause_button)
	var restart := _button("RESTART", _restart)
	v.add_child(restart)
	status_label = Label.new()
	status_label.text = "READY • Add contestants and press START"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("#a9b7d2"))
	v.add_child(status_label)
	var sep := HSeparator.new(); v.add_child(sep)
	var speed_title := Label.new(); speed_title.text = "SIMULATION SPEED"; v.add_child(speed_title)
	var speeds := HBoxContainer.new(); v.add_child(speeds)
	for s in [0.25, 0.5, 1.0, 2.0]:
		var b := _button(str(s) + "x", func(): _set_speed(s)); b.custom_minimum_size.x = 54; speeds.add_child(b)
	speed_label = Label.new(); speed_label.text = "Speed: 1.0x"; speed_label.add_theme_color_override("font_color", Color("#79d7ff")); v.add_child(speed_label)
	sep = HSeparator.new(); v.add_child(sep)
	var ctitle := Label.new(); ctitle.text = "ADD CONTESTANT"; ctitle.add_theme_font_size_override("font_size", 15); ctitle.add_theme_color_override("font_color", Color("#79d7ff")); v.add_child(ctitle)
	name_edit = LineEdit.new(); name_edit.placeholder_text = "Name (optional)"; v.add_child(name_edit)
	team_option = OptionButton.new()
	for n in TEAM_NAMES: team_option.add_item(n)
	team_option.selected = 0
	v.add_child(team_option)
	behavior_option = OptionButton.new()
	behavior_option.add_item("Simple Bouncer")
	behavior_option.add_item("Shoot on Touch")
	behavior_option.add_item("Drop Bombs")
	behavior_option.add_item("Split on Wall")
	behavior_option.add_item("Random Blast")
	v.add_child(behavior_option)
	add_button = _button("+ ADD BALL", _add_from_ui); v.add_child(add_button)
	sep = HSeparator.new(); v.add_child(sep)
	var stitle := Label.new(); stitle.text = "SELECTED OBJECT"; stitle.add_theme_font_size_override("font_size", 15); stitle.add_theme_color_override("font_color", Color("#79d7ff")); v.add_child(stitle)
	selected_label = Label.new(); selected_label.text = "None"; selected_label.add_theme_color_override("font_color", Color("#f5d77a")); v.add_child(selected_label)
	var btitle := Label.new(); btitle.text = "BLOCK STUDIO  •  add behavior blocks"; btitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(btitle)
	var block_row := GridContainer.new(); block_row.columns = 2; block_row.add_theme_constant_override("h_separation", 5); block_row.add_theme_constant_override("v_separation", 5); v.add_child(block_row)
	for data in [["WHEN HIT", "ON_HIT"], ["EVERY 3 SEC", "TIMER"], ["ON WALL", "ON_WALL"], ["RANDOM", "RANDOM"]]:
		var b := _button(data[0], func(): _add_block(data[1])); b.custom_minimum_size = Vector2(116, 30); block_row.add_child(b)
	behavior_label = Label.new(); behavior_label.text = "Blocks: —"; behavior_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; behavior_label.add_theme_color_override("font_color", Color("#a9b7d2")); v.add_child(behavior_label)
	sep = HSeparator.new(); v.add_child(sep)
	var atitle := Label.new(); atitle.text = "ARENA STYLE"; atitle.add_theme_font_size_override("font_size", 15); atitle.add_theme_color_override("font_color", Color("#79d7ff")); v.add_child(atitle)
	color_bg = ColorPickerButton.new(); color_bg.text = "Background color"; color_bg.color = background; color_bg.color_changed.connect(_bg_changed); v.add_child(color_bg)
	color_outline = ColorPickerButton.new(); color_outline.text = "Outline color"; color_outline.color = outline; color_outline.color_changed.connect(_outline_changed); v.add_child(color_outline)
	roster_label = Label.new(); roster_label.position = Vector2(42, 104); roster_label.add_theme_color_override("font_color", Color("#8fa2c4")); root.add_child(roster_label)

func _box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var x := StyleBoxFlat.new(); x.bg_color = bg; x.border_color = border
	x.set_border_width_all(1); x.set_corner_radius_all(radius); return x

func _button(text: String, action: Callable) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size.y = 34; b.pressed.connect(action); return b

func _add_from_ui() -> void:
	var n := name_edit.text.strip_edges()
	if n.is_empty(): n = "Contestant " + str(next_id)
	var key := ["BOUNCE", "SHOOT_ON_HIT", "DROP_BOMBS", "SPLIT_ON_WALL", "RANDOM_BLAST"][behavior_option.selected]
	_add_ball(team_option.selected, n, key)
	name_edit.clear()

func _add_ball(team: int, display_name: String, behavior: String, pos := Vector2(-1, -1), vel := Vector2(-1, -1)) -> void:
	var p := pos if pos.x >= 0 else Vector2(100 + fmod(float(next_id * 113), 670.0), 140 + fmod(float(next_id * 71), 500.0))
	var v := vel if vel.x >= 0 else Vector2(110 + fmod(float(next_id * 37), 100.0), -90 - fmod(float(next_id * 23), 100.0))
	balls.append({"id": next_id, "name": display_name, "team": team, "pos": p, "vel": v, "radius": 18.0, "health": 100.0, "max_health": 100.0, "behavior": behavior, "blocks": [behavior], "cooldown": 0.0, "age": 0.0, "hits": 0, "shield": 0.0})
	selected_id = next_id; next_id += 1; _refresh_ui(); queue_redraw()

func _select_ball(id: int) -> void:
	selected_id = id; _refresh_ui()

func _refresh_ui() -> void:
	var lines := ["ROSTER"]
	for b in balls:
		lines.append(("> " if b.id == selected_id else "  ") + str(b.id) + "  " + b.name + "  [" + TEAM_NAMES[b.team] + "]")
	roster_label.text = "\n".join(lines)
	var found := _find_ball(selected_id)
	if found.is_empty(): selected_label.text = "None"; behavior_label.text = "Blocks: —"
	else:
		selected_label.text = found.name + "  •  HP " + str(round(found.health)) + "  •  " + TEAM_NAMES[found.team]
		behavior_label.text = "Blocks: " + ", ".join(found.blocks)

func _find_ball(id: int) -> Dictionary:
	for b in balls:
		if b.id == id: return b
	return {}

func _start() -> void:
	running = true; status_label.text = "RUNNING • Watch the systems collide"; start_button.disabled = true
func _pause() -> void:
	running = not running; status_label.text = "RUNNING • Physics live" if running else "PAUSED • Press PAUSE to resume"; start_button.disabled = running
func _restart() -> void:
	for b in balls:
		b.pos = Vector2(100 + fmod(float(b.id * 113), 670.0), 140 + fmod(float(b.id * 71), 500.0)); b.health = b.max_health; b.age = 0; b.cooldown = 0; b.shield = 0
	projectiles.clear(); effects.clear(); elapsed = 0; running = false; start_button.disabled = false; status_label.text = "READY • Simulation restarted"; queue_redraw()
func _set_speed(s: float) -> void:
	time_scale = s; speed_label.text = "Speed: " + str(s) + "x"
func _bg_changed(c: Color) -> void: background = c; queue_redraw()
func _outline_changed(c: Color) -> void: outline = c; queue_redraw()

func _add_block(block: String) -> void:
	var b := _find_ball(selected_id)
	if b.is_empty(): return
	b.blocks.append(block); behavior_label.text = "Blocks: " + ", ".join(b.blocks)

func _process(delta: float) -> void:
	if running: _simulate(delta * time_scale)
	queue_redraw()

func _simulate(dt: float) -> void:
	elapsed += dt
	for b in balls:
		b.age += dt; b.cooldown = max(0.0, b.cooldown - dt); b.shield = max(0.0, b.shield - dt)
		b.pos += b.vel * dt
		var bounced := false
		if b.pos.x - b.radius < ARENA.position.x: b.pos.x = ARENA.position.x + b.radius; b.vel.x = abs(b.vel.x); bounced = true
		if b.pos.x + b.radius > ARENA.end.x: b.pos.x = ARENA.end.x - b.radius; b.vel.x = -abs(b.vel.x); bounced = true
		if b.pos.y - b.radius < ARENA.position.y: b.pos.y = ARENA.position.y + b.radius; b.vel.y = abs(b.vel.y); bounced = true
		if b.pos.y + b.radius > ARENA.end.y: b.pos.y = ARENA.end.y - b.radius; b.vel.y = -abs(b.vel.y); bounced = true
		if bounced: _event(b, "ON_WALL")
		if "TIMER" in b.blocks and fmod(b.age, 3.0) < dt: _shoot(b)
		if b.behavior == "DROP_BOMBS" and fmod(b.age, 3.2) < dt: _bomb(b)
		if b.behavior == "RANDOM_BLAST" and fmod(b.age, 4.5) < dt: _random_blast(b)
	for i in range(balls.size()):
		for j in range(i + 1, balls.size()): _ball_collision(balls[i], balls[j])
	for p in projectiles.duplicate():
		p.pos += p.vel * dt; p.life -= dt
		if p.pos.x < ARENA.position.x or p.pos.x > ARENA.end.x: p.vel.x *= -1
		if p.pos.y < ARENA.position.y or p.pos.y > ARENA.end.y: p.vel.y *= -1
		for b in balls:
			if b.id != p.owner and b.team != p.team and b.pos.distance_to(p.pos) < b.radius + 6:
				_damage(b, p.damage); p.life = 0; break
		if p.life <= 0: projectiles.erase(p)
	for e in effects.duplicate():
		e.life -= dt
		if e.life <= 0: effects.erase(e)
	balls = balls.filter(func(x): return x.health > 0)
	if selected_id != -1 and _find_ball(selected_id).is_empty(): selected_id = balls[0].id if not balls.is_empty() else -1
	_refresh_ui()

func _ball_collision(a: Dictionary, b: Dictionary) -> void:
	var d := a.pos.distance_to(b.pos); var min_d := a.radius + b.radius
	if d > 0 and d < min_d:
		var n := (a.pos - b.pos).normalized(); var overlap := min_d - d
		a.pos += n * overlap * 0.5; b.pos -= n * overlap * 0.5
		var av := a.vel; a.vel = av - n * (2.0 * (av - b.vel).dot(n) * b.get("mass", 1.0) / 2.0); b.vel = b.vel + n * (2.0 * (av - b.vel).dot(n) * a.get("mass", 1.0) / 2.0)
		_event(a, "ON_HIT"); _event(b, "ON_HIT")

func _event(b: Dictionary, event: String) -> void:
	if event == "ON_HIT" and b.behavior == "SHOOT_ON_HIT": _shoot(b)
	if event == "ON_WALL" and b.behavior == "SPLIT_ON_WALL" and b.cooldown <= 0 and balls.size() < 28:
		b.cooldown = 2.0; _add_ball(b.team, b.name + " mini", "BOUNCE", b.pos, Vector2(-b.vel.y, b.vel.x)); balls[-1].radius = 10; balls[-1].health = 35; balls[-1].max_health = 35
	if event == "ON_HIT" and "RANDOM" in b.blocks and b.cooldown <= 0: _random_blast(b)

func _shoot(b: Dictionary) -> void:
	if b.cooldown > 0: return
	b.cooldown = 0.55; var dir := b.vel.normalized(); projectiles.append({"pos": b.pos + dir * 20, "vel": dir * 360, "owner": b.id, "team": b.team, "damage": 14.0, "life": 3.0}); effects.append({"pos": b.pos, "life": 0.12, "kind": "muzzle"})
func _bomb(b: Dictionary) -> void:
	if b.cooldown > 0: return
	b.cooldown = 3.0; effects.append({"pos": b.pos + Vector2(randf_range(-80,80), randf_range(-80,80)), "life": 0.8, "kind": "bomb"})
func _random_blast(b: Dictionary) -> void:
	if b.cooldown > 0: return
	b.cooldown = 1.0; var at := Vector2(randf_range(ARENA.position.x + 20, ARENA.end.x - 20), randf_range(ARENA.position.y + 20, ARENA.end.y - 20)); effects.append({"pos": at, "life": 0.35, "kind": "blast"})
	for other in balls:
		if other.team != b.team and other.pos.distance_to(at) < 95: _damage(other, 10)
func _damage(b: Dictionary, amount: float) -> void:
	if b.shield > 0: b.shield = 0; return
	b.health -= amount; b.hits += 1; b.vel *= 1.04

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1180, 760)), Color("#0b0f18"))
	draw_style_box(_box(background, outline, 10), ARENA)
	draw_line(ARENA.position, Vector2(ARENA.end.x, ARENA.position.y), outline, 3)
	draw_line(Vector2(ARENA.position.x, ARENA.end.y), ARENA.end, outline, 3)
	for b in balls:
		var c: Color = COLORS[b.team]; draw_circle(b.pos, b.radius + 3, Color(c, 0.13)); draw_circle(b.pos, b.radius, c); draw_arc(b.pos, b.radius, 0, TAU, 24, Color("#ffffff"), 1.5)
		if b.shield > 0: draw_arc(b.pos, b.radius + 6, 0, TAU, 24, Color("#75e6ff"), 3)
		var hp := max(0.0, b.health / b.max_health); draw_rect(Rect2(b.pos + Vector2(-20, -b.radius - 12), Vector2(40 * hp, 3)), Color("#7df0a6")); draw_string(ThemeDB.fallback_font, b.pos + Vector2(-b.radius, b.radius + 15), b.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#dce6ff"))
	for p in projectiles: draw_circle(p.pos, 5, COLORS[p.team]); draw_line(p.pos, p.pos - p.vel.normalized() * 10, Color("#fff1a8"), 2)
	for e in effects:
		var r := 25.0 * (1.0 - e.life / 0.8) if e.kind == "bomb" else 70.0 * (1.0 - e.life / 0.35)
		draw_arc(e.pos, r, 0, TAU, 24, Color("#ffb84d", e.life / 0.8), 3)
