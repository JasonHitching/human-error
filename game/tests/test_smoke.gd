extends TestCase


func test_smoke() -> void:
	assert_eq(1 + 1, 2)
	assert_true(true)
	assert_near(0.1 + 0.2, 0.3)
