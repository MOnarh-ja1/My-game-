package main

import (
	"fmt"
	"math"
	"math/rand"
	"runtime"
	"syscall"
	"time"
	"unsafe"
)

const (
	W                   = 640
	H                   = 360
	WS_OVERLAPPEDWINDOW = 0x00CF0000
	WM_DESTROY          = 2
	WM_CLOSE            = 0x10
	WM_KEYDOWN          = 0x100
	WM_MOUSEMOVE        = 0x200
	WM_RBUTTONDOWN      = 0x204
	WM_RBUTTONUP        = 0x205
	WM_LBUTTONDOWN      = 0x201
	VK_ESCAPE           = 27
	BI_RGB              = 0
	DIB_RGB_COLORS      = 0
	SRCCOPY             = 0x00CC0020
	PM_REMOVE           = 1
)

var u = syscall.NewLazyDLL("user32.dll")
var g = syscall.NewLazyDLL("gdi32.dll")
var k = syscall.NewLazyDLL("kernel32.dll")
var regClass = u.NewProc("RegisterClassExW")
var createWin = u.NewProc("CreateWindowExW")
var defWin = u.NewProc("DefWindowProcW")
var showWin = u.NewProc("ShowWindow")
var updateWin = u.NewProc("UpdateWindow")
var peekMsg = u.NewProc("PeekMessageW")
var translate = u.NewProc("TranslateMessage")
var dispatch = u.NewProc("DispatchMessageW")
var postQuit = u.NewProc("PostQuitMessage")
var getDC = u.NewProc("GetDC")
var releaseDC = u.NewProc("ReleaseDC")
var cursor = u.NewProc("ShowCursor")
var getAsync = u.NewProc("GetAsyncKeyState")
var getClient = u.NewProc("GetClientRect")
var textOut = g.NewProc("TextOutW")
var setBk = g.NewProc("SetBkMode")
var setTextColor = g.NewProc("SetTextColor")
var stretch = g.NewProc("StretchDIBits")

type WNDCLASSEX struct {
	Size       uint32
	Style      uint32
	WndProc    uintptr
	ClsExtra   int32
	WndExtra   int32
	Inst       uintptr
	Icon       uintptr
	Cursor     uintptr
	Background uintptr
	MenuName   *uint16
	ClassName  *uint16
	IconSm     uintptr
}
type MSG struct {
	Hwnd    uintptr
	Message uint32
	Pad     uint32
	Wparam  uintptr
	Lparam  uintptr
	Time    uint32
	PtX     int32
	PtY     int32
	Private uint32
}
type Rect struct{ Left, Top, Right, Bottom int32 }
type InfoHeader struct {
	Size                   uint32
	Width, Height          int32
	Planes, BitCount       uint16
	Compression, SizeImage uint32
	XPels, YPels           int32
	ClrUsed, ClrImportant  uint32
}
type BmpInfo struct {
	Header InfoHeader
	Colors [1]uint32
}
type V struct{ x, y, z float64 }
type Tri struct {
	a, b, c V
	col     uint32
}
type ScreenV struct{ x, y, z float64 }
type Dig struct {
	x, z     float64
	progress int
	found    bool
	cleared  bool
	artifact string
	value    int
}

var hwnd uintptr
var running = true
var dragging = false
var lastMX, lastMY int
var cam = V{0, 2.1, -12}
var yaw = 0.0
var pitch = -0.10
var money = 0
var level = 1
var clean = 0
var carrying = -1
var digsites = []Dig{{-7, 4, 0, false, false, "BRONZE RELIC", 45}, {3, 7, 0, false, false, "ANCIENT COIN", 80}, {9, 14, 0, false, false, "AMBER GEM", 120}, {-11, 18, 0, false, false, "LOST IDOL", 220}, {0, 24, 0, false, false, "GOLDEN MASK", 450}, {13, 26, 0, false, false, "STONE TABLET", 150}, {-12, 31, 0, false, false, "SILVER AMULET", 340}}
var frame [W * H]uint32
var depths [W * H]float32
var bmp = BmpInfo{Header: InfoHeader{Size: 40, Width: W, Height: -H, Planes: 1, BitCount: 32, Compression: BI_RGB}}
var tris []Tri
var near = 0.15

func rgb(r, gg, b int) uint32 {
	if r < 0 {
		r = 0
	}
	if r > 255 {
		r = 255
	}
	if gg < 0 {
		gg = 0
	}
	if gg > 255 {
		gg = 255
	}
	if b < 0 {
		b = 0
	}
	if b > 255 {
		b = 255
	}
	return uint32(b)<<16 | uint32(gg)<<8 | uint32(r)
}
func lerp(a, b, t float64) float64 { return a + (b-a)*t }
func terrain(x, z float64) float64 {
	return 0.18*math.Sin(x*.28) + .21*math.Cos(z*.16) + .24*math.Sin(x*.11+z*.24) + .11*math.Sin(z*.65+x*.24)
}
func dist(x, z float64) float64     { return math.Hypot(x-cam.x, z-cam.z) }
func add(a, b, c V, col uint32)     { tris = append(tris, Tri{a, b, c, col}) }
func quad(a, b, c, d V, col uint32) { add(a, b, c, col); add(a, c, d, col) }
func block(x, y, z, sx, sy, sz float64, base int) {
	p := func(dx, dy, dz float64) V { return V{x + dx*sx, y + dy*sy, z + dz*sz} }
	a, b, c, d := p(-.5, 0, -.5), p(.5, 0, -.5), p(.5, 0, .5), p(-.5, 0, .5)
	e, f, h, j := p(-.5, 1, -.5), p(.5, 1, -.5), p(.5, 1, .5), p(-.5, 1, .5)
	quad(a, b, f, e, rgb(base-12, base-10, base-7))
	quad(b, c, h, f, rgb(base+5, base+4, base))
	quad(c, d, j, h, rgb(base-20, base-18, base-12))
	quad(d, a, e, j, rgb(base-5, base-5, base-1))
	quad(e, f, h, j, rgb(base+20, base+17, base+12))
}
func cone(x, y, z, r, height float64, col uint32) {
	n := 8
	top := V{x, y + height, z}
	for i := 0; i < n; i++ {
		t := 2 * math.Pi * float64(i) / float64(n)
		tt := 2 * math.Pi * float64(i+1) / float64(n)
		add(V{x + r*math.Cos(t), y, z + r*math.Sin(t)}, V{x + r*math.Cos(tt), y, z + r*math.Sin(tt)}, top, col)
	}
}
func tree(x, z, scale float64) {
	y := terrain(x, z)
	block(x, y, z, .24*scale, 2.5*scale, .24*scale, 65)
	cone(x, y+1.3*scale, z, 1.25*scale, 2.7*scale, rgb(30, 84, 47))
	cone(x, y+2.3*scale, z, 1.08*scale, 2.5*scale, rgb(36, 99, 53))
	cone(x, y+3.3*scale, z, .77*scale, 1.8*scale, rgb(44, 112, 62))
}
func rock(x, z, scale float64) { y := terrain(x, z); block(x, y, z, scale, scale*.61, scale*.73, 91) }
func buildWorld() {
	tris = tris[:0]
	for z := -22; z < 57; z++ {
		for x := -36; x < 37; x++ {
			xx, zz := float64(x), float64(z)
			if math.Hypot(xx-cam.x, zz-cam.z) > 39 {
				continue
			}
			a := V{xx, terrain(xx, zz), zz}
			b := V{xx + 1, terrain(xx+1, zz), zz}
			c := V{xx + 1, terrain(xx+1, zz+1), zz + 1}
			d := V{xx, terrain(xx, zz+1), zz + 1}
			v := int(8 * math.Sin(xx*2.63+zz*2.4))
			col := rgb(92+v, 91+v, 60+v/2)
			if zz > 2 && math.Abs(xx) < 13 {
				col = rgb(105+v, 87+v/2, 61+v/2)
			}
			for i := range digsites {
				t := &digsites[i]
				if math.Abs(xx-t.x) < 1.3 && math.Abs(zz-t.z) < 1.3 {
					h := .10 * float64(t.progress)
					a.y -= h
					b.y -= h
					c.y -= h
					d.y -= h
					col = rgb(89+v, 61+v/2, 40+v/3)
				}
			}
			quad(a, b, c, d, col)
		}
	}
	for i := 0; i < 85; i++ {
		fi := float64(i)
		x := math.Sin(fi*91.73) * 29
		z := math.Cos(fi*77.13)*29 + 14
		if math.Abs(x) < 12 && z > 0 && z < 36 {
			continue
		}
		if dist(x, z) > 41 {
			continue
		}
		if i%5 == 0 {
			rock(x, z, 1.0+float64(i%4)*.31)
		} else {
			tree(x, z, .7+float64(i%7)*.13)
		}
	}
	// Ancient stone columns / entrance
	for _, z := range []float64{19, 28, 35} {
		for _, x := range []float64{-17, 17} {
			if dist(x, z) < 43 {
				y := terrain(x, z)
				block(x, y, x*0+z, 1.6, 4.1, 1.6, 112)
				block(x, y+4.0, z, 2.2, .43, 2.2, 129)
			}
		}
	}
	// camp & workbench
	if dist(-4, -4) < 40 {
		y := terrain(-4, -4)
		block(-4, y, -4, 4, .65, 2.2, 95)
		block(-5.5, y+.65, -4, .18, 2, .18, 75)
		block(-2.5, y+.65, -4, .18, 2, .18, 75)
		block(-4, y+2.2, -4, 5, .2, 3.3, 116)
	}
	if dist(4, -4) < 40 {
		y := terrain(4, -4)
		block(4, y, -4, 3, 1.1, 1.7, 89)
		block(4, y+1.05, -4, 3.2, .12, 2, 124)
	}
	for i := range digsites {
		p := &digsites[i]
		if dist(p.x, p.z) > 40 {
			continue
		}
		y := terrain(p.x, p.z)
		if !p.found {
			block(p.x, y-.4-float64(p.progress)*.08, p.z, .67, .48, .65, 135)
		} else if !p.cleared {
			block(p.x, y+.1, p.z, .75, .54, .8, 177)
		}
	}
}
func project(v V) (ScreenV, bool) {
	dx, dz := v.x-cam.x, v.z-cam.z
	cy, sy := math.Cos(yaw), math.Sin(yaw)
	x := dx*cy - dz*sy
	z := dx*sy + dz*cy
	dy := v.y - cam.y
	cp, sp := math.Cos(pitch), math.Sin(pitch)
	y := dy*cp - z*sp
	zz := dy*sp + z*cp
	if zz < near {
		return ScreenV{}, false
	}
	f := float64(W) * .90
	return ScreenV{float64(W)/2 + x*f/zz, float64(H)/2 - y*f/zz, zz}, true
}
func paint(t Tri) {
	a, ok := project(t.a)
	if !ok {
		return
	}
	b, ok := project(t.b)
	if !ok {
		return
	}
	c, ok := project(t.c)
	if !ok {
		return
	}
	minx := int(math.Max(0, math.Floor(math.Min(a.x, math.Min(b.x, c.x)))))
	maxx := int(math.Min(W-1, math.Ceil(math.Max(a.x, math.Max(b.x, c.x)))))
	miny := int(math.Max(0, math.Floor(math.Min(a.y, math.Min(b.y, c.y)))))
	maxy := int(math.Min(H-1, math.Ceil(math.Max(a.y, math.Max(b.y, c.y)))))
	den := (b.y-c.y)*(a.x-c.x) + (c.x-b.x)*(a.y-c.y)
	if math.Abs(den) < .001 {
		return
	}
	shade := math.Max(.35, 1.0-math.Min(1, a.z/75)*.56)
	r := int(t.col & 255)
	gg := int((t.col >> 8) & 255)
	bb := int((t.col >> 16) & 255)
	color := rgb(int(float64(r)*shade), int(float64(gg)*shade), int(float64(bb)*shade))
	for y := miny; y <= maxy; y++ {
		for x := minx; x <= maxx; x++ {
			px, py := float64(x)+.5, float64(y)+.5
			v := ((b.y-c.y)*(px-c.x) + (c.x-b.x)*(py-c.y)) / den
			w := ((c.y-a.y)*(px-c.x) + (a.x-c.x)*(py-c.y)) / den
			u := 1 - v - w
			if v < 0 || w < 0 || u < 0 {
				continue
			}
			z := 1 / (v/a.z + w/b.z + u/c.z)
			j := y*W + x
			if float32(z) < depths[j] {
				depths[j] = float32(z)
				frame[j] = color
			}
		}
	}
}
func render() {
	for y := 0; y < H; y++ {
		v := float64(y) / H
		for x := 0; x < W; x++ {
			i := y*W + x
			depths[i] = 99999
			if v < .55 {
				frame[i] = rgb(int(lerp(73, 178, v*1.5)), int(lerp(124, 197, v*1.4)), int(lerp(174, 208, v*1.4)))
			} else {
				frame[i] = rgb(158, 171, 148)
			}
		}
	}
	buildWorld()
	for _, t := range tris {
		paint(t)
	}
	// center crosshair
	for d := -7; d <= 7; d++ {
		if math.Abs(float64(d)) <= 2 {
			continue
		}
		frame[(H/2)*W+(W/2+d)] = rgb(242, 232, 202)
		frame[(H/2+d)*W+W/2] = rgb(242, 232, 202)
	}
	// HUD dark transparent-like bands
	for y := 0; y < 48; y++ {
		for x := 0; x < W; x++ {
			i := y*W + x
			v := frame[i]
			frame[i] = rgb(int(v&255)/4+10, int(v>>8&255)/4+17, int(v>>16&255)/4+20)
		}
	}
	for y := H - 35; y < H; y++ {
		for x := 0; x < W; x++ {
			i := y*W + x
			v := frame[i]
			frame[i] = rgb(int(v&255)/4+8, int(v>>8&255)/4+13, int(v>>16&255)/4+13)
		}
	}
	// Convert RGB colors to Windows DIB pixel order.
	for i, c := range frame {
		frame[i] = (c & 0x0000ff00) | ((c & 0x000000ff) << 16) | ((c & 0x00ff0000) >> 16)
	}
}
func drawText(dc uintptr, x, y int, s string, colour uint32) {
	p, _ := syscall.UTF16PtrFromString(s)
	setTextColor.Call(dc, uintptr(colour))
	textOut.Call(dc, uintptr(x), uintptr(y), uintptr(unsafe.Pointer(p)), uintptr(len([]rune(s))))
}
func present() {
	dc, _, _ := getDC.Call(hwnd)
	var rc Rect
	getClient.Call(hwnd, uintptr(unsafe.Pointer(&rc)))
	ww, hh := int(rc.Right-rc.Left), int(rc.Bottom-rc.Top)
	stretch.Call(dc, 0, 0, uintptr(ww), uintptr(hh), 0, 0, W, H, uintptr(unsafe.Pointer(&frame[0])), uintptr(unsafe.Pointer(&bmp)), DIB_RGB_COLORS, SRCCOPY)
	setBk.Call(dc, 1)
	drawText(dc, 20, 10, "DIG & FIND  |  FIELD EXPEDITION", rgb(238, 239, 223))
	drawText(dc, 20, 30, fmt.Sprintf("CREDITS: %d     SHOVEL LVL: %d     ARTIFACTS: %d/%d", money, level, inventory(), len(digsites)), rgb(195, 222, 174))
	drawText(dc, 20, hh-25, "WASD WALK  |  RMB LOOK  |  E DIG  |  F CLEAN  |  Q SELL  |  1 UPGRADE  |  ESC EXIT", rgb(241, 232, 209))
	if carrying >= 0 {
		p := digsites[carrying]
		msg := fmt.Sprintf("FOUND: %s   |   CLEANING %d%%   |   F TO CLEAN", p.artifact, clean)
		drawText(dc, 20, hh-48, msg, rgb(255, 213, 123))
	} else {
		idx := nearest()
		if idx >= 0 {
			p := digsites[idx]
			if !p.found {
				drawText(dc, 20, hh-48, fmt.Sprintf("DIG SITE: %d / %d  |  PRESS E", p.progress, 6), rgb(252, 223, 139))
			} else if !p.cleared {
				drawText(dc, 20, hh-48, "PRESS E TO PICK UP ARTIFACT", rgb(255, 229, 140))
			}
		}
	}
	releaseDC.Call(hwnd, dc)
}
func inventory() int {
	n := 0
	for _, p := range digsites {
		if p.cleared {
			n++
		}
	}
	return n
}
func nearest() int {
	best := 2.8
	id := -1
	for i := range digsites {
		p := &digsites[i]
		d := math.Hypot(p.x-cam.x, p.z-cam.z)
		if d < best {
			best = d
			id = i
		}
	}
	return id
}
func interact() {
	if carrying >= 0 {
		return
	}
	idx := nearest()
	if idx < 0 {
		return
	}
	p := &digsites[idx]
	if !p.found {
		p.progress += level
		if p.progress >= 6 {
			p.progress = 6
			p.found = true
		}
	} else if !p.cleared {
		carrying = idx
		clean = 0
	}
}
func cleanUp() {
	if carrying < 0 {
		return
	}
	clean += 20 + level*5
	if clean >= 100 {
		clean = 100
		digsites[carrying].cleared = true
		money += digsites[carrying].value
		carrying = -1
		clean = 0
	}
}
func keydown(key int) {
	if key < 0 || key > 255 {
		return
	}
	if key == VK_ESCAPE {
		running = false
		return
	}
	if key == 'E' {
		interact()
	}
	if key == 'F' {
		cleanUp()
	}
	if key == 'Q' {
		if carrying >= 0 {
			cleanUp()
		}
	}
	if key == '1' && money >= 100*level {
		money -= 100 * level
		level++
	}
}
func wndProc(h uintptr, m uint32, w, l uintptr) uintptr {
	switch m {
	case WM_CLOSE, WM_DESTROY:
		running = false
		postQuit.Call(0)
		return 0
	case WM_KEYDOWN:
		keydown(int(w))
		return 0
	case WM_RBUTTONDOWN:
		dragging = true
		lastMX = int(int16(l & 0xFFFF))
		lastMY = int(int16(l >> 16))
		return 0
	case WM_RBUTTONUP:
		dragging = false
		return 0
	case WM_MOUSEMOVE:
		if dragging {
			mx, my := int(int16(l&0xFFFF)), int(int16(l>>16))
			yaw += float64(mx-lastMX) * .004
			pitch += float64(my-lastMY) * .003
			if pitch > 1.15 {
				pitch = 1.15
			}
			if pitch < -0.9 {
				pitch = -.9
			}
			lastMX = mx
			lastMY = my
		}
		return 0
	case WM_LBUTTONDOWN:
		interact()
		return 0
	}
	r, _, _ := defWin.Call(h, uintptr(m), w, l)
	return r
}
func down(v int) bool { r, _, _ := getAsync.Call(uintptr(v)); return r&0x8000 != 0 }
func update(dt float64) {
	speed := 4.2
	if down(0x10) {
		speed = 6.2
	}
	fwd, side := 0., 0.
	if down('W') {
		fwd++
	}
	if down('S') {
		fwd--
	}
	if down('D') {
		side++
	}
	if down('A') {
		side--
	}
	if fwd != 0 || side != 0 {
		norm := math.Hypot(fwd, side)
		fwd /= norm
		side /= norm
		cam.x += (math.Sin(yaw)*fwd + math.Cos(yaw)*side) * speed * dt
		cam.z += (math.Cos(yaw)*fwd - math.Sin(yaw)*side) * speed * dt
	}
	if cam.x > 30 {
		cam.x = 30
	}
	if cam.x < -30 {
		cam.x = -30
	}
	if cam.z > 48 {
		cam.z = 48
	}
	if cam.z < -19 {
		cam.z = -19
	}
	cam.y = terrain(cam.x, cam.z) + 2.1
}
func main() {
	runtime.LockOSThread()
	rand.Seed(time.Now().UnixNano())
	inst, _, _ := k.NewProc("GetModuleHandleW").Call(0)
	class := syscall.StringToUTF16Ptr("DigAndFindNative")
	wc := WNDCLASSEX{Size: uint32(unsafe.Sizeof(WNDCLASSEX{})), WndProc: syscall.NewCallback(wndProc), Inst: inst, ClassName: class}
	regClass.Call(uintptr(unsafe.Pointer(&wc)))
	title := syscall.StringToUTF16Ptr("DIG & FIND - Field Expedition")
	hwnd, _, _ = createWin.Call(0, uintptr(unsafe.Pointer(class)), uintptr(unsafe.Pointer(title)), WS_OVERLAPPEDWINDOW, 120, 90, 1200, 720, 0, 0, inst, 0)
	if hwnd == 0 {
		panic("CreateWindowEx failed")
	}
	showWin.Call(hwnd, 5)
	updateWin.Call(hwnd)
	prev := time.Now()
	var msg MSG
	for running {
		for {
			r, _, _ := peekMsg.Call(uintptr(unsafe.Pointer(&msg)), 0, 0, 0, PM_REMOVE)
			if r == 0 {
				break
			}
			translate.Call(uintptr(unsafe.Pointer(&msg)))
			dispatch.Call(uintptr(unsafe.Pointer(&msg)))
		}
		dt := time.Since(prev).Seconds()
		prev = time.Now()
		if dt > .05 {
			dt = .05
		}
		update(dt)
		render()
		present()
		time.Sleep(17 * time.Millisecond)
	}
}