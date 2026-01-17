package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/linux"
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
		((size) << _IOC_SIZESHIFT) \
	)
}

_IOR :: proc(type: u32, nr: u32, T: typeid) -> u32 {
	return _IOC(_IOC_READ, (type), (nr), (size_of(T)))
}

EVIOCGNAME :: proc(len: u32) -> u32 {
	return _IOC(_IOC_READ, u32('E'), 0x06, len)
}

EVIOCGBIT :: proc(ev: u32, len: u32) -> u32 {
	return _IOC(_IOC_READ, u32('E'), 0x20 + (ev), len)
}

EVIOCGABS :: proc(abs: u32) -> u32 {
	return _IOR('E', 0x40 + (abs), input_absinfo)
}

EV_SYN :: 0x00
EV_KEY :: 0x01
EV_REL :: 0x02
EV_ABS :: 0x03
EV_MSC :: 0x04
EV_SW :: 0x05
EV_LED :: 0x11
EV_SND :: 0x12
EV_REP :: 0x14
EV_FF :: 0x15
EV_PWR :: 0x16
EV_FF_STATUS :: 0x17
EV_MAX :: 0x1f
EV_CNT :: (EV_MAX + 1)

KEY_MAX :: 0x2ff

// This is the first and base button
// This is used as the bit index to check for existence
// and also the as the event code
BTN_GAMEPAD :: 0x130

// In linux/input.h there are 15 different mapped buttons
Linux_Button :: enum u32 {
	BTN_0  = BTN_GAMEPAD,
	BTN_1  = BTN_GAMEPAD + 1,
	BTN_2  = BTN_GAMEPAD + 2,
	BTN_3  = BTN_GAMEPAD + 3,
	BTN_4  = BTN_GAMEPAD + 4,
	BTN_5  = BTN_GAMEPAD + 5,
	BTN_6  = BTN_GAMEPAD + 6,
	BTN_7  = BTN_GAMEPAD + 7,
	BTN_8  = BTN_GAMEPAD + 8,
	BTN_9  = BTN_GAMEPAD + 9,
	BTN_10 = BTN_GAMEPAD + 10,
	BTN_11 = BTN_GAMEPAD + 11,
	BTN_13 = BTN_GAMEPAD + 13,
	BTN_14 = BTN_GAMEPAD + 14,
	BTN_15 = BTN_GAMEPAD + 15,
}

Linux_Button_State :: enum u32 {
	Released = 0,
	Pressed  = 1,
	Repeated = 2,
}

// Dont use the same base that we use for buttons because
// they are nice and contiguous
Linux_Axis :: enum u32 {
	X          = 0x00,
	Y          = 0x01,
	Z          = 0x02,
	RX         = 0x03,
	RY         = 0x04,
	RZ         = 0x05,
	THROTTLE   = 0x06,
	RUDDER     = 0x07,
	WHEEL      = 0x08,
	GAS        = 0x09,
	BRAKE      = 0x0a,
	HAT0X      = 0x10,
	HAT0Y      = 0x11,
	HAT1X      = 0x12,
	HAT1Y      = 0x13,
	HAT2X      = 0x14,
	HAT2Y      = 0x15,
	HAT3X      = 0x16,
	HAT3Y      = 0x17,
	PRESSURE   = 0x18,
	DISTANCE   = 0x19,
	TILT_X     = 0x1a,
	TILT_Y     = 0x1b,
	TOOL_WIDTH = 0x1c,
}

Linux_Axis_Info :: struct {
	absinfo: input_absinfo,
	state:   i32, // originaly a c.int
}

js_event :: struct {
	time:   u32,
	value:  i16,
	type:   u8,
	number: u8,
}

input_event :: struct {
	time:  linux.Time_Val,
	type:  u16,
	code:  u16,
	value: c.int,
}

input_absinfo :: struct {
	value:      i32,
	minimum:    i32,
	maximum:    i32,
	fuzz:       i32,
	flat:       i32,
	resolution: i32,
}

Gamepad :: struct {
	fd:   os.Handle,
	name: string,
	axes: map[Linux_Axis]Linux_Axis_Info,
}


MAX_GAMEPADS :: 4
gamepads: [MAX_GAMEPADS]Gamepad = {}

test_bit :: proc(bits: []u64, bit: u64) -> bool {
	word_bits: u64 = size_of(u64) * 8
	idx := bit / word_bits
	pos := bit % word_bits

	return bits[idx] & (1 << pos) != 0

}

get_potential_gamepad_device_paths :: proc() -> []string {
	result: [dynamic]string
	udev := udev_new()
	// set_log_fn(udev, logger)

	en := enumerate_new(udev)
	enumerate_add_match_subsystem(en, "input")
	enumerate_scan_devices(en)

	for entry := enumerate_get_list_entry(en); entry != nil; entry = list_entry_get_next(entry) {
		syspath := list_entry_get_name(entry)
		dev := device_new_from_syspath(udev, syspath)
		node := device_get_devnode(dev)

		if node == nil do continue
		node_str := strings.clone_from_cstring(node)

		if !strings.starts_with(node_str, "/dev/input/event") do continue // Focus on evdev device files

		prop := device_get_property_value(dev, "ID_INPUT_JOYSTICK")
		is_joystick := prop != "" ? true : false
		if is_joystick {
			append(&result, strings.clone_from_cstring(node))
		}
	}
	return result[:]
}

check_for_btn_gamepad :: proc(path: string) -> bool {
	fd, err := os.open("/dev/input/event4", os.O_RDONLY | os.O_NONBLOCK)

	if err != nil {
		return false
	}
	key_bits: [KEY_MAX / (8 * size_of(u64)) + 1]u64 = {}
	linux.ioctl(linux.Fd(fd), EVIOCGBIT(EV_KEY, size_of(key_bits)), cast(uintptr)&key_bits)

	return test_bit(key_bits[:], u64(BTN_GAMEPAD))
}

create_gamepad :: proc(id: u32, device_path: string) -> Gamepad {
	fd, err := os.open(device_path, os.O_RDONLY | os.O_NONBLOCK)
	if err != nil {
		panic(fmt.tprintf("%s", err))
	}
	name: [256]u8
	linux.ioctl(linux.Fd(fd), EVIOCGNAME(size_of(name)), cast(uintptr)&name)

	// Create gamepad
	gamepad := Gamepad {
		fd   = fd,
		name = strings.clone_from_bytes(name[:]),
	}

	fmt.printf("Detected gamepad %d\n", id)
	fmt.printf("\tname -> '%s', device_path -> '%s'\n", name, device_path)

	ev_bits: [EV_MAX / (8 * size_of(u64)) + 1]u64 = {}
	linux.ioctl(linux.Fd(fd), EVIOCGBIT(0, size_of(ev_bits)), cast(uintptr)&ev_bits)
	has_abs := test_bit(ev_bits[:], EV_ABS)
	fmt.printf("\thas_buttons-> '%t'\n", test_bit(ev_bits[:], EV_KEY))
	fmt.printf("\thas_absolute_movement-> '%t'\n", has_abs)
	fmt.printf("\thas_relative_movement-> '%t'\n", test_bit(ev_bits[:], EV_REL))

	if has_abs {
		abs_bits: [EV_ABS / (8 * size_of(u64)) + 1]u64 = {}
		linux.ioctl(linux.Fd(fd), EVIOCGBIT(EV_ABS, size_of(abs_bits)), cast(uintptr)&abs_bits)

		for i in Linux_Axis.X ..< Linux_Axis.TOOL_WIDTH + Linux_Axis(1) {
			has_axis := test_bit(abs_bits[:], u64(i))
			if has_axis {
				axis_info := Linux_Axis_Info{}
				linux.ioctl(linux.Fd(fd), EVIOCGABS(u32(i)), cast(uintptr)&axis_info.absinfo)
				gamepad.axes[i] = axis_info
			}
		}

	}
	fmt.println(gamepad)

	return gamepad
}

main :: proc() {
	potential_pads := get_potential_gamepad_device_paths()

	for pad, idx in potential_pads {
		is_joystick := check_for_btn_gamepad(pad)
		if is_joystick {
			gamepads[idx] = create_gamepad(u32(idx), pad)
		}
	}

	gamepad := gamepads[0]
	buf: [size_of(input_event)]u8
	for {
		// time.sleep(200.0  * time.Millisecond)
		n, read_err := os.read(gamepad.fd, buf[:])

		if read_err != nil {
			continue
			// fmt.println(read_err)
		}
		if n != size_of(input_event) {
			continue
		}

		event := transmute(input_event)buf

		// Ignore "trivial" events for now
		// SYN is data tranmission control events, SYN_REPORT might be
		// important to sync composite events like touch gestures in modern gamepads.
		// MSC is Misc that I don't really know what they mean...
		// https://docs.kernel.org/input/event-codes.html
		if event.type == EV_SYN || event.type == EV_MSC do continue

		if event.type == EV_KEY {
			fmt.println(Linux_Button(event.code), Linux_Button_State(event.value))
		}
		if event.type == EV_ABS {
			(&gamepad.axes[Linux_Axis(event.code)]).state = event.value
			fmt.println(gamepad.axes)
		}
		// etype := event.type & ~u8(JS_EVENT_INIT)

		// if etype == JS_EVENT_AXIS {
		// fmt.println(event)
		// 	gamepad.axis_state[event.number] = event.value
		// }
	}

	// name: [256]u8
	// fd, err := os.open("/dev/input/event4", os.O_RDONLY | os.O_NONBLOCK)

	// if err != nil {
	// 	fmt.println(err)
	// 	return
	// }

	// ev_bits: [EV_MAX / (8 * size_of(u64)) + 1]u64 = {}
	// key_bits: [KEY_MAX / (8 * size_of(u64)) + 1]u64 = {}

	// fmt.println("ev_bits size", size_of(ev_bits))
	// fmt.println("key_bits size", size_of(key_bits))

	// linux.ioctl(linux.Fd(fd), EVIOCGNAME(size_of(name)), cast(uintptr)&name)
	// fmt.println(strings.clone_from(name[:]))

	// // This call to EVIOCGBIT uses 0 meaning to get the capabilities of gamepad
	// // This has to match the ev_bits since its sized to EV_MAX
	// linux.ioctl(linux.Fd(fd), EVIOCGBIT(0, size_of(ev_bits)), cast(uintptr)&ev_bits)

	// for bit := 0; bit < EV_MAX + 1; bit += 1 {
	// 	fmt.printf("%02X %t\n", bit, test_bit(ev_bits[:], u64(bit)))
	// }

	// fmt.println("Keys")
	// linux.ioctl(linux.Fd(fd), EVIOCGBIT(EV_KEY, size_of(key_bits)), cast(uintptr)&key_bits)

	// for bit := 0; bit < KEY_MAX + 1; bit += 1 {
	// 	available := test_bit(key_bits[:], u64(bit))
	// 	if available {
	// 		fmt.printf("%02X %t\n", bit, available)
	// 	}
	// }


	// buf: [size_of(input_event)]u8
	// for {
	// 	// time.sleep(200.0  * time.Millisecond)
	// 	n, read_err := os.read(fd, buf[:])

	// 	if read_err != nil {
	// 		continue
	// 		// fmt.println(read_err)
	// 	}
	// 	if n != size_of(input_event) {
	// 		continue
	// 	}
	// 	event := transmute(input_event)buf
	// 	fmt.println(event)
	// 	// etype := event.type & ~u8(JS_EVENT_INIT)

	// 	// if etype == JS_EVENT_AXIS {
	// 	// fmt.println(event)
	// 	// 	gamepad.axis_state[event.number] = event.value
	// 	// }
	// }
}
