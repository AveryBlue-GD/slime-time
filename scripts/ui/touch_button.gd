class_name TouchButton
extends Button

## The menu button (UIKit.make_button). While touch is in use (UIKit.touch_active: the last pointer
## event was a touch, or --touch) its hit area is bigger than its art: the drawn rect grown by
## UIKit.hit_pad() on every side (HIT_PAD in English: a 13 px button becomes 23 px, about 44 pt on a phone; a taller script's taller button grows less, to the same 23). The grown margin is shared fairly: a point in it belongs to the nearest touch
## target (UIKit.TOUCH_GROUP on the same canvas layer, ties to the lower instance id), and never to
## this button when it lies inside another target's drawn rect. So hit areas never overlap and a tap
## between two buttons goes to the closer one. Targets kept out of focus by UIKit.lock_focus (behind
## an open panel) don't compete. The grown margin never reaches outside the safe area (Platform.safe_rect):
## on an iPhone the bottom row's margin stops above the home indicator. With a mouse (even on a touchscreen laptop) the hit area is exactly
## the drawn rect.


func _init() -> void:
	add_to_group(UIKit.TOUCH_GROUP)


func _has_point(point: Vector2) -> bool:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.has_point(point):
		return true
	if not UIKit.touch_active():
		return false
	return claims(get_global_transform() * point)


## True when a touch at `at` (canvas coordinates of this button's layer), outside the drawn rect,
## belongs to this button: within hit_pad() of it and nearer to it than to any other target.
func claims(at: Vector2) -> bool:
	var mine := global_rect()
	if not mine.grow(UIKit.hit_pad()).has_point(at):
		return false
	var safe := Platform.safe_rect()
	if safe != Platform.FULL_VIEW and not safe.has_point(at):
		return false  # (the grown margin stops at the safe area: the iPhone home-indicator strip stays the system's;
		# with the whole view safe, the letterbox around it still counts, as before)
	var my_distance := _distance(mine, at)
	var canvas := get_canvas()
	for node in get_tree().get_nodes_in_group(UIKit.TOUCH_GROUP):
		var other := node as Control
		if other == null or other == self or not other.is_visible_in_tree() or other.get_canvas() != canvas:
			continue
		var rect := TouchButton.rect_of(other)
		if rect.has_point(at):
			return false  # inside another target's own rect
		if other.focus_mode == Control.FOCUS_NONE and other is BaseButton:
			continue  # locked out behind an open panel (UIKit.lock_focus)
		var d := _distance(rect, at)
		if d < my_distance or (d == my_distance and other.get_instance_id() < get_instance_id()):
			return false
	return true


## This button's drawn rect in canvas coordinates.
func global_rect() -> Rect2:
	return TouchButton.rect_of(self)


static func rect_of(control: Control) -> Rect2:
	var xf := control.get_global_transform()
	return Rect2(xf.origin, control.size * xf.get_scale())


static func _distance(rect: Rect2, at: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - at.x, at.x - rect.end.x), 0.0)
	var dy := maxf(maxf(rect.position.y - at.y, at.y - rect.end.y), 0.0)
	return maxf(dx, dy)
