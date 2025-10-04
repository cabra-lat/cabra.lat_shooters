class_name Utils
extends Object

static func create_timer(wait):
	var timer = Timer.new()
	timer.wait_time = wait
	return timer
