package main

import (
	"encoding/json"
	"math"
	"math/rand"
	"os"
	"path/filepath"
	"time"
)

type World struct {
	Name, Short, Flavor                                     string
	Cost                                                    int
	SkyTop, SkyBottom, Ground, Road, Edge, Decor, Highlight uint32
}

var worlds = []World{
	{"ЗЕЛЁНАЯ ДОЛИНА", "ДОЛИНА", "Луга, дубы и старые мостики", 0, rgb(86, 167, 218), rgb(219, 244, 215), rgb(97, 169, 98), rgb(165, 129, 92), rgb(226, 209, 153), rgb(48, 125, 77), rgb(250, 228, 125)},
	{"ПЕСЧАНОЕ КОРОЛЕВСТВО", "ПУСТЫНЯ", "Дюны и древние руины", 80, rgb(101, 152, 204), rgb(254, 217, 157), rgb(231, 177, 100), rgb(173, 119, 80), rgb(252, 221, 159), rgb(186, 106, 63), rgb(255, 217, 113)},
	{"СНЕЖНЫЕ ВЕРШИНЫ", "СНЕГ", "Сугробы, ели и ледяные тропы", 200, rgb(72, 130, 194), rgb(207, 239, 252), rgb(220, 237, 245), rgb(138, 173, 184), rgb(245, 251, 255), rgb(68, 117, 139), rgb(248, 252, 255)},
	{"ЗАТЕРЯННЫЕ ДЖУНГЛИ", "ДЖУНГЛИ", "Тайные храмы и тропический лес", 420, rgb(41, 133, 134), rgb(159, 216, 163), rgb(67, 135, 70), rgb(130, 110, 71), rgb(192, 185, 125), rgb(34, 95, 55), rgb(250, 199, 89)},
	{"ВУЛКАНИЧЕСКИЙ ОСТРОВ", "ВУЛКАН", "Лава и базальтовые скалы", 800, rgb(80, 70, 96), rgb(229, 144, 104), rgb(108, 84, 80), rgb(91, 76, 75), rgb(209, 121, 75), rgb(56, 50, 62), rgb(255, 181, 84)},
}

type Object struct {
	lane, kind int
	z          float64
	used       bool
}

const (
	Rock   = 0
	Bar    = 1
	Fence  = 2
	Coin   = 3
	Shield = 4
)
const (
	Menu    = 0
	Shop    = 1
	Playing = 2
	Paused  = 3
	Over    = 4
)

type Saved struct {
	Wallet   int     `json:"wallet"`
	Best     [5]int  `json:"best"`
	Owned    [5]bool `json:"owned"`
	Selected int     `json:"selected"`
}
type Game struct {
	state                           int
	save                            Saved
	savePath                        string
	objects                         []Object
	lane                            int
	smoothLane                      float64
	jump, slide, shield, invuln     float64
	elapsed, roadMove, speed, spawn float64
	score, runCoins, hearts         int
	world                           int
	feedback                        string
	feedbackTime                    float64
	lastSave                        time.Time
}

func NewGame() *Game {
	g := &Game{state: Menu, hearts: 3, lane: 1, smoothLane: 1}
	g.save.Owned[0] = true
	return g
}
func (g *Game) Load() {
	base, err := os.UserConfigDir()
	if err != nil {
		base = os.TempDir()
	}
	g.savePath = filepath.Join(base, "MiryNaBegu", "progress.json")
	content, err := os.ReadFile(g.savePath)
	if err == nil {
		var s Saved
		if json.Unmarshal(content, &s) == nil {
			g.save = s
		}
	}
	g.save.Owned[0] = true
	if g.save.Selected < 0 || g.save.Selected >= len(worlds) || !g.save.Owned[g.save.Selected] {
		g.save.Selected = 0
	}
	if g.save.Wallet < 0 {
		g.save.Wallet = 0
	}
	g.world = g.save.Selected
}
func (g *Game) Save() {
	if g.savePath == "" {
		return
	}
	b, e := json.MarshalIndent(g.save, "", "  ")
	if e != nil {
		return
	}
	if os.MkdirAll(filepath.Dir(g.savePath), 0755) == nil {
		_ = os.WriteFile(g.savePath, b, 0644)
	}
}
func (g *Game) Start() {
	g.state = Playing
	g.world = g.save.Selected
	g.lane = 1
	g.smoothLane = 1
	g.jump = 0
	g.slide = 0
	g.shield = 0
	g.invuln = 0
	g.elapsed = 0
	g.roadMove = 0
	g.spawn = 0.8
	g.speed = .35
	g.objects = nil
	g.score = 0
	g.runCoins = 0
	g.hearts = 3
	g.feedback = ""
	g.lastSave = time.Now()
}
func (g *Game) End() {
	if g.state != Playing {
		return
	}
	g.state = Over
	if g.score > g.save.Best[g.world] {
		g.save.Best[g.world] = g.score
	}
	g.Save()
}
func (g *Game) Key(k int) {
	switch g.state {
	case Menu:
		if k == 13 || k == 32 {
			g.Start()
		} else if k == 66 {
			g.state = Shop
		}
	case Shop:
		if k == 27 || k == 8 {
			g.state = Menu
		} else if k >= 49 && k <= 53 {
			g.Choose(k - 49)
		}
	case Playing:
		switch k {
		case 65, 37:
			if g.lane > 0 {
				g.lane--
			}
		case 68, 39:
			if g.lane < 2 {
				g.lane++
			}
		case 87, 38, 32:
			if g.jump <= 0 && g.slide <= 0 {
				g.jump = .78
			}
		case 83, 40, 17:
			if g.slide <= 0 && g.jump <= 0 {
				g.slide = .77
			}
		case 27, 80:
			g.state = Paused
			g.Save()
		}
	case Paused:
		if k == 27 || k == 80 || k == 13 {
			g.state = Playing
		} else if k == 77 {
			g.state = Menu
			g.Save()
		}
	case Over:
		if k == 13 || k == 32 || k == 82 {
			g.Start()
		} else if k == 27 || k == 77 {
			g.state = Menu
		}
	}
}
func in(x, y int, r Box) bool { return x >= r.X && x <= r.X+r.W && y >= r.Y && y <= r.Y+r.H }
func (g *Game) Click(x, y int) {
	switch g.state {
	case Menu:
		if in(x, y, Box{117, 392, 298, 60}) {
			g.Start()
		} else if in(x, y, Box{117, 465, 298, 60}) {
			g.state = Shop
		}
	case Shop:
		if in(x, y, Box{24, 22, 138, 44}) {
			g.state = Menu
			return
		}
		for i := 0; i < len(worlds); i++ {
			if in(x, y, Box{21 + i*218, 202, 201, 342}) {
				g.Choose(i)
				return
			}
		}
	case Playing:
		if in(x, y, Box{1028, 20, 52, 49}) {
			g.state = Paused
			g.Save()
		}
	case Paused:
		if in(x, y, Box{395, 323, 310, 65}) {
			g.state = Playing
		} else if in(x, y, Box{395, 407, 310, 61}) {
			g.state = Menu
			g.Save()
		}
	case Over:
		if in(x, y, Box{403, 414, 294, 64}) {
			g.Start()
		} else if in(x, y, Box{403, 500, 294, 59}) {
			g.state = Menu
		}
	}
}
func (g *Game) Choose(i int) {
	if i < 0 || i >= len(worlds) {
		return
	}
	if g.save.Owned[i] {
		g.save.Selected = i
		g.world = i
		g.state = Menu
		g.feedback = ""
		g.Save()
		return
	}
	if g.save.Wallet >= worlds[i].Cost {
		g.save.Wallet -= worlds[i].Cost
		g.save.Owned[i] = true
		g.save.Selected = i
		g.world = i
		g.state = Menu
		g.feedback = "МИР ОТКРЫТ!"
		g.feedbackTime = 2.6
		g.Save()
		return
	}
	g.feedback = "НЕ ХВАТАЕТ МОНЕТ: НУЖНО ЕЩЁ " + itoa(worlds[i].Cost-g.save.Wallet)
	g.feedbackTime = 2.7
}
func (g *Game) Update(dt float64) {
	if g.feedbackTime > 0 {
		g.feedbackTime -= dt
	}
	if g.state != Playing {
		return
	}
	g.elapsed += dt
	g.roadMove += dt * g.speed
	g.speed = math.Min(.72, .35+g.elapsed*.0030)
	g.smoothLane += (float64(g.lane) - g.smoothLane) * math.Min(1, dt*13)
	g.jump = math.Max(0, g.jump-dt)
	g.slide = math.Max(0, g.slide-dt)
	g.shield = math.Max(0, g.shield-dt)
	g.invuln = math.Max(0, g.invuln-dt)
	g.score += int(dt * (160 + g.elapsed*.75))
	g.spawn -= dt
	if g.spawn <= 0 {
		g.spawnGroup()
		g.spawn = .88 + rand.Float64()*.42
		g.spawn *= math.Max(.78, 1-g.elapsed/550)
	}
	for i := len(g.objects) - 1; i >= 0; i-- {
		o := &g.objects[i]
		o.z += g.speed * dt
		if o.z > 1.20 {
			g.objects = append(g.objects[:i], g.objects[i+1:]...)
			continue
		}
		if o.used || o.z < .94 || o.z > 1.06 {
			continue
		}
		same := o.lane == g.lane && math.Abs(g.smoothLane-float64(g.lane)) < .38
		if !same {
			continue
		}
		switch o.kind {
		case Coin:
			o.used = true
			g.runCoins++
			g.save.Wallet++
			g.score += 40
		case Shield:
			o.used = true
			g.shield = 8.0
		default:
			o.used = true
			avoid := (o.kind == Bar && g.slide > 0) || (o.kind == Fence && g.jump > .13)
			if avoid {
				continue
			}
			if g.shield > 0 {
				g.shield = 0
				g.invuln = 1.1
				continue
			}
			if g.invuln > 0 {
				continue
			}
			g.hearts--
			g.invuln = 1.35
			if g.hearts <= 0 {
				g.End()
				return
			}
		}
	}
	if time.Since(g.lastSave) > 8*time.Second {
		g.Save()
		g.lastSave = time.Now()
	}
}
func (g *Game) spawnGroup() {
	blocked := rand.Intn(3)
	kinds := []int{Rock, Fence, Bar, Rock}
	g.objects = append(g.objects, Object{lane: blocked, kind: kinds[rand.Intn(len(kinds))], z: -.06})
	safe := []int{}
	two := g.elapsed > 22 && rand.Float64() < .35
	other := -1
	if two {
		other = (blocked + rand.Intn(2) + 1) % 3
		g.objects = append(g.objects, Object{lane: other, kind: kinds[rand.Intn(len(kinds))], z: -.06})
	}
	for i := 0; i < 3; i++ {
		if i != blocked && i != other {
			safe = append(safe, i)
		}
	}
	coinLane := safe[rand.Intn(len(safe))]
	for j := 0; j < 4; j++ {
		g.objects = append(g.objects, Object{lane: coinLane, kind: Coin, z: -.28 - float64(j)*.16})
	}
	if rand.Float64() < .10 {
		g.objects = append(g.objects, Object{lane: coinLane, kind: Shield, z: -.46})
	}
}
func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	if n < 0 {
		return "-" + itoa(-n)
	}
	var s [20]byte
	i := len(s)
	for n > 0 {
		i--
		s[i] = byte('0' + n%10)
		n /= 10
	}
	return string(s[i:])
}
