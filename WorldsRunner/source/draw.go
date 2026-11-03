package main

import (
	"math"
	"math/rand"
	"time"
)

type Box struct{ X, Y, W, H int }

func rgb(r, g, b uint8) uint32 { return uint32(r)<<16 | uint32(g)<<8 | uint32(b) }
func col(r, g, b int) uint32   { return rgb(uint8(r), uint8(g), uint8(b)) }
func colorRef(c uint32) uint32 { return ((c & 0xff) << 16) | (c & 0xff00) | ((c >> 16) & 0xff) }
func mix(a, b uint32, t float64) uint32 {
	if t < 0 {
		t = 0
	}
	if t > 1 {
		t = 1
	}
	return rgb(uint8(float64((a>>16)&255)*(1-t)+float64((b>>16)&255)*t), uint8(float64((a>>8)&255)*(1-t)+float64((b>>8)&255)*t), uint8(float64(a&255)*(1-t)+float64(b&255)*t))
}
func abs(a int) int {
	if a < 0 {
		return -a
	}
	return a
}
func clamp(a, lo, hi int) int {
	if a < lo {
		return lo
	}
	if a > hi {
		return hi
	}
	return a
}
func fill(c uint32) {
	for i := range pixels {
		pixels[i] = c
	}
}
func rectFill(x, y, w, h int, c uint32) {
	if x >= screenW || y >= screenH || x+w <= 0 || y+h <= 0 || w <= 0 || h <= 0 {
		return
	}
	x0 := clamp(x, 0, screenW)
	y0 := clamp(y, 0, screenH)
	x1 := clamp(x+w, 0, screenW)
	y1 := clamp(y+h, 0, screenH)
	for yy := y0; yy < y1; yy++ {
		start := yy * screenW
		for xx := x0; xx < x1; xx++ {
			pixels[start+xx] = c
		}
	}
}
func blendRect(x, y, w, h int, c uint32, alpha float64) {
	if alpha <= 0 {
		return
	}
	x0 := clamp(x, 0, screenW)
	y0 := clamp(y, 0, screenH)
	x1 := clamp(x+w, 0, screenW)
	y1 := clamp(y+h, 0, screenH)
	if x0 >= x1 || y0 >= y1 {
		return
	}
	for yy := y0; yy < y1; yy++ {
		for xx := x0; xx < x1; xx++ {
			i := yy*screenW + xx
			pixels[i] = mix(pixels[i], c, alpha)
		}
	}
}
func circle(cx, cy, r int, c uint32) {
	if r <= 0 {
		return
	}
	for yy := clamp(cy-r, 0, screenH); yy < clamp(cy+r+1, 0, screenH); yy++ {
		dy := yy - cy
		dx := int(math.Sqrt(float64(r*r - dy*dy)))
		rectFill(cx-dx, yy, dx*2+1, 1, c)
	}
}
func ellipse(cx, cy, rx, ry int, c uint32) {
	if rx <= 0 || ry <= 0 {
		return
	}
	for yy := clamp(cy-ry, 0, screenH); yy < clamp(cy+ry+1, 0, screenH); yy++ {
		dy := float64(yy-cy) / float64(ry)
		dx := int(float64(rx) * math.Sqrt(math.Max(0, 1-dy*dy)))
		rectFill(cx-dx, yy, dx*2+1, 1, c)
	}
}
func line(x0, y0, x1, y1, t int, c uint32) {
	dx := abs(x1 - x0)
	dy := abs(y1 - y0)
	sx := -1
	if x0 < x1 {
		sx = 1
	}
	sy := -1
	if y0 < y1 {
		sy = 1
	}
	err := dx - dy
	for j := 0; j < 4000; j++ {
		rectFill(x0-t/2, y0-t/2, t, t, c)
		if x0 == x1 && y0 == y1 {
			break
		}
		e2 := err * 2
		if e2 > -dy {
			err -= dy
			x0 += sx
		}
		if e2 < dx {
			err += dx
			y0 += sy
		}
	}
}
func tri(x1, y1, x2, y2, x3, y3 int, c uint32) {
	minY := clamp(min(y1, min(y2, y3)), 0, screenH)
	maxY := clamp(max(y1, max(y2, y3)), 0, screenH)
	for y := minY; y <= maxY; y++ {
		xs := []float64{}
		edges := [3][4]int{{x1, y1, x2, y2}, {x2, y2, x3, y3}, {x3, y3, x1, y1}}
		for _, e := range edges {
			if e[1] == e[3] {
				continue
			}
			if y >= min(e[1], e[3]) && y < max(e[1], e[3]) {
				f := float64(y-e[1]) / float64(e[3]-e[1])
				xs = append(xs, float64(e[0])+f*float64(e[2]-e[0]))
			}
		}
		if len(xs) >= 2 {
			l, r := int(xs[0]), int(xs[1])
			if r < l {
				l, r = r, l
			}
			rectFill(l, y, r-l+1, 1, c)
		}
	}
}
func rounded(x, y, w, h, r int, c uint32) {
	if r <= 0 {
		rectFill(x, y, w, h, c)
		return
	}
	rectFill(x+r, y, w-2*r, h, c)
	rectFill(x, y+r, r, h-2*r, c)
	rectFill(x+w-r, y+r, r, h-2*r, c)
	circle(x+r, y+r, r, c)
	circle(x+w-r-1, y+r, r, c)
	circle(x+r, y+h-r-1, r, c)
	circle(x+w-r-1, y+h-r-1, r, c)
}
func gradient(y0, y1 int, top, bottom uint32) {
	for y := max(0, y0); y < min(screenH, y1); y++ {
		v := float64(y-y0) / float64(max(1, y1-y0))
		rectFill(0, y, screenW, 1, mix(top, bottom, v))
	}
}
func txt(s string, x, y, px int, c uint32, bold bool) { putText(s, x, y, px, c, false, bold) }
func ctr(s string, x, y, px int, c uint32, bold bool) { putText(s, x, y, px, c, true, bold) }

var white = rgb(250, 250, 246)
var dark = rgb(22, 40, 51)
var ink = rgb(37, 54, 62)
var pale = rgb(222, 235, 235)
var gold = rgb(255, 213, 101)

func (g *Game) Draw() {
	labels = labels[:0]
	sceneWorld := g.world
	if g.state == Shop {
		sceneWorld = g.save.Selected
	}
	g.drawLandscape(sceneWorld, 0, 0)
	g.drawTrack(sceneWorld)
	if g.state == Playing || g.state == Paused || g.state == Over {
		g.drawEntities()
		g.drawPlayer()
	}
	switch g.state {
	case Menu:
		g.drawMenu()
	case Shop:
		g.drawShop()
	case Playing:
		g.drawHUD()
	case Paused:
		g.drawHUD()
		g.drawPause()
	case Over:
		g.drawGameOver()
	}
}
func (g *Game) drawLandscape(world int, shiftX, shiftY int) {
	w := worlds[world]
	gradient(0, screenH, w.SkyTop, w.SkyBottom)
	if world == 4 { // volcanic ash haze
		circle(885, 120, 63, rgb(244, 167, 93))
		circle(888, 118, 48, rgb(255, 209, 127))
	} else {
		circle(882, 122, 65, mix(w.Highlight, w.SkyBottom, .42))
		circle(886, 116, 50, w.Highlight)
	}
	for n := 0; n < 5; n++ {
		x := (int(n*254+49)+int(g.roadMove*30)+2000)%1350 - 120
		y := 70 + n%3*35
		if world != 4 {
			ellipse(x, y, 74, 18, mix(w.SkyBottom, white, .7))
			ellipse(x+39, y-8, 40, 23, mix(w.SkyBottom, white, .7))
		}
	}
	// distant mountain range
	for i := -1; i < 7; i++ {
		x := i*224 - int(g.roadMove*6)%224
		h := 142 + (i*i*27)%85
		cc := mix(w.Decor, w.SkyBottom, .50)
		if world == 2 {
			cc = rgb(156, 198, 218)
		}
		tri(x, 325, x+133, 325-h, x+286, 325, cc)
		if world == 2 {
			tri(x+133, 325-h, x+103, 325-h+50, x+159, 325-h+50, white)
		}
	}
	rectFill(0, 320, screenW, 330, w.Ground)
	for i := -1; i < 10; i++ {
		x := i*145 - (int(g.roadMove*17) % 145)
		y := 321 + (i*i*17)%44
		ellipse(x+70, y+12, 140, 30, mix(w.Ground, w.SkyBottom, .19))
	}
	// scenery appears on the left and right of the runner's path
	for i := 0; i < 9; i++ {
		depth := math.Mod(float64(i)/8+g.roadMove*.46, 1)
		y := int(190 + 450*math.Pow(depth, 1.55))
		s := int(10 + depth*65)
		spread := int(130 + depth*460)
		for _, side := range []int{-1, 1} {
			x := screenW/2 + side*spread
			if x < -100 || x > screenW+100 {
				continue
			}
			g.drawProp(world, x, y, s, i+1)
		}
	}
	if world == 4 {
		for i := 0; i < 15; i++ {
			x := (i*137 + int(g.roadMove*30)) % screenW
			y := int(330 + float64(i*i*23%300))
			circle(x, y, 2+i%3, rgb(252, 162, 87))
		}
	}
}
func (g *Game) drawProp(w, x, y, s, i int) {
	switch w {
	case 0: // trunks and bushy oak crowns
		rectFill(x-s/8, y-s*2, s/4, s*2, rgb(112, 77, 55))
		circle(x, y-s*2, s/2, rgb(47, 129, 70))
		circle(x-s/3, y-s*17/10, s/2, rgb(76, 167, 88))
		circle(x+s/3, y-s*17/10, s/2, rgb(90, 173, 93))
	case 1:
		// desert cactus, sandstone columns
		if i%3 == 0 {
			rectFill(x-s/2, y-s*2, s, s*2, rgb(190, 127, 84))
			rectFill(x-s*3/5, y-s*21/10, s*6/5, s/4, rgb(224, 173, 109))
		} else {
			rectFill(x-s/8, y-s*2, s/4, s*2, rgb(72, 139, 92))
			circle(x, y-s*2, s/7, rgb(72, 139, 92))
			rectFill(x-s/3, y-s*12/10, s/3, s/4, rgb(72, 139, 92))
			rectFill(x-s/3, y-s*16/10, s/5, s/2, rgb(72, 139, 92))
			rectFill(x+s/10, y-s*9/10, s/3, s/4, rgb(72, 139, 92))
		}
	case 2:
		tri(x-s/2, y-s/3, x, y-s*2, x+s/2, y-s/3, rgb(61, 119, 125))
		tri(x-s*2/5, y-s/3, x, y-s*16/10, x+s*2/5, y-s/3, rgb(82, 148, 146))
		rectFill(x-s/10, y-s/2, s/5, s/2, rgb(87, 92, 110))
		ellipse(x, y, s*2/3, s/7, white)
	case 3:
		rectFill(x-s/9, y-s*2, s/5, s*2, rgb(81, 82, 48))
		for n := 0; n < 5; n++ {
			a := float64(n) * math.Pi * 2 / 5
			line(x, y-s*2, x+int(math.Sin(a)*float64(s)), y-s*2-int(math.Cos(a)*float64(s)/2), max(2, s/7), rgb(37, 116, 69))
		}
		circle(x, y-s*2, s/4, rgb(53, 159, 78))
	case 4:
		tri(x-s/2, y, x-s/8, y-s*16/10, x+s/2, y, rgb(63, 56, 61))
		tri(x-s/4, y, x+s/5, y-s, x+s*2/3, y, rgb(89, 66, 63))
		ellipse(x, y+3, s, s/7, rgb(236, 108, 64))
	}
}
func (g *Game) drawTrack(world int) {
	w := worlds[world]
	// road and shoulders — trapezoids in pseudo-perspective
	tri(407, 166, 693, 166, -40, 650, w.Edge)
	tri(693, 166, 1140, 650, -40, 650, w.Edge)
	tri(418, 166, 682, 166, 20, 650, w.Road)
	tri(682, 166, 1080, 650, 20, 650, w.Road)
	tri(423, 166, 677, 166, 44, 650, mix(w.Road, white, .12))
	tri(677, 166, 1056, 650, 44, 650, mix(w.Road, white, .12))
	for i := 0; i < 18; i++ {
		z := math.Mod(float64(i)/18+g.roadMove*.9, 1)
		z2 := math.Min(1, z+.035+z*.032)
		y1 := projectY(z)
		y2 := projectY(z2)
		for b := -1; b <= 1; b += 2 {
			x1 := 550 + int(float64(b)*(45+255*z))
			x2 := 550 + int(float64(b)*(45+255*z2))
			line(x1, y1, x2, y2, max(1, int(1+z*7)), mix(w.Edge, white, .45))
		}
	}
	// side stripes
	for _, side := range []int{-1, 1} {
		line(550+side*132, 166, 550+side*515, 650, 7, w.Edge)
		line(550+side*135, 166, 550+side*518, 650, 2, mix(w.Edge, white, .5))
	}
}
func projectY(z float64) int           { return int(165 + 475*math.Pow(math.Max(0, math.Min(1, z)), 1.52)) }
func projectX(lane int, z float64) int { return 550 + int((float64(lane)-1)*(43+255*z)) }
func (g *Game) drawEntities() {
	// draw far-to-near so foreground items overlap correctly
	for i := len(g.objects) - 1; i >= 0; i-- {
		o := g.objects[i]
		if o.used || o.z < 0 || o.z > 1.16 {
			continue
		}
		z := o.z
		x := projectX(o.lane, z)
		y := projectY(z)
		s := .20 + .82*z
		w := int(72 * s)
		h := int(88 * s)
		switch o.kind {
		case Coin:
			yy := y - int(46*s) + int(math.Sin(g.elapsed*10+z*13)*5*s)
			circle(x, yy, int(17*s)+2, rgb(169, 118, 34))
			circle(x, yy, int(15*s)+1, gold)
			circle(x, yy, int(11*s), rgb(255, 232, 157))
			ctr("★", x, yy-int(12*s), max(9, int(24*s)), rgb(193, 126, 46), true)
		case Shield:
			yy := y - int(50*s)
			circle(x, yy, int(26*s), rgb(228, 241, 248))
			circle(x, yy, int(21*s), rgb(71, 153, 190))
			ctr("✦", x, yy-int(13*s), max(12, int(29*s)), white, true)
		case Rock:
			tri(x-w/2, y, x-int(25*s), y-h, x+int(18*s), y-h/2, worlds[g.world].Decor)
			tri(x-w/2, y, x+int(18*s), y-h/2, x+w/2, y, rgb(82, 81, 82))
			tri(x-int(25*s), y-h, x+int(14*s), y-int(70*s), x+int(18*s), y-h/2, mix(worlds[g.world].Decor, white, .32))
		case Bar:
			post := max(3, int(12*s))
			rectFill(x-w/2, y-h, post, h, mix(worlds[g.world].Decor, dark, .30))
			rectFill(x+w/2-post, y-h, post, h, mix(worlds[g.world].Decor, dark, .30))
			rectFill(x-w/2, y-h, w, max(7, int(24*s)), rgb(223, 157, 72))
			rectFill(x-w/2, y-h, w, max(3, int(7*s)), rgb(250, 211, 131))
		case Fence:
			rectFill(x-w/2, y-int(44*s), w, max(4, int(19*s)), rgb(164, 93, 55))
			rectFill(x-w/2, y-int(36*s), w, max(3, int(9*s)), rgb(235, 185, 89))
			rectFill(x-w/2, y-int(44*s), max(3, int(11*s)), int(45*s), rgb(120, 77, 59))
			rectFill(x+w/2-int(11*s), y-int(44*s), max(3, int(11*s)), int(45*s), rgb(120, 77, 59))
		}
	}
}
func (g *Game) drawPlayer() {
	x := 550 + int((g.smoothLane-1)*298)
	ground := 555
	ellipse(x, ground+10, 45, 13, rgb(67, 71, 66))
	jumpHeight := 0
	if g.jump > 0 {
		jumpHeight = int(math.Sin(math.Pi*(1-g.jump/.78)) * 150)
	}
	y := ground - jumpHeight
	if g.invuln > 0 && int(g.elapsed*16)%2 == 0 {
		return
	}
	if g.shield > 0 {
		circle(x, y-72, 88, rgb(173, 224, 230))
		circle(x, y-72, 77, rgb(123, 196, 206))
	}
	if g.slide > 0 {
		rounded(x-51, y-47, 98, 36, 12, rgb(241, 188, 90))
		circle(x+38, y-44, 22, rgb(247, 203, 158))
		rectFill(x+45, y-48, 13, 6, dark)
		line(x-36, y-12, x-64, y, 13, rgb(58, 79, 103))
		line(x+13, y-8, x+58, y, 12, rgb(58, 79, 103))
		return
	}
	stride := int(math.Sin(g.elapsed*16) * 17)
	// legs
	line(x-14, y-51, x-19+stride, y-8, 14, rgb(65, 91, 117))
	line(x+13, y-51, x+22-stride, y-8, 14, rgb(65, 91, 117))
	rounded(x-35+stride, y-16, 31, 16, 6, rgb(36, 54, 63))
	rounded(x+8-stride, y-16, 34, 16, 6, rgb(36, 54, 63))
	// backpack and arms
	rounded(x-33, y-132, 66, 89, 17, rgb(67, 118, 90))
	line(x-29, y-118, x-43-stride, y-75, 15, rgb(246, 189, 142))
	line(x+29, y-118, x+45+stride, y-75, 15, rgb(246, 189, 142))
	rounded(x-28, y-133, 56, 83, 14, rgb(236, 167, 70))
	rounded(x-18, y-123, 36, 55, 9, rgb(247, 198, 98))
	rectFill(x-9, y-102, 18, 6, rgb(159, 118, 65))
	// friendly stylized adventurer: face/hair/cap
	circle(x, y-158, 31, rgb(250, 201, 155))
	ellipse(x, y-177, 34, 14, rgb(88, 66, 54))
	rounded(x-34, y-186, 68, 14, 6, rgb(72, 121, 84))
	rectFill(x-34, y-175, 42, 5, rgb(59, 103, 75))
	circle(x-11, y-154, 3, dark)
	circle(x+11, y-154, 3, dark)
	line(x-6, y-143, x+6, y-143, 2, rgb(170, 109, 92))
}
func (g *Game) drawHUD() {
	rounded(18, 18, 250, 86, 17, rgb(40, 59, 65))
	rounded(278, 18, 224, 86, 17, rgb(40, 59, 65))
	rounded(512, 18, 255, 86, 17, rgb(40, 59, 65))
	rounded(777, 18, 239, 86, 17, rgb(40, 59, 65))
	rounded(1028, 20, 52, 49, 11, rgb(40, 59, 65))
	txt("СЧЁТ", 35, 28, 17, pale, true)
	txt(itoa(g.score), 35, 52, 35, white, true)
	txt("МОНЕТЫ ЗАБЕГА", 294, 29, 14, pale, true)
	txt("★ "+itoa(g.runCoins), 294, 53, 33, gold, true)
	txt("МИР: "+worlds[g.world].Short, 529, 29, 17, pale, true)
	txt("РЕКОРД "+itoa(g.save.Best[g.world]), 529, 60, 22, white, true)
	txt("ЗДОРОВЬЕ", 793, 30, 17, pale, true)
	for i := 0; i < 3; i++ {
		cc := rgb(102, 116, 117)
		if i < g.hearts {
			cc = rgb(255, 120, 113)
		}
		circle(805+i*50, 78, 14, cc)
	}
	ctr("Ⅱ", 1054, 27, 30, white, true)
	rounded(192, 604, 716, 32, 12, rgb(40, 59, 65))
	ctr("A / D  —  ПОЛОСЫ       ПРОБЕЛ  —  ПРЫЖОК       S  —  ПОДКАТ", 550, 610, 16, white, false)
	if g.shield > 0 {
		rounded(450, 125, 202, 36, 15, rgb(48, 130, 156))
		ctr("ЩИТ: "+itoa(int(math.Ceil(g.shield)))+" СЕК", 551, 130, 20, white, true)
	}
}
func (g *Game) drawMenu() {
	blendRect(0, 0, screenW, screenH, dark, .20)
	rounded(82, 85, 450, 473, 32, rgb(30, 57, 67))
	rounded(101, 105, 412, 433, 26, rgb(39, 70, 77))
	txt("ПРИКЛЮЧЕНИЕ НА ПК", 119, 124, 18, gold, true)
	txt("МИРЫ", 114, 169, 71, white, true)
	txt("НА БЕГУ", 114, 251, 56, white, true)
	txt("Беги, собирай монеты", 119, 331, 21, pale, false)
	txt("и открывай новые миры!", 119, 357, 21, pale, false)
	button(Box{117, 392, 298, 60}, "▶  ИГРАТЬ", rgb(248, 200, 100), dark)
	button(Box{117, 465, 298, 60}, "МАГАЗИН МИРОВ", rgb(114, 205, 177), dark)
	rounded(645, 140, 390, 375, 26, rgb(245, 242, 215))
	rounded(662, 154, 356, 280, 19, worlds[g.world].SkyBottom)
	for i := 0; i < 9; i++ {
		x := 666 + i*43
		y := 380 - i%3*18
		g.drawSmallProp(g.world, x, y, 23)
	}
	rounded(663, 445, 354, 53, 12, rgb(33, 65, 72))
	ctr(worlds[g.world].Name, 840, 450, 23, white, true)
	ctr("РЕКОРД  "+itoa(g.save.Best[g.world]), 840, 482, 16, pale, false)
	rounded(777, 30, 277, 53, 15, rgb(30, 57, 67))
	ctr("★  "+itoa(g.save.Wallet)+" МОНЕТ", 916, 44, 24, gold, true)
	ctr("СТРЕЛКИ / A D — СМЕНА ПОЛОСЫ     ПРОБЕЛ — ПРЫЖОК     S — ПОДКАТ", 550, 607, 18, white, true)
	if g.feedbackTime > 0 {
		rounded(348, 566, 404, 38, 14, rgb(29, 93, 72))
		ctr(g.feedback, 550, 573, 19, white, true)
	}
}
func (g *Game) drawSmallProp(world, x, y, s int) {
	if world == 0 || world == 3 {
		rectFill(x-3, y-35, 7, 35, rgb(113, 86, 58))
		circle(x, y-40, 17, worlds[world].Decor)
	} else if world == 2 {
		tri(x-20, y, x, y-53, x+20, y, worlds[world].Decor)
	} else if world == 1 {
		tri(x-16, y, x, y-41, x+16, y, worlds[world].Decor)
	} else {
		tri(x-20, y, x-7, y-45, x+24, y, worlds[world].Decor)
	}
}
func (g *Game) drawShop() {
	blendRect(0, 0, screenW, screenH, dark, .72)
	rounded(22, 20, 145, 47, 13, rgb(237, 216, 162))
	ctr("← НАЗАД", 94, 27, 20, dark, true)
	ctr("МАГАЗИН МИРОВ", 550, 62, 49, white, true)
	ctr("СОБИРАЙ МОНЕТЫ В ЗАБЕГАХ И ОТКРЫВАЙ НОВЫЕ ПРИКЛЮЧЕНИЯ", 550, 121, 19, pale, false)
	rounded(838, 21, 245, 48, 13, rgb(29, 57, 63))
	ctr("★  "+itoa(g.save.Wallet)+" МОНЕТ", 961, 31, 23, gold, true)
	for i, w := range worlds {
		x := 21 + i*218
		y := 202
		frame := rgb(239, 236, 212)
		if i == g.save.Selected {
			frame = rgb(255, 212, 109)
		}
		rounded(x, y, 197, 342, 18, frame)
		rounded(x+9, y+9, 179, 191, 11, w.SkyBottom)
		for sy := y + 9; sy < y+126; sy++ {
			rectFill(x+9, sy, 179, 1, mix(w.SkyTop, w.SkyBottom, float64(sy-y-9)/117))
		}
		circle(x+140, y+49, 23, w.Highlight)
		tri(x+9, y+150, x+60, y+70, x+117, y+150, mix(w.Decor, w.SkyBottom, .5))
		tri(x+64, y+161, x+131, y+86, x+188, y+161, mix(w.Decor, w.SkyBottom, .3))
		rectFill(x+9, y+152, 179, 48, w.Ground)
		g.drawSmallProp(i, x+49, y+180, 26)
		g.drawSmallProp(i, x+151, y+182, 25)
		ctr(w.Short, x+98, y+211, 22, dark, true)
		if g.save.Owned[i] {
			rounded(x+13, y+268, 171, 46, 10, rgb(90, 165, 134))
			cap := "ВЫБРАТЬ"
			if i == g.save.Selected {
				cap = "ВЫБРАН ✓"
			}
			ctr(cap, x+99, y+280, 18, white, true)
		} else {
			rounded(x+13, y+268, 171, 46, 10, rgb(212, 152, 81))
			ctr("★  "+itoa(w.Cost)+" МОНЕТ", x+99, y+280, 17, white, true)
		}
	}
	ctr("КЛИКНИ ПО МИРУ, ЧТОБЫ КУПИТЬ ИЛИ ВЫБРАТЬ • КЛАВИШИ 1–5", 550, 573, 18, pale, false)
	if g.feedbackTime > 0 {
		rounded(199, 596, 702, 38, 13, rgb(109, 63, 56))
		ctr(g.feedback, 550, 604, 19, white, true)
	}
}
func (g *Game) drawPause() {
	blendRect(0, 0, screenW, screenH, dark, .76)
	rounded(321, 176, 458, 336, 30, rgb(37, 67, 73))
	ctr("ПАУЗА", 550, 212, 57, white, true)
	ctr("ESC ИЛИ P — ПРОДОЛЖИТЬ", 550, 284, 21, pale, false)
	button(Box{395, 323, 310, 65}, "ПРОДОЛЖИТЬ", gold, dark)
	button(Box{395, 407, 310, 61}, "ГЛАВНОЕ МЕНЮ", rgb(109, 202, 177), dark)
}
func (g *Game) drawGameOver() {
	blendRect(0, 0, screenW, screenH, dark, .75)
	rounded(302, 96, 496, 492, 30, rgb(39, 70, 77))
	ctr("ЗАБЕГ ОКОНЧЕН", 550, 137, 43, white, true)
	ctr("ТВОЙ СЧЁТ", 550, 210, 23, pale, false)
	ctr(itoa(g.score), 550, 249, 69, gold, true)
	ctr("★  +"+itoa(g.runCoins)+" МОНЕТ", 550, 350, 25, white, true)
	button(Box{403, 414, 294, 64}, "ЕЩЁ РАЗ", gold, dark)
	button(Box{403, 500, 294, 59}, "ГЛАВНОЕ МЕНЮ", rgb(117, 212, 184), dark)
}
func button(b Box, s string, c, foreground uint32) {
	rounded(b.X, b.Y, b.W, b.H, 13, c)
	ctr(s, b.X+b.W/2, b.Y+b.H/2-13, 24, foreground, true)
}

// A deterministic source of minor visual variation, independent of obstacle RNG.
func init() { rand.Seed(time.Now().UnixNano()) }
