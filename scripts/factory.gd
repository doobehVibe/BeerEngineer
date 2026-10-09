extends Node2D
## BeerEngineer — slice 1: brouwketen + order, top-down grid, muis+keyboard.
## Placeholder-visuals in code; 16-bit art wordt later gegenereerd.

const CELL := 48
const COLS := 12
const ROWS := 8

const STEP_NAMES := ["Schroten", "Maischen", "Koken", "Vergisten", "Rijpen"]
const STEP_TIMES := [3.0, 4.0, 4.0, 6.0, 6.0]
const STEP_COLORS := [
	Color(0.55, 0.40, 0.25), Color(0.60, 0.55, 0.30), Color(0.75, 0.30, 0.15),
	Color(0.40, 0.60, 0.35), Color(0.45, 0.35, 0.55),
]
const RECIPE := {"grain": 2, "hops": 1, "yeast": 1}
const ING_NAMES := {"grain": "Graan", "hops": "Hop", "yeast": "Gist"}
const ING_COLORS := {
	"grain": Color(0.80, 0.65, 0.30),
	"hops": Color(0.40, 0.70, 0.30),
	"yeast": Color(0.90, 0.85, 0.60),
}
const BATCH_SIZE := 5
const UNIT_PRICE := 8
const ORDER_SIZE := 5
const CAM_SPEED := 500.0

var money := 100
var inv := {"grain": 4, "hops": 2, "yeast": 2}
const ING_PRICES := {"grain": 2, "hops": 3, "yeast": 4}

var machines: Array[Node2D] = []
var cam: Camera2D
var ui := {}
var storage_beer := 0
var delivered := 0

var drag_item: String = ""   # "ingredient:<type>" | "batch:<step>" | "beer"
var drag_count := 0
var drag_source: Node2D = null
var ghost: ColorRect = null

func _ready() -> void:
	randomize()
	_build_floor()
	_build_machines()
	_build_storage()
	_build_shop_panel()
	_build_order_panel()
	_build_hud()
	cam = Camera2D.new()
	cam.zoom = Vector2(1, 1)
	cam.position = Vector2(COLS * CELL * 0.5, ROWS * CELL * 0.5)
	add_child(cam)
	cam.make_current()
	_update_hud()

## ---------- Bouw ----------

func _build_floor() -> void:
	for y in ROWS:
		for x in COLS:
			var c := ColorRect.new()
			c.color = Color(0.13, 0.15, 0.18) if (x + y) % 2 == 0 else Color(0.16, 0.18, 0.21)
			c.position = Vector2(x * CELL, y * CELL)
			c.size = Vector2(CELL, CELL)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(c)

func _build_machines() -> void:
	for i in STEP_NAMES.size():
		var m := Node2D.new()
		m.set_script(load("res://scripts/machine.gd"))
		m.step_index = i
		m.position = Vector2((2 + i * 2) * CELL, 3 * CELL)
		add_child(m)
		machines.append(m)

func _build_storage() -> void:
	var box := ColorRect.new()
	box.color = Color(0.35, 0.25, 0.15)
	box.position = Vector2(11 * CELL, 6 * CELL)
	box.size = Vector2(CELL, CELL)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	ui["storage_box"] = box
	var lbl := _make_label("Bier: 0", Vector2(11 * CELL, 7 * CELL + 4), 12)
	add_child(lbl)
	ui["storage_label"] = lbl

func _build_shop_panel() -> void:
	var panel := _make_panel(Vector2(16, 16), Vector2(340, 104), "Leverancier")
	add_child(panel)
	var x := 120.0
	for item in ["grain", "hops", "yeast"]:
		var btn := Button.new()
		btn.position = Vector2(x, 34)
		btn.size = Vector2(56, 56)
		btn.modulate = ING_COLORS[item]
		btn.tooltip_text = "%s kopen — %d goud (je hebt er %d)" % [ING_NAMES[item], ING_PRICES[item], inv[item]]
		btn.pressed.connect(func() -> void: _buy(item))
		panel.add_child(btn)
		x += 72.0

func _build_order_panel() -> void:
	var panel := _make_panel(Vector2(16, 136), Vector2(340, 130), "Order: De Zythoeker")
	add_child(panel)
	var lbl := _make_label("", Vector2(120, 148), 13)
	add_child(lbl)
	ui["order_label"] = lbl
	var area := ColorRect.new()
	area.color = Color(0.20, 0.25, 0.20, 0.95)
	area.position = Vector2(120, 172)
	area.size = Vector2(220, 70)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(area)
	ui["order_area"] = area
	panel.add_child(_make_label("Sleep bier hierheen om te leveren", Vector2(128, 196), 11))

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := _make_panel(Vector2(400, 16), Vector2(864, 40), "")
	layer.add_child(panel)
	ui["money"] = _make_label("", Vector2(416, 26), 15)
	layer.add_child(ui["money"])
	ui["inv"] = _make_label("", Vector2(530, 26), 15)
	layer.add_child(ui["inv"])
	ui["tip"] = _make_label("", Vector2(16, 688), 13)
	layer.add_child(ui["tip"])

func _make_panel(pos: Vector2, size: Vector2, title: String) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	if title != "":
		p.add_child(_make_label(title, Vector2(8, 4), 14))
	return p

func _make_label(text: String, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	return l

## ---------- Spelersacties ----------

func _buy(item: String) -> void:
	if money >= ING_PRICES[item]:
		money -= ING_PRICES[item]
		inv[item] += 1
		_update_hud()

func has_recipe() -> bool:
	for k in RECIPE:
		if inv[k] < RECIPE[k]:
			return false
	return true

func consume_recipe() -> void:
	for k in RECIPE:
		inv[k] -= RECIPE[k]
	_update_hud()

func _update_hud() -> void:
	ui["money"].text = "Geld: %d" % money
	ui["inv"].text = "Graan: %d   Hop: %d   Gist: %d" % [inv["grain"], inv["hops"], inv["yeast"]]
	ui["order_label"].text = "Pils %d/%d  (%d goud/unit)" % [delivered, ORDER_SIZE, UNIT_PRICE]
	ui["storage_label"].text = "Bier: %d" % storage_beer

## ---------- Drag & drop ----------

func start_drag(item: String, count: int, source: Node2D, color: Color) -> void:
	cancel_drag()
	drag_item = item
	drag_count = count
	drag_source = source
	ghost = ColorRect.new()
	ghost.color = color
	ghost.size = Vector2(26, 26)
	add_child(ghost)

func cancel_drag() -> void:
	if ghost:
		ghost.queue_free()
		ghost = null
	drag_item = ""
	drag_count = 0
	drag_source = null

func _return_drag() -> void:
	if drag_item.begins_with("ingredient:"):
		inv[drag_item.split(":")[1]] += drag_count
	elif drag_item.begins_with("batch:"):
		drag_source.buffer_ready = true
	elif drag_item == "beer":
		storage_beer += drag_count
	_update_hud()

## ---------- Input ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var pos := get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if drag_item != "":
				_return_drag()
				cancel_drag()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom = (cam.zoom * 1.1).clamp(Vector2(0.5, 0.5), Vector2(2.0, 2.0))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom = (cam.zoom / 1.1).clamp(Vector2(0.5, 0.5), Vector2(2.0, 2.0))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(pos)
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
		cam.position -= event.relative / cam.zoom

func _handle_left_click(pos: Vector2) -> void:
	# 1. Order-gebied (levert bier uit de drag)
	if drag_item == "beer" and _in_order_area(pos):
		_deliver()
		return
	# 2. Machines
	for m in machines:
		if m.is_clicked(pos):
			_click_machine(m)
			return
	# 3. Opslagbox: bier oppakken
	if drag_item == "" and _in_storage(pos) and storage_beer > 0:
		storage_beer -= 1
		_update_hud()
		start_drag("beer", 1, null, Color(0.85, 0.6, 0.1))
	# 4. Leeg gebied met drag: annuleren behalve als drag begon bij klik — niets doen
	if drag_item == "":
		cancel_drag()

func _click_machine(m: Node2D) -> void:
	if m.buffer_ready:
		if drag_item != "":
			return
		m.buffer_ready = false
		if m.step_index == STEP_NAMES.size() - 1:
			# Rijpen klaar → bier gaat naar opslag (batch)
			storage_beer += BATCH_SIZE
			_update_hud()
		else:
			start_drag("batch:%d" % m.step_index, BATCH_SIZE, m, STEP_COLORS[m.step_index + 1])
	if m.step_index == 0 and drag_item == "":
		# Schrotmolen: recept-check en start (ingredienten uit je voorraad)
		if has_recipe():
			consume_recipe()
			m.working = true
			m.time_left = STEP_TIMES[0]
		else:
			_tip("Recept Pils nodig: 2 graan, 1 hop, 1 gist")
	elif drag_item.begins_with("batch:") and m.step_index == int(drag_item.split(":")[1]) + 1:
		# Output vorige stap → input deze machine
		drag_item = ""
		drag_count = 0
		if ghost:
			ghost.queue_free()
			ghost = null
		drag_source = null
		m.working = true
		m.time_left = STEP_TIMES[m.step_index]

func _deliver() -> void:
	var take := mini(drag_count, ORDER_SIZE - delivered)
	delivered += take
	drag_count -= take
	money += take * UNIT_PRICE
	if delivered >= ORDER_SIZE:
		delivered = 0
		_tip("Order geleverd! Nieuwe order binnengekomen.")
	if drag_count <= 0:
		cancel_drag()
	_update_hud()

func _in_order_area(pos: Vector2) -> bool:
	var a: ColorRect = ui["order_area"]
	var gp := a.global_position
	return pos.x >= gp.x and pos.x <= gp.x + a.size.x and pos.y >= gp.y and pos.y <= gp.y + a.size.y

func _in_storage(pos: Vector2) -> bool:
	var b: ColorRect = ui["storage_box"]
	return pos.x >= b.position.x and pos.x <= b.position.x + b.size.x \
		and pos.y >= b.position.y and pos.y <= b.position.y + b.size.y

## ---------- Tooltip & camera ----------

func _process(delta: float) -> void:
	if ghost:
		ghost.global_position = get_global_mouse_position() - Vector2(13, 13)
	var dir := Input.get_vector("pan_left", "pan_right", "pan_up", "pan_down")
	cam.position += dir * CAM_SPEED * delta / cam.zoom.x
	var pos := get_global_mouse_position()
	var tip := ""
	for m in machines:
		if m.is_clicked(pos):
			tip = m.tooltip()
			break
	if tip != "":
		ui["tip"].text = tip
	else:
		ui["tip"].text = ""

func _tip(text: String) -> void:
	ui["tip"].text = text
