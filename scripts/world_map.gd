extends Node2D
## Mapa del mundo: seleccion de playa. Usa assets/map.png como fondo
## (si no existe, dibuja un oceano). Marcadores segun Global.STAGES[i].pos.

const W := 320.0
const H := 180.0

var t := 0.0
var map_tex: Texture2D = null
var logo_tex: Texture2D = null
var star_tex: Texture2D = null
var idle_tex: Texture2D = null
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	Global.play_music_file(Global.MENU_MUSIC)
	for ruta in ["res://assets/map.png", "res://assets/map.jpg", "res://assets/map.jpeg"]:
		if ResourceLoader.exists(ruta):
			map_tex = load(ruta)
			break
	if ResourceLoader.exists("res://assets/logo.png"):
		logo_tex = load("res://assets/logo.png")
	if ResourceLoader.exists("res://assets/star.png"):
		star_tex = load("res://assets/star.png")
	if ResourceLoader.exists("res://assets/surfer_idle.png"):
		idle_tex = load("res://assets/surfer_idle.png")

func _process(delta: float) -> void:
	t += delta * 60.0
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("musica"):
		Global.toggle_music()
	elif event.is_action_pressed("derecha") or event.is_action_pressed("abajo"):
		Global.sel = (Global.sel + 1) % Global.unlocked
		Global.sfx("ui")
	elif event.is_action_pressed("izquierda") or event.is_action_pressed("arriba"):
		Global.sel = (Global.sel + Global.unlocked - 1) % Global.unlocked
		Global.sfx("ui")
	elif event.is_action_pressed("confirmar"):
		Global.infinite = false
		Global.cur = Global.sel
		Global.sfx("ui_entrar")
		get_tree().change_scene_to_file("res://scenes/Stage.tscn")
	elif event.is_action_pressed("atras"):
		Global.sfx("ui_atras")
		get_tree().change_scene_to_file("res://scenes/Title.tscn")


func txt(s: String, x: float, y: float, size: int, col: Color, center := false, right := false) -> void:
	var align := HORIZONTAL_ALIGNMENT_LEFT
	var xx := x
	var wdt := -1
	if center:
		align = HORIZONTAL_ALIGNMENT_CENTER
		xx = x - W / 2
		wdt = int(W) * 4
	elif right:
		align = HORIZONTAL_ALIGNMENT_RIGHT
		xx = x - W
		wdt = int(W) * 4
	# el texto se dibuja a resolucion nativa (sin el 4x) para verse nitido
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(font, Vector2(xx * 4 + 2, y * 4 + 2), s, align, wdt, size * 4, Color(0, 0, 0, 0.55))
	draw_string(font, Vector2(xx * 4, y * 4), s, align, wdt, size * 4, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(4, 4))

func spot_px(i: int) -> Vector2:
	var p: Vector2 = Global.STAGES[i]["pos"]
	return Vector2(p.x * W, p.y * H)

## estrella (sprite si existe y es grande, polygon si es chica)
func _star(c: Vector2, r: float, filled: bool) -> void:
	if star_tex and r >= 4.0:
		var scol := Color.WHITE if filled else Color(0.15, 0.15, 0.15, 0.55)
		draw_texture_rect(star_tex, Rect2(c.x - r, c.y - r, r * 2, r * 2), false, scol)
		return
	var col := Color("ffd166") if filled else Color(0, 0, 0, 0.45)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, c.y - r), Vector2(c.x + r * 0.35, c.y - r * 0.3),
		Vector2(c.x + r, c.y - r * 0.2), Vector2(c.x + r * 0.45, c.y + r * 0.25),
		Vector2(c.x + r * 0.6, c.y + r), Vector2(c.x, c.y + r * 0.5),
		Vector2(c.x - r * 0.6, c.y + r), Vector2(c.x - r * 0.45, c.y + r * 0.25),
		Vector2(c.x - r, c.y - r * 0.2), Vector2(c.x - r * 0.35, c.y - r * 0.3),
	]), col)

func _draw() -> void:
	# render interno 1280x720: todo el codigo usa coordenadas 320x180, escaladas 4x
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(4, 4))
	# fondo: mapa o oceano de respaldo
	if map_tex:
		draw_texture_rect(map_tex, Rect2(0, 0, W, H), false)
	else:
		draw_rect(Rect2(0, 0, W, H), Color("123f66"))
		for i in range(50):
			var mx := fmod(i * 53 + t * 0.4, W)
			var my := fmod(float(i * 37 + (i * 13) % 7), H)
			draw_rect(Rect2(mx, my, 6, 1), Color("1b6ca8"))
		txt("(falta assets/map.png)", W / 2, 90, 8, Color("8ecae6"), true)

	# titulo (logo arcade si existe)
	if logo_tex:
		var lw := 48.0 * logo_tex.get_width() / float(logo_tex.get_height())
		draw_texture_rect(logo_tex, Rect2(W / 2 - lw / 2, 0, lw, 48), false)
	else:
		txt("SURFER WORLD TOUR", W / 2 + 1, 17, 15, Color("083358"), true)
		txt("SURFER WORLD TOUR", W / 2, 15, 15, Color.WHITE, true)

	# spots
	for i in range(Global.NS):
		var S: Dictionary = Global.STAGES[i]
		var pos := spot_px(i)
		var open := i < Global.unlocked
		var done: bool = Global.best[i] >= Global.goal_of(i)
		if open:
			# ruta punteada hacia la siguiente desbloqueada
			if i < Global.unlocked - 1:
				var npos := spot_px(i + 1)
				var a := 0.15
				while a < 1.0:
					if (int(a * 6) + int(t / 12)) % 2 == 0:
						draw_rect(Rect2(pos.lerp(npos, a), Vector2(2, 2)), Color("fff3b0"))
					a += 0.17
			draw_rect(Rect2(pos.x - 4, pos.y - 4, 9, 9), Color("083358"))
			draw_rect(Rect2(pos.x - 3, pos.y - 3, 7, 7), Color("2ec4b6") if done else Color("ffd166"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_string(font, Vector2((pos.x - 6) * 4, (pos.y + 3) * 4), str(S["n"]),
				HORIZONTAL_ALIGNMENT_CENTER, 52, 24, Color("083358"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(4, 4))
			# CHECKPOINT: si moriste contra el jefe de esta playa, al volver
			# entras directo en la pelea. Antes no habia forma de saberlo:
			# entrabas y te aparecia el jefe de golpe sin entender por que.
			if Global.has_boss_checkpoint(i):
				var fx := pos.x + 5.0
				var fy := pos.y - 9.0
				draw_rect(Rect2(fx, fy, 1, 9), Color("083358"))
				draw_colored_polygon(PackedVector2Array([
					Vector2(fx + 1, fy), Vector2(fx + 7, fy + 2), Vector2(fx + 1, fy + 4)
				]), Color("e63946"))
			# estrellas ganadas bajo el spot
			if Global.stars[i] > 0:
				for k in range(3):
					_star(Vector2(pos.x - 5 + k * 5, pos.y + 8), 2.2, k < Global.stars[i])
		else:
			draw_rect(Rect2(pos.x - 3, pos.y - 3, 7, 7), Color(0, 0, 0, 0.55))
			draw_rect(Rect2(pos.x - 1, pos.y - 1, 3, 3), Color("5b6770"))
		# cursor
		if i == Global.sel:
			var ay := pos.y - 10 + sin(t * 0.15) * 2
			draw_colored_polygon(PackedVector2Array([
				Vector2(pos.x - 3, ay), Vector2(pos.x + 4, ay), Vector2(pos.x + 0.5, ay + 5)
			]), Color("ff4757"))
			draw_rect(Rect2(pos.x - 5.5, pos.y - 5.5, 12, 12), Color.WHITE, false, 1.0)

	# surfista en idle esperando en medio del Pacifico
	if idle_tex:
		var fw := idle_tex.get_width() / 5.0
		var fh := float(idle_tex.get_height())
		var frame := int(t / 9.0) % 5
		var dw := fw * 0.2
		var dh := fh * 0.2
		var by := 60.0 + sin(t * 0.06) * 2.0
		draw_rect(Rect2(298 - 9, by - 1, 18, 2), Color(1, 1, 1, 0.3))
		draw_texture_rect_region(idle_tex, Rect2(298 - dw / 2, by - dh, dw, dh),
			Rect2(frame * fw, 0, fw, fh))

	# tarjeta de info
	var S: Dictionary = Global.STAGES[Global.sel]
	draw_rect(Rect2(10, H - 50, W - 20, 44), Color(0.03, 0.2, 0.35, 0.93))
	draw_rect(Rect2(10, H - 50, W - 20, 44), Color("ffd166"), false, 1.0)
	txt("N%d  %s - %s" % [S["n"], S["name"], S["pais"]], 16, H - 38, 9, Color("ffd166"))
	# estrellas de la playa seleccionada (en la tarjeta)
	for k in range(3):
		_star(Vector2(W - 54 + k * 12, H - 41), 4.5, k < Global.stars[Global.sel])
	txt(S["desc"], 16, H - 28, 7, Color("cfe8ff"))
	txt(S["sptxt"], 16, H - 19, 7, Color("2ec4b6"))
	var bt: String = ("MEJOR " + Global.fmt(Global.best[Global.sel])) if Global.best[Global.sel] > 0 else "SIN JUGAR"
	txt(bt + "   META " + Global.fmt(Global.goal_of(Global.sel)), 16, H - 10, 7, Color.WHITE)
	if Global.has_boss_checkpoint(Global.sel):
		txt("BANDERA: entras directo a la pelea del jefe", 16, H - 46, 7, Color("e63946"))
	if int(t / 30) % 2 == 0:
		txt("ENTER: SURFEAR", W - 16, H - 10, 8, Color("2ec4b6"), false, true)
	txt("<- -> elegir playa   N musica   MANTEN saltar = salto alto", W / 2, H - 54, 7, Color("8ecae6"), true)
	txt("ESC = menu principal", W / 2, H - 62, 7, Color("ffd166"), true)
	# total de estrellas del tour
	var tot := 0
	for k in range(Global.NS):
		tot += Global.stars[k]
	_star(Vector2(16, 28), 5, true)
	txt("%d/36" % tot, 24, 31, 8, Color("ffd166"))
	if Global.unlocked == Global.NS and Global.best[Global.NS - 1] >= Global.goal_of(Global.NS - 1):
		txt("* TOUR COMPLETADO *", W / 2, 26, 8, Color("ffd166"), true)
