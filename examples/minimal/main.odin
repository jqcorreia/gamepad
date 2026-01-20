package main

import gp "../.."
import "core:fmt"
import "core:time"

main :: proc() {
	controller := gp.gamepad_new_controller()

	pad := controller.gamepads[0]

	gp.gamepad_set_rumble(&pad, 0xFFFF, 0)
	time.sleep(5 * time.Second)

	gp.gamepad_set_rumble(&pad, 0x0, 0xFFFF)
	time.sleep(2 * time.Second)

	gp.gamepad_set_rumble(&pad, 0x0, 0x0)
	time.sleep(2 * time.Second)
}
