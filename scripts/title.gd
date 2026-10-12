extends Node2D
## Menu principal: Modo Arcade, Modo Infinito, Records, Como Jugar y Opciones.

const W := 320.0
const H := 180.0
const OPTIONS := ["MODO ARCADE", "MODO INFINITO", "RECORDS", "COMO JUGAR", "OPCIONES"]

var t := 0.0
var view := "menu"   # menu | records | help | options
var sel := 0
var confirm_reset := false   # confirmacion antes de borrar el progreso
var help_pg := 0             # pagina de COMO JUGAR (0 controles / 1 jefes)
var opt_sel := 0             # fila elegida en OPCIONES (0 musica / 1 efectos)
var font: Font
var bg_i := 0

var logo_tex: Texture2D = null
var idle_tex: Texture2D = null
var wave_tex: Texture2D = null
var surf_tex: Texture2D = null
var sea_tex: Texture2D = null
var star_tex: Texture2D = null
var trofeo_tex: Texture2D = null
var board_tex: Texture2D = null
var infinito_tex: Texture2D = null
var bg_texs: Array = []


func _load(p: String) -> Texture2D:
	return load(p) if ResourceLoader.exists(p) else null


func _ready() -> void:
	font = ThemeDB.fallback_font
	Global.play_music_file(Global.MENU_MUSIC)
	logo_tex = _load("res://assets/logo.png")
	idle_tex = _load("res://assets/surfer_idle.png")
	wave_tex = _load("res://assets/ola_big.png")
	surf_tex = _load("res://assets/surfer_surf.png")
	sea_tex = _load("res://assets/sea_tile.png")
	star_tex = _load("res://assets/star.png")
	trofeo_tex = _load("res://assets/trofeo.png")
	board_tex = _load("res://assets/board.png")
	infinito_tex = _load("res://assets/infinito.png")
	for i in range(Global.NS):
		bg_texs.append(_load("res://assets/bg_%d.png" % i))
	bg_i = randi() % Global.NS


func _process(delta: float) -> void:
	t += delta * 60.0
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("musica"):
		Global.toggle_music()
		return
	if view == "menu":
		if event.is_action_pressed("abajo"):
			sel = (sel + 1) % OPTIONS.size()
			Global.sfx("ui")
		elif event.is_action_pressed("arriba"):
			sel = (sel + OPTIONS.size() - 1) % OPTIONS.size()
			Global.sfx("ui")
		elif event.is_action_pressed("confirmar"):
			Global.sfx("ui_entrar")
			match sel:
				0:
					Global.infinite = false
					get_tree().change_scene_to_file("res://scenes/WorldMap.tscn")
				1:
					Global.infinite = true
					Global.cur = 0
					get_tree().change_scene_to_file("res://scenes/Stage.tscn")
				2:
					view = "records"
				3:
					view = "help"
					help_pg = 0
				4:
					view = "options"
					opt_sel = 0
		return
	# --- dentro de una subpantalla ---
	if view == "help" and (event.is_action_pressed("izquierda") or event.is_action_pressed("derecha")):
		help_pg = 1 - help_pg
		Global.sfx("ui")
		return
	if view == "options":
		if confirm_reset:
			if event.is_action_pressed("confirmar"):
				Global.reset_progress()
				confirm_reset = false
				Global.sfx("golpe_duro", 0.8)
			elif event.is_action_pressed("atras"):
				confirm_reset = false
				Global.sfx("ui")
			return
		# volumen: arriba/abajo elige la fila, izquierda/derecha la ajusta
		if event.is_action_pressed("arriba") or event.is_action_pressed("abajo"):
			opt_sel = 1 - opt_sel
			Global.sfx("ui")
			return
		if event.is_action_pressed("izquierda") or event.is_action_pressed("derecha"):
			var d := 0.1 if event.is_action_pressed("derecha") else -0.1
			if opt_sel == 0:
				Global.vol_mus = clampf(Global.vol_mus + d, 0.0, 1.0)
			else:
				Global.vol_sfx = clampf(Global.vol_sfx + d, 0.0, 1.0)
			Global.aplicar_volumen()
			Global.save_game()
			Global.sfx("ui")   # se oye al momento como queda
			return
		if _tecla(event, KEY_F):
			var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
			Global.sfx("ui")
			return
		if _tecla(event, KEY_R):
			confirm_reset = true
			Global.sfx("ui")
			return
	if event.is_action_pressed("atras") or event.is_action_pressed("confirmar") \
			or event.is_action_pressed("mapa"):
		view = "menu"
		confirm_reset = false
		Global.sfx("ui_atras")


## atajos de una sola tecla que no tienen accion propia (F, R en opciones)
func _tecla(event: InputEvent, code: int) -> bool:
	return event is InputEventKey and event.pressed and event.keycode == code


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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(font, Vector2(xx * 4 + 2, y * 4 + 2), s, align, wdt, size * 4, Color(0, 0, 0, 0.55))
	draw_string(font, Vector2(xx * 4, y * 4), s, align, wdt, size * 4, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(4, 4))


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(4, 4))
	# cielo atardecer
	var sky := [Color("ffd66b"), Color("ffb54d"), Color("ff8f5e"), Color("e56b8f")]
	for i in range(4):
		draw_rect(Rect2(0, i * 18, W, 18), sky[i])
	draw_rect(Rect2(0, 72, W, 40), Color("ffe9a8"))
	# sol
	draw_circle(Vector2(262, 46), 15, Color("fff3b0"))
	draw_circle(Vector2(262, 46), 11, Color("ffd166"))
	# paisaje aleatorio en el horizonte (cambia en cada visita al menu)
	var bgt: Texture2D = bg_texs[bg_i] if bg_texs.size() > bg_i else null
	if bgt:
		var bh := W * bgt.get_height() / float(bgt.get_width())
		draw_texture_rect(bgt, Rect2(0, 112 - bh, W, bh), false)
	# mar con scroll
	if sea_tex:
		var tw := float(sea_tex.get_width())
		var off := fmod(t * 0.8, tw)
		draw_texture_rect(sea_tex, Rect2(-off, 110, W + tw, H - 110), true)
		var tint := Color("1b6ca8")
		tint.a = 0.25
		draw_rect(Rect2(0, 110, W, H - 110), tint)
	else:
		draw_rect(Rect2(0, 110, W, H - 110), Color("1b6ca8"))
	# ola con surfista cruzando el fondo
	if wave_tex:
		var wx := fmod(t * 0.45, W + 200.0) - 100.0
		var wh := 34.0
		var ww := wh * wave_tex.get_width() / float(wave_tex.get_height())
		draw_texture_rect(wave_tex, Rect2(wx - ww * 0.6, 116 - wh, ww, wh), false)
		if surf_tex:
			var fw := surf_tex.get_width() / 5.0
			var fh := float(surf_tex.get_height())
			var fr := int(t / 7.0) % 5
			var dh := 16.0
			var dw := dh * fw / fh
			draw_texture_rect_region(surf_tex, Rect2(wx + 4, 118 - dh, dw, dh),
				Rect2(fr * fw, 0, fw, fh))
	# logo grande
	if logo_tex:
		var lw := 62.0 * logo_tex.get_width() / float(logo_tex.get_height())
		draw_texture_rect(logo_tex, Rect2(W / 2 - lw / 2, 4 + sin(t * 0.04) * 1.5, lw, 62), false)
	else:
		txt("SURFER WORLD TOUR", W / 2, 30, 18, Color.WHITE, true)

	match view:
		"menu": _draw_menu()
		"records": _draw_records()
		"help": _draw_help()
		"options": _draw_options()


func _draw_menu() -> void:
	var y := 84.0
	for i in range(OPTIONS.size()):
		var seld := i == sel
		var col := Color("ffd166") if seld else Color.WHITE
		if seld:
			# cursor: la tabla de surf apuntando la opcion
			if board_tex:
				var bw := 14.0
				var bh2 := bw * board_tex.get_height() / float(board_tex.get_width())
				draw_texture_rect(board_tex,
					Rect2(W / 2 - 62 + sin(t * 0.1) * 2, y - 5 + bh2 / 2, bw, bh2), false)
			else:
				txt(">", W / 2 - 54, y, 11, Color("ffd166"), true)
			draw_rect(Rect2(W / 2 - 46, y - 8, 92, 12), Color(0, 0, 0, 0.35))
		txt(OPTIONS[i], W / 2, y, 11 if seld else 10, col, true)
		y += 15.0
	txt("flechas + ENTER, o mando   N musica", W / 2, H - 8, 7, Color("8ecae6"), true)
	txt("v1.0", W - 4, H - 4, 6, Color(1, 1, 1, 0.5), false, true)


func _draw_records() -> void:
	draw_rect(Rect2(24, 74, W - 48, 96), Color(0.03, 0.13, 0.25, 0.92))
	draw_rect(Rect2(24, 74, W - 48, 96), Color("ffd166"), false, 1.0)
	txt("RECORDS", W / 2, 86, 12, Color("ffd166"), true)
	# resumen de la campana
	var done := 0
	var tot_stars := 0
	for i in range(Global.NS):
		if Global.best[i] >= Global.goal_of(i):
			done += 1
		tot_stars += Global.stars[i]
	txt("CAMPANA: %d/12 playas   %d/36 estrellas" % [done, tot_stars],
		W / 2, 100, 8, Color("2ec4b6"), true)
	txt("RECORD INFINITO: " + Global.fmt(Global.hi_inf), W / 2, 111, 8, Color.WHITE, true)
	# top 5 del modo infinito
	var yy := 124.0
	for i in range(5):
		if i < Global.top5.size():
			var e: Dictionary = Global.top5[i]
			txt("%d. %s  %s" % [i + 1, e["name"], Global.fmt(int(e["score"]))],
				W / 2, yy, 8, Color("ffd166") if i == 0 else Color("cfe8ff"), true)
		else:
			txt("%d. ---  ------" % (i + 1), W / 2, yy, 8, Color(1, 1, 1, 0.3), true)
		yy += 9.0
	txt("ESC: volver", W / 2, H - 4, 7, Color("8ecae6"), true)


## Dos paginas: controles y jefes. Se cambia con las flechas.
func _draw_help() -> void:
	draw_rect(Rect2(16, 70, W - 32, 104), Color(0.03, 0.13, 0.25, 0.94))
	draw_rect(Rect2(16, 70, W - 32, 104), Color("ffd166"), false, 1.0)
	var lines: Array = []
	if help_pg == 0:
		txt("COMO JUGAR   1/2", W / 2, 83, 11, Color("ffd166"), true)
		lines = [
			["saltar: ESPACIO / arriba / boton A   (x2 = doble)", "cfe8ff"],
			["MANTEN la tecla = salto alto, un toque = corto.", "ffd166"],
			["flechas <- ->: moverte, y en el aire hacen trucos", "cfe8ff"],
			["pausa: P o START    N: musica    R: reintentar", "cfe8ff"],
			["Lo que BRILLA EN ROSA se puede pisar: cae encima", "2ec4b6"],
			["y rebotas con el doble salto recargado. Encadena", "2ec4b6"],
			["rebotes sin tocar el agua y sube todo. Lo que no", "2ec4b6"],
			["brilla, te choca igual: hay que esquivarlo.", "2ec4b6"],
		]
	else:
		txt("COMO PELEAR   2/2", W / 2, 83, 11, Color("ffd166"), true)
		lines = [
			["El jefe tiene VIDA. Se la bajas asi:", "ffd166"],
			["", "cfe8ff"],
			["1. Esquiva un ataque entero sin que te toque", "2ec4b6"],
			["2. Al terminar queda EXPUESTO y destella:", "2ec4b6"],
			["   clava un truco ahi = el TRIPLE de dano", "2ec4b6"],
			["3. Cae encima de lo que rueda o rebota para", "2ec4b6"],
			["   reventarlo (te devuelve el doble salto)", "2ec4b6"],
			["A mitad de vida se enfurece y saca otro ataque", "ff8f5e"],
		]
	var yy := 96.0
	for l in lines:
		txt(String(l[0]), W / 2, yy, 7, Color(String(l[1])), true)
		yy += 9.5
	if int(t / 30) % 2 == 0:
		txt("<- -> cambiar pagina    ESC: volver", W / 2, H - 4, 7, Color("8ecae6"), true)
	else:
		txt("ESC: volver", W / 2, H - 4, 7, Color("8ecae6"), true)


func _draw_options() -> void:
	draw_rect(Rect2(38, 70, W - 76, 104), Color(0.03, 0.13, 0.25, 0.94))
	draw_rect(Rect2(38, 70, W - 76, 104), Color("ffd166"), false, 1.0)
	if confirm_reset:
		txt("¿BORRAR TODO EL PROGRESO?", W / 2, 100, 11, Color("e63946"), true)
		txt("Playas, estrellas y records volveran a cero", W / 2, 116, 8, Color("cfe8ff"), true)
		txt("confirmar: si, borrar    atras: cancelar", W / 2, 138, 9, Color("ffd166"), true)
		return
	txt("OPCIONES", W / 2, 84, 12, Color("ffd166"), true)
	# --- barras de volumen ---
	for i in range(2):
		var y := 100.0 + i * 16.0
		var v: float = Global.vol_mus if i == 0 else Global.vol_sfx
		var elegido := i == opt_sel
		if elegido:
			draw_rect(Rect2(46, y - 8, W - 92, 13), Color(1, 1, 1, 0.10))
			txt("<", 56, y + 1, 9, Color("ffd166"), true)
			txt(">", W - 56, y + 1, 9, Color("ffd166"), true)
		txt("MUSICA" if i == 0 else "EFECTOS", 66, y + 1, 8,
			Color("ffd166") if elegido else Color.WHITE)
		# barra de 10 pasos
		var bx := 138.0
		draw_rect(Rect2(bx, y - 5, 84, 7), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(bx, y - 5, 84.0 * v, 7), Color("2ec4b6") if elegido else Color("1b6ca8"))
		draw_rect(Rect2(bx, y - 5, 84, 7), Color.WHITE, false, 1.0)
		txt("%d%%" % int(round(v * 100)), bx + 106, y + 1, 8, Color("cfe8ff"), false, true)
	txt("F - Pantalla completa: " + ("SI" if DisplayServer.window_get_mode()
		== DisplayServer.WINDOW_MODE_FULLSCREEN else "NO"), W / 2, 138, 8, Color.WHITE, true)
	txt("R - Borrar progreso (empezar de cero)", W / 2, 150, 8, Color("ff8f5e"), true)
	txt("N: musica on/off    hay soporte de mando", W / 2, 164, 7, Color("8ecae6"), true)
	txt("atras: volver", W / 2, H - 4, 7, Color("8ecae6"), true)