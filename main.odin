package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:sys/linux"

udev_log_proc :: #type proc "c" (
	_: ^udev,
	_: c.int,
	_: cstring,
	_: c.int,
	_: cstring,
	_: cstring,
	_args: ..c.int,
)

logger :: proc "c" (
	_: ^udev,
	_: c.int,
	file: cstring,
	_: c.int,
	fn: cstring,
	format: cstring,
	_args: ..c.int,
) {
	context = runtime.default_context()
	fmt.println("Udev logging", file, fn, format)
}

get_gamepad_fd :: proc() {
	udev := udev_new()
	// set_log_fn(udev, logger)

	en := enumerate_new(udev)
	enumerate_add_match_subsystem(en, "input")
	enumerate_scan_devices(en)

	for entry := enumerate_get_list_entry(en); entry != nil; entry = list_entry_get_next(entry) {
		syspath := list_entry_get_name(entry)
		dev := device_new_from_syspath(udev, syspath)
		node := device_get_devnode(dev)
		dt := device_get_devnum(dev)

		major := major(dt)
		minor := minor(dt)

		if node == nil do continue

		prop := device_get_property_value(dev, "ID_INPUT_JOYSTICK")
		is_joystick := prop != "" ? true : false
		if is_joystick {
			for prop_entry := device_get_properties_list_entry(dev);
			    prop_entry != nil;
			    prop_entry = list_entry_get_next(prop_entry) {

				fmt.println(list_entry_get_name(prop_entry), list_entry_get_value(prop_entry))
			}
		}
		fmt.println(node, prop, is_joystick, major, minor)
	}
}

main :: proc() {
	get_gamepad_fd()

	bus := new(sd_bus)
	error := sd_bus_error{}
	message := new(sd_bus_message)

	bus_open_system(&bus)

	r := bus_call_method(
		bus,
		"org.freedesktop.login1",
		"/org/freedesktop/login1/session/self/",
		"org.freedesktop.login1.Session",
		"TakeDevice",
		&error,
		&message,
		"uu",
		uint(13),
		uint(1),
	)

	fmt.println(r)
	fmt.println(error)
	fmt.println(message)

	bus_unref(bus)
}
