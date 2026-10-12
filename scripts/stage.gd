extends Node2D
## Stage de surf: runner infinito con mecanicas especiales por playa.
## Estados: play / pause / over / clear / champion

const W := 320.0
const H := 180.0
const WATER := 124.0
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

# ---------- SENSACION DEL SALTO ----------
# Antes: un solo impulso fijo (-5.3) y una sola gravedad (0.28). Siempre el
# mismo salto, apretaras como apretaras.
#
# Ahora hay tres cosas:
#
# 1. ALTURA VARIABLE. Si sueltas la tecla mientras subes, el salto se corta.
#    Un toque = salto corto para pasar algo bajito. Mantener = salto completo.
#
# 2. GRAVEDAD EN TRES ZONAS. Subes normal, FLOTAS en el punto mas alto y
#    caes con peso. Es el truco de Mario/Celeste: arriba te da tiempo de
#    leer lo que viene, y la bajada se siente contundente en vez de blanda.
#
# 3. BUFFER. Si aprietas hasta 8 frames antes de tocar el agua, el salto
#    sale igual al aterrizar en vez de perderse.
#
# Los numeros estan calculados para que la ALTURA MAXIMA quede igual que
# antes (47.4 px contra 47.5 px), asi ningun obstaculo ni ataque de jefe
# cambia de dificultad. Lo unico que cambia es como se siente.
const JUMP_VY := -5.22      # impulso del primer salto
const JUMP_VY2 := -4.8      # impulso del doble salto (igual que antes)
const G_RISE := 0.28        # gravedad subiendo
const G_APEX := 0.12        # gravedad en el punto alto: aqui flotas
const G_FALL := 0.52        # gravedad cayendo: 1.9x la de subida
const APEX_BAND := 1.0      # margen de velocidad que cuenta como "punto alto"
const JUMP_CUT := -2.6      # al soltar, la velocidad se corta hasta aca
const JUMP_BUFFER := 8.0    # frames de gracia para adelantar el salto

# VELOCIDAD DE LOS ATAQUES DE LOS JEFES: +40%.
# Va aparte de la velocidad de los obstaculos, que BAJO un 20%. La idea es
# el contraste: surfear queda mas tranquilo y la pelea es el momento tenso.
# El aviso telegrafiado (atk_warn) no se toca, asi que sigues teniendo el
# mismo tiempo para leer QUE viene; lo que cambia es lo rapido que llega.
#   embestida baja  2.75s -> 1.97s de cruce
#   vuelo rasante   2.26s -> 1.62s
#   rodillo de coral 1.86s -> 1.33s
const ATK_SPD := 1.4

# tiempos (en frames a ~60fps) del ataque "puas" (aviso con burbujas + pua activa)
# no se escalan: la pua no viaja, emerge. Su dificultad esta en el aviso, y
# acortarlo seria quitarte la lectura, no hacerlo mas rapido.
const SPIKE_WARN := 55.0
const SPIKE_TOTAL := 90.0
# tiempos del ataque "meteor" (caida desde el cielo + geiser al impactar)
const MET_FALL := 55.0 / ATK_SPD
const MET_BURST := 22.0
# tiempos del "salto sagrado" del Mono del Templo (caida recta + chapuzon)
const SALTO_FALL := 40.0 / ATK_SPD
const SALTO_BURST := 20.0

# ---------- ATAQUES PROPIOS DE LOS JEFES 2-9 ----------
# Antes estos 8 jefes se turnaban los mismos 6 movimientos genericos
# (low/lowfast/low2x/high/bounce/ink). Cada uno tiene ahora AL MENOS un
# ataque insignia con mecanica propia (no solo sprite nuevo), siguiendo el
# mismo patron de estado (aviso -> activo -> se retira) que ya usan el
# rodillo/puas del Guardian de Coral y el salto sagrado del Mono.
const TENT_WARN := 45.0    # Pulpo: burbujas antes de que emerja el tentaculo
const TENT_SWEEP := 55.0   # ...y cuanto dura barriendo de lado a lado
const TUBO_CLOSE_RANGE := 26.0  # Espiritu: a que distancia se empieza a cerrar
const TUBO_CLOSE_T := 26.0      # ...y cuanto tarda en cerrarse del todo
const GRIETA_WARN := 40.0   # Diablo de Lava: aviso antes de que prenda
const GRIETA_ACTIVE := 30.0 # ...y cuanto se queda ardiendo
const MEGASALTO_FALL := 42.0 / ATK_SPD   # Megalodon: caida del salto mortal
const MEGASALTO_BURST := 20.0            # ...y el impacto/onda al caer
const LOBO_WARN := 26.0     # Lobo Alfa: cuanto se para en la roca antes de tirarse

# mini-jefes por playa (indice = etapa 0..10; Corralejo tiene a la Ola Monstruo)
# verbos: low/lowfast (saltar), low2x (dos saltos), high (no saltar),
# pinza (ambos lados), bounce (salta cuando caiga), ink (tinta: oscurece)
const MBOSS := [
	{"name": "EL GUARDIAN DE CORAL", "nf": 3, "a": "low", "b": "low2x"}, # jefe v2: usa roll/puas/meteor (ver Global.cur == 0)
	{"name": "LA GAVIOTA REINA", "nf": 3, "a": "high", "b": "low"}, # jefe v2: usa dive/birds/feathers (ver Global.cur == 1)
	{"name": "EL MONO DEL TEMPLO", "nf": 2, "a": "bounce", "b": "low"}, # jefe v2: usa cocos/monitos/salto (ver Global.cur == 2)
	# "c" = tercer ataque, se desbloquea en FASE 2 (mitad de la pelea)
	{"name": "EL PULPO DEL ESTUARIO", "nf": 2, "a": "low", "b": "ink", "c": "pinza"}, # jefe v2: tentaculo real (ver Global.cur == 3)
	{"name": "EL ESPIRITU DEL TUBO", "nf": 3, "a": "low", "b": "lowfast", "c": "low2x"}, # jefe v2: anillos + tubo que se cierra (ver Global.cur == 4)
	{"name": "EL DIABLO DE LAVA", "nf": 3, "a": "bounce", "b": "lowfast", "c": "high"}, # jefe v2: grieta de lava (ver Global.cur == 5)
	{"name": "EL REY KAHUNA", "nf": 3, "a": "lowfast", "b": "high", "c": "low2x"}, # jefe v2: marejada del baston (ver Global.cur == 6)
	{"name": "EL MEGALODON", "nf": 3, "a": "lowfast", "b": "bounce", "c": "high"}, # jefe v2: salto mortal con sombra (ver Global.cur == 7)
	{"name": "LA MANTARRAYA COLOSAL", "nf": 3, "a": "high", "b": "low2x", "c": "ola_doble"}, # jefe v2: el vals (ver Global.cur == 8)
	{"name": "EL LOBO ALFA", "nf": 3, "a": "low", "b": "pinza", "c": "lowfast"}, # jefe v2: la manada (ver Global.cur == 9)
	{"name": "EL GENIO DE LAS DUNAS", "nf": 3, "a": "low", "b": "high", "c": "pinza"}, # jefe v2: remolino que acelera (ver Global.cur == 10)
]

# aviso telegrafiado de cada ataque: [texto, color]
const ATK_HINT := {
	"emb":       ["¡AHI VIENE! SALTALA", "ffd166"],
	"low":       ["¡AHI VIENE! SALTALA", "ffd166"],
	"lowfast":   ["¡RAPIDA! SALTALA", "ffd166"],
	"ras":       ["¡VUELA BAJO! NO SALTES", "ffd166"],
	"high":      ["¡VUELA BAJO! NO SALTES", "ffd166"],
	"doble":     ["¡VIENEN DOS! UN SALTO CADA UNA", "ff8f5e"],
	"low2x":     ["¡VIENEN DOS! UN SALTO CADA UNA", "ff8f5e"],
	"bounce":    ["¡SALTA CUANDO CAIGA!", "ff8f5e"],
	"ink":       ["¡ESQUIVA LA TINTA!", "ff8f5e"],
	"ola":       ["¡OLA POR LA DERECHA!", "ffd166"],
	"ola_doble": ["¡DOS OLAS POR LA DERECHA!", "ff8f5e"],
	"pinza":     ["¡POR AMBOS LADOS!", "e63946"],
	"tormenta":  ["¡TORMENTA! ¡AGUANTA!", "e63946"],
	# Guardian de Coral (N12)
	"roll":      ["¡RODILLOS DE CORAL! SALTA", "ffd166"],
	"puas":      ["¡PUAS ABAJO! MUEVETE Y SALTA", "ff8f5e"],
	"meteor":    ["¡LLUVIA DE CORAL! CORRE", "e63946"],
	# Gaviota Reina (N11)
	"dive":      ["¡PICADA! MIRA DE DONDE VIENE", "e63946"],
	"birds":     ["¡BANDADA! ALTO Y BAJO", "ff8f5e"],
	"feathers":  ["¡PLUMAS NAVAJA! BUSCA EL HUECO", "ff8f5e"],
	# Mono del Templo (N10)
	"cocos":     ["¡COCOS! SALTA CADA REBOTE", "ffd166"],
	"monitos":   ["¡TROPA DE MONITOS! MEZCLA CARRILES", "ff8f5e"],
	"salto":     ["¡SALTO SAGRADO! SAL DE LA SOMBRA", "e63946"],
	# Pulpo del Estuario (N9)
	"tentaculo": ["¡TENTACULO! SALTA EL BARRIDO", "ffd166"],
	"agarre":    ["¡TE AGARRA DESDE ABAJO! MUEVETE", "e63946"],
	# Espiritu del Tubo (N8)
	"anillos":   ["¡ANILLOS! SALTALES ENCIMA", "ffd166"],
	"tubocierra":["¡EL TUBO SE CIERRA! SALTA AL FINAL", "ff8f5e"],
	"espejismo": ["¡ESPEJISMO! ¿CUAL ES EL REAL?", "ff8f5e"],
	# Diablo de Lava (N7)
	"grieta":    ["¡GRIETA DE LAVA! SALTALA", "ff8f5e"],
	"geiser_pie":["¡GEISER BAJO TUS PIES! MUEVETE", "e63946"],
	# Rey Kahuna (N6)
	"marejada":  ["¡MAREJADA! ALTO-BAJO-ALTO", "e63946"],
	# Megalodon (N5)
	"megasalto": ["¡SALTO MORTAL! MIRA LA SOMBRA", "e63946"],
	"mordida":   ["¡TE MUERDE DESDE ABAJO! MUEVETE", "e63946"],
	# Mantarraya Colosal (N4)
	"vals":      ["¡EL VALS! SIGUE EL RITMO", "e63946"],
	# Lobo Alfa (N3)
	"manada":    ["¡LA MANADA SE TIRA!", "e63946"],
	# Genio de las Dunas (N2)
	"tornado":   ["¡REMOLINO! ACELERA, SALTALO A TIEMPO", "ffd166"],
	"tresdeseos":["¡LOS TRES DESEOS! EL EXAMEN FINAL", "e63946"],
}

# ingreso de iniciales estilo arcade (top 5 del modo infinito)
var ini := [0, 0, 0]
var ini_pos := 0

var font: Font
var state := "play"
var t := 0.0
var score := 0.0
var progress := 0.0   # avance hacia la meta (solo surf real; los trucos aportan 25%)
var shake := 0.0      # sacudida de camara al chocar
var lives := 3
var speed := 2.0
var inv := 0.0
var intro := 170.0
var tube_t := 420.0
var tube_on := 0.0
var tube_acc := 0.0    # bonus acumulado dentro del tubo
var tube_clean := true # true si no saltaste durante el tubo

# power-ups
var shield := false    # aguanta 1 golpe
var x2_t := 0.0        # puntos x2 (frames restantes)
var magnet_t := 0.0    # iman de bonus (frames restantes)
var pw_t := 600.0      # timer de aparicion de power-ups

# jefe final: la Ola Monstruo (solo Corralejo)
var boss := false
var boss_t := 0.0      # red de seguridad: tiempo maximo de pelea
var boss_hp := 100.0     # vida del jefe: esto es lo que hay que bajar
var boss_hpmax := 100.0
var boss_open := 0.0     # frames que le quedan al jefe expuesto (ventana de castigo)
var atk_live := false    # hay un ataque suyo en curso
var atk_clean := true    # ...y todavia no te ha tocado
var boss_p2 := false   # fase 2: ojos rojos y ataques avanzados
var boss_out := -1.0   # secuencia de retirada (la ola se calma y se va)
var boss_tmax := 3600.0
var ink_t := 0.0       # tinta del pulpo: pantalla oscura
var atk_t := 0.0       # tiempo hasta el proximo ataque
var atk_warn := 0.0    # aviso telegrafiado
var atk_type := "emb"  # emb / ras / doble / ola
# picada de la Gaviota Reina (estilo "Storm Eagle"): sube aleteando a un
# punto al azar cerca del cielo antes de picar, para que no se sepa por
# donde va a salir
var dive_start := Vector2.ZERO
var dive_active := false
var dive_chain := 0     # picadas encadenadas pendientes (embiste 2 veces seguidas)
# bolsa de ataques: evita que un mini-jefe de 3 ataques repita el mismo
# varias veces seguidas (se reparte como cartas, se reponen al vaciarse)
var atk_bag: Array = []
# salto sagrado del Mono del Templo: salta vertical, deja sombra apuntada
# al surfista y cae en picada recta sobre ese punto
var salto_target := Vector2.ZERO
var salto_active := false
# salto mortal del Megalodon: mismo concepto, sombra + caida recta
var mega_target := Vector2.ZERO
var batks: Array = []  # proyectiles del jefe (entidades que se mueven)
var surge_t := 380.0
var surge_on := 0.0
var coll_t := 180.0
var msg := ""
var msg_t := 0.0
var spawn_t := 90.0

# jugador
var px := 64.0
var y_off := 0.0
var vy := 0.0
var air := false
var jumps := 0        # para el doble salto
var jump_buf := 0.0   # salto pedido que todavia no se pudo ejecutar
var cut_done := false # ya se corto este salto por soltar la tecla
var ang := 0.0
var spin_dir := 0
var spin_acc := 0.0
var tricks := 0
var combo := 0        # trucos encadenados en un mismo salto
var trick_prog := 0.0 # cuanto de la barra vino de trucos (tiene tope)
var bar_flash := 0.0  # destello de la barra al alimentarla con un truco
var parry_chain := 0  # rebotes encadenados sin tocar el agua
# --- sensacion ---
var hitstop := 0.0    # frames congelados al pegar o recibir: da impacto
var squash := 0.0     # deformacion del surfista (-1 achatado / +1 estirado)
# tramo de patron fijo en curso
var pat_lista: Array = []   # entradas que faltan por soltar
var pat_t := 0.0            # frames hasta soltar la siguiente
var pat_hechos := 0         # cuantos tramos van disparados en esta playa
# mini-encuentro de mitad de playa
var enc_tipo := ""      # "" = no hay ninguno en curso
var enc_fase := 0       # que formacion toca (0..2)
var enc_t := 0.0        # frames hasta la siguiente
var enc_aviso := 0.0    # frames de telegrafo
var enc_limpio := true  # ¿aguantaste esta formacion sin que te toquen?
var enc_ok := 0         # formaciones aguantadas limpias
var enc_hecho := false  # ya salio en esta playa
var enc_out := 0.0      # se esta yendo
var enc_activa := false # hay una formacion suya en el aire
var st_score := false # estrella 2: score >= Global.STAR_SCORE_MULT x meta
var st_nodmg := false # estrella 3: sin recibir dano
var took_damage := false  # BUGFIX: antes se miraba "lives == 3", asi que
						  # perder una vida y recuperarla con un corazon
						  # regalaba la estrella de "sin dano"
var clear_t := 0.0    # momento en que se completo (para animar estrellas)

var obs: Array = []
var parts: Array = []
var pops: Array = []  # puntos flotantes ("+150") donde ocurre el truco

# fase del stage: remo (llenar barra) -> popup (animacion) -> surf (juego)
var phase := "remo"
var paddle := 0.0
var pop_t := 0.0

# sprites opcionales (si existen en assets/, si no se dibuja por codigo)
const FRAMES := 5
var tex_surf: Texture2D = null
var tex_air: Texture2D = null
var tex_sea: Texture2D = null
var tex_wave: Texture2D = null
var tex_remo: Texture2D = null
var tex_popup: Texture2D = null
var tex_fall: Texture2D = null
var tex_splash: Texture2D = null
var tex_go1: Texture2D = null
var tex_go2: Texture2D = null
var tex_sharkfull: Texture2D = null
var tex_sharkfin: Texture2D = null
var tex_buoy: Texture2D = null
var tex_wood: Texture2D = null
var tex_board: Texture2D = null
# laminas 3-7: jefe, obstaculos, power-ups, paisajes y UI
var tex_boss: Texture2D = null
var tex_boss_low: Texture2D = null
var tex_boss_high: Texture2D = null
var tex_warn: Texture2D = null
var tex_rock: Texture2D = null
var tex_rock_c: Texture2D = null
var tex_bird: Texture2D = null
var tex_lobo: Texture2D = null
var tex_rival: Texture2D = null
var tex_dolphin: Texture2D = null
var tex_banana: Texture2D = null
var tex_pausa: Texture2D = null
var tex_completada: Texture2D = null
var tex_trofeo: Texture2D = null
var tex_celebrar: Texture2D = null
var tex_infinito: Texture2D = null
var tex_star: Texture2D = null
var tex_heart: Texture2D = null
var tex_pw := {}
var tex_parry := {}   # versiones "pisables" (brillo rosa) por tipo
var tex_bgs: Array = []
var tex_boss2: Texture2D = null
var tex_boss_doble: Texture2D = null
var tex_low2: Texture2D = null
var tex_warn2: Texture2D = null
var tex_calm: Texture2D = null
var tex_mb: Texture2D = null    # cuerpo del mini-jefe de esta playa
var tex_mb_out: Texture2D = null  # su animacion de derrota (opcional)
# ataques propios del mini-jefe. TODOS son opcionales: si el archivo no
# esta, se dibuja el respaldo generico de siempre.
var tex_atk_low: Texture2D = null    # proyectil a ras del agua (SALTAR)
var tex_atk_high: Texture2D = null   # proyectil a media altura (NO SALTAR)
var tex_atk_bounce: Texture2D = null # proyectil que rebota en arco
var tex_atk_ink: Texture2D = null    # nube de tinta (solo el Pulpo)
var tex_ola1: Texture2D = null  # ola generica para proyectiles de mini-jefes
# jefe v2: Guardian del Coral (ataques con sprites propios)
var tex_cb_ball: Texture2D = null
var tex_cb_bub: Texture2D = null
var tex_cb_spike: Texture2D = null
var tex_cb_out: Texture2D = null
var tex_geiser_small: Texture2D = null
var tex_geiser_big: Texture2D = null
var tex_geiser_warn: Texture2D = null
var tex_geiser_triple: Texture2D = null
# jefe v2: El Mono del Templo
var tex_mono_coco: Texture2D = null
var tex_mono_surf: Texture2D = null
var tex_mono_out: Texture2D = null
var tex_mono_rise: Texture2D = null
var tex_mono_shadow: Texture2D = null
var tex_mono_fall: Texture2D = null
var tex_mono_splash: Texture2D = null

# animacion de muerte (wipeout) y arte de game over
var die_t := 0.0
var go_art := 1

var _inf_idx := 0   # playa visual actual en modo infinito (rota cada 1200 pts)

func _sidx() -> int:
	return _inf_idx if Global.infinite else Global.cur

func S() -> Dictionary:
	return Global.STAGES[_sidx()]

func water_y(x: float) -> float:
	return WATER + sin(x * 0.045 + t * 0.06) * 2.0

## Ancho maximo que puede ocupar el cuerpo de un jefe (de 320 de pantalla).
const BOSS_MAXW := 122.0
## Que fraccion del cuerpo queda DENTRO de la pantalla (0.86 = asoma un 14%).
const BOSS_ANCHOR := 0.86

## Ajusta el porte de un jefe para que no se coma la pantalla: si la lamina
## es muy ancha se reduce en proporcion (manteniendo el aspecto) en vez de
## crecer a lo ancho sin control.
func _fit_boss(h: float, w: float) -> Vector2:
	if w > BOSS_MAXW:
		h *= BOSS_MAXW / w
		w = BOSS_MAXW
	return Vector2(w, h)

func _load_opt(p: String) -> Texture2D:
	return load(p) if ResourceLoader.exists(p) else null

func _ready() -> void:
	font = ThemeDB.fallback_font
	speed = Global.base_spd(Global.cur)
	if Global.infinite:
		Global.play_music_file(Global.STAGE_MUSIC[11])  # el tema mas energico
	else:
		Global.play_music_file(Global.STAGE_MUSIC[Global.cur])
	# checkpoint: si moriste contra un jefe, reintentas directo en el jefe.
	# BUGFIX: el checkpoint ahora recuerda de QUE playa era. Antes, morir
	# contra el jefe de una playa y entrar despues a OTRA playa te dejaba
	# empezando esa otra al 75% de la barra y con el puntaje inflado.
	if not Global.infinite and Global.has_boss_checkpoint(Global.cur):
		phase = "surf"
		intro = 0
		var bth := 0.7 if Global.cur == Global.NS - 1 else 0.75
		progress = Global.goal_of(Global.cur) * bth
		score = progress
		# ya moriste una vez en esta playa: la estrella "sin dano" no cuenta
		took_damage = true
		pat_hechos = PATRON_EN.size()   # los tramos ya quedaron atras
	else:
		Global.clear_boss_checkpoint()
	tex_surf = _load_opt("res://assets/surfer_surf.png")
	tex_air = _load_opt("res://assets/surfer_aereo.png")
	tex_sea = _load_opt("res://assets/sea_tile.png")
	tex_wave = _load_opt("res://assets/ola_big.png")
	tex_remo = _load_opt("res://assets/surfer_remo.png")
	tex_popup = _load_opt("res://assets/surfer_popup.png")
	tex_fall = _load_opt("res://assets/surfer_caida.png")
	tex_splash = _load_opt("res://assets/splash.png")
	tex_go1 = _load_opt("res://assets/gameover_1.png")
	tex_go2 = _load_opt("res://assets/gameover_2.png")
	tex_sharkfull = _load_opt("res://assets/shark_full.png")
	tex_sharkfin = _load_opt("res://assets/shark_fin.png")
	tex_buoy = _load_opt("res://assets/buoy.png")
	tex_wood = _load_opt("res://assets/wood.png")
	tex_board = _load_opt("res://assets/board.png")
	tex_boss = _load_opt("res://assets/boss_body.png")
	tex_boss_low = _load_opt("res://assets/boss_low.png")
	tex_boss_high = _load_opt("res://assets/boss_high.png")
	tex_warn = _load_opt("res://assets/boss_warn.png")
	tex_rock = _load_opt("res://assets/rock_gray.png")
	tex_rock_c = _load_opt("res://assets/rock_coral.png")
	tex_bird = _load_opt("res://assets/bird.png")
	tex_lobo = _load_opt("res://assets/lobo.png")
	tex_rival = _load_opt("res://assets/rival.png")
	tex_dolphin = _load_opt("res://assets/dolphin.png")
	tex_banana = _load_opt("res://assets/banana.png")
	tex_pausa = _load_opt("res://assets/pausa.png")
	tex_completada = _load_opt("res://assets/completada.png")
	tex_trofeo = _load_opt("res://assets/trofeo.png")
	tex_celebrar = _load_opt("res://assets/celebrar.png")
	tex_infinito = _load_opt("res://assets/infinito.png")
	tex_star = _load_opt("res://assets/star.png")
	tex_heart = _load_opt("res://assets/heart_hud.png")
	for k in ["pw_shield", "pw_x2", "pw_magnet", "pw_heart"]:
		tex_pw[k] = _load_opt("res://assets/%s.png" % k)
	tex_boss2 = _load_opt("res://assets/boss_body2.png")
	tex_boss_doble = _load_opt("res://assets/boss_doble.png")
	tex_low2 = _load_opt("res://assets/boss_low2.png")
	tex_warn2 = _load_opt("res://assets/boss_warn2.png")
	tex_calm = _load_opt("res://assets/boss_calm.png")
	tex_ola1 = _load_opt("res://assets/ola_1.png")
	# versiones marcadas en rosa: las unicas que se pueden pisar
	tex_parry["buoy"] = _load_opt("res://assets/parry_buoy.png")
	tex_parry["log"] = _load_opt("res://assets/parry_log.png")
	tex_parry["shark_fin"] = _load_opt("res://assets/parry_shark_fin.png")
	tex_parry["shark"] = _load_opt("res://assets/parry_shark.png")
	tex_parry["bird"] = _load_opt("res://assets/parry_bird.png")
	if not Global.infinite and Global.cur < Global.NS - 1:
		tex_mb = _load_opt("res://assets/mboss_%d.png" % Global.cur)
		# derrota: opcional. Si el archivo no esta, el jefe simplemente se
		# aleja usando su lamina de cuerpo, como hasta ahora.
		tex_mb_out = _load_opt("res://assets/mboss_out_%d.png" % Global.cur)
		tex_atk_low = _load_opt("res://assets/atk_low_%d.png" % Global.cur)
		tex_atk_high = _load_opt("res://assets/atk_high_%d.png" % Global.cur)
		tex_atk_bounce = _load_opt("res://assets/atk_bounce_%d.png" % Global.cur)
		tex_atk_ink = _load_opt("res://assets/atk_ink_%d.png" % Global.cur)
	tex_cb_ball = _load_opt("res://assets/cb_ball.png")
	tex_cb_bub = _load_opt("res://assets/cb_bubbles.png")
	tex_cb_spike = _load_opt("res://assets/cb_spike.png")
	tex_cb_out = _load_opt("res://assets/cb_out.png")
	tex_geiser_small = _load_opt("res://assets/geiser_small.png")
	tex_geiser_big = _load_opt("res://assets/geiser_big.png")
	tex_geiser_warn = _load_opt("res://assets/geiser_warn.png")
	tex_geiser_triple = _load_opt("res://assets/geiser_triple.png")
	tex_mono_coco = _load_opt("res://assets/mono_coco.png")
	tex_mono_surf = _load_opt("res://assets/mono_surf.png")
	tex_mono_out = _load_opt("res://assets/mono_out.png")
	tex_mono_rise = _load_opt("res://assets/mono_rise.png")
	tex_mono_shadow = _load_opt("res://assets/mono_shadow.png")
	tex_mono_fall = _load_opt("res://assets/mono_fall.png")
	tex_mono_splash = _load_opt("res://assets/mono_splash.png")
	for i in range(Global.NS):
		tex_bgs.append(_load_opt("res://assets/bg_%d.png" % i))

func _process(delta: float) -> void:
	var dt: float = minf(delta * 60.0, 3.0)
	# HITSTOP: al recibir o dar un golpe fuerte el juego se congela unos
	# frames. Es lo que hace que un impacto se SIENTA en vez de solo verse.
	if hitstop > 0.0:
		hitstop -= dt
		t += dt * 0.25
		queue_redraw()
		return
	if state == "play":
		_update(dt)
	elif state == "dying":
		die_t -= dt
		if shake > 0: shake = maxf(0.0, shake - 0.55 * dt)
		_update_parts(dt)
		if int(t) % 4 == 0:
			_splash(px, water_y(px) - 2, 1.5)
		if die_t <= 0:
			if Global.infinite and Global.top5_qualifies(int(score)):
				state = "initials"   # ¡entro al top 5!
				ini = [0, 0, 0]
				ini_pos = 0
				Global.sfx("ui_ok")
				Global.sfx("ui_ok", 1.2)
			else:
				state = "over"
			Global.sfx("caida")
	elif state == "over":
		_update_parts(dt)
		if int(t) % 14 == 0:
			_splash(px, water_y(px), 0.4)
	t += dt
	queue_redraw()

## Ahora se leen ACCIONES, no teclas sueltas. Cada accion esta mapeada a
## teclado Y a mando en project.godot, asi que el mismo codigo sirve para
## los dos y ademas se pueden reconfigurar sin tocar nada de esto.
func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("musica"):
		Global.toggle_music()
		return
	match state:
		"play":
			if phase == "remo":
				if event.is_action_pressed("saltar"):
					paddle += 13.0
					Global.sfx("remo", 0.85 + paddle * 0.006)
					_splash(px - 10, water_y(px) - 2, 1.2)
				elif event.is_action_pressed("pausa"):
					# BUGFIX: al pausar remando no se aplicaba el efecto de
					# musica lenta (solo pasaba si ya estabas surfeando)
					state = "pause"
					Global.set_music_pause(true)
					Global.sfx("ui")
			elif phase == "popup":
				pass  # animacion en curso, sin control
			elif event.is_action_pressed("saltar"):
				# no se salta aqui: se APUNTA el salto y _update lo ejecuta
				# en cuanto se pueda. Asi, si aprietas justo antes de caer,
				# el salto sale al aterrizar en vez de perderse.
				jump_buf = JUMP_BUFFER
			elif air and event.is_action_pressed("izquierda"):
				spin_dir = -1
			elif air and event.is_action_pressed("derecha"):
				spin_dir = 1
			elif event.is_action_pressed("pausa"):
				state = "pause"
				jump_buf = 0.0   # que no salte solo al despausar
				Global.set_music_pause(true)
				Global.sfx("ui")
		"pause":
			if event.is_action_pressed("pausa") or event.is_action_pressed("confirmar"):
				state = "play"
				Global.set_music_pause(false)
				Global.sfx("ui_ok")
			elif event.is_action_pressed("mapa"):
				Global.set_music_pause(false)
				_go_map()
		"over":
			if event.is_action_pressed("confirmar") or event.is_action_pressed("reintentar"):
				Global.sfx("ui_ok")
				get_tree().reload_current_scene()
			elif event.is_action_pressed("mapa"):
				_go_map()
			elif Global.infinite and event is InputEventKey and event.keycode == KEY_T:
				state = "ranking"
				Global.sfx("ui")
		"initials":
			if event.is_action_pressed("arriba"):
				ini[ini_pos] = (ini[ini_pos] + 1) % 26
				Global.sfx("ui")
			elif event.is_action_pressed("abajo"):
				ini[ini_pos] = (ini[ini_pos] + 25) % 26
				Global.sfx("ui")
			elif event.is_action_pressed("izquierda"):
				ini_pos = maxi(0, ini_pos - 1)
				Global.sfx("ui")
			elif event.is_action_pressed("derecha"):
				ini_pos = mini(2, ini_pos + 1)
				Global.sfx("ui")
			elif event.is_action_pressed("confirmar"):
				if ini_pos < 2:
					ini_pos += 1
					Global.sfx("ui")
				else:
					var nm := "%s%s%s" % [LETTERS[ini[0]], LETTERS[ini[1]], LETTERS[ini[2]]]
					Global.top5_add(nm, int(score))
					state = "ranking"
					Global.sfx("ui_ok")
		"ranking":
			if event.is_action_pressed("confirmar") or event.is_action_pressed("reintentar"):
				Global.sfx("ui_ok")
				get_tree().reload_current_scene()
			elif event.is_action_pressed("mapa"):
				_go_map()
		"clear", "champion":
			if event.is_action_pressed("confirmar") or event.is_action_pressed("mapa"):
				# dejar seleccionada la playa recien desbloqueada
				Global.sel = mini(Global.cur + 1, Global.unlocked - 1)
				Global.sfx("ui_ok")
				get_tree().change_scene_to_file("res://scenes/WorldMap.tscn")

## Velocidad extra de los proyectiles cuando el jefe entra en fase 2.
const P2_SPD := 1.25

# ---------- COMO SE LE HACE DANO AL JEFE ----------
# Antes la barra roja parecia vida pero era un reloj: bajaba igual jugaras
# perfecto o de milagro. No habia forma de pegarle. Ahora:
#
#   1. ESQUIVAR un ataque completo sin que te toque .... le duele
#   2. Al terminar cada ataque queda EXPUESTO un momento:
#      si clavas un truco en esa ventana ............... le duele el triple
#   3. PARRY estilo Cuphead: caerle encima a algo que rueda o rebota
#      lo revienta, le hace dano y te devuelve el doble salto
#
# El reloj sigue existiendo pero solo como red de seguridad muy holgada,
# para que la pelea no sea infinita si el jugador no hace nada.
# Bajados desde 11/12/15: las peleas terminaban demasiado rapido. Con estos
# valores un jugador normal tarda 46 s en un mini-jefe en vez de 30 s.
const DMG_DODGE := 7.0     # esquivar un ataque limpio
const DMG_PUNISH := 8.0    # truco con el jefe expuesto
const DMG_PARRY := 10.0    # reventarle un proyectil de un pisoton
const BOSS_OPEN_T := 90.0  # 1.5 s de ventana para castigar
## proyectiles a los que se les puede caer encima
const PARRY_OK := {"roll": true, "bounce": true, "anillo": true}

# ---------- PARRY SOBRE OBSTACULOS NORMALES ----------
# Antes el tramo de surf era un pasillo: todo se resolvia esquivando y las
# unicas dos respuestas eran saltar o no saltar. Ahora hay una tercera:
# caerle ENCIMA. Boya y tronco a ras del agua, gaviota arriba: con eso se
# pueden encadenar rebotes sin tocar el agua y cruzar la playa por el aire.
#
# Pero NO todos: si se pudiera pisar cualquier cosa, el tramo se volveria
# facil y aburrido. Como en Cuphead, solo unos pocos estan MARCADOS (brillan
# en rosa) y son los unicos que aceptan el pisoton. Los demas, aunque sean
# del mismo tipo, te chocan igual que siempre.
const PARRY_OBS := {"buoy": true, "log": true, "bird": true, "shark": true}
## probabilidad de que un obstaculo de esos tipos salga marcado
const PARRY_CHANCE := 0.3

# ---------- TRAMOS DE PATRON FIJO ----------
# El tramo de surf era todo aleatorio, y lo aleatorio nunca se siente
# dominado: reaccionas, pero no ejecutas. Estos tramos estan disenados a
# mano y salen SIEMPRE IGUAL, asi que se pueden aprender y clavar.
#
# La separacion va en FRAMES, no en pixeles: el arco del rebote dura 39
# frames sea cual sea la velocidad, asi que midiendolo en frames el patron
# se siente identico en la N12 y en la N1. En pixeles habria que reescribir
# cada patron para cada playa.
#
# Formato: [tipo, frames desde el anterior, marcado para pisoton]
const PATRONES := {
	# cadena de rebotes: la razon de ser de todo esto
	"cadena":   [["buoy", 0, 1], ["bird", 40, 1], ["buoy", 40, 1], ["bird", 40, 1]],
	# balsa: cadena facil a ras del agua, para ensenar la mecanica
	"balsa":    [["log", 0, 1], ["log", 42, 1], ["log", 42, 1]],
	# muro: sin nada que pisar, tres saltos limpios y seguidos
	"muro":     [["rock", 0, 0], ["rock", 55, 0], ["rock", 55, 0]],
	# cebo: el del medio NO esta marcado. Si vas en piloto automatico, cobras
	"cebo":     [["buoy", 0, 1], ["buoy", 44, 0], ["buoy", 44, 1]],
	# bandada: alturas alternas, hay que leer cual se salta y cual no
	"bandada":  [["bird", 0, 0], ["bird", 30, 1], ["bird", 30, 0], ["bird", 30, 1]],
	# colmillo: solo en playas con tiburon. El de en medio es una roca
	"colmillo": [["shark", 0, 1], ["rock", 70, 0], ["shark", 70, 1]],
}
## que tres tramos le tocan a cada playa (indice 0 = N12 ... 11 = N1)
const PATRON_PLAYA := [
	["balsa", "cadena", "muro"],       # N12 ensena: pisar, encadenar, esquivar
	["cadena", "bandada", "muro"],     # N11
	["balsa", "muro", "cebo"],         # N10
	["cadena", "cebo", "bandada"],     # N9
	["muro", "cadena", "cebo"],        # N8
	["bandada", "muro", "cadena"],     # N7
	["cebo", "cadena", "muro"],        # N6
	["colmillo", "cadena", "cebo"],    # N5 Gold Coast: tiene tiburones
	["bandada", "cebo", "cadena"],     # N4
	["muro", "cadena", "cebo"],        # N3
	["cadena", "bandada", "cebo"],     # N2
	["colmillo", "cebo", "muro"],      # N1 el examen final
]
## En que punto de la barra arranca cada tramo. Son DOS, no tres: el tercer
## momento de la playa es el mini-encuentro (ENC_EN), que dura unos 15 s y
## se pisaba con el tercer tramo. Asi queda: tramo, tramo, encuentro, jefe.
const PATRON_EN := [0.28, 0.46]

# ---------- MINI-ENCUENTROS ----------
# Un rival con cara aparece a mitad de playa, te lanza tres formaciones
# telegrafiadas y se va. Dura unos 15 s y NO congela la barra: es una
# subida de intensidad, no una pausa, asi que no alarga la playa.
#
# Reusa las piezas que ya existen: las formaciones tienen el mismo formato
# que los tramos de patron ([tipo, frames desde el anterior, marcado]) y
# se sueltan con el mismo codigo. Lo unico nuevo es el bicho, el aviso y
# la cuenta de cuantas aguantaste.
const ENC_EN := 0.53          # a que altura de la barra aparece
const ENC_ESPERA := 150.0     # frames entre una formacion y la siguiente
const ENC_AVISO := 60.0       # aviso antes de cada una
const ENC_PREMIO := 90.0      # empujon de barra al vencerlo

const ENC_TIPOS := {
	"rival": {"nom": "EL RIVAL", "spr": "rival", "nf": 3, "dh": 34.0,
		"atk": [
			[["estela", 0, 0], ["estela", 58, 0]],
			[["buoy", 0, 1], ["buoy", 44, 0], ["buoy", 44, 1]],
			[["estela", 0, 0], ["buoy", 46, 1], ["estela", 46, 0]],
		],
		"txt": ["¡TE TIRA LA ESTELA!", "¡BOYAS! MIRA CUAL BRILLA", "¡ESTELA Y BOYA!"]},
	"manada": {"nom": "LA MANADA", "spr": "lobo", "nf": 2, "dh": 32.0,
		"atk": [
			[["lobo", 0, 0], ["lobo", 54, 0]],
			[["estela", 0, 0], ["lobo", 52, 0]],
			[["lobo", 0, 0], ["bird", 38, 1], ["lobo", 38, 0]],
		],
		"txt": ["¡SE TIRAN AL AGUA!", "¡PANZAZO!", "¡TODA LA MANADA!"]},
	"bandada": {"nom": "LA BANDADA", "spr": "bird", "nf": 2, "dh": 24.0,
		"atk": [
			[["bird", 0, 0], ["bird", 30, 1], ["bird", 30, 0]],
			[["bird", 0, 1], ["bird", 26, 0], ["bird", 26, 1], ["bird", 26, 0]],
			[["bird", 0, 0], ["buoy", 40, 1], ["bird", 40, 0]],
		],
		"txt": ["¡PICAN EN FILA!", "¡BANDADA CERRADA!", "¡TE RODEAN!"]},
	"aleta": {"nom": "LA ALETA", "spr": "shark", "nf": 3, "dh": 30.0,
		"atk": [
			[["estela", 0, 0], ["estela", 52, 0]],
			[["shark", 0, 1], ["estela", 62, 0]],
			[["estela", 0, 0], ["shark", 50, 1], ["estela", 50, 0]],
		],
		"txt": ["¡ONDAS DE LA ALETA!", "¡EMBISTE!", "¡NO TE DA TREGUA!"]},
}
## Que rival le toca a cada playa (indice 0 = N12 ... 11 = N1).
## Antes se elegia por el tipo de peligro de la playa y salia LA BANDADA en
## 9 de 12: el encuentro estaba para dar variedad y hacia justo lo contrario.
const ENC_PLAYA := [
	"bandada",  # N12 Teahupoo
	"rival",    # N11 Hossegor, capital europea del surf: pico lleno
	"rival",    # N10 Uluwatu
	"bandada",  # N9 Mundaka
	"rival",    # N8 Supertubos, sede de campeonato
	"manada",   # N7 El Gringo (Arica tiene lobos marinos)
	"rival",    # N6 Pipeline
	"aleta",    # N5 Gold Coast
	"bandada",  # N4 Male
	"manada",   # N3 Punta de Lobos
	"bandada",  # N2 Taghazout
	"aleta",    # N1 Corralejo
]

## Jefes cuya derrota es HUIR (cruzan la pantalla alejandose y se desvanecen).
## Los demas se van EN EL SITIO: se hunden, se disuelven o se echan a dormir,
## y ahi deslizarlos por la pantalla quedaria absurdo.
##   1 = LA GAVIOTA REINA .. vuela lejos despeinada
##   7 = EL MEGALODON ...... nada lejos con la aleta caida
## (el Pulpo se hunde, el Espiritu se disuelve, el Lobo se duerme en la roca,
##  el Kahuna se funde con el mar, el Genio vuelve a su lampara: todos se
##  quedan donde estan)
const DERROTA_HUYE := {1: true, 7: true}

const PARRY_VY := -4.6      # impulso del rebote
const PARRY_PTS := 200      # puntos base (x cadena)
const PARRY_PROG := 14.0    # cuanto empuja la barra (comparte tope con los trucos)

## lanza el ataque elegido como proyectiles moviles
func _boss_spawn_attack() -> void:
	var n0 := batks.size()
	_spawn_attack_body()
	# en fase 2 todo lo que viaja va un 25% mas rapido
	if boss_p2:
		for i in range(n0, batks.size()):
			var b: Dictionary = batks[i]
			if b["t"] == "dive":
				# la picada no usa vx como velocidad sino "dur" (su vx es solo
				# el signo de la direccion), asi que se acorta la duracion
				b["dur"] = maxf(20.0, float(b["dur"]) / P2_SPD)
			else:
				b["vx"] = float(b["vx"]) * P2_SPD
				if b.has("vy"):
					b["vy"] = float(b["vy"]) * P2_SPD


func _spawn_attack_body() -> void:
	match atk_type:
		"emb":
			# la cara de la ola se lanza deslizandose por el agua
			batks.append({"t": "emb", "x": -55.0, "vx": 2.3 * ATK_SPD, "w": 16.0, "hit": false})
		"ras":
			# vuelo rasante por el aire: quedate en el agua
			batks.append({"t": "ras", "x": -65.0, "vx": 2.8 * ATK_SPD, "w": 16.0, "hit": false})
		"doble":
			# dos embestidas bien espaciadas: un salto para cada una
			batks.append({"t": "emb", "x": -55.0, "vx": 2.4 * ATK_SPD, "w": 16.0, "hit": false})
			batks.append({"t": "emb", "x": -150.0, "vx": 2.4 * ATK_SPD, "w": 16.0, "hit": false})
		"roll":
			# rodillo de coral rodando desde la derecha: mas rapido y con un
			# segundo rodillo detras, para subir la dificultad
			batks.append({"t": "roll", "x": W + 40.0, "vx": -3.4 * ATK_SPD, "w": 13.0,
				"hit": false, "ph": 0.0})
			batks.append({"t": "roll", "x": W + 140.0, "vx": -3.4 * ATK_SPD, "w": 13.0,
				"hit": false, "ph": 0.0})
		"puas":
			# puas que emergen bajo el jugador (con burbujas de aviso).
			# BUGFIX: la segunda pua sale hacia el lado con mas espacio libre.
			# Antes salia siempre a la izquierda, asi que pegandose al borde
			# derecho el ataque se esquivaba solo.
			var lado := -1.0 if px > 90.0 else 1.0
			batks.append({"t": "spike", "x": clampf(px, 30.0, 150.0), "vx": 0.0,
				"w": 12.0, "hit": false, "ph": 0.0})
			batks.append({"t": "spike", "x": clampf(px + lado * 42.0, 30.0, 150.0), "vx": 0.0,
				"w": 12.0, "hit": false, "ph": -25.0})
		"meteor":
			# lluvia de coral: 5 meteoros bien juntos (revientan de a uno,
			# pero hay que reposicionarse seguido porque dejan poco espacio)
			# la mayoria son geiser chico, algunos grande, y de vez en
			# cuando sale el triple (tres puntos de peligro a la vez)
			for k in range(5):
				var r := randf()
				var tier := 0
				if r < 0.15:
					tier = 2
				elif r < 0.5:
					tier = 1
				var tw := 10.0
				if tier == 1: tw = 14.0
				elif tier == 2: tw = 26.0
				# BUGFIX: el rango era 28..138 y el surfista llega hasta x=150,
				# asi que quedandose pegado a la derecha no le caia ni uno.
				# Ahora cubre todo el carril jugable (30..150).
				batks.append({"t": "meteor", "x": 30.0 + randf() * 120.0, "vx": 0.0,
					"w": tw, "hit": false, "ph": -32.0 * k, "fy": -30.0, "tier": tier})
		# nota: low/lowfast/low2x/high/bounce/ink son ataques exclusivos de los
		# mini-jefes (el jefe final usa "emb"/"ras"/"doble" directamente), asi
		# que siempre nacen por la DERECHA, igual que el cuerpo del mini-jefe
		"low":
			# FASE 2: una segunda detras, mas apretada
			batks.append({"t": "emb", "x": W + 55.0, "vx": -2.3 * ATK_SPD, "w": 15.0, "hit": false})
			if boss_p2:
				batks.append({"t": "emb", "x": W + 130.0, "vx": -2.5 * ATK_SPD, "w": 15.0, "hit": false})
		"lowfast":
			# FASE 2: par rapido, la segunda pisandole los talones a la primera
			batks.append({"t": "emb", "x": W + 55.0, "vx": -3.2 * ATK_SPD, "w": 15.0, "hit": false})
			if boss_p2:
				batks.append({"t": "emb", "x": W + 100.0, "vx": -3.4 * ATK_SPD, "w": 15.0, "hit": false})
		"low2x":
			# FASE 2: tres coletazos en vez de dos
			var n_l2 := 3 if boss_p2 else 2
			for k in range(n_l2):
				batks.append({"t": "emb", "x": W + 55.0 + k * 95.0, "vx": -2.4 * ATK_SPD, "w": 15.0, "hit": false})
		"high":
			# FASE 2: par a media altura, obliga a aguantar el "no saltar" mas tiempo
			batks.append({"t": "ras", "x": W + 65.0, "vx": -2.8 * ATK_SPD, "w": 16.0, "hit": false})
			if boss_p2:
				batks.append({"t": "ras", "x": W + 130.0, "vx": -3.0 * ATK_SPD, "w": 16.0, "hit": false})
		"bounce":
			# FASE 2: dos rocas rebotando desfasadas (dos saltos con el ritmo justo)
			batks.append({"t": "bounce", "x": W + 45.0, "vx": -2.2 * ATK_SPD, "w": 12.0,
				"hit": false, "ph": 0.0, "fy": WATER - 10.0})
			if boss_p2:
				batks.append({"t": "bounce", "x": W + 130.0, "vx": -2.4 * ATK_SPD, "w": 12.0,
					"hit": false, "ph": 1.6, "fy": WATER - 10.0})
		"ink":
			# FASE 2: tres nubes de tinta en abanico en vez de una
			var n_ink := 3 if boss_p2 else 1
			for k in range(n_ink):
				batks.append({"t": "ink", "x": W + 60.0 + k * 60.0,
					"vx": (-2.6 - k * 0.2) * ATK_SPD, "w": 14.0, "hit": false})
		"ola":
			# ola gigante que llega por la derecha
			batks.append({"t": "ola", "x": W + 55.0, "vx": -2.6 * ATK_SPD, "w": 14.0, "hit": false})
		"ola_doble":
			# dos olas seguidas por la derecha
			batks.append({"t": "ola", "x": W + 55.0, "vx": -2.5 * ATK_SPD, "w": 14.0, "hit": false})
			batks.append({"t": "ola", "x": W + 165.0, "vx": -2.5 * ATK_SPD, "w": 14.0, "hit": false})
		"pinza":
			# ¡por ambos lados! embestida desde la izq + ola desde la der (desfasadas)
			# FASE 2: se suma una tercera ola justo por el medio, un instante despues
			batks.append({"t": "emb", "x": -55.0, "vx": 2.3 * ATK_SPD, "w": 16.0, "hit": false})
			batks.append({"t": "ola", "x": W + 55.0, "vx": -2.6 * ATK_SPD, "w": 14.0, "hit": false})
			if boss_p2:
				batks.append({"t": "ola", "x": W + 210.0, "vx": -2.9 * ATK_SPD, "w": 14.0, "hit": false})
		"tormenta":
			# el gran final: 4 olas alternando direcciones
			batks.append({"t": "emb", "x": -55.0, "vx": 2.2 * ATK_SPD, "w": 16.0, "hit": false})
			batks.append({"t": "ola", "x": W + 60.0, "vx": -2.5 * ATK_SPD, "w": 14.0, "hit": false})
			batks.append({"t": "emb", "x": -300.0, "vx": 2.2 * ATK_SPD, "w": 16.0, "hit": false})
			batks.append({"t": "ola", "x": W + 235.0, "vx": -2.5 * ATK_SPD, "w": 14.0, "hit": false})
		"dive":
			# picada real (estilo "Storm Eagle"): pica desde el punto donde
			# quedo flotando (dive_start) apuntando al surfista, y sigue de
			# largo hasta salir por el lado que le quede mas lejos -> segun
			# donde haya quedado flotando, sale derecha/izquierda/diagonal
			# BUGFIX: la picada NUNCA pasaba por el surfista (se iba entre 29 y
			# 98 px por encima, y lo peor era justo cuando la reina quedaba
			# encima tuyo). El codigo viejo estiraba la recta hasta el borde
			# lateral (x=410), eso daba una "y" muy por debajo de la pantalla,
			# y despues la recortaba con un clamp: al mover el punto final,
			# la recta se aplanaba y dejaba de pasar por donde apuntaba.
			#
			# Ahora se lanza un rayo desde la reina PASANDO por el surfista y
			# se corta en el primer borde que toque (un costado o el agua).
			# El punto final sale del rayo, asi que la trayectoria pasa
			# siempre exactamente por donde estaba el surfista al despegar.
			var aim := Vector2(px, water_y(px) - 6.0)
			var dir: Vector2 = aim - dive_start
			if dir.length() < 1.0:
				dir = Vector2(0.0, 1.0)
			dir = dir.normalized()
			var tmax := 99999.0
			if dir.x > 0.001:
				tmax = minf(tmax, (W + 90.0 - dive_start.x) / dir.x)
			elif dir.x < -0.001:
				tmax = minf(tmax, (-90.0 - dive_start.x) / dir.x)
			if dir.y > 0.001:
				# el agua tambien corta la picada (se zambulle)
				tmax = minf(tmax, (WATER + 2.0 - dive_start.y) / dir.y)
			var fin: Vector2 = dive_start + dir * tmax
			var dist: float = dive_start.distance_to(fin)
			# velocidad fija (3.0 px/frame de base) en vez de "cruzar la
			# pantalla en X tiempo": al cortarse la picada en el agua el
			# recorrido es mucho mas corto y quedaba en 0.31 s, imposible de
			# esquivar. Con un minimo de 26 frames siempre se puede leer.
			batks.append({"t": "dive", "x": dive_start.x, "y": dive_start.y,
				"x0": dive_start.x, "y0": dive_start.y, "x1": fin.x, "y1": fin.y,
				"ph": 0.0, "dur": maxf(26.0, dist / (3.0 * ATK_SPD)),
				"vx": 1.0 if fin.x >= dive_start.x else -1.0, "w": 14.0, "hit": false})
			dive_active = true
		"birds":
			# ataque de pajaros: bandada mas grande, mas rapida y mas apretada
			# desde la derecha, alternando altura para que sea dificil de leer
			var bheights := [WATER - 6.0, WATER - 42.0, WATER - 6.0, WATER - 42.0, WATER - 6.0]
			for k in range(5):
				batks.append({"t": "bird", "x": W + 30.0 + k * 50.0,
					"vx": (-3.2 - randf() * 0.5) * ATK_SPD, "y": bheights[k], "w": 9.0, "hit": false})
		"feathers":
			# plumas navaja: abanico mas amplio, con mas plumas y mas rapidas
			for k in range(7):
				# ojo: no llamar "ang" a esta variable, que tapa el angulo
				# del surfista (variable de la clase) y Godot avisa
				var fang: float = lerpf(-0.65, 0.65, k / 6.0)
				batks.append({"t": "feather", "x": W + 15.0, "y": WATER - 28.0,
					"vx": -3.4 * ATK_SPD * cos(fang), "vy": 3.4 * ATK_SPD * sin(fang), "w": 7.0, "hit": false})
		"cocos":
			# canon de cocos: 3 en abanico, cada uno rebota una vez
			for k in range(3):
				batks.append({"t": "bounce", "x": W + 35.0 + k * 65.0, "vx": (-2.5 - k * 0.15) * ATK_SPD,
					"w": 11.0, "hit": false, "ph": k * 1.4, "fy": WATER - 10.0})
		"monitos":
			# tropa de monitos surfistas: 5 a la vez, en carriles bien
			# distintos (pegados al agua y mas altos mezclados) para que
			# sea dificil esquivarlos solo saltando siempre igual
			var mheights := [WATER - 2.0, WATER - 16.0, WATER - 6.0, WATER - 22.0, WATER - 4.0]
			for k in range(5):
				batks.append({"t": "monkeysurf", "x": W + 30.0 + k * 52.0,
					"vx": (-2.6 - randf() * 0.9) * ATK_SPD, "y": mheights[k], "w": 13.0, "hit": false})
		"salto":
			# salto sagrado: cae recto (sin diagonal) sobre la sombra que
			# quedo marcada al apuntar al surfista
			batks.append({"t": "salto", "x": salto_target.x, "y": 10.0,
				"tx": salto_target.x, "y0": 10.0, "y1": salto_target.y,
				"ph": 0.0, "vx": 0.0, "w": 15.0, "hit": false})
			salto_active = true
		"tentaculo":
			# EL PULPO: en vez de viajar en linea recta, emerge cerca del
			# jugador (con aviso de burbujas) y BARRE de lado a lado.
			# FASE 2: sale un segundo tentaculo por el otro lado a la vez.
			var tcx := clampf(px + (randf() - 0.5) * 50.0, 30.0, 150.0)
			batks.append({"t": "tentaculo", "x": tcx, "cx": tcx, "vx": 0.0,
				"w": 15.0, "hit": false, "ph": -TENT_WARN})
			if boss_p2:
				var tcx2 := clampf(tcx + (40.0 if tcx < 90.0 else -40.0), 30.0, 150.0)
				batks.append({"t": "tentaculo", "x": tcx2, "cx": tcx2, "vx": 0.0,
					"w": 15.0, "hit": false, "ph": -TENT_WARN - 12.0})
		"agarre":
			# EL PULPO: un tentaculo se agarra desde ABAJO, directo bajo tus
			# pies. No se salta: el aviso marca el punto exacto y hay que
			# haberse movido de ahi antes de que reviente.
			var agx := clampf(px, 30.0, 150.0)
			batks.append({"t": "erupt", "x": agx, "vx": 0.0, "w": 20.0, "hit": false,
				"ph": 0.0, "warn": 55.0, "active": 20.0, "kind": "tentaculo"})
			if boss_p2:
				var agx2 := clampf(agx + (36.0 if agx < 90.0 else -36.0), 30.0, 150.0)
				batks.append({"t": "erupt", "x": agx2, "vx": 0.0, "w": 20.0, "hit": false,
					"ph": -14.0, "warn": 55.0, "active": 20.0, "kind": "tentaculo"})
		"anillos":
			# EL ESPIRITU DEL TUBO: anillos de espuma rodando, uno detras de
			# otro a distinta velocidad. Se les puede caer encima (parry).
			# FASE 2: un tercer anillo.
			var n_an := 3 if boss_p2 else 2
			for k in range(n_an):
				batks.append({"t": "anillo", "x": W + 40.0 + k * 60.0,
					"vx": (-3.0 - k * 0.5) * ATK_SPD, "w": 12.0, "hit": false, "ph": 0.0})
		"tubocierra":
			# EL ESPIRITU DEL TUBO: viaja tranquilo y se ve inofensivo, pero
			# al acercarse a la tabla se congela en el sitio y el hueco se
			# cierra encima. FASE 2: dos tubos a distancias distintas.
			batks.append({"t": "tubocierra", "x": W + 50.0, "vx": -2.0 * ATK_SPD,
				"w": 15.0, "hit": false, "closing": false, "ph": 0.0})
			if boss_p2:
				batks.append({"t": "tubocierra", "x": W + 150.0, "vx": -2.3 * ATK_SPD,
					"w": 15.0, "hit": false, "closing": false, "ph": 0.0})
		"espejismo":
			# EL ESPIRITU DEL TUBO: se duplica en varias siluetas fantasma;
			# solo UNA es real. Hay que LEER cual (la mas solida), no
			# reaccionar a tiempo: un tipo de ataque distinto a todos los
			# demas del juego. FASE 2: un fantasma mas (mas dificil de leer).
			var n_gh := 3 if boss_p2 else 2
			var real_idx := randi() % n_gh
			for k in range(n_gh):
				batks.append({"t": "decoy", "x": W + 40.0 + k * 55.0,
					"vx": -2.6 * ATK_SPD, "w": 13.0, "hit": false, "real": k == real_idx})
		"grieta":
			# EL DIABLO DE LAVA: la lava prende en el sitio (no viaja) y se
			# apaga sola. FASE 2: prende en 3 puntos seguidos en vez de 2,
			# como si la grieta corriera mas lejos por el fondo.
			var gx := clampf(px, 30.0, 150.0)
			var glado := -1.0 if px > 90.0 else 1.0
			var n_gr := 3 if boss_p2 else 2
			for k in range(n_gr):
				batks.append({"t": "grieta", "x": clampf(gx + glado * 36.0 * k, 30.0, 150.0),
					"vx": 0.0, "w": 16.0, "hit": false, "ph": -22.0 * k})
		"geiser_pie":
			# EL DIABLO DE LAVA: geiser de vapor que revienta bajo tus pies
			# (reusa el geiser del Guardian de Coral, pero saliendo del
			# punto exacto donde estas parado, no cayendo del cielo).
			# FASE 2: dos geiseres a la vez, en puntos distintos.
			var gpx := clampf(px, 30.0, 150.0)
			batks.append({"t": "erupt", "x": gpx, "vx": 0.0, "w": 18.0, "hit": false,
				"ph": 0.0, "warn": 50.0, "active": 22.0, "kind": "geyser"})
			if boss_p2:
				var gpx2 := clampf(gpx + (40.0 if gpx < 90.0 else -40.0), 30.0, 150.0)
				batks.append({"t": "erupt", "x": gpx2, "vx": 0.0, "w": 18.0, "hit": false,
					"ph": 0.0, "warn": 50.0, "active": 22.0, "kind": "geyser"})
		"marejada":
			# EL REY KAHUNA: golpea el baston y salen olas en secuencia
			# rapida, alto-bajo-alto. FASE 2: dos golpes mas (5 en vez de 3).
			var mspd := -3.0 * ATK_SPD
			batks.append({"t": "ras", "x": W + 60.0, "vx": mspd, "w": 15.0, "hit": false})
			batks.append({"t": "emb", "x": W + 140.0, "vx": mspd, "w": 15.0, "hit": false})
			batks.append({"t": "ras", "x": W + 220.0, "vx": mspd, "w": 15.0, "hit": false})
			if boss_p2:
				batks.append({"t": "emb", "x": W + 300.0, "vx": mspd, "w": 15.0, "hit": false})
				batks.append({"t": "ras", "x": W + 380.0, "vx": mspd, "w": 15.0, "hit": false})
		"megasalto":
			# EL MEGALODON: salto mortal en arco, con sombra de aviso y
			# onda de impacto al caer. FASE 2: al caer encadena un segundo
			# hop mas chico y mas rapido, como rematando el ataque.
			mega_target = Vector2(clampf(px, 30.0, 150.0), WATER - 6.0)
			batks.append({"t": "megasalto", "x": mega_target.x, "y": 10.0,
				"tx": mega_target.x, "y0": 10.0, "y1": mega_target.y,
				"ph": 0.0, "vx": 0.0, "w": 15.0, "hit": false,
				"chain": 1 if boss_p2 else 0})
		"mordida":
			# EL MEGALODON: MUERDE desde ABAJO, directo bajo la tabla. El
			# aviso marca el punto exacto (un remolino cerrandose) y hay que
			# haberse movido de ahi antes de que salga: no se salta, es
			# demasiado alto. FASE 2: dos mordidas casi juntas.
			var mox := clampf(px, 30.0, 150.0)
			batks.append({"t": "erupt", "x": mox, "vx": 0.0, "w": 22.0, "hit": false,
				"ph": 0.0, "warn": 45.0, "active": 18.0, "kind": "shark"})
			if boss_p2:
				var mox2 := clampf(mox + (44.0 if mox < 90.0 else -44.0), 30.0, 150.0)
				batks.append({"t": "erupt", "x": mox2, "vx": 0.0, "w": 22.0, "hit": false,
					"ph": -10.0, "warn": 45.0, "active": 18.0, "kind": "shark"})
		"vals":
			# LA MANTARRAYA: planeo - coletazo - planeo encadenados sin
			# pausa. FASE 2: un cuarto tiempo (planeo final), el vals completo.
			var vspd := -2.6 * ATK_SPD
			batks.append({"t": "ras", "x": W + 60.0, "vx": vspd, "w": 16.0, "hit": false})
			batks.append({"t": "emb", "x": W + 170.0, "vx": vspd, "w": 14.0, "hit": false})
			batks.append({"t": "ras", "x": W + 260.0, "vx": vspd, "w": 16.0, "hit": false})
			if boss_p2:
				batks.append({"t": "emb", "x": W + 350.0, "vx": vspd, "w": 14.0, "hit": false})
		"manada":
			# EL LOBO ALFA: la manada se tira de a uno desde la roca.
			# FASE 2: un cuarto lobo, con menos tiempo entre uno y otro.
			var n_lb := 4 if boss_p2 else 3
			var lb_gap := 20.0 if boss_p2 else 26.0
			for k in range(n_lb):
				batks.append({"t": "lobosalta", "x": W + 18.0, "vx": 0.0, "w": 15.0,
					"hit": false, "ph": -float(k) * lb_gap})
		"tornado":
			# EL GENIO DE LAS DUNAS: el remolino ACELERA a medida que viaja.
			# FASE 2: un segundo remolino mas lento detras, hay que seguir
			# a los dos a la vez.
			batks.append({"t": "tornado", "x": W + 45.0, "vx": -1.4 * ATK_SPD,
				"w": 13.0, "hit": false})
			if boss_p2:
				batks.append({"t": "tornado", "x": W + 140.0, "vx": -1.0 * ATK_SPD,
					"w": 13.0, "hit": false})
		"tresdeseos":
			# EL GENIO DE LAS DUNAS: remolino - alfombra - remolino
			# encadenados, el examen final antes de la Ola Monstruo.
			# FASE 2: un cuarto deseo.
			var dspd := -2.7 * ATK_SPD
			batks.append({"t": "emb", "x": W + 60.0, "vx": dspd, "w": 14.0, "hit": false})
			batks.append({"t": "ras", "x": W + 160.0, "vx": dspd, "w": 15.0, "hit": false})
			batks.append({"t": "emb", "x": W + 250.0, "vx": dspd, "w": 14.0, "hit": false})
			if boss_p2:
				batks.append({"t": "ras", "x": W + 340.0, "vx": dspd, "w": 15.0, "hit": false})


## salir del stage: en infinito vuelve al menu, en campana al mapa
func _go_map() -> void:
	if Global.infinite:
		get_tree().change_scene_to_file("res://scenes/Title.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/WorldMap.tscn")


## ¿Se le puede caer encima a este obstaculo? Hace falta que sea de los
## pisables, que vengas por el AIRE y BAJANDO, y que tus pies esten por
## encima de su mitad: si le entras de frente, te choca como siempre.
func _puede_pisar(o: Dictionary, py: float, oy: float) -> bool:
	if not o.get("parry", false):
		return false   # solo los marcados en rosa
	return air and vy > 0.0 and py + 6.0 <= oy + o["h"] * 0.6


## Revienta el obstaculo, te impulsa y encadena.
func _parry_obs(o: Dictionary, oy: float) -> void:
	parry_chain += 1
	hitstop = 4.0        # pisoton con pegada
	var mult: float = 1.0 + (parry_chain - 1) * 0.5     # x1, x1.5, x2, x2.5...
	vy = PARRY_VY
	jumps = 1          # te devuelve el doble salto: por eso se puede encadenar
	cut_done = false
	air = true
	var pts := int(PARRY_PTS * mult * _mult())
	score += pts
	# el avance de barra comparte tope con los trucos, para que no se pueda
	# romper la playa combinando las dos cosas
	if not boss and not Global.infinite:
		var goal := Global.goal_of(Global.cur)
		var cap: float = goal * Global.TRICK_PROGRESS_CAP
		var add: float = minf(PARRY_PROG * mult, cap - trick_prog)
		if add > 0.0:
			trick_prog += add
			progress += add
			bar_flash = 22.0
	if parry_chain > 1:
		_msg("¡CADENA x%d! +%d" % [parry_chain, pts])
	else:
		_msg("¡REBOTE! +" + str(pts))
	pops.append({"x": o["x"], "y": oy - 8, "txt": "+" + str(pts), "life": 45.0})
	shake = maxf(shake, 3.0)
	Global.sfx("parry", 1.0 + parry_chain * 0.12)
	for j in range(10):
		_splash(o["x"], oy, 1.8)


## Le quita vida al jefe y lo avisa en pantalla.
func _boss_damage(d: float, txt_: String) -> void:
	if boss_hp <= 0.0:
		return
	boss_hp = maxf(0.0, boss_hp - d)
	hitstop = 5.0
	_msg(txt_ + " -" + str(int(d)))
	pops.append({"x": px + 14, "y": water_y(px) - 34 + y_off,
		"txt": "-" + str(int(d)), "life": 45.0})
	shake = maxf(shake, 4.0)
	Global.sfx("castigo")


## PARRY: le caes encima a un proyectil que rueda o rebota. Lo revientas,
## le haces dano al jefe y sales rebotado con el doble salto recargado.
func _parry(bx: float, py: float) -> void:
	_boss_damage(DMG_PARRY, "¡REBOTE!")
	vy = -4.2          # el pisoton te impulsa
	jumps = 1          # y te devuelve el doble salto
	cut_done = false
	air = true
	shake = 6.0
	Global.sfx("parry", 1.15)
	for j in range(12):
		_splash(bx, py + 6, 2.0)


## Elige el punto del cielo desde donde va a picar la Gaviota Reina.
## Se evita que quede justo encima del surfista: una picada vertical cae
## demasiado rapido y no se puede leer ni esquivar. Siempre queda en
## diagonal, que es lo que hace legible el ataque.
func _pick_dive_start() -> void:
	var qx := 24.0 + randf() * (W - 48.0)
	if absf(qx - px) < 70.0:
		var lado := 1.0 if px < W * 0.5 else -1.0
		qx = clampf(px + lado * (70.0 + randf() * 60.0), 24.0, W - 24.0)
	dive_start = Vector2(qx, 12.0 + randf() * 10.0)


## ¿esta apretada la tecla de salto ahora mismo?
func _jump_held() -> bool:
	return Input.is_action_pressed("saltar")


## ¿queda algun salto disponible? (piso + doble salto)
func _can_jump() -> bool:
	return not air or jumps < 2


func _jump() -> void:
	if tube_on > 0:
		tube_clean = false   # saltar rompe el tubo perfecto
	cut_done = false   # empieza un salto nuevo: se puede volver a cortar
	if not air:
		air = true
		jumps = 1
		vy = JUMP_VY
		squash = 1.0          # se estira al despegar
		Global.sfx("salto")
		for i in range(6):
			_splash(px, water_y(px) - 4, 1.5)
	elif jumps < 2:
		# doble salto: impulso extra en el aire para combos imposibles
		jumps = 2
		vy = JUMP_VY2
		Global.sfx("salto2")
		for i in range(5):
			_splash(px, water_y(px) - 10 + y_off, 1.0)

func _splash(x: float, y: float, pow_: float) -> void:
	parts.append({
		"x": x + randf() * 10 - 5, "y": y,
		"vx": (randf() - 0.7) * 2, "vy": -randf() * 2 * pow_,
		"life": 20 + randf() * 15
	})

func _mk_obs(type: String, x: float) -> Dictionary:
	var o := {"type": type, "x": x, "hit": false, "bob": randf() * 6, "c": false,
		"w": 14.0, "h": 12.0, "fy": 0.0, "ph": 0.0, "variant": 0, "timer": 0.0,
		# solo algunos salen marcados para el pisoton (ver PARRY_CHANCE)
		"parry": PARRY_OBS.has(type) and randf() < PARRY_CHANCE}
	match type:
		"rock":
			o["w"] = 20.0 if S()["sp"].has("coral") else 18.0
			o["h"] = 14.0
			o["variant"] = randi() % 2
		"buoy":
			o["w"] = 13.0; o["h"] = 19.0
			o["variant"] = randi() % 5
		"log":
			o["w"] = 28.0; o["h"] = 12.0
			o["variant"] = randi() % 6
		"bird":
			o["w"] = 13.0; o["h"] = 9.0
			o["fy"] = WATER - 42 - randf() * 10
		"estela":
			# ola de estela: la tira el rival del mini-encuentro. Viaja mas
			# rapido que un obstaculo normal y NO se puede pisar: o la saltas
			# o te lleva. Es lo que le da un ataque propio al encuentro.
			o["w"] = 17.0; o["h"] = 13.0
		"shark": o["w"] = 12.0; o["h"] = 8.0  # empieza como aleta, crece al acercarse
		"lobo": o["w"] = 16.0; o["h"] = 20.0
		"rival": o["w"] = 14.0; o["h"] = 19.0
	return o

func _spawn() -> void:
	var sp: Array = S()["sp"]
	var r := randf()
	var type := "rock"
	if sp.has("shark") and tube_on <= 0 and r < 0.25:
		type = "shark"  # nunca durante un tubo (seria injusto)
	elif sp.has("lobo") and r < 0.3:
		type = "lobo"
	elif sp.has("rival") and r < 0.28:
		type = "rival"
	elif score > 350 and tube_on <= 0 and r < 0.42:
		type = "bird"
	elif r < 0.6:
		type = "buoy"
	elif r < 0.8:
		type = "log"
	# el tiburon asoma pegado al borde derecho (acecha antes de atacar)
	obs.append(_mk_obs(type, W + 5 if type == "shark" else W + 20))
	if type == "shark":
		Global.sfx("tiburon")
	if sp.has("cluster") and type in ["rock", "buoy", "log"] and randf() < 0.55:
		obs.append(_mk_obs(type, W + 56))
		if randf() < 0.5:
			obs.append(_mk_obs(type, W + 92))

## Que rival le toca a esta playa (tabla fija, ver ENC_PLAYA).
func _enc_de_playa() -> String:
	return String(ENC_PLAYA[clampi(Global.cur, 0, ENC_PLAYA.size() - 1)])


## Mini-encuentro: aparece, lanza tres formaciones avisadas y se va.
##
## OJO con el orden de esta maquina de estados: la primera version lanzaba
## la formacion 1 en vez de la 0 (la 0 no salia nunca) y regalaba la primera
## "aguantada" sin haber esquivado nada. De tres formaciones solo se veian
## dos, y por eso el encuentro parecia que no hacia nada.
func _update_encuentro(dt: float, goal: int) -> void:
	if Global.infinite:
		return
	# --- se esta yendo ---
	if enc_out > 0.0:
		enc_out -= dt
		if enc_out <= 0.0:
			enc_tipo = ""
		return
	# --- ¿toca que aparezca? ---
	if enc_tipo == "":
		if not enc_hecho and pat_lista.is_empty() and progress / goal >= ENC_EN:
			enc_hecho = true
			enc_tipo = _enc_de_playa()
			enc_fase = 0
			enc_ok = 0
			enc_activa = false
			enc_limpio = true
			enc_aviso = 90.0     # un respiro para verlo llegar
			enc_t = 0.0
			_msg("¡" + String(ENC_TIPOS[enc_tipo]["nom"]) + "!")
			shake = 7.0
			Global.sfx("jefe", 1.35)
		return
	var d: Dictionary = ENC_TIPOS[enc_tipo]
	var total: int = (d["atk"] as Array).size()
	# --- telegrafo: avisa y despues suelta la formacion que toca ---
	if enc_aviso > 0.0:
		enc_aviso -= dt
		if enc_aviso <= 0.0:
			pat_lista = ((d["atk"] as Array)[enc_fase] as Array).duplicate(true)
			pat_t = 0.0
			enc_limpio = true
			enc_activa = true
			enc_t = 110.0        # lo que tardan en cruzar hasta el surfista
			Global.sfx("aviso")
		return
	# --- formacion en curso ---
	if enc_activa:
		if not pat_lista.is_empty():
			return               # todavia quedan piezas por soltar
		enc_t -= dt
		if enc_t > 0.0:
			return               # dejar que terminen de cruzar
		enc_activa = false
		if enc_limpio:
			enc_ok += 1
			Global.sfx("bonus", 1.15)
		enc_fase += 1
		if enc_fase >= total:
			# se acabo: premio si aguantaste al menos dos
			enc_out = 110.0
			if enc_ok >= 2:
				progress += ENC_PREMIO
				score += 400
				bar_flash = 22.0
				_msg("¡%s VENCIDO! +400" % String(d["nom"]))
				Global.sfx("victoria")
			else:
				_msg("SE VA " + String(d["nom"]))
				Global.sfx("ui_atras")
			return
		enc_aviso = ENC_AVISO
	return


## Arranca el tramo de patron fijo que le toca a esta playa.
func _empezar_patron() -> void:
	var nombres: Array = PATRON_PLAYA[clampi(Global.cur, 0, PATRON_PLAYA.size() - 1)]
	var nom: String = String(nombres[pat_hechos % nombres.size()])
	# el "colmillo" solo tiene sentido donde hay tiburones
	if nom == "colmillo" and not S()["sp"].has("shark"):
		nom = "cadena"
	pat_hechos += 1
	pat_lista = (PATRONES[nom] as Array).duplicate(true)
	pat_t = 0.0
	# limpiar lo aleatorio que venia de antes para que el patron se lea
	# limpio, pero respetando los bonus y power-ups que estan en camino
	for i in range(obs.size() - 1, -1, -1):
		if not obs[i]["c"]:
			obs.remove_at(i)
	_msg("¡TRAMO!")
	Global.sfx("castigo")


## Suelta la siguiente pieza del patron.
func _soltar_patron() -> void:
	var e: Array = pat_lista.pop_front()
	var o := _mk_obs(String(e[0]), W + 20)
	# en un patron el marcado NO es al azar: es parte del diseno
	o["parry"] = PARRY_OBS.has(o["type"]) and int(e[2]) == 1
	if o["type"] == "bird":
		o["fy"] = WATER - 46.0   # altura fija: si no, el patron no se aprende
	obs.append(o)
	# los frames de la SIGUIENTE pieza
	pat_t = float(pat_lista[0][1]) if not pat_lista.is_empty() else 0.0


func _spawn_coll() -> void:
	var sp: Array = S()["sp"]
	if sp.has("banana"):
		var o := _mk_obs("banana", W + 16)
		o["c"] = true
		o["w"] = 9.0; o["h"] = 9.0
		o["fy"] = WATER - 24 - randf() * 18
		obs.append(o)
	if sp.has("dolphin"):
		var o := _mk_obs("dolphin", W + 16)
		o["c"] = true
		o["w"] = 13.0; o["h"] = 10.0
		o["fy"] = WATER
		obs.append(o)

func _update(dt: float) -> void:
	if intro > 0: intro -= dt

	# --- fase REMO: machacar espacio para tomar la ola ---
	if phase == "remo":
		paddle = maxf(0.0, paddle - 0.35 * dt)
		if int(t) % 4 == 0:
			_splash(px - 12, water_y(px) - 1, 0.6)
		if paddle >= 100.0:
			phase = "popup"
			pop_t = 44.0
			Global.sfx("bonus", 0.95)
		return
	# --- fase POP-UP: animacion de pararse en la tabla ---
	if phase == "popup":
		pop_t -= dt
		if pop_t <= 0:
			phase = "surf"
			_msg("ARRIBA! A SURFEAR")
			Global.fanfare()
			for i in range(10):
				_splash(px, water_y(px) - 2, 2.0)
		return

	# modo infinito: la playa (colores y peligros) rota cada 1200 pts
	if Global.infinite:
		var ni := int(score / 1200.0) % Global.NS
		if ni != _inf_idx:
			_inf_idx = ni
			_msg("AHORA: " + Global.STAGES[ni]["name"])
			Global.sfx("bonus", 1.1)

	var sp: Array = S()["sp"]
	var goal := Global.goal_of(Global.cur)

	# ===== JEFES: mini-jefe en cada playa + LA OLA MONSTRUO en Corralejo =====
	if not Global.infinite:
		var bfinal := Global.cur == Global.NS - 1
		if not boss and progress >= goal * (0.7 if bfinal else 0.75):
			boss = true
			# EL JEFE AHORA TIENE VIDA, NO RELOJ. El reloj queda solo como red
			# de seguridad muy holgada para que la pelea no sea infinita si el
			# jugador se queda quieto sin esquivar nada.
			boss_hpmax = 200.0 if bfinal else 100.0
			boss_hp = boss_hpmax
			# red de seguridad: subida junto con la bajada de dano, si no el
			# jugador pasivo (84 s) se pasaba del tope viejo de 80 s
			boss_tmax = 10200.0 if bfinal else 6000.0
			boss_t = boss_tmax
			boss_open = 0.0
			atk_live = false
			atk_clean = true
			atk_t = 150.0
			obs.clear()       # el jefe reemplaza el caos, no se suma
			# si el encuentro seguia en curso, el rival se larga: el jefe manda
			enc_tipo = ""
			enc_out = 0.0
			pat_lista.clear()
			if bfinal:
				_msg("¡LA OLA MONSTRUO!")
			else:
				_msg("¡" + String(MBOSS[Global.cur]["name"]) + "!")
			shake = 12.0
			Global.sfx("jefe")
			# corazon de regalo antes de la pelea
			obs.append({"type": "pw_heart", "c": true, "x": W + 16, "fy": WATER - 30,
				"w": 11.0, "h": 11.0, "hit": false, "bob": 0.0, "ph": 0.0,
				"variant": 0, "timer": 0.0})
		if boss:
			boss_t -= dt
			# FASE 2 PARA TODOS LOS JEFES (antes solo la Ola Monstruo la tenia).
			# A la mitad de la pelea se enfurece: ataca mas seguido, mas
			# rapido, y entra su tercer ataque. Con peleas de 50 s hacia
			# falta que tuvieran forma, no que fueran el mismo bucle mas rato.
			if not boss_p2 and boss_hp < boss_hpmax * 0.5:
				boss_p2 = true
				atk_bag.clear()   # se rearma la bolsa incluyendo el 3er ataque
				if bfinal:
					_msg("¡LA OLA SE ENFURECE!")
				else:
					_msg("¡SE ENFURECE!")
				shake = 10.0
				Global.sfx("furia")
			if boss_open > 0:
				boss_open -= dt
			if boss_hp <= 0 or boss_t <= 0:
				# secuencia de retirada: la ola se calma antes de la victoria
				if boss_out < 0:
					boss_out = 200.0
					batks.clear()
					atk_warn = 0.0
					dive_active = false
					dive_chain = 0
					salto_active = false
					_msg("¡LA OLA SE RETIRA!" if bfinal else "¡VENCIDO!")
					Global.sfx("victoria")
				boss_out -= dt
				if int(t) % 5 == 0:
					_splash(15 + randf() * 70, WATER - 4, 1.6)
				if boss_out <= 0:
					boss = false
					Global.clear_boss_checkpoint()
					progress = goal   # victoria: completa la playa
			else:
				# proyectiles: se mueven por el agua y se esquivan a la vista
				var py2 := water_y(px) - 10 + y_off
				for i in range(batks.size() - 1, -1, -1):
					var b: Dictionary = batks[i]
					b["x"] += b["vx"] * dt
					if b["t"] == "bounce":
						# proyectil que rebota en arco (coco/roca/megalodon)
						b["ph"] += 0.05 * dt
						b["fy"] = WATER - 10.0 - absf(sin(b["ph"])) * 40.0
					elif b["t"] == "spike":
						# puas del arrecife: burbujas de aviso -> pua activa -> se retira
						b["ph"] += dt
						if b["ph"] >= SPIKE_TOTAL:
							batks.remove_at(i)
							continue
					elif b["t"] == "meteor":
						# meteoro de coral que cae y estalla en un geiser al llegar
						b["ph"] += dt
						if b["ph"] >= 0.0 and b["ph"] < MET_FALL:
							b["fy"] = lerpf(-30.0, WATER - 8.0, clampf(b["ph"] / MET_FALL, 0.0, 1.0))
						if b["ph"] >= MET_FALL + MET_BURST:
							batks.remove_at(i)
							continue
					elif b["t"] == "dive":
						# picada real: linea recta desde el punto de despegue (dive_start)
						# hasta el punto de salida elegido al azar (ph 0..1)
						b["ph"] += dt / b["dur"]
						var k4: float = clampf(b["ph"], 0.0, 1.0)
						b["x"] = lerpf(b["x0"], b["x1"], k4)
						b["y"] = lerpf(b["y0"], b["y1"], k4)
						if b["ph"] >= 1.0:
							dive_active = false
							batks.remove_at(i)
							if dive_chain > 0:
								# embiste de nuevo: sube y pica una segunda vez
								dive_chain -= 1
								_pick_dive_start()
								atk_warn = 85.0
								atk_type = "dive"
							continue
					elif b["t"] == "feather":
						b["y"] += b["vy"] * dt
					elif b["t"] == "salto":
						# salto sagrado: cae recto sobre la sombra y explota
						b["ph"] += dt
						if b["ph"] < SALTO_FALL:
							b["y"] = lerpf(b["y0"], b["y1"], clampf(b["ph"] / SALTO_FALL, 0.0, 1.0))
						if b["ph"] >= SALTO_FALL + SALTO_BURST:
							salto_active = false
							batks.remove_at(i)
							continue
					elif b["t"] == "tentaculo":
						# barrido de tentaculo: no viaja, oscila de lado a
						# lado alrededor del punto donde emergio
						b["ph"] += dt
						if b["ph"] >= 0.0:
							b["x"] = b["cx"] + sin(b["ph"] * 0.22) * 22.0
						if b["ph"] >= TENT_SWEEP:
							batks.remove_at(i)
							continue
					elif b["t"] == "tubocierra":
						# viaja tranquilo hasta acercarse a la tabla; ahi se
						# congela en el sitio y el hueco se cierra encima
						if not b["closing"] and absf(b["x"] - px) < TUBO_CLOSE_RANGE:
							b["closing"] = true
							b["vx"] = 0.0
							b["ph"] = 0.0
						if b["closing"]:
							b["ph"] += dt
							if b["ph"] >= TUBO_CLOSE_T:
								batks.remove_at(i)
								continue
					elif b["t"] == "grieta":
						# grieta de lava: prende en el sitio, no viaja
						b["ph"] += dt
						if b["ph"] >= GRIETA_WARN + GRIETA_ACTIVE:
							batks.remove_at(i)
							continue
					elif b["t"] == "megasalto":
						# salto mortal del Megalodon: mismo ritmo que el
						# salto sagrado, cae recto sobre la sombra. En fase 2
						# encadena un segundo hop mas chico al aterrizar.
						b["ph"] += dt
						if b["ph"] < MEGASALTO_FALL:
							b["y"] = lerpf(b["y0"], b["y1"], clampf(b["ph"] / MEGASALTO_FALL, 0.0, 1.0))
						if b["ph"] >= MEGASALTO_FALL + MEGASALTO_BURST:
							batks.remove_at(i)
							if int(b.get("chain", 0)) > 0:
								var mtx2 := clampf(b["tx"] + (30.0 if b["tx"] < 90.0 else -30.0), 30.0, 150.0)
								batks.append({"t": "megasalto", "x": mtx2, "y": -6.0,
									"tx": mtx2, "y0": -6.0, "y1": WATER - 6.0,
									"ph": 0.0, "vx": 0.0, "w": 15.0, "hit": false, "chain": 0})
							continue
					elif b["t"] == "lobosalta":
						# se para en la roca (aviso, sin moverse) y despues
						# se tira embistiendo como una ola mas
						b["ph"] += dt
						if b["ph"] >= LOBO_WARN and b["vx"] == 0.0:
							b["vx"] = -2.6 * ATK_SPD
					elif b["t"] == "tornado":
						# remolino de arena: ACELERA con el tiempo
						b["vx"] -= 0.014 * dt
					elif b["t"] == "erupt":
						# emerge desde ABAJO en un punto fijo: aviso -> revienta
						# (no viaja). No se salta: el hitbox activo es muy alto,
						# hay que estar en otro lado cuando explote.
						b["ph"] += dt
						if b["ph"] >= float(b["warn"]) + float(b["active"]):
							batks.remove_at(i)
							continue
					# solo se eliminan cuando SALEN en su direccion de viaje
					# (los ataques dobles nacen lejos fuera de pantalla)
					if b["vx"] != 0.0 and ((b["vx"] > 0 and b["x"] > W + 90) or (b["vx"] < 0 and b["x"] < -90)):
						batks.remove_at(i)
						continue
					# red de seguridad: las plumas en abanico pueden derivar fuera
					# de pantalla en vertical antes de salir por un costado
					if b.has("y") and (b["y"] < -80.0 or b["y"] > H + 80.0):
						batks.remove_at(i)
						continue
					var top := WATER - 13.0
					var bot := WATER + 4.0
					if b["t"] == "ras":
						top = WATER - 46.0
						bot = WATER - 25.0
					elif b["t"] == "ola":
						top = WATER - 18.0
					elif b["t"] == "bounce":
						top = b["fy"] - 9.0
						bot = b["fy"] + 9.0
					elif b["t"] == "ink":
						top = WATER - 42.0
						bot = WATER - 24.0
					elif b["t"] == "spike":
						if b["ph"] < SPIKE_WARN:
							top = -999.0
							bot = -998.0
						else:
							top = WATER - 15.0
							bot = WATER + 2.0
					elif b["t"] == "meteor":
						if b["ph"] < 0.0:
							# todavia en el aviso (burbujas): no golpea
							top = -999.0
							bot = -998.0
						elif b["ph"] < MET_FALL:
							# cayendo: tambien golpea si te para justo debajo
							top = b["fy"] - 8.0
							bot = b["fy"] + 8.0
						else:
							top = WATER - 12.0
							bot = WATER + 6.0
					elif b["t"] == "dive":
						top = b["y"] - 18.0
						bot = b["y"] + 18.0
					elif b["t"] == "bird":
						top = b["y"] - 7.0
						bot = b["y"] + 7.0
					elif b["t"] == "feather":
						top = b["y"] - 6.0
						bot = b["y"] + 6.0
					elif b["t"] == "monkeysurf":
						top = b["y"] - 21.0
						bot = b["y"] + 4.0
					elif b["t"] == "salto":
						if b["ph"] < SALTO_FALL - 10.0:
							top = -999.0
							bot = -998.0
						else:
							top = WATER - 16.0
							bot = WATER + 4.0
					elif b["t"] == "tentaculo":
						if b["ph"] < 0.0:
							top = -999.0
							bot = -998.0
						else:
							top = WATER - 20.0
							bot = WATER + 4.0
					elif b["t"] == "tubocierra":
						if b["closing"]:
							top = WATER - 22.0
							bot = WATER + 8.0
						else:
							top = WATER - 10.0
							bot = WATER + 3.0
					elif b["t"] == "grieta":
						if b["ph"] < GRIETA_WARN:
							top = -999.0
							bot = -998.0
						else:
							top = WATER - 6.0
							bot = WATER + 5.0
					elif b["t"] == "megasalto":
						if b["ph"] < MEGASALTO_FALL - 8.0:
							top = -999.0
							bot = -998.0
						else:
							top = WATER - 16.0
							bot = WATER + 4.0
					elif b["t"] == "erupt":
						if b["ph"] < float(b["warn"]):
							top = -999.0
							bot = -998.0
						else:
							# bien alto: NO se puede saltar, hay que estar
							# en otro lado cuando revienta
							top = WATER - 60.0
							bot = WATER + 8.0
					elif b["t"] == "decoy":
						if b["real"]:
							top = WATER - 13.0
							bot = WATER + 4.0
						else:
							top = -999.0
							bot = -998.0
					if not b["hit"] and inv <= 0 \
							and px + 6 > b["x"] - b["w"] and px - 6 < b["x"] + b["w"] \
							and py2 + 6 > top and py2 - 10 < bot:
						# PARRY ESTILO CUPHEAD: si le caes ENCIMA a algo que
						# rueda o rebota, en vez de golpearte lo revientas,
						# le haces dano al jefe y sales rebotado con el doble
						# salto recargado. Solo cuenta cayendo (vy > 0).
						if PARRY_OK.has(b["t"]) and air and vy > 0.0:
							b["hit"] = true
							_parry(b["x"], py2)
							batks.remove_at(i)
							continue
						b["hit"] = true
						if b["t"] == "ink":
							# la tinta no dana: oscurece la pantalla
							ink_t = 200.0
							_msg("¡TINTA! CASI NO VES")
							Global.sfx("golpe", 0.8)
							batks.remove_at(i)
							continue
						atk_clean = false   # te toco: este ataque ya no da dano
						Global.sfx("golpe_duro")
						_take_hit(py2)
				if atk_warn > 0:
					atk_warn -= dt
					if atk_warn <= 0:
						_boss_spawn_attack()
						atk_live = true
						atk_clean = true   # empieza limpio; si te toca, se cae
						boss_open = 0.0    # atacando ya no esta expuesto
						shake = 6.0
						Global.sfx("aviso")
				elif batks.is_empty():
					# el ataque termino: si lo esquivaste limpio, le duele, y
					# el jefe queda EXPUESTO un momento para castigarlo
					if atk_live:
						atk_live = false
						if atk_clean:
							_boss_damage(DMG_DODGE, "¡ESQUIVADA!")
						boss_open = BOSS_OPEN_T
						Global.sfx("ui")
					atk_t -= dt
					if atk_t <= 0:
						# RITMO: la mitad del ciclo de ataque era espera muerta
						# (2.7 s de 6.6 s). Bajado para que la pelea no sea
						# "esperar - esquivar - esperar". Igual se acelera a
						# medida que avanza, y en fase 2 aprieta mas.
						# el ritmo se acelera segun le baja la VIDA, no el reloj
						# (el reloj ahora es solo una red de seguridad larga,
						#  asi que atado a el los ataques no apretaban nunca)
						atk_t = 40.0 + 40.0 * (boss_hp / boss_hpmax) + randf() * 25.0
						if boss_p2:
							atk_t *= 0.7
						atk_warn = 70.0
						if bfinal:
							var pool := ["emb", "ras", "ola"]
							if boss_p2:
								pool = ["emb", "ras", "ola", "doble",
									"ola_doble", "pinza", "tormenta"]
							atk_type = pool[randi() % pool.size()]
						elif Global.cur == 0:
							# Guardian del Coral: rodillo y puas desde el principio;
							# la lluvia de coral (su ataque grande) entra en fase 2.
							# Es el primer jefe del juego: tiene que ensenar antes
							# de castigar.
							if atk_bag.is_empty():
								atk_bag = ["roll", "puas"]
								if boss_p2:
									atk_bag.append("meteor")
								atk_bag.shuffle()
							atk_type = atk_bag.pop_back()
						elif Global.cur == 1:
							# Gaviota Reina: picada y bandada de entrada;
							# el abanico de plumas entra en fase 2
							if atk_bag.is_empty():
								atk_bag = ["dive", "birds"]
								if boss_p2:
									atk_bag.append("feathers")
								atk_bag.shuffle()
							atk_type = atk_bag.pop_back()
							if atk_type == "dive":
								# antes de picar sube aleteando a un punto al azar cerca
								# del cielo, para que no se sepa por donde va a atacar
								_pick_dive_start()
								atk_warn = 130.0
								# a veces embiste dos veces seguidas, encadenando otra
								# picada apenas termina la primera
								dive_chain = 1 if randf() < 0.5 else 0
						elif Global.cur == 2:
							# Mono del Templo: cocos y tropa de monitos de entrada;
							# el salto sagrado (lo mas espectacular) en fase 2
							if atk_bag.is_empty():
								atk_bag = ["cocos", "monitos"]
								if boss_p2:
									atk_bag.append("salto")
								atk_bag.shuffle()
							atk_type = atk_bag.pop_back()
							if atk_type == "salto":
								# deja la sombra apuntada a donde estas ahora y
								# se toma su tiempo saltando antes de caer
								salto_target = Vector2(clampf(px, 30.0, 150.0), WATER - 6.0)
								atk_warn = 100.0
						elif Global.cur == 3:
							# Pulpo del Estuario: 3 ataques desde el arranque
							# (tentaculo, agarre desde abajo, tinta). En fase
							# 2 cada uno se intensifica por dentro (ver el
							# "if boss_p2" propio de cada uno en el spawn).
							if atk_bag.is_empty():
								atk_bag = ["tentaculo", "agarre", "ink"]
								atk_bag.shuffle()
							atk_type = atk_bag.pop_back()
							if atk_type == "agarre":
								atk_warn = 95.0
						elif Global.cur == 4:
							# Espiritu del Tubo: anillos (parry), tubo que se
							# cierra, y espejismo (hay que LEER cual es real)
							if atk_bag.is_empty():
								atk_bag = ["anillos", "tubocierra", "espejismo"]
								atk_bag.shuffle()
							atk_type = atk_bag.pop_back()
						elif Global.cur == 5:
							# Diablo de Lava: roca ardiente, grieta de lava,
							# y geiser bajo los pies (no se salta, hay que
							# moverse)
							if atk_bag.is_empty():
								atk_bag = ["bounce", "grieta", "geiser_pie"]
								atk_bag.shuffle()
							atk_type = atk_bag.pop_back()
							if atk_type == "geiser_pie":
								atk_warn = 90.0
						elif Global.cur == 6:
							# Rey Kahuna: jabalina baja, jabalina alta (ya se
							# distinguen por sprite propio) y la marejada
							# -ritmo fijo alto-bajo-alto-
							if atk_bag.is_empty():
								atk_bag = ["lowfast", "high", "marejada"]
								atk_bag.shuffle()
							atk_type = atk_bag.pop_back()
						elif Global.cur == 7:
							# Megalodon: embestida, mordida desde abajo (no
							# se salta), y salto mortal con sombra de aviso
							if atk_bag.is_empty():
								atk_bag = ["lowfast", "mordida", "megasalto"]
								atk_bag.shuffle()
							atk_type = atk_bag.pop_back()
							if atk_type == "megasalto":
								atk_warn = 90.0
							elif atk_type == "mordida":
								atk_warn = 85.0
						elif Global.cur == 8:
							# Mantarraya Colosal: planeo rasante, coletazo, y
							# el vals (planeo-coletazo-planeo encadenado)
							if atk_bag.is_empty():
								atk_bag = ["high", "low2x", "vals"]
								atk_bag.shuffle()
							atk_type = atk_bag.pop_back()
						elif Global.cur == 9:
							# Lobo Alfa: ladrido (ola), panzazo (pinza), y la
							# manada tirandose de la roca de a uno
							if atk_bag.is_empty():
								atk_bag = ["low", "pinza", "manada"]
								atk_bag.shuffle()
							atk_type = atk_bag.pop_back()
						elif Global.cur == 10:
							# Genio de las Dunas: remolino que acelera,
							# alfombra voladora, y los tres deseos
							# encadenados -el examen final antes de Corralejo-
							if atk_bag.is_empty():
								atk_bag = ["tornado", "high", "tresdeseos"]
								atk_bag.shuffle()
							atk_type = atk_bag.pop_back()
						else:
							# mini-jefe: sus 2 ataques tematicos, y en fase 2
							# entra el tercero. Se reparten como una bolsa para
							# que no salga el mismo tres veces seguidas.
							var mb: Dictionary = MBOSS[Global.cur]
							if atk_bag.is_empty():
								atk_bag = [mb["a"], mb["b"]]
								if boss_p2 and mb.has("c"):
									atk_bag.append(mb["c"])
								atk_bag.shuffle()
							atk_type = atk_bag.pop_back()
						Global.sfx("aviso", 1.2)

	# ola gigante
	if sp.has("surge") and not boss and surge_on <= 0:
		surge_t -= dt
		if surge_t <= 0:
			surge_on = 180
			surge_t = 620 + randf() * 400
			_msg("OLA GIGANTE!")
			Global.sfx("jefe", 1.4)
	if surge_on > 0: surge_on -= dt
	# tubo
	if sp.has("tube") and not boss and tube_on <= 0:
		tube_t -= dt
		if tube_t <= 0:
			tube_on = 260
			tube_acc = 0.0
			tube_clean = true
			tube_t = 720 + randf() * 420
			_msg("TUBO! QUEDATE ABAJO")
			Global.sfx("bonus", 0.95)
	if tube_on > 0:
		tube_on -= dt
		if not air:
			tube_acc += 0.35 * dt   # el bonus se acumula y se cobra al final
			if int(t) % 5 == 0:
				_splash(px + 10, water_y(px) - 16, 1)
		if tube_on <= 0 and tube_acc > 0:
			# fin del tubo: x2 si nunca saltaste (tubo perfecto)
			var tpts := int(tube_acc * (2.0 if tube_clean else 1.0) * _mult())
			score += tpts   # el tubo da SCORE, no distancia
			_msg(("¡TUBO PERFECTO! +" if tube_clean else "TUBO +") + str(tpts))
			pops.append({"x": px + 12, "y": water_y(px) - 30,
				"txt": "+" + str(tpts), "life": 45.0})
			Global.sfx("bonus", 0.9)
	# coleccionables
	if not boss and (sp.has("banana") or sp.has("dolphin")):
		coll_t -= dt
		if coll_t <= 0:
			_spawn_coll()
			coll_t = 230 + randf() * 200
	# power-ups (en todas las playas, cada ~14-22s; no durante el jefe)
	if not boss:
		pw_t -= dt
		if pw_t <= 0:
			pw_t = 850 + randf() * 500
			var kinds := ["pw_shield", "pw_x2"]
			if sp.has("banana") or sp.has("dolphin"):
				kinds.append("pw_magnet")   # el iman solo donde hay bonus que atraer
			else:
				kinds.append("pw_heart")    # en las demas playas: vida extra
			obs.append({"type": kinds[randi() % 3], "c": true, "x": W + 16,
				"fy": WATER - 26 - randf() * 18, "w": 11.0, "h": 11.0, "hit": false,
				"bob": randf() * 6, "ph": 0.0, "variant": 0, "timer": 0.0})

	if Global.infinite:
		speed = minf(5.6, 1.76 + score / 2000.0)  # sube sin limite de playa (-20%)
	else:
		# la velocidad sube con la DISTANCIA recorrida, no con los puntos:
		# asi la curva de dificultad es la misma juegues como juegues
		speed = minf(Global.max_spd(Global.cur),
			Global.base_spd(Global.cur) + progress / Global.SPD_RAMP)
	if surge_on > 0: speed += 1.4
	score += speed * 0.09 * dt * _mult()
	if not boss:
		# LA BARRA MIDE DISTANCIA SURFEADA Y NADA MAS (ver GOALS en global.gd).
		# Sin _mult(): el power-up x2 multiplica PUNTOS, no distancia.
		# Contra el jefe se congela: la unica forma de ganar es aguantar
		# la pelea completa.
		progress += speed * 0.09 * dt
	if inv > 0: inv -= dt
	if shake > 0: shake = maxf(0.0, shake - 0.55 * dt)
	if x2_t > 0: x2_t -= dt
	if bar_flash > 0: bar_flash -= dt
	if squash != 0.0:
		squash = move_toward(squash, 0.0, 0.09 * dt)
	if magnet_t > 0: magnet_t -= dt
	if ink_t > 0: ink_t -= dt
	if msg_t > 0:
		msg_t -= dt
		if msg_t <= 0: msg = ""

	# meta alcanzada (en infinito no hay meta; la barra avanza con progress)
	if not Global.infinite and progress >= goal:
		Global.best[Global.cur] = maxi(Global.best[Global.cur], int(score))
		if Global.cur == Global.unlocked - 1 and Global.unlocked < Global.NS:
			Global.unlocked += 1
		# estrellas: meta / score alto / sin dano
		st_score = score >= goal * Global.STAR_SCORE_MULT
		st_nodmg = not took_damage
		var sc_stars := 1 + (1 if st_score else 0) + (1 if st_nodmg else 0)
		Global.stars[Global.cur] = maxi(Global.stars[Global.cur], sc_stars)
		clear_t = t
		Global.save_game()
		Global.fanfare()
		state = "champion" if Global.cur == Global.NS - 1 else "clear"
		return

	# movimiento horizontal: adelante/atras en un rango limitado
	# (en el aire tambien sirve, y ademas inicia los giros)
	if phase == "surf":
		# get_axis devuelve -1..1: con el stick del mando se mueve
		# proporcionalmente, con las flechas es todo o nada
		var mdir := Input.get_axis("izquierda", "derecha")
		px = clampf(px + mdir * 1.9 * dt, 30.0, 150.0)

	# --- salto pedido con el buffer: sale en cuanto haya uno disponible ---
	if jump_buf > 0.0:
		jump_buf -= dt
		if _can_jump():
			_jump()
			jump_buf = 0.0

	# fisica del surfista
	if air:
		# ALTURA VARIABLE: si soltaste la tecla mientras subias, se corta el
		# impulso. Un toque da un salto bajito, mantener da el salto entero.
		if not cut_done and vy < JUMP_CUT and not _jump_held():
			vy = JUMP_CUT
			cut_done = true
		# GRAVEDAD EN TRES ZONAS: subida normal / flote arriba / caida pesada
		var g := G_APEX
		if absf(vy) > APEX_BAND:
			g = G_RISE if vy < 0.0 else G_FALL
		vy += g * dt
		y_off += vy * dt
		if spin_dir != 0:
			ang += 0.27 * spin_dir * dt
			spin_acc += 0.27 * dt
			if spin_acc >= TAU:
				spin_acc -= TAU
				combo += 1
				var pts := int(150 * combo * _mult())   # x2, x3... en el mismo salto
				score += pts
				# cada truco empuja la barra una cantidad FIJA: chica, pero
				# constante durante toda la playa (ver global.gd). El tope
				# solo esta para que no se pueda romper machacando giros.
				if not boss and not Global.infinite:
					var tcap: float = goal * Global.TRICK_PROGRESS_CAP
					var tadd: float = minf(Global.TRICK_PROGRESS_FLAT,
						tcap - trick_prog)
					if tadd > 0.0:
						trick_prog += tadd
						progress += tadd
						bar_flash = 22.0   # que se VEA que la barra avanzo
				tricks += 1
				# CASTIGO: si clavas el truco con el jefe expuesto, le duele
				# de verdad. Es la forma de acortar la pelea.
				if boss and boss_open > 0.0:
					boss_open = 0.0   # un solo castigo por ventana
					_boss_damage(DMG_PUNISH, "¡CASTIGO!")
				elif combo > 1:
					_msg("¡TRUCO x%d! +%d" % [combo, pts])
				else:
					_msg("TRUCO! +150")
				pops.append({"x": px + 12, "y": water_y(px) - 26 + y_off,
					"txt": "+" + str(pts), "life": 45.0})
				Global.sfx("truco", 1.0 + combo * 0.13)
		if y_off >= 0:
			y_off = 0; air = false; vy = 0; ang = 0; spin_dir = 0; spin_acc = 0
			jumps = 0
			combo = 0
			cut_done = false
			squash = -1.0        # se achata al aterrizar
			if parry_chain > 2:
				_msg("CADENA DE %d REBOTES" % parry_chain)
			parry_chain = 0   # tocar el agua corta la cadena
			Global.sfx("agua")
			for i in range(8):
				_splash(px, water_y(px) - 2, 2)
	else:
		if int(t) % 3 == 0:
			_splash(px - 8, water_y(px) - 2, 0.8)

	# spawn de obstaculos
	# durante el jefe NO aparecen obstaculos: la pelea es solo contra sus ataques
	if not boss:
		_update_encuentro(dt, goal)
		# ¿toca arrancar un tramo de patron fijo?
		if pat_lista.is_empty() and enc_tipo == "" and not Global.infinite \
				and pat_hechos < PATRON_EN.size():
			if progress / goal >= PATRON_EN[pat_hechos]:
				_empezar_patron()
		if not pat_lista.is_empty():
			# durante el tramo manda el patron: el azar se calla
			pat_t -= dt
			while not pat_lista.is_empty() and pat_t <= 0.0:
				_soltar_patron()
			# al terminar, un respiro antes de volver al azar
			if pat_lista.is_empty():
				spawn_t = 70.0
		else:
			spawn_t -= dt
			if spawn_t <= 0:
				_spawn()
				var ramp: float = score if Global.infinite else progress
				spawn_t = maxf(30.0, (85.0 - _sidx() * 3) - ramp / Global.SPAWN_RAMP) + randf() * 40

	# mover + colisiones
	var py := water_y(px) - 10 + y_off
	for i in range(obs.size() - 1, -1, -1):
		var o: Dictionary = obs[i]
		var mv := 1.0
		if o["type"] == "bird": mv = 1.5
		elif o["type"] == "estela": mv = 1.7   # la estela viene rapida
		elif o["type"] == "shark":
			# fase 1 (acecho ~2s): la aleta casi no avanza / fase 2: ataque
			o["timer"] += dt
			mv = 0.12 if o["timer"] < 130 else 0.75
		elif o["type"] == "rival": mv = 0.55
		o["x"] -= speed * mv * dt
		if o["type"] == "shark":
			# hitbox chico mientras acecha, grande cuando ataca de cerca
			if o["timer"] > 130 and o["x"] - px < 70:
				o["w"] = 28.0; o["h"] = 16.0
			else:
				o["w"] = 12.0; o["h"] = 8.0
		if o["type"] == "dolphin":
			o["ph"] += 0.055 * dt
			o["fy"] = WATER - 12 - abs(sin(o["ph"])) * 36
		if o["x"] < -30:
			obs.remove_at(i)
			continue
		var oy := _obs_y(o)
		var tocando: bool = (px + 6 > o["x"] - o["w"] / 2 + 2 and px - 6 < o["x"] + o["w"] / 2 - 2
			and py + 6 > oy - 2 and py - 10 < oy + o["h"] - 2)
		if o["c"]:
			# iman: atrae los bonus hacia el surfista
			if magnet_t > 0 and not o["hit"]:
				var ddx: float = o["x"] - px
				if absf(ddx) < 110:
					o["x"] -= ddx * 0.05 * dt
					o["fy"] = lerpf(o["fy"], water_y(px) - 12 + y_off, 0.05 * dt)
			if not o["hit"] and tocando:
				o["hit"] = true
				obs.remove_at(i)
				_collect(o, oy)
			continue
		if not o["hit"] and tocando and _puede_pisar(o, py, oy):
			# PARRY (estilo Cuphead) sobre obstaculos normales: si le caes
			# ENCIMA, en vez de chocar lo revientas y sales rebotado.
			o["hit"] = true
			obs.remove_at(i)
			_parry_obs(o, oy)
			continue
		if inv <= 0 and not o["hit"] and tocando:
			o["hit"] = true
			if not shield:
				_hit_sfx(o["type"])
			_take_hit(py)

	# particulas
	_update_parts(dt)

func _update_parts(dt: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var p: Dictionary = parts[i]
		p["x"] += (p["vx"] - speed * 0.6) * dt
		p["y"] += p["vy"] * dt
		p["vy"] += 0.15 * dt
		p["life"] -= dt
		if p["life"] <= 0 or p["y"] > H:
			parts.remove_at(i)
	for i in range(pops.size() - 1, -1, -1):
		var p: Dictionary = pops[i]
		p["y"] -= 0.35 * dt
		p["life"] -= dt
		if p["life"] <= 0:
			pops.remove_at(i)

func _obs_y(o: Dictionary) -> float:
	var ot: String = o["type"]
	if ot == "bird" or o["c"]:
		var extra := 0.0
		if ot.begins_with("pw_"):
			extra = sin(t * 0.08 + o["bob"]) * 4.0   # los power-ups flotan
		return o["fy"] + extra
	var bob: float = sin(t * 0.1 + o["bob"]) * (2.0 if ot == "buoy" else 0.0)
	return water_y(o["x"]) - o["h"] + 3 + bob

func _mult() -> float:
	return 2.0 if x2_t > 0 else 1.0

## recibe un golpe: el escudo lo absorbe; maneja muerte y checkpoint del jefe
func _take_hit(py: float) -> void:
	if shield:
		shield = false
		inv = 70
		shake = 5.0
		_msg("¡ESCUDO ROTO!")
		Global.sfx("escudo")
		for j in range(10):
			_splash(px, py, 2.0)
		return
	lives -= 1
	took_damage = true
	hitstop = 7.0        # el golpe se siente
	enc_limpio = false   # esta formacion del encuentro ya no cuenta
	inv = 100
	shake = 9.0
	for j in range(14):
		_splash(px, py, 2.5)
	if lives <= 0:
		if Global.infinite:
			Global.hi_inf = maxi(Global.hi_inf, int(score))
		else:
			Global.best[Global.cur] = maxi(Global.best[Global.cur], int(score))
			if boss:
				# reintentar directo en el jefe DE ESTA playa
				Global.set_boss_checkpoint(Global.cur)
		Global.save_game()
		state = "dying"      # animacion de caida antes del game over
		shake = 14.0
		die_t = 55.0
		go_art = 1 + randi() % 2
		Global.sfx("caida")

## efectos al recoger coleccionables y power-ups
func _collect(o: Dictionary, oy: float) -> void:
	var pts := 0
	match o["type"]:
		"banana":
			pts = int(100 * _mult())
			_msg("¡PLATANO! +" + str(pts))
		"dolphin":
			pts = int(200 * _mult())
			_msg("¡DELFIN! +" + str(pts))
		"pw_shield":
			if shield:
				pts = 200
				_msg("ESCUDO YA ACTIVO +200")
			else:
				shield = true
				_msg("¡ESCUDO!")
		"pw_x2":
			x2_t = 600.0
			_msg("¡PUNTOS x2 POR 10s!")
		"pw_magnet":
			magnet_t = 600.0
			_msg("¡IMAN DE BONUS!")
		"pw_heart":
			if lives < 3:
				lives += 1
				_msg("¡VIDA EXTRA!")
			else:
				pts = 300
				_msg("VIDAS LLENAS +300")
	if pts > 0:
		# platanos, delfines y power-ups dan SCORE, no distancia: el delfin
		# solo aportaba a la barra 2.7 veces lo que aportaba surfear
		score += pts
		pops.append({"x": o["x"], "y": oy - 6, "txt": "+" + str(pts), "life": 45.0})
	Global.sfx("bonus")
	for j in range(8):
		_splash(o["x"], oy, 1.5)

func _msg(s: String) -> void:
	msg = s
	msg_t = 60

## sonido caracteristico segun con que chocaste
func _hit_sfx(type: String) -> void:
	match type:
		"buoy":  Global.sfx("metal")            # campanazo de la boya
		"log":   Global.sfx("madera")           # golpe seco
		"rock":  Global.sfx("golpe", 0.85)      # crujido grave
		"bird":  Global.sfx("golpe", 1.9)       # graznido agudo
		"shark": Global.sfx("golpe_duro", 0.9)  # mordida
		"lobo":  Global.sfx("golpe", 1.25)
		"rival": Global.sfx("madera", 1.3)      # choque entre tablas
		_:       Global.sfx("golpe")


# ---------- DIBUJO ----------

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
	draw_set_transform(_shk, 0.0, Vector2.ONE)
	draw_string(font, Vector2(xx * 4 + 2, y * 4 + 2), s, align, wdt, size * 4, Color(0, 0, 0, 0.55))
	draw_string(font, Vector2(xx * 4, y * 4), s, align, wdt, size * 4, col)
	_set_cam()

## agrega puntos de una curva cuadratica al arreglo
func _qcurve(arr: PackedVector2Array, p0: Vector2, p1: Vector2, p2: Vector2, n := 8) -> void:
	for i in range(1, n + 1):
		var a := float(i) / n
		arr.append(p0.lerp(p1, a).lerp(p1.lerp(p2, a), a))

## dibuja un frame de un strip con altura logica dh, anclado abajo-centro
func _draw_sprite(tex: Texture2D, nf: int, frame: int, base: Vector2, dh: float, flip := false) -> void:
	var fw := tex.get_width() / float(nf)
	var fh := float(tex.get_height())
	var dw := dh * fw / fh
	var src := Rect2(frame * fw, 0, -fw if flip else fw, fh)
	draw_texture_rect_region(tex, Rect2(base.x - dw / 2, base.y - dh, dw, dh), src)

func _draw_surfer(pos: Vector2, angle: float, alt := false) -> void:
	# elegir animacion segun la fase (solo el jugador usa remo/popup)
	var tex: Texture2D = null
	var nf := FRAMES
	var frame := 0
	if alt:
		tex = tex_surf
		frame = int(t / 7.0) % FRAMES
	elif phase == "remo":
		tex = tex_remo
		nf = 4
		frame = int(t / 8.0) % 4
	elif phase == "popup":
		tex = tex_popup
		nf = 4
		frame = clampi(3 - int(pop_t / 11.0), 0, 3)
	elif air:
		tex = tex_air
		frame = int(t / 6.0) % FRAMES
	else:
		tex = tex_surf
		frame = int(t / 7.0) % FRAMES
	if tex:
		var fw := tex.get_width() / float(nf)
		var fh := tex.get_height()
		# los sprites vienen a resolucion completa: se dibujan a 0.2x logico
		# (mismo tamano en pantalla, maxima definicion con el render 4x)
		var dw := fw * 0.2
		var dh := fh * 0.2
		var tint := Color(1, 0.65, 0.6) if alt else Color.WHITE
		# SQUASH & STRETCH: se estira al despegar y se achata al caer.
		# El volumen se mantiene (lo que se estira a lo alto se encoge a lo
		# ancho), que es lo que hace que se lea como deformacion y no como
		# un cambio de tamano.
		var sq := 0.0 if alt else squash
		var esc := Vector2(4.0 * (1.0 - sq * 0.16), 4.0 * (1.0 + sq * 0.22))
		draw_set_transform(Vector2(int(pos.x) * 4, int(pos.y) * 4) + _shk, angle, esc)
		draw_texture_rect_region(tex, Rect2(-dw / 2, -dh + 7, dw, dh),
			Rect2(frame * fw, 0, fw, fh), tint)
		_set_cam()
		return
	draw_set_transform(Vector2(int(pos.x) * 4, int(pos.y) * 4) + _shk, angle, Vector2(4, 4))
	draw_rect(Rect2(-10, 4, 20, 3), Color("2a9d54") if alt else Color("ff4757"))
	draw_rect(Rect2(-10, 4, 5, 3), Color("ffd166"))
	draw_rect(Rect2(8, 4, 2, 3), Color.WHITE)
	draw_rect(Rect2(-5, -1, 2, 5), Color("16324f"))
	draw_rect(Rect2(2, -1, 2, 5), Color("16324f"))
	draw_rect(Rect2(-3, -8, 6, 7), Color("8d0801") if alt else Color("1d3557"))
	draw_rect(Rect2(-3, -8, 6, 2), Color("ffb703") if alt else Color("2ec4b6"))
	draw_rect(Rect2(-7, -7, 4, 2), Color("f2c094"))
	draw_rect(Rect2(3, -6, 4, 2), Color("f2c094"))
	draw_rect(Rect2(-2, -13, 5, 5), Color("f2c094"))
	draw_rect(Rect2(-2, -14, 5, 2), Color("222222") if alt else Color("6b3e1e"))
	_set_cam()

var _shk := Vector2.ZERO

## transform base de camara: escala 4x + sacudida
func _set_cam() -> void:
	draw_set_transform(_shk, 0.0, Vector2(4, 4))

func _draw() -> void:
	# render interno 1280x720: coordenadas logicas 320x180 escaladas 4x
	_shk = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 1.2 if shake > 0 else Vector2.ZERO
	_set_cam()
	var st := S()
	var sky: Array = st["sky"]
	# cielo
	for i in range(4):
		draw_rect(Rect2(0, i * 18, W, 18), sky[i])
	draw_rect(Rect2(0, 72, W, WATER - 72), sky[0])
	# sol
	draw_circle(Vector2(250, 52), 16, Color("fff3b0"))
	draw_circle(Vector2(250, 52), 12, Color("ffd166"))
	# nubes
	for i in range(3):
		var cx := fposmod(i * 140 - t * 0.3, W + 60) - 30
		var cy := 20 + i * 16
		draw_rect(Rect2(cx, cy, 26, 5), Color(1, 1, 1, 0.8))
		draw_rect(Rect2(cx + 5, cy - 3, 14, 3), Color(1, 1, 1, 0.8))
	# paisaje del horizonte (uno por playa) o isla lejana de respaldo
	var bgt: Texture2D = tex_bgs[_sidx()] if tex_bgs.size() > _sidx() else null
	if bgt:
		var bh := W * bgt.get_height() / float(bgt.get_width())
		draw_texture_rect(bgt, Rect2(0, WATER - 2 - bh, W, bh), false)
	else:
		draw_colored_polygon(PackedVector2Array([
			Vector2(280, WATER - 14), Vector2(300, WATER - 26), Vector2(316, WATER - 16),
			Vector2(330, WATER - 8), Vector2(270, WATER - 8)
		]), Color("b06a8f"))
	# mar (tile con scroll si hay sprite, si no rectangulos)
	if tex_sea:
		var tw := float(tex_sea.get_width())
		var off := fmod(t * 1.2, tw)
		draw_texture_rect(tex_sea, Rect2(-off, WATER - 4, W + tw, H - WATER + 4), true)
		# tinte del agua segun la playa
		var tint: Color = st["sea"]
		tint.a = 0.35
		draw_rect(Rect2(0, WATER - 4, W, H - WATER + 4), tint)
	else:
		draw_rect(Rect2(0, WATER - 4, W, H - WATER + 4), st["sea"])
		for i in range(4):
			var xx := -20.0
			while xx < W:
				var rx := fposmod(xx - t * (1.5 + i * 0.5), W + 40) - 20
				draw_rect(Rect2(rx, 140 + i * 10, 22, 2), st["sea_dk"])
				xx += 40
	var x := 0.0
	while x < W:
		draw_rect(Rect2(x, water_y(x) - 4, 4, 6), st["sea_hi"])
		x += 4

	# gran ola (fija: el surfista se mueve sobre ella, ella no lo sigue)
	var sc := 1.0 + _sidx() * 0.045 + (0.25 if surge_on > 0 else 0.0)
	var wx := 58.0
	var wy := WATER + sin(t * 0.05) * 2
	if tex_wave:
		var hgt := 56.0 * sc
		var wdt := hgt * tex_wave.get_width() / tex_wave.get_height()
		draw_texture_rect(tex_wave, Rect2(wx - wdt * 0.62, wy + 10 - hgt, wdt, hgt), false)
	else:
		var wave := PackedVector2Array([Vector2(wx - 52 * sc, wy + 22)])
		_qcurve(wave, Vector2(wx - 52 * sc, wy + 22), Vector2(wx - 40 * sc, wy - 40 * sc), Vector2(wx + 6, wy - 36 * sc))
		_qcurve(wave, Vector2(wx + 6, wy - 36 * sc), Vector2(wx + 32, wy - 33 * sc), Vector2(wx + 28, wy - 16))
		_qcurve(wave, Vector2(wx + 28, wy - 16), Vector2(wx + 20, wy - 26), Vector2(wx + 2, wy - 24))
		_qcurve(wave, Vector2(wx + 2, wy - 24), Vector2(wx - 16, wy - 20), Vector2(wx - 10, wy + 22))
		draw_colored_polygon(wave, st["sea_hi"])
		for i in range(7):
			var a := i / 6.0
			var fx := wx - 40 * sc + a * 68 * sc
			var fy := wy - 38 * sc + a * 20 + sin(t * 0.2 + i) * 2
			draw_circle(Vector2(fx, fy), 3.5 - a, Color("eaf6ff"))
		draw_rect(Rect2(wx + 22, wy - 18 + sin(t * 0.25) * 2, 8, 3), Color.WHITE)

	# el jefe de esta playa (o la Ola Monstruo) acechando desde su lado
	if boss:
		# durante la retirada usa los frames de derrota y se aleja / se desarma
		var dfinal := Global.cur == Global.NS - 1
		# todos los jefes tematicos aparecen por la DERECHA mirando a la
		# IZQUIERDA (y lo mismo sus ataques); solo la Ola Monstruo (jefe
		# final) se queda a la izquierda, como siempre
		var right_boss := not dfinal
		var out_k := 0.0
		# ojo: la derrota ahora llega por VIDA, no por reloj. Si esto siguiera
		# mirando boss_t, la animacion de derrota no se veria nunca.
		if boss_out > 0:
			out_k = 1.0 - boss_out / 200.0
		var bt := tex_boss2 if (boss_p2 and tex_boss2) else tex_boss
		var bnf := 3
		if not dfinal and tex_mb:
			bt = tex_mb
			bnf = int(MBOSS[Global.cur]["nf"])
		var defeat_anim := false
		# huida: la lamina mboss_out_N ya viene dibujada mirando hacia donde
		# se va, asi que NO hay que voltearla. Ademas cruza la pantalla y
		# sube, en vez de quedarse clavada en su sitio encogiendose.
		var huida := false
		if dfinal and out_k > 0 and tex_calm:
			bt = tex_calm
			bnf = 2
		elif Global.cur == 0 and out_k > 0 and tex_cb_out:
			# el Guardian de Coral se desarma en pedacitos en vez de alejarse nadando
			bt = tex_cb_out
			bnf = 3
			defeat_anim = true
		elif Global.cur == 2 and out_k > 0 and tex_mono_out:
			# el Mono del Templo se inclina, sus monitos festejan y rema lejos
			bt = tex_mono_out
			bnf = 3
		elif out_k > 0 and tex_mb_out:
			# ANIMACION DE DERROTA GENERICA: basta con dejar el archivo
			# assets/mboss_out_N.png (3 frames) y se usa solo, sin tocar codigo.
			bt = tex_mb_out
			bnf = 3
			defeat_anim = true
			huida = DERROTA_HUYE.has(Global.cur)
		# la Gaviota Reina desaparece de su sitio mientras sube aleteando y
		# durante la picada misma (la dibuja el proyectil "dive" mas abajo)
		var queen_rising := not dfinal and Global.cur == 1 and atk_type == "dive" and atk_warn > 0
		var queen_hidden := queen_rising or (not dfinal and Global.cur == 1 and dive_active)
		# el Mono del Templo desaparece de su sitio mientras salta y durante
		# la caida del "salto sagrado" (la dibuja el proyectil "salto")
		var mono_rising := not dfinal and Global.cur == 2 and atk_type == "salto" and atk_warn > 0
		var mono_hidden := mono_rising or (not dfinal and Global.cur == 2 and salto_active)
		if bt and not queen_hidden and not mono_hidden:
			var bh2 := (104.0 + sin(t * 0.05) * 4) * (1.0 - out_k * (0.2 if defeat_anim else 0.55))
			var bfw := bt.get_width() / float(bnf)
			var bw2 := bh2 * bfw / bt.get_height()
			# BUGFIX de encuadre: el tamano se calculaba SOLO por la altura, y
			# las laminas anchas (Mantarraya, Megalodon, Rey Kahuna) salian de
			# 200 a 235 px de ancho en una pantalla de 320. Ademas el cuerpo se
			# anclaba por su CENTRO en x=308, asi que la mitad del jefe quedaba
			# fuera de pantalla. Ahora se limita el ancho y se ancla dejando
			# solo un pedacito asomando por el borde.
			var sz := _fit_boss(bh2, bw2)
			bh2 = sz.y
			bw2 = sz.x
			var bfr := clampi(int(out_k * bnf), 0, bnf - 1) if defeat_anim else int(t / 10.0) % bnf
			var slide := 0.0 if defeat_anim else out_k * 130.0
			var dest_x := (W - 6 - bw2 * BOSS_ANCHOR + slide) if right_boss \
				else (6 - bw2 * (1.0 - BOSS_ANCHOR) - slide)
			var src_w := -bfw if right_boss else bfw
			var dest_y := WATER + 16 + out_k * 26.0 - bh2
			if huida:
				# se va cruzando la pantalla hacia el lado contrario y subiendo,
				# con una curva suave (rapido al principio, se frena al fondo)
				var k7: float = out_k * out_k
				dest_x = W - 6 - bw2 * BOSS_ANCHOR - k7 * (W * 0.85)
				dest_y = WATER + 16 - bh2 - k7 * 46.0
				src_w = bfw     # la lamina ya mira hacia donde huye
			# EXPUESTO: destella en dorado para que se vea que toca castigarlo
			var btint := Color.WHITE
			if boss_open > 0.0 and int(t / 4) % 2 == 0:
				btint = Color(1.6, 1.35, 0.7)
			elif out_k > 0.0:
				# Se desvanece ANTES de que termine la retirada, asi el ultimo
				# medio segundo es el surfista solo en el agua y despues entra
				# la pantalla de victoria. Antes el jefe seguia a la vista al
				# 25% y la pantalla cortaba encima: por eso se sentia brusco.
				var fin_k: float = 0.80 if huida else 0.90
				btint = Color(1, 1, 1, clampf((fin_k - out_k) / (fin_k * 0.45), 0.0, 1.0))
			draw_texture_rect_region(bt,
				Rect2(dest_x, dest_y, bw2, bh2),
				Rect2(bfr * bfw, 0, src_w, bt.get_height()), btint)
		elif queen_rising and tex_mb:
			# estilo "Storm Eagle": sube aleteando a un punto al azar y flota ahi
			var rise_k: float = clampf(1.0 - atk_warn / 130.0, 0.0, 1.0)
			var rk2: float = clampf(rise_k / 0.55, 0.0, 1.0)
			var anchor := Vector2(W - 12.0, 88.0)  # centro aprox. del cuerpo anclado
			var qpos: Vector2 = anchor.lerp(dive_start, rk2)
			qpos.y += sin(t * 0.3) * 2.0
			var qnf := int(MBOSS[1]["nf"])
			var qfw := tex_mb.get_width() / float(qnf)
			var qdh := 104.0 + sin(t * 0.05) * 4.0  # mismo porte que el cuerpo anclado
			var qdw := qdh * qfw / tex_mb.get_height()
			var qsz := _fit_boss(qdh, qdw)
			qdh = qsz.y
			qdw = qsz.x
			# el despegue siempre va del ancla (derecha) hacia dive_start (mas
			# a la izquierda), asi que hay que voltear el sprite (mira a la
			# derecha de forma nativa) para que quede mirando hacia donde va
			draw_texture_rect_region(tex_mb,
				Rect2(qpos.x - qdw / 2, qpos.y - qdh / 2, qdw, qdh),
				Rect2((int(t / 5.0) % qnf) * qfw, 0, -qfw, tex_mb.get_height()))
		elif mono_rising and tex_mono_rise:
			# se agacha y salta bien alto, en su sitio (sin vuelo diagonal)
			var rise_k2: float = clampf(1.0 - atk_warn / 100.0, 0.0, 1.0)
			var mfr2 := 1 if rise_k2 > 0.4 else 0
			var mfw2 := tex_mono_rise.get_width() / 2.0
			var mdh2 := 104.0 + sin(t * 0.05) * 4.0  # mismo porte que el cuerpo anclado
			var mdw2 := mdh2 * mfw2 / tex_mono_rise.get_height()
			var msz := _fit_boss(mdh2, mdw2)
			mdh2 = msz.y
			mdw2 = msz.x
			var hop := sin(clampf(rise_k2, 0.0, 1.0) * PI) * 20.0
			var anchor_x := W - 6.0 - mdw2 * (BOSS_ANCHOR - 0.5)
			draw_texture_rect_region(tex_mono_rise,
				Rect2(anchor_x - mdw2 / 2, WATER + 16 - mdh2 - hop, mdw2, mdh2),
				Rect2(mfr2 * mfw2, 0, -mfw2, tex_mono_rise.get_height()))
		elif tex_wave and not queen_hidden and not mono_hidden:
			var mh := 96.0 + sin(t * 0.05) * 5
			var mw2 := mh * tex_wave.get_width() / float(tex_wave.get_height())
			draw_texture_rect(tex_wave, Rect2(-30, WATER + 16 - mh, mw2, mh), false,
				Color(0.5, 0.55, 0.75))
	# proyectiles del jefe: embestidas, vuelos rasantes y olas viajeras
	var pj_final := Global.cur == Global.NS - 1 or Global.infinite
	for b in batks:
		var bx: float = b["x"]
		if b["t"] == "dive":
			# la reina pica en linea recta desde el punto de despegue
			var by: float = b["y"]
			var dang: float = atan2(b["y1"] - b["y0"], b["x1"] - b["x0"])
			var going_right: bool = b["x1"] > b["x0"]
			# el sprite base mira a la DERECHA (pico a la derecha, ala hacia
			# atras a la izquierda); si no se voltea hay que restar 180° o
			# queda mirando para atras
			var rot: float = dang if going_right else dang - PI
			draw_set_transform(Vector2(int(bx) * 4, int(by) * 4) + _shk, rot, Vector2(4, 4))
			if tex_mb:
				var dnf := int(MBOSS[1]["nf"])
				var dfw := tex_mb.get_width() / float(dnf)
				var ddh := 104.0 + sin(t * 0.05) * 4.0  # mismo porte que el cuerpo anclado
				var ddw := ddh * dfw / tex_mb.get_height()
				var dsz := _fit_boss(ddh, ddw)
				ddh = dsz.y
				ddw = dsz.x
				draw_texture_rect_region(tex_mb, Rect2(-ddw / 2, -ddh / 2, ddw, ddh),
					Rect2((int(t / 5.0) % dnf) * dfw, 0, dfw if going_right else -dfw, tex_mb.get_height()))
			else:
				draw_circle(Vector2.ZERO, 8, Color("e0e0e0"))
			_set_cam()
			if by > WATER - 20.0 and int(t) % 3 == 0:
				_splash(bx, WATER, 1.0)
			continue
		if b["t"] == "bird":
			if tex_bird:
				_draw_sprite(tex_bird, 2, int(t / 8.0) % 2, Vector2(bx, b["y"]), 13.0, b["vx"] < 0)
			else:
				draw_circle(Vector2(bx, b["y"]), 5, Color("cfd8dc"))
			continue
		if b["t"] == "feather":
			var fang := atan2(b["vy"], b["vx"])
			draw_set_transform(Vector2(int(bx) * 4, int(b["y"]) * 4) + _shk, fang, Vector2(4, 4))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-7, -1.5), Vector2(6, 0), Vector2(-7, 1.5)
			]), Color("eaf6ff"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-7, -1.5), Vector2(-2, 0), Vector2(-7, 1.5)
			]), Color("8ecae6"))
			_set_cam()
			continue
		if b["t"] == "monkeysurf":
			# monito surfista de la tropa: anclado por abajo para que su
			# tabla quede pegada a la linea de agua real, no flotando
			if tex_mono_surf:
				var mdh := 22.0
				var mdw := mdh * tex_mono_surf.get_width() / float(tex_mono_surf.get_height())
				draw_texture_rect_region(tex_mono_surf,
					Rect2(bx - mdw / 2, b["y"] - mdh, mdw, mdh),
					Rect2(0, 0, -tex_mono_surf.get_width(), tex_mono_surf.get_height()))
			else:
				draw_circle(Vector2(bx, b["y"] - 6), 5, Color("8d6748"))
			continue
		if b["t"] == "salto":
			# salto sagrado: sombra que apunta, caida recta y chapuzon
			var by2: float = b["y"]
			if b["ph"] < SALTO_FALL:
				if tex_mono_shadow:
					var shk: float = clampf(b["ph"] / SALTO_FALL, 0.0, 1.0)
					var shh := 5.0 + shk * 4.0
					var shw := shh * tex_mono_shadow.get_width() / float(tex_mono_shadow.get_height())
					draw_texture_rect(tex_mono_shadow,
						Rect2(b["tx"] - shw / 2, WATER - shh / 2, shw, shh), false,
						Color(1, 1, 1, 0.5 + shk * 0.4))
				if tex_mono_fall:
					var ffr := int(t / 5.0) % 2
					var ffw := tex_mono_fall.get_width() / 2.0
					var fdh := 104.0 + sin(t * 0.05) * 4.0  # mismo porte que el cuerpo anclado
					var fdw := fdh * ffw / tex_mono_fall.get_height()
					var fsz := _fit_boss(fdh, fdw)
					fdh = fsz.y
					fdw = fsz.x
					draw_texture_rect_region(tex_mono_fall,
						Rect2(bx - fdw / 2, by2 - fdh, fdw, fdh),
						Rect2(ffr * ffw, 0, ffw, tex_mono_fall.get_height()))
				else:
					draw_circle(Vector2(bx, by2), 8, Color("8d6748"))
			else:
				var bk: float = 1.0 - clampf((b["ph"] - SALTO_FALL) / SALTO_BURST, 0.0, 1.0)
				if tex_mono_splash:
					var sdh := 30.0 * bk
					var sdw := sdh * tex_mono_splash.get_width() / float(tex_mono_splash.get_height())
					draw_texture_rect(tex_mono_splash,
						Rect2(bx - sdw / 2, WATER + 6 - sdh, sdw, sdh), false)
				else:
					draw_rect(Rect2(bx - 3, WATER - 6 - 30.0 * bk, 6, 30.0 * bk), Color(0.8, 0.95, 1.0, 0.8))
				if int(t) % 2 == 0:
					_splash(bx, WATER, 1.4)
			continue
		if b["t"] == "tentaculo":
			# EL PULPO: burbujas de aviso, despues barre con el sprite
			# propio del tentaculo (o una silueta si todavia no esta)
			if b["ph"] < 0.0:
				var tbk: float = 1.0 - clampf(-b["ph"] / TENT_WARN, 0.0, 1.0)
				draw_circle(Vector2(bx, WATER - 2 - tbk * 6.0), 2.0 + tbk * 2.0, Color(0.55, 0.3, 0.65, 0.6))
			else:
				if tex_atk_low:
					var tlfw := tex_atk_low.get_width() / 3.0
					var tldh := 22.0
					var tldw := tldh * tlfw / tex_atk_low.get_height()
					draw_texture_rect_region(tex_atk_low,
						Rect2(bx - tldw / 2, WATER + 4 - tldh, tldw, tldh),
						Rect2((int(t / 5.0) % 3) * tlfw, 0, tlfw, tex_atk_low.get_height()))
				else:
					draw_colored_polygon(PackedVector2Array([
						Vector2(bx - 8, WATER + 4), Vector2(bx - 3, WATER - 20),
						Vector2(bx + 3, WATER - 20), Vector2(bx + 8, WATER + 4)
					]), Color("6a4c93"))
				if int(t) % 3 == 0:
					_splash(bx, WATER, 1.0)
			continue
		if b["t"] == "tubocierra":
			# EL ESPIRITU DEL TUBO: capsula translucida que viaja tranquila
			# y se pone blanca/roja y crece cuando esta por cerrarse
			var tuclose: bool = b["closing"]
			var tuh: float = 10.0 if not tuclose else 10.0 + clampf(b["ph"] / TUBO_CLOSE_T, 0.0, 1.0) * 11.0
			var tucol := Color(0.75, 0.95, 1.0, 0.55) if not tuclose else Color(1.0, 0.9, 0.85, 0.8)
			draw_rect(Rect2(bx - 13, WATER - tuh, 26, tuh), tucol)
			draw_circle(Vector2(bx - 13, WATER - tuh * 0.5), tuh * 0.5, tucol)
			draw_circle(Vector2(bx + 13, WATER - tuh * 0.5), tuh * 0.5, tucol)
			if tuclose and int(t) % 2 == 0:
				_splash(bx, WATER, 1.2)
			continue
		if b["t"] == "anillo":
			# EL ESPIRITU DEL TUBO: anillo de espuma rodando (parry-able)
			if tex_atk_low:
				var rfw := tex_atk_low.get_width() / 3.0
				var rdh := 16.0
				var rdw := rdh * rfw / tex_atk_low.get_height()
				draw_texture_rect_region(tex_atk_low,
					Rect2(bx - rdw / 2, WATER + 4 - rdh, rdw, rdh),
					Rect2((int(t / 4.0) % 3) * rfw, 0, rfw, tex_atk_low.get_height()))
			else:
				draw_arc(Vector2(bx, WATER - 5), 7.0, 0, TAU, 16, Color("d8f3ff"), 2.5)
			if int(t) % 3 == 0:
				_splash(bx, WATER - 2, 0.9)
			continue
		if b["t"] == "grieta":
			# EL DIABLO DE LAVA: prende en el sitio (no viaja) y se apaga
			if b["ph"] < GRIETA_WARN:
				var gbk: float = clampf(b["ph"] / GRIETA_WARN, 0.0, 1.0)
				draw_circle(Vector2(bx, WATER + 1), 3.0 + gbk * 3.0, Color(1.0, 0.4, 0.1, 0.15 + gbk * 0.3))
			else:
				var gk2: float = clampf((b["ph"] - GRIETA_WARN) / GRIETA_ACTIVE, 0.0, 1.0)
				var gcol: Color = Color(1.0, 0.85, 0.3).lerp(Color(0.55, 0.08, 0.05), gk2)
				draw_colored_polygon(PackedVector2Array([
					Vector2(bx - 9, WATER + 3), Vector2(bx - 3, WATER - 3),
					Vector2(bx + 2, WATER + 1), Vector2(bx + 9, WATER - 4),
					Vector2(bx + 9, WATER + 5), Vector2(bx - 9, WATER + 5)
				]), gcol)
				draw_circle(Vector2(bx, WATER), 3.0, Color(1.0, 0.9, 0.5, 0.7 * (1.0 - gk2)))
			continue
		if b["t"] == "megasalto":
			# EL MEGALODON: salto mortal, sombra + silueta cayendo + impacto
			var mgby: float = b["y"]
			if b["ph"] < MEGASALTO_FALL:
				var mgsk: float = clampf(b["ph"] / MEGASALTO_FALL, 0.0, 1.0)
				var mgsh := 5.0 + mgsk * 5.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(b["tx"] - mgsh * 1.6, WATER), Vector2(b["tx"] + mgsh * 1.6, WATER),
					Vector2(b["tx"] + mgsh, WATER + 2), Vector2(b["tx"] - mgsh, WATER + 2)
				]), Color(0, 0, 0, 0.25 + mgsk * 0.25))
				draw_colored_polygon(PackedVector2Array([
					Vector2(bx - 9, mgby + 6), Vector2(bx, mgby - 10),
					Vector2(bx + 9, mgby + 6), Vector2(bx, mgby + 10)
				]), Color("3a5a78"))
				draw_colored_polygon(PackedVector2Array([
					Vector2(bx - 2, mgby - 8), Vector2(bx + 2, mgby - 8), Vector2(bx, mgby - 16)
				]), Color("2b4560"))
			else:
				var mgbk: float = 1.0 - clampf((b["ph"] - MEGASALTO_FALL) / MEGASALTO_BURST, 0.0, 1.0)
				draw_circle(Vector2(bx, WATER), 4.0 + 22.0 * (1.0 - mgbk), Color(0.85, 0.95, 1.0, 0.5 * mgbk))
				if int(t) % 2 == 0:
					_splash(bx, WATER, 1.6)
			continue
		if b["t"] == "lobosalta":
			# EL LOBO ALFA: se para en la roca (aviso) y despues embiste
			if b["vx"] == 0.0:
				var lbk: float = clampf((b["ph"] + LOBO_WARN) / LOBO_WARN, 0.0, 1.0)
				if tex_lobo:
					_draw_sprite(tex_lobo, 2, int(t / 8.0) % 2, Vector2(bx, WATER + 6), 20.0 * lbk)
				else:
					draw_circle(Vector2(bx, WATER), 6.0 * lbk, Color("6d4c41"))
			else:
				if tex_lobo:
					_draw_sprite(tex_lobo, 2, int(t / 6.0) % 2, Vector2(bx, WATER + 4), 18.0, true)
				else:
					draw_circle(Vector2(bx, WATER - 4), 7, Color("6d4c41"))
				if int(t) % 3 == 0:
					_splash(bx, WATER - 2, 1.1)
			continue
		if b["t"] == "tornado":
			# EL GENIO DE LAS DUNAS: remolino de arena girando (acelera)
			var trot := t * 0.5
			for k2 in range(3):
				var tk: float = k2 / 3.0
				var tang: float = trot + tk * TAU
				var trad: float = 3.0 + tk * 6.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(bx + cos(tang) * trad, WATER + 2 - tk * 3.0),
					Vector2(bx + cos(tang + 0.9) * (trad + 3.0), WATER + 2 - tk * 3.0 - 4.0),
					Vector2(bx + cos(tang - 0.9) * (trad + 3.0), WATER + 2 - tk * 3.0 - 4.0)
				]), Color(0.85, 0.7, 0.35, 0.55))
			draw_colored_polygon(PackedVector2Array([
				Vector2(bx - 9, WATER + 3), Vector2(bx - 3, WATER - 16),
				Vector2(bx + 3, WATER - 16), Vector2(bx + 9, WATER + 3)
			]), Color(0.82, 0.65, 0.3, 0.5))
			continue
		if b["t"] == "erupt":
			# emerge desde ABAJO en un punto fijo: aviso (remolino cerrandose
			# sobre el punto exacto) -> revienta con la forma segun el jefe
			var ewarn: float = float(b["warn"])
			var eactive: float = float(b["active"])
			var ekind: String = b["kind"]
			if b["ph"] < ewarn:
				var ebk: float = clampf(b["ph"] / ewarn, 0.0, 1.0)
				draw_arc(Vector2(bx, WATER), 14.0 * (1.0 - ebk) + 4.0, 0, TAU, 20,
					Color(1.0, 0.35, 0.2, 0.3 + ebk * 0.4), 2.0)
				draw_circle(Vector2(bx, WATER), 2.5, Color(0, 0, 0, 0.3))
			else:
				var eak: float = 1.0 - clampf((b["ph"] - ewarn) / eactive, 0.0, 1.0)
				if ekind == "shark":
					draw_colored_polygon(PackedVector2Array([
						Vector2(bx - 11, WATER + 6), Vector2(bx - 9, WATER - 18.0 * eak),
						Vector2(bx, WATER - 24.0 * eak), Vector2(bx + 9, WATER - 18.0 * eak),
						Vector2(bx + 11, WATER + 6)
					]), Color("3a5a78"))
					draw_colored_polygon(PackedVector2Array([
						Vector2(bx - 6, WATER - 3.0 * eak), Vector2(bx, WATER - 13.0 * eak),
						Vector2(bx + 6, WATER - 3.0 * eak)
					]), Color(0.95, 0.97, 1.0, 0.9))
				elif ekind == "geyser":
					if tex_geiser_big:
						var gdh2 := 8.0 + 26.0 * eak
						var gdw2 := gdh2 * tex_geiser_big.get_width() / float(tex_geiser_big.get_height())
						draw_texture_rect(tex_geiser_big,
							Rect2(bx - gdw2 / 2, WATER + 4 - gdh2, gdw2, gdh2), false)
					else:
						draw_rect(Rect2(bx - 4, WATER - 4 - 26.0 * eak, 8, 26.0 * eak),
							Color(0.85, 0.95, 1.0, 0.8))
				else:  # "tentaculo"
					draw_colored_polygon(PackedVector2Array([
						Vector2(bx - 7, WATER + 6), Vector2(bx - 4, WATER - 22.0 * eak),
						Vector2(bx + 4, WATER - 22.0 * eak), Vector2(bx + 7, WATER + 6)
					]), Color("6a4c93"))
				if int(t) % 2 == 0:
					_splash(bx, WATER, 1.3)
			continue
		if b["t"] == "decoy":
			# EL ESPIRITU DEL TUBO: siluetas fantasma; la real se ve solida,
			# las falsas titilan mas transparentes (hay que leerlas, no
			# reaccionar a tiempo)
			var da: float = 1.0 if b["real"] else 0.4 + sin(t * 0.5) * 0.15
			draw_rect(Rect2(bx - 12, WATER - 9, 24, 9), Color(0.78, 0.95, 1.0, 0.55 * da))
			draw_circle(Vector2(bx - 12, WATER - 4.5), 4.5, Color(0.78, 0.95, 1.0, 0.55 * da))
			draw_circle(Vector2(bx + 12, WATER - 4.5), 4.5, Color(0.78, 0.95, 1.0, 0.55 * da))
			continue
		if b["t"] == "roll":
			# rodillo de coral: bola rodando desde la derecha
			if tex_cb_ball:
				var oh := 22.0
				var ow := oh * tex_cb_ball.get_width() / float(tex_cb_ball.get_height())
				draw_texture_rect(tex_cb_ball, Rect2(bx - ow / 2, WATER + 6 - oh, ow, oh), false)
			else:
				draw_circle(Vector2(bx, WATER - 4), 8, Color("c9184a"))
			if int(t) % 3 == 0:
				_splash(bx, WATER - 2, 1.0)
			continue
		if b["t"] == "spike":
			# puas del arrecife: burbujas de aviso, luego la pua emerge
			if b["ph"] < SPIKE_WARN:
				var bk: float = clampf(b["ph"] / SPIKE_WARN, 0.0, 1.0)
				if tex_cb_bub:
					var buh := 8.0 + bk * 8.0
					var buw := buh * tex_cb_bub.get_width() / float(tex_cb_bub.get_height())
					draw_texture_rect(tex_cb_bub,
						Rect2(bx - buw / 2, WATER - 4 - buh, buw, buh), false,
						Color(1, 1, 1, 0.5 + bk * 0.5))
				else:
					draw_circle(Vector2(bx, WATER - 4 - bk * 8), 2.0 + bk * 2.0, Color(0.7, 0.9, 1.0, 0.7))
			else:
				if tex_cb_spike:
					var sph := 20.0
					var spw := sph * tex_cb_spike.get_width() / float(tex_cb_spike.get_height())
					draw_texture_rect(tex_cb_spike, Rect2(bx - spw / 2, WATER + 2 - sph, spw, sph), false)
				else:
					draw_colored_polygon(PackedVector2Array([
						Vector2(bx - 6, WATER + 2), Vector2(bx, WATER - 18), Vector2(bx + 6, WATER + 2)
					]), Color("e07a9b"))
				if int(t) % 4 == 0:
					_splash(bx, WATER, 0.8)
			continue
		if b["t"] == "meteor":
			# meteoro de coral que cae del cielo y estalla en un geiser
			var tier: int = b.get("tier", 0)
			if b["ph"] < 0.0:
				# aviso: puas de coral asomando antes de que caiga el meteoro
				var sk: float = 1.0 - clampf(-b["ph"] / 40.0, 0.0, 1.0)
				if tex_geiser_warn:
					var wdh: float = 7.0 + sk * 7.0
					var wdw: float = wdh * tex_geiser_warn.get_width() / float(tex_geiser_warn.get_height())
					draw_texture_rect(tex_geiser_warn,
						Rect2(bx - wdw / 2, WATER + 4 - wdh, wdw, wdh), false,
						Color(1, 1, 1, 0.5 + sk * 0.5))
				else:
					draw_circle(Vector2(bx, WATER + 2), 5.0 + sk * 3.0, Color(0, 0, 0, 0.25))
			elif b["ph"] < MET_FALL:
				draw_circle(Vector2(bx, WATER + 2), 4, Color(0, 0, 0, 0.3))
				if tex_rock_c:
					_draw_sprite(tex_rock_c, 2, int(t / 4.0) % 2, Vector2(bx, b["fy"]), 14.0)
				else:
					draw_circle(Vector2(bx, b["fy"]), 6, Color("ff7b54"))
			else:
				# geiser al impactar: crece y se apaga (chico/grande/triple)
				var gk: float = 1.0 - clampf((b["ph"] - MET_FALL) / MET_BURST, 0.0, 1.0)
				var gt: Texture2D = tex_geiser_small
				if tier == 1: gt = tex_geiser_big
				elif tier == 2: gt = tex_geiser_triple
				if gt:
					var gdh: float = (26.0 if tier == 2 else (28.0 if tier == 1 else 20.0)) * gk
					var gdw: float = gdh * gt.get_width() / float(gt.get_height())
					draw_texture_rect(gt, Rect2(bx - gdw / 2, WATER + 4 - gdh, gdw, gdh), false)
				else:
					draw_rect(Rect2(bx - 3, WATER - 6 - 30.0 * gk, 6, 30.0 * gk), Color(0.8, 0.95, 1.0, 0.8))
				if int(t) % 2 == 0:
					_splash(bx, WATER, 1.4)
					if tier == 2:
						_splash(bx - 14, WATER, 1.2)
						_splash(bx + 14, WATER, 1.2)
			continue
		if b["t"] == "bounce":
			# coco/roca en arco; el Megalodon salta el mismo
			if tex_atk_bounce:
				var qfw := tex_atk_bounce.get_width() / 2.0
				var qdh := 14.0
				var qdw := qdh * qfw / tex_atk_bounce.get_height()
				draw_texture_rect_region(tex_atk_bounce,
					Rect2(bx - qdw / 2, b["fy"] - qdh / 2, qdw, qdh),
					Rect2((int(t / 7.0) % 2) * qfw, 0, qfw, tex_atk_bounce.get_height()))
				if b["fy"] > WATER - 14 and int(t) % 3 == 0:
					_splash(bx, WATER - 2, 1.2)
				continue
			if Global.cur == 7 and tex_mb:
				var mfw := tex_mb.get_width() / 3.0
				var mdh := 22.0
				var mdw := mdh * mfw / tex_mb.get_height()
				draw_texture_rect_region(tex_mb,
					Rect2(bx - mdw / 2, b["fy"] - mdh / 2, mdw, mdh),
					Rect2(0, 0, -mfw if b["vx"] < 0 else mfw, tex_mb.get_height()))
			elif Global.cur == 2 and tex_mono_coco:
				_draw_sprite(tex_mono_coco, 1, 0, Vector2(bx, b["fy"] + 8), 12.0)
			elif tex_rock:
				_draw_sprite(tex_rock, 2, 0, Vector2(bx, b["fy"] + 8), 12.0)
			else:
				draw_circle(Vector2(bx, b["fy"]), 6, Color("7f5539"))
			if b["fy"] > WATER - 14 and int(t) % 3 == 0:
				_splash(bx, WATER - 2, 1.2)
			continue
		if b["t"] == "ink":
			if tex_atk_ink:
				var kfw := tex_atk_ink.get_width() / 3.0
				var kdh := 22.0
				var kdw := kdh * kfw / tex_atk_ink.get_height()
				draw_texture_rect_region(tex_atk_ink,
					Rect2(bx - kdw / 2, WATER - 33 - kdh / 2, kdw, kdh),
					Rect2((int(t / 6.0) % 3) * kfw, 0, kfw, tex_atk_ink.get_height()))
				continue
			# nube de tinta del pulpo
			draw_circle(Vector2(bx, WATER - 33), 8, Color(0.25, 0.1, 0.3, 0.9))
			draw_circle(Vector2(bx - 7, WATER - 30), 5, Color(0.2, 0.08, 0.25, 0.8))
			draw_circle(Vector2(bx + 6, WATER - 37), 5, Color(0.3, 0.12, 0.35, 0.8))
			continue
		if b["t"] == "emb" and not pj_final:
			# proyectil de mini-jefe. Si el jefe tiene lamina propia se usa
			# esa; si no, la ola generica de siempre.
			if tex_atk_low:
				var lw := 20.0 * (tex_atk_low.get_width() / 3.0) / tex_atk_low.get_height()
				draw_texture_rect_region(tex_atk_low,
					Rect2(bx - lw / 2, WATER + 4 - 20.0, lw, 20.0),
					Rect2((int(t / 6.0) % 3) * (tex_atk_low.get_width() / 3.0), 0,
						-tex_atk_low.get_width() / 3.0 if b["vx"] < 0 else tex_atk_low.get_width() / 3.0,
						tex_atk_low.get_height()))
				if int(t) % 3 == 0:
					_splash(bx + (10 if b["vx"] < 0 else -10), WATER - 2, 1.0)
				continue
			if Global.cur == 7 and tex_sharkfin:
				_draw_sprite(tex_sharkfin, 4, 2, Vector2(bx, WATER + 4), 13.0, true)
			elif tex_ola1:
				var wfw := float(tex_ola1.get_width())
				var wdh := 18.0
				var wdw := wdh * wfw / tex_ola1.get_height()
				draw_texture_rect_region(tex_ola1, Rect2(bx - wdw / 2, WATER + 4 - wdh, wdw, wdh),
					Rect2(0, 0, -wfw if b["vx"] < 0 else wfw, tex_ola1.get_height()))
			else:
				draw_rect(Rect2(bx - 14, WATER - 12, 28, 16), Color(0.9, 0.95, 1.0, 0.9))
			if int(t) % 3 == 0:
				_splash(bx + (10 if b["vx"] < 0 else -10), WATER - 2, 1.0)
			continue
		if b["t"] == "ras" and not pj_final and tex_atk_high:
			# lamina propia del ataque alto (antes se dibujaba el cuerpo del
			# jefe encogido, que quedaba raro y no se leia como proyectil)
			var hfw := tex_atk_high.get_width() / 3.0
			var hdh := 18.0
			var hdw := hdh * hfw / tex_atk_high.get_height()
			draw_texture_rect_region(tex_atk_high,
				Rect2(bx - hdw / 2, WATER - 26 - hdh, hdw, hdh),
				Rect2((int(t / 6.0) % 3) * hfw, 0, -hfw if b["vx"] < 0 else hfw,
					tex_atk_high.get_height()))
			continue
		if b["t"] == "ras" and not pj_final and tex_mb:
			# el mini-jefe (o su ataque) cruza volando bajo
			var rnf := int(MBOSS[Global.cur]["nf"])
			var rfw2 := tex_mb.get_width() / float(rnf)
			var rdh2 := 16.0
			var rdw2 := rdh2 * rfw2 / tex_mb.get_height()
			draw_texture_rect_region(tex_mb,
				Rect2(bx - rdw2 / 2, WATER - 26 - rdh2, rdw2, rdh2),
				Rect2((int(t / 7.0) % rnf) * rfw2, 0, -rfw2 if b["vx"] < 0 else rfw2, tex_mb.get_height()))
			continue
		if b["t"] == "emb":
			# la cara de la ola deslizandose (derrapado)
			var et: Texture2D = tex_low2 if tex_low2 else tex_boss_low
			if et:
				var enf := 2 if et == tex_low2 else 3
				var efr := int(t / 7.0) % enf
				var efw := et.get_width() / float(enf)
				var edh := 24.0
				var edw := edh * efw / et.get_height()
				draw_texture_rect_region(et, Rect2(bx - edw / 2, WATER + 5 - edh, edw, edh),
					Rect2(efr * efw, 0, efw, et.get_height()))
			else:
				draw_rect(Rect2(bx - 16, WATER - 12, 32, 16), Color(0.9, 0.95, 1.0, 0.9))
			if int(t) % 3 == 0:
				_splash(bx - 12, WATER - 2, 1.0)
		elif b["t"] == "ras":
			# trozo de ola volando a media altura
			if tex_boss_high:
				var rfr := int(t / 6.0) % 3
				var rfw := tex_boss_high.get_width() / 3.0
				var rdh := 20.0
				var rdw := rdh * rfw / tex_boss_high.get_height()
				draw_texture_rect_region(tex_boss_high,
					Rect2(bx - rdw / 2, WATER - 25 - rdh, rdw, rdh),
					Rect2(rfr * rfw, 0, rfw, tex_boss_high.get_height()))
			else:
				draw_rect(Rect2(bx - 16, WATER - 44, 32, 18), Color(0.3, 0.45, 0.65, 0.9))
		elif b["t"] == "ola":
			# ola gigante viajera (volteada segun su direccion de viaje)
			var ot2: Texture2D = tex_boss_doble if tex_boss_doble else tex_wave
			if ot2:
				var onf := 3 if ot2 == tex_boss_doble else 1
				var ofr := 1 if onf == 3 else 0
				var ofw := ot2.get_width() / float(onf)
				var odh := 27.0
				var odw := odh * ofw / ot2.get_height()
				# si viaja hacia la izquierda, el sprite se voltea
				var osrc := Rect2(ofr * ofw, 0, -ofw if b["vx"] < 0 else ofw, ot2.get_height())
				draw_texture_rect_region(ot2, Rect2(bx - odw / 2, WATER + 4 - odh, odw, odh), osrc)
			else:
				draw_rect(Rect2(bx - 14, WATER - 18, 28, 22), Color(0.2, 0.5, 0.8, 0.9))
			if int(t) % 3 == 0:
				_splash(bx + (10 if b["vx"] < 0 else -10), WATER - 2, 1.0)
	# aviso "!" sobre el surfista durante el telegraph (mas intenso en fase 2)
	if boss and atk_warn > 0 and tex_warn:
		var wt := tex_warn2 if (boss_p2 and tex_warn2) else tex_warn
		# se sube un poco: a la altura anterior chocaba con la banda del aviso
		var wy2: float = minf(water_y(px) - 40 + y_off, WATER - 40)
		_draw_sprite(wt, 3, int(t / 7.0) % 3, Vector2(px, wy2), 18.0)

	# --- mini-encuentro: el rival asomado por la derecha ---
	if enc_tipo != "" and ENC_TIPOS.has(enc_tipo):
		var ed: Dictionary = ENC_TIPOS[enc_tipo]
		var etx: Texture2D = null
		match String(ed["spr"]):
			"rival": etx = tex_rival
			"lobo":  etx = tex_lobo
			"bird":  etx = tex_bird
			"shark": etx = tex_sharkfull
		if etx:
			var enf := int(ed["nf"])
			var edh: float = float(ed["dh"])
			var efw := etx.get_width() / float(enf)
			var edw := edh * efw / etx.get_height()
			# se acerca al aparecer y se aleja al irse
			var ek: float = 1.0 if enc_out <= 0.0 else (enc_out / 110.0)
			var ex := W - 16.0 - edw / 2 + (1.0 - ek) * 70.0
			var ey := WATER + 4 - edh + sin(t * 0.07) * 2.0
			if String(ed["spr"]) == "bird":
				ey = WATER - 52.0 + sin(t * 0.09) * 4.0
			draw_texture_rect_region(etx,
				Rect2(ex - edw / 2, ey, edw, edh),
				Rect2((int(t / 8.0) % enf) * efw, 0, -efw, etx.get_height()),
				Color(1, 1, 1, clampf(ek, 0.0, 1.0)))
			# aviso de la formacion que viene
			if enc_aviso > 0.0 and int(t / 8) % 2 == 0:
				var eh: String = String((ed["txt"] as Array)[mini(enc_fase, 2)])
				var ehw: float = font.get_string_size(eh, HORIZONTAL_ALIGNMENT_LEFT,
					-1, 11 * 4).x / 4.0 + 8.0
				draw_rect(Rect2(W / 2 - ehw / 2, 88, ehw, 13), Color(0, 0, 0, 0.5))
				txt(eh, W / 2, 98, 11, Color("ff8f5e"), true)

	# obstaculos
	var coral: bool = st["sp"].has("coral")
	for o in obs:
		if o["hit"] and not o["c"]:
			continue
		var oy := _obs_y(o)
		var ox: float = o["x"]
		_draw_obstacle(o, ox, oy, coral)

	# tubo por encima
	if tube_on > 0 and tex_wave:
		# el tubo es la misma ola del sprite, gigante y envolviendo al surfista
		# entra y sale con fundido: antes aparecia de golpe al 85%
		var alpha: float = minf(1.0, tube_on / 40.0) * minf(1.0, (260.0 - tube_on) / 25.0) * 0.85
		var hg2 := 82.0 + sin(t * 0.06) * 3
		var wd2 := hg2 * tex_wave.get_width() / float(tex_wave.get_height())
		draw_texture_rect(tex_wave, Rect2(px - wd2 * 0.55, WATER + 12 - hg2, wd2, hg2),
			false, Color(1, 1, 1, alpha))

	# SOMBRA en el agua: mientras estas en el aire marca DONDE vas a caer.
	# Sin ella hay que adivinar la altura, y con obstaculos pisables eso
	# importa mucho. Se encoge y se aclara cuanto mas alto estas.
	if air and (state == "play" or state == "pause") and phase == "surf":
		var alt_k: float = clampf(-y_off / 55.0, 0.0, 1.0)
		var sw: float = 15.0 * (1.0 - alt_k * 0.55)
		var sh2: float = 4.0 * (1.0 - alt_k * 0.55)
		var sa: float = 0.30 * (1.0 - alt_k * 0.6)
		if tex_mono_shadow:
			draw_texture_rect(tex_mono_shadow,
				Rect2(px - sw / 2, water_y(px) + 1 - sh2 / 2, sw, sh2), false,
				Color(1, 1, 1, sa * 2.2))
		else:
			draw_colored_polygon(PackedVector2Array([
				Vector2(px - sw / 2, water_y(px) + 1),
				Vector2(px, water_y(px) + 1 - sh2 / 2),
				Vector2(px + sw / 2, water_y(px) + 1),
				Vector2(px, water_y(px) + 1 + sh2 / 2),
			]), Color(0.05, 0.15, 0.25, sa))

	# surfista (o caida / naufrago segun el estado)
	var py := water_y(px) - 10 + y_off
	if state == "dying":
		if tex_fall and die_t > 14:
			var fr := clampi(int((55.0 - die_t) / 11.0), 0, 3)
			_draw_sprite(tex_fall, 4, fr, Vector2(px, py + 8), 30.0)
		elif tex_splash:
			_draw_sprite(tex_splash, 1, 0, Vector2(px, water_y(px) + 4), 18.0)
		else:
			_draw_surfer(Vector2(px, py), PI / 2)
	elif state == "over":
		# naufrago: solo la tabla flotando entre la espuma
		var bob := sin(t * 0.08) * 1.5
		if tex_board:
			_draw_sprite(tex_board, 1, 0,
				Vector2(px + 4, water_y(px + 4) + 5 + bob), 10.0)
		draw_rect(Rect2(px - 8, water_y(px) + bob, 7, 2), Color("eaf6ff"))
		draw_rect(Rect2(px + 12, water_y(px + 12) - bob, 5, 2), Color("eaf6ff"))
	elif state == "clear" or state == "champion" or inv <= 0 or int(t / 4) % 2 == 0:
		_draw_surfer(Vector2(px, py), ang)
	# burbuja del escudo (centrada en el cuerpo del surfista)
	if shield and (state == "play" or state == "pause"):
		var bc := Vector2(px, water_y(px) - 16 + y_off)
		draw_circle(bc, 16, Color(0.45, 0.85, 1.0, 0.14))
		draw_arc(bc, 16, 0, TAU, 24, Color(0.7, 0.95, 1.0, 0.5), 1.0)

	# particulas
	for p in parts:
		draw_rect(Rect2(int(p["x"]), int(p["y"]), 2, 2), Color("eaf6ff"))
	# puntos flotantes de los trucos
	for p in pops:
		var alpha: float = clampf(p["life"] / 45.0, 0.0, 1.0)
		txt(p["txt"], p["x"], p["y"], 9, Color(1.0, 0.84, 0.4, alpha), true)
	# tinta del pulpo: pantalla casi negra que se disipa
	if ink_t > 0:
		draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.02, 0.08, minf(0.85, ink_t / 50.0)))

	_draw_hud(st)
	match state:
		"pause": _draw_pause()
		"over": _draw_over()
		"clear": _draw_clear()
		"champion": _draw_champion()
		"initials": _draw_initials()
		"ranking": _draw_ranking()

func _draw_obstacle(o: Dictionary, ox: float, oy: float, coral: bool) -> void:
	var xI := int(ox)
	var yI := int(oy)
	# power-ups
	var ot: String = o["type"]
	if ot.begins_with("pw_"):
		var pt: Texture2D = tex_pw.get(ot)
		if pt:
			_draw_sprite(pt, 1, 0, Vector2(xI, yI + 8), 15.0)
			return
		if ot == "pw_shield":
			draw_circle(Vector2(xI, yI), 6, Color(0.45, 0.85, 1.0, 0.3))
			draw_arc(Vector2(xI, yI), 6, 0, TAU, 14, Color("eaf6ff"), 1.0)
			draw_rect(Rect2(xI - 3, yI - 3, 2, 2), Color.WHITE)
		elif ot == "pw_x2":
			draw_rect(Rect2(xI - 7, yI - 6, 14, 12), Color("ffd166"))
			draw_rect(Rect2(xI - 7, yI - 6, 14, 12), Color("e36414"), false, 1.0)
			txt("x2", xI + 1, yI + 4, 9, Color("7f2d00"), true)
		elif ot == "pw_magnet":
			draw_rect(Rect2(xI - 5, yI - 5, 4, 8), Color("e63946"))
			draw_rect(Rect2(xI + 1, yI - 5, 4, 8), Color("2e86de"))
			draw_rect(Rect2(xI - 5, yI + 3, 10, 3), Color("c1121f"))
			draw_rect(Rect2(xI - 5, yI - 5, 4, 2), Color("eaf6ff"))
			draw_rect(Rect2(xI + 1, yI - 5, 4, 2), Color("eaf6ff"))
		elif ot == "pw_heart":
			draw_rect(Rect2(xI - 5, yI - 5, 4, 4), Color("e63946"))
			draw_rect(Rect2(xI + 1, yI - 5, 4, 4), Color("e63946"))
			draw_rect(Rect2(xI - 5, yI - 2, 10, 4), Color("e63946"))
			draw_rect(Rect2(xI - 3, yI + 2, 6, 2), Color("e63946"))
			draw_rect(Rect2(xI - 1, yI + 4, 2, 1), Color("e63946"))
			draw_rect(Rect2(xI - 4, yI - 4, 2, 2), Color("ff8fa3"))
		return
	# MARCADO PARA PISOTON: se dibuja EXACTAMENTE igual que el normal, solo
	# que con la lamina del contorno rosa. Esas laminas se generan a partir
	# de las normales (ver herramientas/marcar_parry.py), asi que tienen los
	# mismos frames, las mismas poses y las mismas medidas: no hay nada que
	# calibrar y no pueden desincronizarse.
	var mrk: bool = o.get("parry", false)
	var t_bird: Texture2D = tex_parry.get("bird") if mrk and tex_parry.has("bird") else tex_bird
	var t_buoy: Texture2D = tex_parry.get("buoy") if mrk and tex_parry.has("buoy") else tex_buoy
	var t_wood: Texture2D = tex_parry.get("log") if mrk and tex_parry.has("log") else tex_wood
	var t_shfu: Texture2D = tex_parry.get("shark") if mrk and tex_parry.has("shark") else tex_sharkfull
	var t_shfi: Texture2D = tex_parry.get("shark_fin") if mrk and tex_parry.has("shark_fin") else tex_sharkfin
	if o["type"] == "estela":
		if tex_ola1:
			var ew := 19.0 * tex_ola1.get_width() / float(tex_ola1.get_height())
			draw_texture_rect_region(tex_ola1,
				Rect2(xI - ew / 2, yI + o["h"] + 3 - 19.0, ew, 19.0),
				Rect2(0, 0, -tex_ola1.get_width(), tex_ola1.get_height()))
		else:
			draw_rect(Rect2(xI - 9, yI, 18, o["h"]), Color(0.9, 0.95, 1.0, 0.9))
		if int(t) % 3 == 0:
			_splash(xI + 8, WATER - 2, 1.0)
		return
	# obstaculos con sprites de las laminas nuevas
	if o["type"] == "rock" and tex_rock:
		var rt := tex_rock_c if (coral and tex_rock_c) else tex_rock
		_draw_sprite(rt, 2, o["variant"] % 2, Vector2(xI, yI + o["h"] + 3), 21.0)
		return
	if o["type"] == "bird" and t_bird:
		# volteada: vuela hacia la izquierda (su direccion de viaje)
		_draw_sprite(t_bird, 2, int(t / 8.0) % 2, Vector2(xI, yI + o["h"] + 2), 13.0, true)
		return
	if o["type"] == "lobo" and tex_lobo:
		_draw_sprite(tex_lobo, 2, int(t / 34.0) % 2, Vector2(xI, yI + o["h"] + 3), 25.0)
		return
	if o["type"] == "rival" and tex_rival:
		_draw_sprite(tex_rival, 3, int(t / 8.0) % 3, Vector2(xI, yI + o["h"] + 2), 24.0)
		return
	if o["type"] == "dolphin" and tex_dolphin:
		var dfr := 1 if absf(sin(o["ph"])) > 0.85 else (0 if cos(o["ph"]) * sin(o["ph"]) > 0 else 2)
		_draw_sprite(tex_dolphin, 3, dfr, Vector2(xI, yI + o["h"] + 2), 18.0)
		return
	if o["type"] == "banana" and tex_banana:
		_draw_sprite(tex_banana, 1, 0, Vector2(xI, yI + o["h"] + 2), 12.0)
		return
	# sprites nuevos: boyas, maderas y tiburon completo animado
	if o["type"] == "buoy" and t_buoy:
		_draw_sprite(t_buoy, 5, o["variant"], Vector2(xI, yI + o["h"] + 3), 25.0)
		return
	if o["type"] == "log" and t_wood:
		_draw_sprite(t_wood, 6, o["variant"], Vector2(xI, yI + o["h"] + 3), 16.0)
		return
	if o["type"] == "shark" and t_shfu:
		# acecho: la aleta crece de a poco / ataque: emerge y muerde
		var dist := ox - px
		var base := Vector2(xI, yI + o["h"] + 3)
		if o["timer"] < 130 and t_shfi:
			var fin_fr := clampi(int(o["timer"] / 45.0), 0, 2)
			_draw_sprite(t_shfi, 4, fin_fr, base, 9.0 + fin_fr * 3.0, true)
		elif dist > 50 and t_shfi:
			_draw_sprite(t_shfi, 4, 3, base, 19.0, true)
		else:
			_draw_sprite(t_shfu, 3, int(t / 8.0) % 3, base, 22.0, true)
		return
	match o["type"]:
		"rock":
			draw_colored_polygon(PackedVector2Array([
				Vector2(xI - 8, yI + o["h"]), Vector2(xI - 5, yI + 3), Vector2(xI, yI),
				Vector2(xI + 4, yI + 4), Vector2(xI + 8, yI + o["h"])
			]), Color("e07a5f") if coral else Color("5b6770"))
			draw_rect(Rect2(xI - 2, yI + 3, 3, 3), Color("f4a261") if coral else Color("7d8a94"))
			if coral:
				draw_rect(Rect2(xI - 5, yI + 6, 2, 4), Color("ffb4a2"))
				draw_rect(Rect2(xI + 3, yI + 5, 2, 5), Color("ffb4a2"))
			draw_rect(Rect2(xI - 9, yI + o["h"] - 2, 18, 2), Color("eaf6ff"))
		"buoy":
			draw_rect(Rect2(xI - 5, yI, 10, 5), Color("e63946"))
			draw_rect(Rect2(xI - 5, yI + 5, 10, 4), Color.WHITE)
			draw_rect(Rect2(xI - 5, yI + 9, 10, 4), Color("e63946"))
			draw_rect(Rect2(xI - 1, yI - 4, 2, 4), Color("333333"))
			draw_rect(Rect2(xI - 2, yI - 6, 4, 3), Color("ffd166"))
		"log":
			draw_rect(Rect2(xI - 12, yI, 24, 6), Color("7f5539"))
			draw_rect(Rect2(xI - 12, yI, 24, 2), Color("9c6644"))
			draw_rect(Rect2(xI - 8, yI + 2, 3, 2), Color("5e3d26"))
			draw_rect(Rect2(xI + 4, yI + 2, 3, 2), Color("5e3d26"))
		"bird":
			var flap := -3 if sin(t * 0.3) > 0 else 2
			draw_rect(Rect2(xI - 4, yI, 9, 4), Color("f1f1f1"))
			draw_rect(Rect2(xI - 8, yI + flap, 5, 2), Color("f1f1f1"))
			draw_rect(Rect2(xI + 4, yI + flap, 5, 2), Color("f1f1f1"))
			draw_rect(Rect2(xI + 5, yI + 1, 3, 2), Color("ffb703"))
			draw_rect(Rect2(xI + 2, yI + 1, 1, 1), Color("222222"))
		"shark":
			draw_rect(Rect2(xI - 11, yI + o["h"] - 1, 22, 3), Color(0, 0, 0, 0.27))
			draw_colored_polygon(PackedVector2Array([
				Vector2(xI - 6, yI + o["h"] - 1), Vector2(xI - 1, yI - 1), Vector2(xI + 5, yI + o["h"] - 1)
			]), Color("4a5560"))
			draw_rect(Rect2(xI - 1, yI + 3, 3, 4), Color("39424c"))
			draw_rect(Rect2(xI - 8, yI + o["h"] - 1, 4, 2), Color("eaf6ff"))
		"lobo":
			draw_rect(Rect2(xI - 8, yI + 11, 16, 6), Color("5b6770"))
			draw_rect(Rect2(xI - 6, yI + 6, 12, 6), Color("6d4c33"))
			draw_rect(Rect2(xI + 1, yI - 1, 5, 8), Color("6d4c33"))
			draw_rect(Rect2(xI + 1, yI - 4, 6, 4), Color("8a6a4b"))
			draw_rect(Rect2(xI + 5, yI - 3, 1, 1), Color("222222"))
			draw_rect(Rect2(xI - 6, yI + 9, 4, 3), Color("a58565"))
		"rival":
			_draw_surfer(Vector2(xI, yI + o["h"] - 6), 0.0, true)
		"banana":
			draw_rect(Rect2(xI - 4, yI + 2, 8, 3), Color("ffd166"))
			draw_rect(Rect2(xI - 5, yI, 2, 3), Color("ffd166"))
			draw_rect(Rect2(xI + 3, yI, 2, 3), Color("ffd166"))
			draw_rect(Rect2(xI - 5, yI - 1, 1, 2), Color("7f5539"))
			draw_rect(Rect2(xI - 2, yI + 3, 4, 1), Color("fff3b0"))
		"dolphin":
			draw_rect(Rect2(xI - 6, yI, 12, 4), Color("7f9db6"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(xI - 6, yI + 2), Vector2(xI - 10, yI - 2), Vector2(xI - 9, yI + 4)
			]), Color("7f9db6"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(xI - 1, yI), Vector2(xI + 1, yI - 4), Vector2(xI + 3, yI)
			]), Color("7f9db6"))
			draw_rect(Rect2(xI - 4, yI + 3, 9, 1), Color("b9cfe0"))
			draw_rect(Rect2(xI + 4, yI + 1, 1, 1), Color("222222"))
			draw_rect(Rect2(xI + 5, yI + 2, 3, 1), Color("5a7d99"))

func _draw_hud(st: Dictionary) -> void:
	# HUD de la fase de remo: barra y aviso
	if phase == "remo" or phase == "popup":
		var pct := paddle / 100.0 if phase == "remo" else 1.0
		draw_rect(Rect2(W / 2 - 50, 130, 100, 9), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(W / 2 - 50, 130, 100.0 * pct, 9), Color("ffd166"))
		draw_rect(Rect2(W / 2 - 50, 130, 100, 9), Color.WHITE, false, 1.0)
		txt("REMO", W / 2 - 78, 138, 8, Color("ffd166"))
		if phase == "remo" and int(t / 20) % 2 == 0:
			txt("REMA! machaca ESPACIO", W / 2, 155, 10, Color.WHITE, true)
		if Global.infinite:
			txt("MODO INFINITO", 6, 14, 8, Color("2ec4b6"))
		else:
			txt("N%d %s" % [st["n"], st["name"]], 6, 14, 8, Color("ffd166"))
		if intro > 0:
			draw_rect(Rect2(0, 58, W, 62), Color(0, 0, 0, 0.55))
			if Global.infinite:
				if tex_infinito:
					var iw := 36.0 * tex_infinito.get_width() / float(tex_infinito.get_height())
					draw_texture_rect(tex_infinito, Rect2(W / 2 - iw / 2, 60, iw, 36), false)
				else:
					txt("MODO INFINITO", W / 2, 80, 13, Color.WHITE, true)
				txt("Sobrevive lo maximo posible y marca un record", W / 2, 104, 8, Color("cfe8ff"), true)
				txt("Las playas y sus peligros van rotando", W / 2, 115, 8, Color("ffd166"), true)
			else:
				txt("N%d: %s" % [st["n"], st["name"]], W / 2, 76, 13, Color.WHITE, true)
				txt(st["pais"], W / 2, 88, 9, Color("8ecae6"), true)
				txt(st["desc"], W / 2, 100, 8, Color("cfe8ff"), true)
				txt(st["sptxt"], W / 2, 112, 8, Color("ffd166"), true)
		return
	txt("SCORE " + Global.fmt(score), 6, 14, 10, Color.WHITE)
	if Global.infinite:
		txt("RECORD " + Global.fmt(Global.hi_inf), 6, 26, 8, Color("ffd166"))
		txt("INFINITO - " + st["name"], 6, 38, 8, Color("2ec4b6"))
	elif not boss:
		# BUGFIX: durante la pelea la barra de meta esta CONGELADA y ademas
		# el nombre del jefe (texto centrado y largo) se le montaba encima.
		# Ahora, mientras hay jefe, la barra de meta se oculta y manda la
		# barra de supervivencia del jefe.
		var goal := Global.goal_of(Global.cur)
		# barra de progreso hacia la meta (avanza con surf real)
		draw_rect(Rect2(6, 20, 90, 6), Color(0, 0, 0, 0.4))
		var pw := minf(90.0, 90.0 * progress / goal)
		draw_rect(Rect2(6, 20, pw, 6), Color("2ec4b6"))
		# el trozo que aportaron los trucos, en dorado al final de la barra
		if trick_prog > 0.0:
			var tw2: float = minf(pw, 90.0 * trick_prog / goal)
			draw_rect(Rect2(6 + pw - tw2, 20, tw2, 6), Color("ffd166"))
		# destello al clavar un truco: es lo unico que te dice que sumo
		if bar_flash > 0.0:
			var fk: float = clampf(bar_flash / 22.0, 0.0, 1.0)
			draw_rect(Rect2(6, 20, 90, 6), Color(1, 1, 1, 0.55 * fk))
			draw_rect(Rect2(4, 18, 94, 10), Color(1.0, 0.82, 0.4, fk), false, 1.0)
		draw_rect(Rect2(6, 20, 90, 6), Color.WHITE, false, 1.0)
		draw_rect(Rect2(98, 18, 2, 10), Color("e63946"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(100, 18), Vector2(106, 20), Vector2(100, 22)
		]), Color("e63946"))
		txt("N%d %s" % [st["n"], st["name"]], 6, 38, 8, Color("ffd166"))
	# (durante la pelea no se dibuja el nombre de la playa: se le montaba
	#  encima al nombre del jefe, que es texto largo y centrado)
	# marcador del mini-encuentro: cuantas formaciones llevas aguantadas
	if enc_tipo != "" and ENC_TIPOS.has(enc_tipo) and enc_out <= 0.0:
		var ed2: Dictionary = ENC_TIPOS[enc_tipo]
		var tot: int = (ed2["atk"] as Array).size()
		txt(String(ed2["nom"]), W / 2, 22, 9, Color("ff8f5e"), true)
		for i in range(tot):
			var cx := W / 2 - (tot - 1) * 6.0 + i * 12.0
			var lleno := i < enc_ok
			draw_rect(Rect2(cx - 4, 26, 8, 5), Color(0, 0, 0, 0.5))
			if lleno:
				draw_rect(Rect2(cx - 4, 26, 8, 5), Color("2ec4b6"))
			draw_rect(Rect2(cx - 4, 26, 8, 5), Color.WHITE, false, 1.0)

	# vidas (corazones)
	for i in range(3):
		if tex_heart:
			var hcol := Color.WHITE if i < lives else Color(0.2, 0.2, 0.2, 0.55)
			draw_texture_rect(tex_heart, Rect2(W - 18 - i * 14, 7, 12, 11), false, hcol)
			continue
		var col := Color("e63946") if i < lives else Color(0, 0, 0, 0.33)
		var hx := W - 16 - i * 14
		draw_rect(Rect2(hx, 8, 4, 4), col)
		draw_rect(Rect2(hx + 5, 8, 4, 4), col)
		draw_rect(Rect2(hx, 11, 9, 4), col)
		draw_rect(Rect2(hx + 2, 15, 5, 2), col)
		draw_rect(Rect2(hx + 4, 17, 1, 1), col)
	# indicadores de power-ups activos (bajo los corazones)
	var iy := 27.0
	if shield:
		draw_circle(Vector2(W - 13, iy), 5, Color(0.45, 0.85, 1.0, 0.35))
		draw_arc(Vector2(W - 13, iy), 5, 0, TAU, 12, Color("eaf6ff"), 1.0)
		iy += 12
	if x2_t > 0:
		txt("x2 %ds" % int(x2_t / 60.0 + 1), W - 7, iy + 3, 8, Color("ffd166"), false, true)
		iy += 11
	if magnet_t > 0:
		txt("IMAN %ds" % int(magnet_t / 60.0 + 1), W - 7, iy + 3, 8, Color("ff8f5e"), false, true)
	if msg != "":
		txt(msg, W / 2, 60, 12, Color("ffd166"), true)
	# contador de cadena de rebotes, mientras sigas en el aire
	if parry_chain > 1:
		txt("x%d" % parry_chain, px + 16, water_y(px) - 34 + y_off, 13,
			Color("ffd166") if parry_chain < 4 else Color("ff8f5e"), true)
	# contador del bonus de tubo mientras estas adentro
	if tube_on > 0:
		var tl := "TUBO +%d" % int(tube_acc)
		if tube_clean:
			tl += "  (x2 si no saltas)"
		txt(tl, W / 2, 74, 8, Color("2ec4b6"), true)
	# aviso de tiburon independiente de los mensajes de trucos
	for o in obs:
		if o["type"] == "shark" and not o["hit"] and o["timer"] < 130:
			if int(t / 10) % 2 == 0:
				txt("¡TIBURON!", W - 14, 34, 10, Color("ff4757"), false, true)
			break
	# HUD del jefe: barra de supervivencia y avisos de ataque
	if boss:
		# contador visible: que se note que la pelea avanza
		var bname := "OLA MONSTRUO"
		if Global.cur < Global.NS - 1:
			bname = String(MBOSS[Global.cur]["name"])
		# la barra ahora es VIDA de verdad, no un reloj disfrazado
		if boss_hp <= 0.0 or boss_t <= 0.0:
			txt("¡LO LOGRASTE!", W / 2, 22, 10, Color("2ec4b6"), true)
		else:
			var extra := "  FASE 2" if boss_p2 else ""
			txt(bname + extra, W / 2, 22, 9, Color("e63946"), true)
		draw_rect(Rect2(W / 2 - 45, 26, 90, 5), Color(0, 0, 0, 0.5))
		var hpw: float = 90.0 * maxf(boss_hp, 0.0) / boss_hpmax
		draw_rect(Rect2(W / 2 - 45, 26, hpw, 5), Color("e63946") if boss_p2 else Color("ff8f5e"))
		draw_rect(Rect2(W / 2 - 45, 26, 90, 5), Color.WHITE, false, 1.0)
		# marca del 50%: ahi se enfurece
		draw_rect(Rect2(W / 2, 25, 1, 7), Color(1, 1, 1, 0.6))
		# VENTANA DE CASTIGO: el momento de pegarle
		if boss_open > 0.0:
			var ok: float = clampf(boss_open / BOSS_OPEN_T, 0.0, 1.0)
			draw_rect(Rect2(W / 2 - 45, 33, 90.0 * ok, 2), Color("ffd166"))
			if int(t / 5) % 2 == 0:
				txt("¡AHORA! HAZ UN TRUCO", W / 2, 47, 11, Color("ffd166"), true)
		# BUGFIX: faltaban los avisos de los 9 ataques nuevos (Guardian de
		# Coral, Gaviota Reina y Mono del Templo peleaban SIN telegrafiar
		# nada por texto). Ahora estan todos en una sola tabla.
		if atk_warn > 0 and int(t / 8) % 2 == 0 and ATK_HINT.has(atk_type):
			var hint: Array = ATK_HINT[atk_type]
			var htxt := String(hint[0])
			# placa oscura AJUSTADA al texto: antes el aviso se leia mal
			# sobre la ola clara, y una banda de lado a lado partia la
			# pantalla en dos justo sobre la linea del horizonte
			var hw: float = font.get_string_size(htxt, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 12 * 4).x / 4.0 + 8.0
			draw_rect(Rect2(W / 2 - hw / 2, 88, hw, 14), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(W / 2 - hw / 2, 88, hw, 14), Color(1, 1, 1, 0.25), false, 1.0)
			txt(htxt, W / 2, 99, 12, Color(String(hint[1])), true)
	if intro > 0:
		draw_rect(Rect2(0, 58, W, 62), Color(0, 0, 0, 0.55))
		if Global.infinite:
			# BUGFIX: en modo infinito, apenas terminabas de remar esta
			# tarjeta cambiaba sola a la ficha de campana ("N12: TEAHUPOO,
			# meta...") aunque en infinito no hay meta ni numero de playa
			if tex_infinito:
				var iw2 := 36.0 * tex_infinito.get_width() / float(tex_infinito.get_height())
				draw_texture_rect(tex_infinito, Rect2(W / 2 - iw2 / 2, 60, iw2, 36), false)
			else:
				txt("MODO INFINITO", W / 2, 80, 13, Color.WHITE, true)
			txt("Sobrevive lo maximo posible y marca un record", W / 2, 104, 8, Color("cfe8ff"), true)
			txt("Las playas y sus peligros van rotando", W / 2, 115, 8, Color("ffd166"), true)
		else:
			txt("N%d: %s" % [st["n"], st["name"]], W / 2, 76, 13, Color.WHITE, true)
			txt(st["pais"], W / 2, 88, 9, Color("8ecae6"), true)
			txt(st["desc"], W / 2, 100, 8, Color("cfe8ff"), true)
			txt(st["sptxt"], W / 2, 112, 8, Color("ffd166"), true)

## pantalla arcade de ingreso de iniciales
func _draw_initials() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.78))
	txt("¡ENTRASTE AL TOP 5!", W / 2, 42, 15, Color("ffd166"), true)
	txt("SCORE " + Global.fmt(score), W / 2, 60, 10, Color.WHITE, true)
	txt("Ingresa tus iniciales:", W / 2, 82, 9, Color("cfe8ff"), true)
	for i in range(3):
		var cx := W / 2 - 26 + i * 26
		var sel := i == ini_pos
		txt(LETTERS[ini[i]], cx, 118, 22, Color("2ec4b6") if sel else Color.WHITE, true)
		if sel and int(t / 12) % 2 == 0:
			draw_rect(Rect2(cx - 8, 122, 16, 2), Color("2ec4b6"))
	txt("flechas: cambiar letra    ENTER: confirmar", W / 2, 152, 8, Color("8ecae6"), true)

## tabla top 5 del modo infinito
func _draw_ranking() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.82))
	if tex_trofeo:
		draw_texture_rect(tex_trofeo, Rect2(W / 2 - 66, 14, 22, 26), false)
		draw_texture_rect(tex_trofeo, Rect2(W / 2 + 44, 14, 22, 26), false)
	txt("TOP 5 - MODO INFINITO", W / 2, 32, 13, Color("ffd166"), true)
	var yy := 58.0
	for i in range(5):
		if i < Global.top5.size():
			var e: Dictionary = Global.top5[i]
			var mine: bool = Global.infinite and int(e["score"]) == int(score)
			var col := Color("2ec4b6") if mine else Color.WHITE
			txt("%d.   %s   %s" % [i + 1, e["name"], Global.fmt(int(e["score"]))],
				W / 2, yy, 12, col, true)
		else:
			txt("%d.   ---   ------" % (i + 1), W / 2, yy, 12, Color(1, 1, 1, 0.28), true)
		yy += 19
	if int(t / 30) % 2 == 0:
		txt("R / ENTER: otra vez    M: mapa", W / 2, 162, 9, Color("cfe8ff"), true)

func _draw_pause() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
	if tex_pausa:
		var dh := 88.0
		var dw := dh * tex_pausa.get_width() / float(tex_pausa.get_height())
		draw_texture_rect(tex_pausa, Rect2(W / 2 - dw / 2, 28, dw, dh), false)
	else:
		txt("PAUSA", W / 2, 84, 20, Color.WHITE, true)
	txt("P continuar   M mapa", W / 2, 136, 10, Color("cfe8ff"), true)

func _draw_over() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.72))
	var go := tex_go1 if go_art == 1 else tex_go2
	if go:
		# arte de game over del sprite (elegido al azar entre los dos)
		var dh := 104.0
		var dw := dh * go.get_width() / float(go.get_height())
		draw_texture_rect(go, Rect2(W / 2 - dw / 2, 6, dw, dh), false)
	else:
		txt("WIPEOUT!", W / 2, 64, 22, Color("e63946"), true)
	if Global.infinite:
		txt("SCORE %s   RECORD %s" % [Global.fmt(score), Global.fmt(Global.hi_inf)],
			W / 2, 126, 9, Color("ffd166"), true)
		if int(score) >= Global.hi_inf and int(score) > 0 and int(t / 15) % 2 == 0:
			txt("¡NUEVO RECORD!", W / 2, 114, 11, Color("2ec4b6"), true)
	else:
		txt("SCORE %s   META %s" % [Global.fmt(score), Global.fmt(Global.goal_of(Global.cur))],
			W / 2, 126, 9, Color("ffd166"), true)
	txt("TRUCOS " + str(tricks), W / 2, 140, 9, Color("2ec4b6"), true)
	if int(t / 30) % 2 == 0:
		var hint := "R / ENTER: otra vez    M: mapa"
		if Global.infinite:
			hint += "    T: top 5"
		txt(hint, W / 2, 158, 10, Color("cfe8ff"), true)

## estrella (sprite si existe, polygon de respaldo)
func _star(c: Vector2, r: float, filled: bool) -> void:
	if tex_star and r >= 4.0:
		var scol := Color.WHITE if filled else Color(0.18, 0.18, 0.18, 0.5)
		draw_texture_rect(tex_star, Rect2(c.x - r, c.y - r, r * 2, r * 2), false, scol)
		return
	var col := Color("ffd166") if filled else Color(1, 1, 1, 0.18)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, c.y - r), Vector2(c.x + r * 0.35, c.y - r * 0.3),
		Vector2(c.x + r, c.y - r * 0.2), Vector2(c.x + r * 0.45, c.y + r * 0.25),
		Vector2(c.x + r * 0.6, c.y + r), Vector2(c.x, c.y + r * 0.5),
		Vector2(c.x - r * 0.6, c.y + r), Vector2(c.x - r * 0.45, c.y + r * 0.25),
		Vector2(c.x - r, c.y - r * 0.2), Vector2(c.x - r * 0.35, c.y - r * 0.3),
	]), col)

func _draw_clear() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.67))
	var st := S()
	if tex_completada:
		var dwc := 58.0 * tex_completada.get_width() / float(tex_completada.get_height())
		draw_texture_rect(tex_completada, Rect2(W / 2 - dwc / 2, 4, dwc, 58), false)
	else:
		txt("PLAYA COMPLETADA!", W / 2, 52, 16, Color("2ec4b6"), true)
	txt("N%d %s - %s" % [st["n"], st["name"], st["pais"]], W / 2, 70, 10, Color.WHITE, true)
	txt("SCORE %s   TRUCOS %d" % [Global.fmt(score), tricks], W / 2, 86, 9, Color("ffd166"), true)
	# estrellas ganadas (aparecen una a una)
	var shown := 1 + (1 if st_score else 0) + (1 if st_nodmg else 0)
	for k in range(3):
		var lit: bool = k < shown and t - clear_t > 20 + k * 25
		_star(Vector2(W / 2 - 22 + k * 22, 102), 8, lit)
	txt("meta %s   score x%.1f %s   sin dano %s" % ["SI", Global.STAR_SCORE_MULT,
		"SI" if st_score else "no", "SI" if st_nodmg else "no"],
		W / 2, 122, 7, Color("8ecae6"), true)
	if Global.cur < Global.NS - 1:
		var nx: Dictionary = Global.STAGES[Global.cur + 1]
		txt("DESBLOQUEADA: N%d %s" % [nx["n"], nx["name"]], W / 2, 134, 9, Color("fff3b0"), true)
	if int(t / 30) % 2 == 0:
		txt("ENTER: volver al mapa", W / 2, 150, 10, Color("cfe8ff"), true)

func _draw_champion() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("083358"))
	var confetti := [Color("ffd166"), Color("e63946"), Color("2ec4b6"), Color.WHITE]
	for i in range(60):
		var cx := fmod(i * 67 + t * (1 + i % 3), W)
		var cy := fmod(i * 41 + t * 0.7 * (1 + i % 2), H)
		draw_rect(Rect2(cx, cy, 2, 2), confetti[i % 4])
	txt("CAMPEON MUNDIAL DE SURF!", W / 2, 56, 15, Color("ffd166"), true)
	txt("Completaste las 12 mejores", W / 2, 78, 10, Color.WHITE, true)
	txt("playas del mundo", W / 2, 92, 10, Color.WHITE, true)
	if tex_trofeo:
		# trofeo dorado + surfista celebrando
		draw_texture_rect(tex_trofeo, Rect2(W / 2 - 32, 100, 34, 40), false)
		if tex_celebrar:
			var cfr := int(t / 12.0) % 2
			var cw := tex_celebrar.get_width() / 2.0
			draw_texture_rect_region(tex_celebrar, Rect2(W / 2 + 8, 104, 21, 36),
				Rect2(cfr * cw, 0, cw, tex_celebrar.get_height()))
	else:
		var tx := W / 2 - 8
		var ty := 104.0
		draw_rect(Rect2(tx, ty, 16, 10), Color("ffd166"))
		draw_rect(Rect2(tx + 4, ty + 10, 8, 4), Color("ffd166"))
		draw_rect(Rect2(tx + 2, ty + 14, 12, 3), Color("ffd166"))
		draw_rect(Rect2(tx - 4, ty + 2, 4, 5), Color("ffd166"))
		draw_rect(Rect2(tx + 16, ty + 2, 4, 5), Color("ffd166"))
		_draw_surfer(Vector2(W / 2, 96), sin(t * 0.1) * 0.2)
	if int(t / 30) % 2 == 0:
		txt("ENTER: volver al mapa", W / 2, 150, 10, Color("cfe8ff"), true)
