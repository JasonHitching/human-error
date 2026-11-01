class_name TestCase
extends RefCounted

var failures: Array[String] = []


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual != expected:
		failures.append("assert_eq: got %s, expected %s %s" % [str(actual), str(expected), msg])


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		failures.append("assert_true failed %s" % msg)


func assert_near(actual: float, expected: float, eps: float = 0.0001, msg: String = "") -> void:
	if absf(actual - expected) > eps:
		failures.append("assert_near: got %s, expected %s ±%s %s" % [actual, expected, eps, msg])
