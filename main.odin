package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:sys/linux"
import "core:strings"
import "core:time"

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

_IOC_READ :: 2
_IOC_NRSHIFT :: 0
_IOC_TYPESHIFT :: (_IOC_NRSHIFT + _IOC_NRBITS)
_IOC_SIZESHIFT :: (_IOC_TYPESHIFT + _IOC_TYPEBITS)
_IOC_DIRSHIFT :: (_IOC_SIZESHIFT + _IOC_SIZEBITS)

_IOC_NRBITS :: 8
_IOC_TYPEBITS :: 8
_IOC_SIZEBITS :: 14

_IOC :: proc(dir: u32, type: u32, nr: u32, size: u32) -> u32 {

	return(
		((dir) << _IOC_DIRSHIFT) |
		((type) << _IOC_TYPESHIFT) |
		((nr) << _IOC_NRSHIFT) |
		((size) << _IOC_SIZESHIFT) 
	)
}

EVIOCGNAME :: proc(len: u32) -> u32 {
    return _IOC(_IOC_READ, u32('E'), 0x06, len)
}

EVIOCGBIT :: proc(ev: u32, len: u32) -> u32 {	
    return _IOC(_IOC_READ, u32('E'), 0x20 + (ev), len)	
}

EV_SYN ::	0x00
EV_KEY ::	0x01
EV_REL ::	0x02
EV_ABS ::	0x03
EV_MSC ::	0x04
EV_SW ::	0x05
EV_LED ::	0x11
EV_SND ::	0x12
EV_REP ::	0x14
EV_FF ::	0x15
EV_PWR ::	0x16
EV_FF_STATUS ::0x17
EV_MAX ::	0x1f
EV_CNT ::	(EV_MAX+1)

KEY_MAX	 :: 		0x2ff

js_event :: struct {
	time:   u32,
	value:  i16,
	type:   u8,
	number: u8,
}

input_event :: struct {
	time:   linux.Time_Val,
    type : u16,
    code : u16,
    value: c.uint,
}

Gamepad :: struct {
    fd: os.Handle
}

test_bit :: proc(bits: []u64, bit: u64) -> bool{
    word_bits: u64 = size_of(u64) * 8
    idx := bit / word_bits
    pos := bit % word_bits

    return bits[idx] & (1 << pos) != 0

}

main :: proc() {
	// get_gamepad_fd()
    name: [256]u8
	buf: [size_of(input_event)]u8
	fd, err := os.open("/dev/input/event26", os.O_RDONLY | os.O_NONBLOCK)

    if err != nil {
        fmt.println(err)
        return
    }

    ev_bits: [EV_MAX / (8*size_of(u64)) + 1]u64 = {};

    fmt.println("ev bits size", size_of(ev_bits))
    linux.ioctl(linux.Fd(fd), EVIOCGNAME(size_of(name)), cast(uintptr)&name)
    fmt.println(strings.clone_from(name[:]))

    io_err := linux.ioctl(linux.Fd(fd), EVIOCGBIT(0, size_of(ev_bits)), cast(uintptr)&ev_bits)

    for bit := 0; bit < EV_MAX + 1; bit += 1 {
        fmt.printf("%02X %t\n", bit, test_bit(ev_bits[:], u64(bit)))
    }




	// for {
        // // time.sleep(200.0  * time.Millisecond)
	// 	n, read_err := os.read(fd, buf[:])

        // if read_err != nil {
            // continue
            // // fmt.println(read_err)
        // }
	// 	if n != size_of(input_event) {
            // continue
	// 	}
	// 	event := transmute(input_event)buf
        // fmt.println(event)
	// 	// etype := event.type & ~u8(JS_EVENT_INIT)

	// 	// if etype == JS_EVENT_AXIS {
            // // fmt.println(event)
	// 	// 	gamepad.axis_state[event.number] = event.value 
	// 	// }
	// }
}
