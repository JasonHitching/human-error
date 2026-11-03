extends TestCase
## FloorCamera: zoom and pan are clamped to the factory bounds, zoom keeps its anchor point.

const CONTENT := Rect2(-400, 0, 800, 900)


func _cam(z: float = 1.0) -> FloorCamera:
	var cam := FloorCamera.new()
	cam.set_view(Vector2(390, 700))
	cam.reset(CONTENT, z)
	return cam


func test_zoom_clamps() -> void:
	var cam := _cam()
	cam.zoom_at(100.0, Vector2(100, 100))
	assert_eq(cam.zoom, FloorCamera.MAX_ZOOM, "max")
	cam.zoom_at(0.0001, Vector2(100, 100))
	assert_eq(cam.zoom, FloorCamera.MIN_ZOOM, "min")


func test_pan_clamps_to_bounds() -> void:
	var cam := _cam()
	cam.pan_screen(Vector2(-100000, -100000))
	var half := cam.view / (2.0 * cam.zoom)
	assert_near(cam.center.x, cam.bounds.end.x - half.x, 0.001, "far x")
	assert_near(cam.center.y, cam.bounds.end.y - half.y, 0.001, "far y")
	cam.pan_screen(Vector2(100000, 100000))
	assert_near(cam.center.x, cam.bounds.position.x + half.x, 0.001, "near x")
	assert_near(cam.center.y, cam.bounds.position.y + half.y, 0.001, "near y")


func test_pan_works_when_factory_fits_the_view() -> void:
	var cam := FloorCamera.new()
	cam.set_view(Vector2(720, 1280))
	cam.reset(Rect2(0, 0, 300, 300), 1.0)  # content much smaller than the view
	var c0 := cam.center
	cam.pan_screen(Vector2(-60, -40))
	assert_true(cam.center.distance_to(c0) > 1.0, "a small factory still pans")
	cam.pan_screen(Vector2(-100000, -100000))
	assert_true(cam.bounds.grow(0.01).has_point(cam.center), "centre stays inside the bounds")
	cam.pan_screen(Vector2(100000, 100000))
	assert_true(cam.bounds.grow(0.01).has_point(cam.center), "centre stays inside the bounds (other side)")


func test_zoom_keeps_anchor_and_round_trips() -> void:
	var cam := _cam()
	var w := Vector2(50, 300)
	var s := cam.world_to_screen(w)
	cam.zoom_at(1.3, s)
	assert_true(cam.world_to_screen(w).distance_to(s) < 0.01, "anchor fixed")
	assert_true(cam.screen_to_world(cam.world_to_screen(w)).distance_to(w) < 0.001, "round trip")


func test_small_factory_stays_centred_and_big_one_need_not_fit() -> void:
	var cam := FloorCamera.new()
	cam.set_view(Vector2(2000, 2000))
	cam.reset(Rect2(0, 0, 100, 100), 1.0)
	assert_eq(cam.center, cam.bounds.get_center(), "centred")
	var big := _cam()
	assert_true(big.view.x / big.zoom < big.bounds.size.x, "view smaller than factory at default zoom")


func _safe() -> Rect2:
	return Rect2(8, 8, 374, 612)


func test_focus_ends_with_target_in_safe_rect() -> void:
	for t: Vector2 in [Vector2(-300, 40), Vector2(0, 450), Vector2(380, 860), Vector2(100, 100)]:
		var cam := _cam(0.6)
		cam.focus_on(t, _safe())
		assert_true(cam.moving, "moving")
		for i in 100:
			cam.step(0.01)
		assert_true(not cam.moving, "done")
		assert_true(_safe().has_point(cam.world_to_screen(t)), "target in safe rect %s" % str(t))
		assert_true(cam.zoom >= FloorCamera.FOCUS_ZOOM - 0.001, "zoomed in")


func test_focus_is_smooth_and_input_cancels() -> void:
	var cam := _cam(0.6)
	var start := cam.center
	cam.focus_on(Vector2(300, 800), _safe())
	cam.step(0.1)
	var mid := cam.center
	assert_true(mid != start and cam.moving, "partway")
	cam.cancel()
	cam.step(1.0)
	assert_eq(cam.center, mid, "cancelled: stays put")
	assert_true(not cam.moving, "stopped")
