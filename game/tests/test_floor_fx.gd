extends TestCase
## Floor atmosphere: fixed particle pool, state colours, effects-off clears particles.


func test_pool_never_exceeds_budget() -> void:
	var fx := FloorFx.new()
	FloorFx.enabled = true
	fx.reset(5)
	var kinds := PackedInt32Array([2, 2, 2, 2, 2])
	for i in 600:
		fx.update(0.1, kinds)
		assert_true(fx.live_count() <= 40, "live %d" % fx.live_count())


func test_off_clears_particles() -> void:
	var fx := FloorFx.new()
	FloorFx.enabled = true
	fx.reset(2)
	for i in 50:
		fx.update(0.1, PackedInt32Array([1, 1]))
	FloorFx.enabled = false
	fx.update(0.1, PackedInt32Array([1, 1]))
	assert_eq(fx.live_count(), 0, "no particles when off")
	FloorFx.enabled = true


func test_glow_colour_by_state() -> void:
	var fx := FloorFx.new()
	var healthy := fx.glow_color(0, 0.0)
	var warn := fx.glow_color(1, 0.0)
	var crit := fx.glow_color(2, 0.0)
	assert_true(warn.r > warn.b and warn.g > crit.g, "amber is warmer than red")
	assert_true(crit.r > crit.g + 0.3, "red is red")
	assert_true(healthy.a < warn.a and warn.a < crit.a, "louder with severity")
