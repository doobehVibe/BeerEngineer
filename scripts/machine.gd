extends Node2D
## Machine: één brouwstap; verwerkt automatisch na aanlevering.
## Klikhandling gebeurt centraal in factory.gd (is_clicked / _click_machine).

var step_index: int = 0
var time_left := 0.0
var working := false
var buffer_ready := false
var input := {}   # alleen schrotmolen: {"grain":n,"hops":n,"yeast":n}

var body: ColorRect
var bar: ColorRect
var bar_bg: ColorRect
var name_label: Label
var input_label: Label

const SIZE := Vector2(44, 44)

func _ready() -> void:
	var f := get_parent()
	body = ColorRect.new()
	body.color = f.STEP_COLORS[step_index]
	body.size = SIZE
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	bar_bg = ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.6)
	bar_bg.position = Vector2(0, SIZE.y - 6)
	bar_bg.size = Vector2(SIZE.x, 6)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_bg)
	bar = ColorRect.new()
	bar.color = Color(0.3, 0.9, 0.4)
	bar.position = Vector2(0, SIZE.y - 6)
	bar.size = Vector2(0, 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	name_label = f._make_label(f.STEP_NAMES[step_index], Vector2(-8, -20), 11)
	add_child(name_label)
	input_label = f._make_label("", Vector2(-8, -6), 10)
	input_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(input_label)

func _physics_process(delta: float) -> void:
	if working:
		time_left -= delta
		var total: float = get_parent().STEP_TIMES[step_index]
		bar.size.x = clampf(SIZE.x * (1.0 - time_left / total), 0.0, SIZE.x)
		if time_left <= 0.0:
			working = false
			buffer_ready = true

func add_ingredient(item: String) -> void:
	input[item] = input.get(item, 0) + 1
	_update_input_label()

func _update_input_label() -> void:
	if step_index != 0:
		input_label.text = ""
		return
	var f := get_parent()
	var parts := []
	for item in f.RECIPE:
		var have := input.get(item, 0)
		if have > 0:
			parts.append("%s %d/%d" % [f.ING_SHORT[item], have, f.RECIPE[item]])
	input_label.text = " ".join(parts)

func reset_input() -> void:
	input = {}
	_update_input_label()

func is_clicked(pos: Vector2) -> bool:
	return pos.x >= position.x and pos.x <= position.x + SIZE.x \
		and pos.y >= position.y and pos.y <= position.y + SIZE.y

func tooltip() -> String:
	var f := get_parent()
	if working:
		return "%s: %.1fs" % [f.STEP_NAMES[step_index], time_left]
	if buffer_ready:
		return "%s: klaar — klik om op te pakken" % f.STEP_NAMES[step_index]
	if step_index == 0:
		return "%s: sleep graan/hop/gist hierheen (recept: 2 graan, 1 hop, 1 gist)" % f.STEP_NAMES[step_index]
	return "%s: wacht op input" % f.STEP_NAMES[step_index]
