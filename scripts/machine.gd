extends Node2D
## Machine: één brouwstap; verwerkt automatisch na aanlevering.
## Klikhandling gebeurt centraal in factory.gd (is_clicked / _click_machine).

var step_index: int = 0
var time_left := 0.0
var working := false
var buffer_ready := false

var body: ColorRect
var bar: ColorRect
var bar_bg: ColorRect
var name_label: Label

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

func _physics_process(delta: float) -> void:
	if working:
		time_left -= delta
		var total: float = get_parent().STEP_TIMES[step_index]
		bar.size.x = clampf(SIZE.x * (1.0 - time_left / total), 0.0, SIZE.x)
		if time_left <= 0.0:
			working = false
			buffer_ready = true

func is_clicked(pos: Vector2) -> bool:
	return pos.x >= position.x and pos.x <= position.x + SIZE.x \
		and pos.y >= position.y and pos.y <= position.y + SIZE.y

func tooltip() -> String:
	var f := get_parent()
	if working:
		return "%s: %.1fs" % [f.STEP_NAMES[step_index], time_left]
	if buffer_ready:
		return "%s: klaar — klik om op te pakken" % [f.STEP_NAMES[step_index]]
	return "%s: wacht op input" % f.STEP_NAMES[step_index]
