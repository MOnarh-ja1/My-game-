//go:build windows

package main

import (
	"fmt"
	"os"
	"runtime"
	"syscall"
	"time"
	"unsafe"
)

const (
	screenW             = 1100
	screenH             = 650
	WM_DESTROY          = 0x0002
	WM_SIZE             = 0x0005
	WM_PAINT            = 0x000F
	WM_CLOSE            = 0x0010
	WM_KEYDOWN          = 0x0100
	WM_LBUTTONDOWN      = 0x0201
	WM_TIMER            = 0x0113
	WS_OVERLAPPEDWINDOW = 0x00CF0000
	WS_VISIBLE          = 0x10000000
	SW_SHOW             = 5
	IDC_ARROW           = 32512
	BI_RGB              = 0
	DIB_RGB_COLORS      = 0
	SRCCOPY             = 0x00CC0020
	TRANSPARENT         = 1
)

type point struct{ x, y int32 }
type rect struct{ l, t, r, b int32 }
type size struct{ cx, cy int32 }
type bitmapInfoHeader struct {
	Size                         uint32
	Width, Height                int32
	Planes, BitCount             uint16
	Compression, SizeImage       uint32
	XPelsPerMeter, YPelsPerMeter int32
	ClrUsed, ClrImportant        uint32
}
type bitmapInfo struct {
	Header bitmapInfoHeader
	Colors [1]uint32
}
type msg struct {
	Hwnd           uintptr
	Message        uint32
	_              uint32
	Wparam, Lparam uintptr
	Time           uint32
	Pt             point
	Lprivate       uint32
	_              uint32
}
type wndClass struct {
	Size                                                               uint32
	Style                                                              uint32
	WndProc                                                            uintptr
	ClsExtra, WndExtra                                                 int32
	Instance, Icon, Cursor, Background, MenuName, ClassName, SmallIcon uintptr
}

var (
	user32        = syscall.NewLazyDLL("user32.dll")
	gdi32         = syscall.NewLazyDLL("gdi32.dll")
	kernel32      = syscall.NewLazyDLL("kernel32.dll")
	regClass      = user32.NewProc("RegisterClassExW")
	createWin     = user32.NewProc("CreateWindowExW")
	showWin       = user32.NewProc("ShowWindow")
	updateWin     = user32.NewProc("UpdateWindow")
	getMsg        = user32.NewProc("GetMessageW")
	translateMsg  = user32.NewProc("TranslateMessage")
	dispatchMsg   = user32.NewProc("DispatchMessageW")
	defProc       = user32.NewProc("DefWindowProcW")
	postQuit      = user32.NewProc("PostQuitMessage")
	getClient     = user32.NewProc("GetClientRect")
	getDC         = user32.NewProc("GetDC")
	releaseDC     = user32.NewProc("ReleaseDC")
	validate      = user32.NewProc("ValidateRect")
	invalidate    = user32.NewProc("InvalidateRect")
	setTimer      = user32.NewProc("SetTimer")
	killTimer     = user32.NewProc("KillTimer")
	adjustWin     = user32.NewProc("AdjustWindowRect")
	loadCursor    = user32.NewProc("LoadCursorW")
	stretchDIB    = gdi32.NewProc("StretchDIBits")
	setTextColor  = gdi32.NewProc("SetTextColor")
	setBkMode     = gdi32.NewProc("SetBkMode")
	textOut       = gdi32.NewProc("TextOutW")
	getTextExtent = gdi32.NewProc("GetTextExtentPoint32W")
	createFont    = gdi32.NewProc("CreateFontW")
	selectObj     = gdi32.NewProc("SelectObject")
	deleteObj     = gdi32.NewProc("DeleteObject")
	getModule     = kernel32.NewProc("GetModuleHandleW")
	HWND          uintptr
	pixels        = make([]uint32, screenW*screenH)
	bmi           = bitmapInfo{Header: bitmapInfoHeader{Size: 40, Width: screenW, Height: -screenH, Planes: 1, BitCount: 32, Compression: BI_RGB}}
	fonts         = map[int]uintptr{}
	app           = NewGame()
	last          = time.Now()
)

type label struct {
	text         string
	x, y, px     int
	color        uint32
	center, bold bool
}

var labels []label

func putText(s string, x, y, px int, color uint32, center, bold bool) {
	labels = append(labels, label{s, x, y, px, color, center, bold})
}
func fontFor(px int, bold bool) uintptr {
	key := px
	if bold {
		key += 1000
	}
	if f, ok := fonts[key]; ok {
		return f
	}
	weight := uintptr(400)
	if bold {
		weight = 700
	}
	family, _ := syscall.UTF16PtrFromString("Segoe UI")
	f, _, _ := createFont.Call(uintptr(int64(-px)), 0, 0, 0, weight, 0, 0, 0, 1, 4, 0, 5, 0, uintptr(unsafe.Pointer(family)))
	fonts[key] = f
	return f
}

func render() {
	rc := rect{}
	getClient.Call(HWND, uintptr(unsafe.Pointer(&rc)))
	w, h := int(rc.r-rc.l), int(rc.b-rc.t)
	if w <= 0 || h <= 0 {
		return
	}
	app.Draw()
	hdc, _, _ := getDC.Call(HWND)
	if hdc == 0 {
		return
	}
	stretchDIB.Call(hdc, 0, 0, uintptr(w), uintptr(h), 0, 0, screenW, screenH, uintptr(unsafe.Pointer(&pixels[0])), uintptr(unsafe.Pointer(&bmi)), DIB_RGB_COLORS, SRCCOPY)
	setBkMode.Call(hdc, TRANSPARENT)
	scaleX := float64(w) / screenW
	scaleY := float64(h) / screenH
	for _, l := range labels {
		f := fontFor(max(9, int(float64(l.px)*scaleY)), l.bold)
		old, _, _ := selectObj.Call(hdc, f)
		setTextColor.Call(hdc, uintptr(colorRef(l.color)))
		text, _ := syscall.UTF16PtrFromString(l.text)
		n := len(syscall.StringToUTF16(l.text)) - 1
		x := int(float64(l.x) * scaleX)
		y := int(float64(l.y) * scaleY)
		if l.center {
			var s size
			getTextExtent.Call(hdc, uintptr(unsafe.Pointer(text)), uintptr(n), uintptr(unsafe.Pointer(&s)))
			x -= int(s.cx) / 2
		}
		textOut.Call(hdc, uintptr(x), uintptr(y), uintptr(unsafe.Pointer(text)), uintptr(n))
		selectObj.Call(hdc, old)
	}
	releaseDC.Call(HWND, hdc)
}

func tick() {
	now := time.Now()
	dt := now.Sub(last).Seconds()
	last = now
	if dt > 0.08 {
		dt = 0.08
	}
	app.Update(dt)
	render()
}

func windowProc(hwnd, message, wparam, lparam uintptr) uintptr {
	switch message {
	case WM_DESTROY:
		app.Save()
		killTimer.Call(hwnd, 1)
		postQuit.Call(0)
		return 0
	case WM_CLOSE:
		app.Save()
	case WM_PAINT:
		validate.Call(hwnd, 0)
		render()
		return 0
	case WM_SIZE:
		invalidate.Call(hwnd, 0, 0)
		return 0
	case WM_TIMER:
		tick()
		return 0
	case WM_KEYDOWN:
		if lparam&(1<<30) == 0 {
			app.Key(int(wparam))
		}
		return 0
	case WM_LBUTTONDOWN:
		var rc rect
		getClient.Call(hwnd, uintptr(unsafe.Pointer(&rc)))
		w, h := int(rc.r-rc.l), int(rc.b-rc.t)
		if w > 0 && h > 0 {
			x := int(int16(lparam&0xFFFF)) * screenW / w
			y := int(int16((lparam>>16)&0xFFFF)) * screenH / h
			app.Click(x, y)
		}
		return 0
	}
	v, _, _ := defProc.Call(hwnd, uintptr(message), wparam, lparam)
	return v
}

func main() {
	runtime.LockOSThread()
	gameTitle, _ := syscall.UTF16PtrFromString("МИРЫ НА БЕГУ — приключение")
	class, _ := syscall.UTF16PtrFromString("WorldsRunnerWindow2026")
	inst, _, _ := getModule.Call(0)
	cursor, _, _ := loadCursor.Call(0, IDC_ARROW)
	wc := wndClass{Size: uint32(unsafe.Sizeof(wndClass{})), Style: 3, WndProc: syscall.NewCallback(windowProc), Instance: inst, Cursor: cursor, ClassName: uintptr(unsafe.Pointer(class))}
	r, _, err := regClass.Call(uintptr(unsafe.Pointer(&wc)))
	if r == 0 {
		fmt.Fprintln(os.Stderr, "RegisterClassEx", err)
		return
	}
	desired := rect{0, 0, screenW, screenH}
	adjustWin.Call(uintptr(unsafe.Pointer(&desired)), WS_OVERLAPPEDWINDOW, 0)
	w := desired.r - desired.l
	h := desired.b - desired.t
	hwnd, _, err := createWin.Call(0, uintptr(unsafe.Pointer(class)), uintptr(unsafe.Pointer(gameTitle)), WS_OVERLAPPEDWINDOW|WS_VISIBLE, 190, 110, uintptr(w), uintptr(h), 0, 0, inst, 0)
	if hwnd == 0 {
		fmt.Fprintln(os.Stderr, "CreateWindowEx", err)
		return
	}
	HWND = hwnd
	app.Load()
	showWin.Call(hwnd, SW_SHOW)
	updateWin.Call(hwnd)
	last = time.Now()
	setTimer.Call(hwnd, 1, 16, 0)
	var m msg
	for {
		ok, _, _ := getMsg.Call(uintptr(unsafe.Pointer(&m)), 0, 0, 0)
		if int32(ok) <= 0 {
			break
		}
		translateMsg.Call(uintptr(unsafe.Pointer(&m)))
		dispatchMsg.Call(uintptr(unsafe.Pointer(&m)))
	}
	for _, f := range fonts {
		deleteObj.Call(f)
	}
}
