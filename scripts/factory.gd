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
const ING_SHORT := {"grain": "Gr", "hops": "Hp", "yeast": "Gi"}
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
	_build_floor()
	_build_machines()
	_build_storage()
	_build_ui()
	cam = Camera2D.new()
	cam.zoom = Vector2(1, 1)
	cam.position = Vector2(COLS * CELL * 0.5, ROWS * CELL * 0.5)
	add_child(cam)
	cam.make_current()
	_update_hud()

## ---------- Wereld ----------

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
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	ui["storage_label"] = lbl

## ---------- UI (screen-space, altijd bovenop) ----------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui["layer"] = layer

	# HUD boven: geld + klikbare ingredienten-iconen + orderknop
	var hud := Panel.new()
	hud.position = Vector2(0, 0)
	hud.size = Vector2(1280, 56)
	layer.add_child(hud)
	ui["money"] = _make_label("", Vector2(16, 17), 16)
	layer.add_child(ui["money"])

	var x := 180.0
	for item in ["grain", "hops", "yeast"]:
		var btn := Button.new()
		btn.position = Vector2(x, 8)
		btn.size = Vector2(90, 40)
		btn.modulate = Color(0.9, 0.9, 0.9)
		var picked_item: String = item
		btn.pressed.connect(func() -> void: _pick_ingredient(picked_item))
		layer.add_child(btn)
		ui["icon_" + item] = btn
		x += 100.0
	ui["inv"] = _make_label("", Vector2(180, 62), 13)
	layer.add_child(ui["inv"])

	# Leverancier: knop die panel toont
	var shop_btn := Button.new()
	shop_btn.position = Vector2(560, 8)
	shop_btn.size = Vector2(130, 40)
	shop_btn.text = "Leverancier"
	layer.add_child(shop_btn)
	shop_btn.pressed.connect(func() -> void: _toggle_shop())
	ui["shop_btn"] = shop_btn

	# Leveranciers-panel (verborgen)
	var shop := Panel.new()
	shop.position = Vector2(560, 56)
	shop.size = Vector2(340, 120)
	shop.visible = false
	layer.add_child(shop)
	shop.add_child(_make_label("Koop ingrediënten", Vector2(12, 8), 14))
	var sx := 20.0
	for item in ["grain", "hops", "yeast"]:
		var b := Button.new()
		b.position = Vector2(sx, 36)
		b.size = Vector2(100, 60)
		b.modulate = ING_COLORS[item]
		b.text = ""
		b.tooltip_text = "%s kopen — %d goud" % [ING_NAMES[item], ING_PRICES[item]]
		b.pressed.connect(func() -> void: _buy(item))
		shop.add_child(b)
		shop.add_child(_make_label("%s\n%d goud" % [ING_NAMES[item], ING_PRICES[item]], Vector2(sx + 8, 40), 11))
		sx += 110.0
	ui["shop"] = shop

	# Order-panel rechtsboven
	var order := Panel.new()
	order.position = Vector2(960, 8)
	order.size = Vector2(310, 120)
	layer.add_child(order)
	order.add_child(_make_label("Order: De Zythoeker", Vector2(12, 8), 14))
	ui["order_label"] = _make_label("", Vector2(12, 30), 13)
	order.add_child(ui["order_label"])
	var area := Button.new()
	area.position = Vector2(12, 54)
	area.size = Vector2(286, 54)
	area.text = "Sleep hier bier om te leveren"
	layer.add_child(area)
	area.pressed.connect(func() -> void: _deliver())
	ui["order_area"] = area

	# Tooltip onderaan
	ui["tip"] = _make_label("", Vector2(16, 690), 13)
	layer.add_child(ui["tip"])

func _toggle_shop() -> void:
	ui["shop"].visible = not ui["shop"].visible

func _make_label(text: String, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## ---------- Spelersacties ----------

func _pick_ingredient(item: String) -> void:
	if drag_item == "" and inv[item] > 0:
		inv[item] -= 1
		start_drag("ingredient:" + item, 1, null, ING_COLORS[item])
		_update_hud()
	elif drag_item == "ingredient:" + item:
		_return_drag()
		cancel_drag()
		_update_hud()

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
	for item in ["grain", "hops", "yeast"]:
		var btn: Button = ui["icon_" + item]
		btn.text = "%s: %d" % [ING_NAMES[item], inv[item]]
	ui["order_label"].text = "Pils %d/%d leveren  (%d goud/unit)" % [delivered, ORDER_SIZE, UNIT_PRICE]
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
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	for m in machines:
		if m.is_clicked(pos):
			_click_machine(m)
			return
	if drag_item == "" and _in_storage(pos) and storage_beer > 0:
		storage_beer -= 1
		_update_hud()
		start_drag("beer", 1, null, Color(0.85, 0.6, 0.1))
	elif drag_item != "":
		# klik in leeg gebied: annuleren en teruggeven
		_return_drag()
		cancel_drag()

func _click_machine(m: Node2D) -> void:
	if m.buffer_ready:
		if drag_item != "":
			return
		m.buffer_ready = false
		if m.step_index == STEP_NAMES.size() - 1:
			storage_beer += BATCH_SIZE
			_update_hud()
		else:
			start_drag("batch:%d" % m.step_index, BATCH_SIZE, m, STEP_COLORS[m.step_index + 1])
		return
	if m.step_index == 0 and drag_item.begins_with("ingredient:"):
		# Ingredient in de schrotmolen deponeren
		var item: String = drag_item.split(":")[1]
		m.add_ingredient(item)
		cancel_drag()
		# check of recept compleet is
		var complete := true
		for k in RECIPE:
			if m.input.get(k, 0) < RECIPE[k]:
				complete = false
				break
		if complete:
			for k in RECIPE:
				m.input[k] -= RECIPE[k]
			m.reset_input()
			m.working = true
			m.time_left = STEP_TIMES[0]
		return
	elif drag_item.begins_with("batch:") and m.step_index == int(drag_item.split(":")[1]) + 1:
		drag_item = ""
		drag_count = 0
		if ghost:
			ghost.queue_free()
			ghost = null
		drag_source = null
		m.working = true
		m.time_left = STEP_TIMES[m.step_index]

func _deliver() -> void:
	if drag_item == "beer" and drag_count > 0:
		var take := mini(drag_count, ORDER_SIZE - delivered)
		delivered += take
		drag_count -= take
		money += take * UNIT_PRICE
		if delivered >= ORDER_SIZE:
			delivered = 0
			_tip("Order geleverd!")
		if drag_count <= 0:
			cancel_drag()
		_update_hud()

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
	ui["tip"].text = tip if tip != "" else _hint_text()

func _hint_text() -> String:
	if drag_item.begins_with("ingredient:"):
		return "Sleep naar de schrotmolen (rechtsklik = terug)"
	if drag_item.begins_with("batch:"):
		return "Sleep naar de volgende machine (rechtsklik = terug)"
	if drag_item == "beer":
		return "Sleep naar de order rechtsboven (rechtsklik = terug)"
	return ""

func _tip(text: String) -> void:
	ui["tip"].text = text
