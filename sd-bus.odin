package main

import "core:c"

sd_bus :: struct {}
sd_bus_message :: struct {}
sd_bus_error :: struct {
	name:       cstring,
	message:    cstring,
	_need_free: c.int,
}

foreign import sdbus "system:systemd"

@(default_calling_convention = "c", link_prefix = "sd_")
foreign sdbus {
	bus_open_system :: proc(_: ^^sd_bus) -> c.int ---
	bus_unref :: proc(_: ^sd_bus) ---
	bus_call_method :: proc(bus: ^sd_bus, destination: cstring, path: cstring, interface: cstring, member: cstring, error: ^sd_bus_error, reply: ^^sd_bus_message, types: cstring, #c_vararg args: ..any) -> c.int ---
}
