extends Node
## Autoload: datos de las 12 playas, progreso guardado, musica y efectos.

const NS := 12

# pos = fraccion (x,y) sobre el mapa (0-1), facil de recalibrar si cambias map.png
var STAGES := [
	{"n":12,"name":"TEAHUPOO","pais":"TAHITI","pos":Vector2(0.120,0.620),"sp":["coral","surge"],
	 "desc":"La ola mas fuerte del mundo, sobre arrecife de coral",
	 "sptxt":"ESPECIAL: coral afilado y olas gigantes",
	 "sky":[Color("7ee8fa"),Color("5cc9f5"),Color("3aa7e8"),Color("2b86d9")],
	 "sea":Color("0f9b8e"),"sea_hi":Color("2ec4b6"),"sea_dk":Color("0b7a70")},
	{"n":11,"name":"HOSSEGOR","pais":"FRANCIA","pos":Vector2(0.455,0.315),"sp":["cluster"],
	 "desc":"Capital europea del surf: Graviere, Nord y Sud",
	 "sptxt":"ESPECIAL: series de obstaculos triples",
	 "sky":[Color("ffd66b"),Color("ffb54d"),Color("ff8f5e"),Color("e56b8f")],
	 "sea":Color("1b6ca8"),"sea_hi":Color("2e86de"),"sea_dk":Color("14548c")},
	{"n":10,"name":"ULUWATU","pais":"INDONESIA","pos":Vector2(0.830,0.600),"sp":["rival"],
	 "desc":"Paraiso entre acantilados, picos en varias direcciones",
	 "sptxt":"ESPECIAL: pico lleno de surfistas rivales",
	 "sky":[Color("ffe29a"),Color("ffc46b"),Color("f79d65"),Color("d97b8f")],
	 "sea":Color("128277"),"sea_hi":Color("31b5a5"),"sea_dk":Color("0d6459")},
	{"n":9,"name":"MUNDAKA","pais":"ESPANA","pos":Vector2(0.448,0.335),"sp":["surge"],
	 "desc":"La mejor izquierda de Europa: 4,5m y 400m de recorrido",
	 "sptxt":"ESPECIAL: rachas de ola rapida",
	 "sky":[Color("a8dadc"),Color("8ecae6"),Color("6baed6"),Color("4a90c2")],
	 "sea":Color("14548c"),"sea_hi":Color("2e86de"),"sea_dk":Color("0e3f6b")},
	{"n":8,"name":"SUPERTUBOS","pais":"PORTUGAL","pos":Vector2(0.436,0.355),"sp":["tube"],
	 "desc":"Tubos potentes en Peniche, sede del circuito WSL",
	 "sptxt":"BONUS: tubos, quedate abajo y suma",
	 "sky":[Color("cdeffd"),Color("a5d8f3"),Color("7fbce9"),Color("5a9bd4")],
	 "sea":Color("1d5f8a"),"sea_hi":Color("3d85b8"),"sea_dk":Color("154768")},
	{"n":7,"name":"EL GRINGO","pais":"ARICA, CHILE","pos":Vector2(0.262,0.625),"sp":["coral","cluster"],
	 "desc":"El Pipeline chileno: ola pesada sobre lava afilada",
	 "sptxt":"ESPECIAL: arrecife afilado y series dobles",
	 "sky":[Color("cfe8f5"),Color("a8d3ea"),Color("7fb6d9"),Color("5a92bd")],
	 "sea":Color("1f6f8b"),"sea_hi":Color("3f97b5"),"sea_dk":Color("175468")},
	{"n":6,"name":"PIPELINE","pais":"HAWAI","pos":Vector2(0.100,0.380),"sp":["tube","rival"],
	 "desc":"Tubos enormes sobre arrecife, cuna de leyendas",
	 "sptxt":"BONUS: tubos enormes + rivales locales",
	 "sky":[Color("83eaf1"),Color("63c9f1"),Color("40a8e0"),Color("2f88c9")],
	 "sea":Color("0b7fab"),"sea_hi":Color("27a3cf"),"sea_dk":Color("085e80")},
	{"n":5,"name":"GOLD COAST","pais":"AUSTRALIA","pos":Vector2(0.935,0.685),"sp":["shark"],
	 "desc":"Superbank: olas de mas de 500 metros de longitud",
	 "sptxt":"CUIDADO: TIBURONES!",
	 "sky":[Color("ffe9a8"),Color("ffd166"),Color("ffb54d"),Color("f48c6a")],
	 "sea":Color("1a7fc1"),"sea_hi":Color("3d9de0"),"sea_dk":Color("135e91")},
	{"n":4,"name":"MALE","pais":"MALDIVAS","pos":Vector2(0.720,0.550),"sp":["dolphin"],
	 "desc":"Arrecifes con olas perfectas y aguas calidas",
	 "sptxt":"BONUS: delfines saltarines +300",
	 "sky":[Color("b8f2e6"),Color("8ee3d0"),Color("63d4c0"),Color("3ec4b0")],
	 "sea":Color("0fb5a5"),"sea_hi":Color("3ed8c8"),"sea_dk":Color("0b877b")},
	{"n":3,"name":"PUNTA DE LOBOS","pais":"PICHILEMU, CHILE","pos":Vector2(0.256,0.705),"sp":["lobo"],
	 "desc":"La joya del surf chileno, olas gigantes junto al morro",
	 "sptxt":"ESPECIAL: lobos marinos en las rocas",
	 "sky":[Color("ffd6a5"),Color("ffab73"),Color("f08080"),Color("9d6b8f")],
	 "sea":Color("2f6690"),"sea_hi":Color("4a90b8"),"sea_dk":Color("24507a")},
	{"n":2,"name":"TAGHAZOUT","pais":"MARRUECOS","pos":Vector2(0.440,0.415),"sp":["banana"],
	 "desc":"Banana Beach, Spider y Devils Rock en un solo lugar",
	 "sptxt":"BONUS: platanos de Banana Beach +100",
	 "sky":[Color("ffe0b5"),Color("ffc98a"),Color("f9a86b"),Color("e07a5f")],
	 "sea":Color("1b6ca8"),"sea_hi":Color("2e86de"),"sea_dk":Color("14548c")},
	{"n":1,"name":"CORRALEJO","pais":"FUERTEVENTURA","pos":Vector2(0.421,0.400),"sp":["shark","tube","surge"],
	 "desc":"La mejor playa del mundo para surfear!",
	 "sptxt":"GRAN FINAL: tiburones, tubos y olas gigantes",
	 "sky":[Color("fff3b0"),Color("ffd166"),Color("ff9f1c"),Color("e36414")],
	 "sea":Color("0077b6"),"sea_hi":Color("0096d6"),"sea_dk":Color("005a8a")},
]

var unlocked := 1
var best: Array = []
var stars: Array = []   # 0-3 estrellas por playa
var cur := 0      # playa en juego
var sel := 0      # playa seleccionada en el mapa
var music_on := true
var vol_mus := 0.70   # volumen de la musica (0..1)
var vol_sfx := 0.80   # volumen de los efectos (0..1)
var infinite := false   # modo infinito (solo puntaje)
var hi_inf := 0         # record del modo infinito
var boss_checkpoint := false  # morir contra el jefe = reintentar en el jefe
var boss_checkpoint_stage := -1  # a QUE playa pertenece ese checkpoint
var top5: Array = []          # ranking arcade del modo infinito [{name, score}]

# tema fijo del menu/mapa + un tema por playa (indice = etapa, de la 12 a la 1)
const MENU_MUSIC := "res://assets/music.mp3"
const STAGE_MUSIC := [
	"res://assets/soulfuljamtracks-summer-ocean-surf-background-322945.mp3",  # N12 Teahupoo
	"res://assets/alanajordan-surf-rock-02-269647.mp3",                       # N11 Hossegor
	"res://assets/alanajordan-surf-rock-03-269646.mp3",                       # N10 Uluwatu
	"res://assets/alanajordan-surf-rock-04-269644.mp3",                       # N9 Mundaka
	"res://assets/alanajordan-surf-rock-05-269645.mp3",                       # N8 Supertubos
	"res://assets/alexguz-surf-rock-155127.mp3",                              # N7 El Gringo
	"res://assets/alanajordan-surf-rock-08-273369.mp3",                       # N6 Pipeline
	"res://assets/alanajordan-surf-rock-09-273370.mp3",                       # N5 Gold Coast
	"res://assets/bfcmusic-surf-rock-summer-325576.mp3",                      # N4 Male
	"res://assets/abydos_music-surf-rock-1-minute-edit-204623.mp3",           # N3 Punta de Lobos
	"res://assets/fkmusic420-mon-vasiya-140vpm-424187.mp3",                   # N2 Taghazout
	"res://assets/tunetank-energetic-surf-rock-music-350069.mp3",             # N1 Corralejo
]

var _music: AudioStreamPlayer
var _music_path := ""
var _sfx_pool: Array = []   # 3 canales para que los efectos no se pisen
var _sfx_i := 0
var _beep_cache := {}

func _ready() -> void:
	best.resize(NS)
	best.fill(0)
	stars.resize(NS)
	stars.fill(0)
	load_save()
	# musica
	_music = AudioStreamPlayer.new()
	add_child(_music)
	play_music_file(MENU_MUSIC)
	# efectos (pool de 3 canales)
	for i in range(3):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)
	aplicar_volumen()

# ---------- RITMO DE LA CAMPANA ----------
# Antes: goal_of(i) = 1800 + i*300.
#
# Habia DOS problemas distintos.
#
# 1) LA BARRA NO MEDIA DISTANCIA, MEDIA TRUCOS. Un truco encadenado aportaba
#    150*combo*0.25 a la barra, contra 0.18 por frame de surfear: 7.6 veces
#    mas. Sumale delfines (+200), platanos (+100), tubos y power-ups, todos a
#    valor completo. Machacando trucos se llegaba al jefe en 7 SEGUNDOS.
#    Ahora la regla es simple y se explica en una linea:
#        LA BARRA MIDE DISTANCIA SURFEADA. Y NADA MAS.
#    Los trucos y los bonus dan SCORE (que es lo que cuenta para la segunda
#    estrella y para los records), no distancia. Igual premian: el score
#    empuja la velocidad, asi que jugar bien te lleva al jefe ~30% antes
#    (100 s surfeando limpio contra ~70 s haciendo trucos todo el rato).
#
# 2) LA FORMA ESTABA MAL. La meta crecia 300 por playa pero la velocidad
#    maxima solo 0.25, asi que las ultimas playas no eran mas dificiles,
#    eran mas LARGAS: 103 s de surf en la N12 contra 139 s en la N1.
#    Ahora la meta se calcula playa por playa para que TODAS tarden lo
#    mismo en llegar al jefe (~100 s). La dificultad la ponen los
#    obstaculos y el jefe, no la duracion.
const GOALS := [1250, 1350, 1450, 1500, 1600, 1700, 1800, 1900, 2000, 2100, 2150, 2450]

## LOS TRUCOS EMPUJAN LA BARRA: POCO, PERO DURANTE TODA LA PLAYA.
##
## Primero se probo con un PORCENTAJE de los puntos del truco (25%, con combo
## y con x2). No funciono: como el combo multiplica, el tope del 12% se
## agotaba en 3 o 4 trucos, o sea en los primeros 15 segundos. Despues hacias
## trucos durante 70 segundos y la barra no se movia un pixel. El total estaba
## bien, el REPARTO estaba mal.
##
## Ahora cada truco aporta una cantidad FIJA (no escala con el combo ni con el
## x2). Asi el empujon es chico pero constante, y se nota toda la playa. El
## tope sigue existiendo solo para que no se pueda romper machacando giros.
##   surfeando limpio ......... 85 s  (no baja: es el incentivo)
##   un truco cada 3 s ........ 67 s
##   un truco cada 1.5 s ...... 55 s
##   machacando sin parar ..... 45 s
## Los trucos pasan a ser LA forma de avanzar rapido, no un extra.
const TRICK_PROGRESS_FLAT := 9.0
const TRICK_PROGRESS_CAP := 0.33

## LA VELOCIDAD SUBE CON LA DISTANCIA, NO CON LOS PUNTOS.
## Antes era base + score/1500, y como los trucos disparan el score, el que
## hacia trucos iba al maximo de velocidad enseguida: la curva de dificultad
## dependia del estilo de juego. Ahora depende de lo avanzada que este la
## playa, que es lo unico que tiene sentido.
const SPD_RAMP := 1000.0

## Idem para cada cuanto aparece un obstaculo (antes score/60). Con 33 sobre
## progress el intervalo queda casi identico al original (error 1.5 frames).
const SPAWN_RAMP := 33.0

## Umbral de la estrella de score (antes 1.5). Verificado: surfeando limpio
## no sale en ninguna de las 12 playas, y haciendo trucos sale en las 12.
const STAR_SCORE_MULT := 1.7

## Lleva vol_mus y vol_sfx (0..1) a los reproductores.
## En 0 se silencia del todo; si no, se convierte a decibelios con el mismo
## desfase que tenian antes fijo (-4 la musica, -10 los efectos), asi que
## con los valores por defecto suena exactamente igual que hasta ahora.
func aplicar_volumen() -> void:
	if _music:
		_music.volume_db = -80.0 if vol_mus <= 0.005 else linear_to_db(vol_mus) - 4.0
	for p in _sfx_pool:
		p.volume_db = -80.0 if vol_sfx <= 0.005 else linear_to_db(vol_sfx) - 10.0


func goal_of(i: int) -> int:
	return int(GOALS[clampi(i, 0, NS - 1)])

# VELOCIDAD DE LOS OBSTACULOS: -20% en todas las playas.
# Antes: base 2.0+0.15i, max 3.8+0.25i. En las ultimas playas veias venir un
# obstaculo 0.70 s antes de que te llegara, que es muy poco para reaccionar.
# Ahora ese margen va de 1.51 s (N12) a 0.88 s (N1).
# Ojo: el hueco EN TIEMPO entre obstaculos no cambia (spawn_t va en frames),
# solo los ves venir desde mas lejos. La dificultad de timing es la misma.
func base_spd(i: int) -> float:
	return 1.6 + i * 0.12    # antes 2.0 + i * 0.15

func max_spd(i: int) -> float:
	return 3.04 + i * 0.20   # antes 3.8 + i * 0.25

## cambia de tema (si ya esta sonando ese mismo, no lo reinicia)
func play_music_file(p: String) -> void:
	aplicar_volumen()
	_music.pitch_scale = 1.0
	if p == _music_path and _music.playing:
		return
	_music_path = p
	if ResourceLoader.exists(p):
		var m = load(p)
		m.loop = true
		_music.stream = m
		if music_on:
			_music.play()

## efecto de pausa: la musica suena mas lenta y mas despacio (transicion suave)
func set_music_pause(paused: bool) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	# la pausa baja 12 dB sobre el volumen que tenga configurado el jugador
	var base: float = -80.0 if vol_mus <= 0.005 else linear_to_db(vol_mus) - 4.0
	tw.tween_property(_music, "volume_db", base - 12.0 if paused else base, 0.4)
	tw.tween_property(_music, "pitch_scale", 0.75 if paused else 1.0, 0.4)

func toggle_music() -> void:
	music_on = not music_on
	if music_on and _music.stream:
		_music.play()
	else:
		_music.stop()

func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("save", "unlocked", unlocked)
	cf.set_value("save", "best", best)
	cf.set_value("save", "hi_inf", hi_inf)
	cf.set_value("save", "stars", stars)
	cf.set_value("save", "top5", top5)
	cf.set_value("save", "vol_mus", vol_mus)
	cf.set_value("save", "vol_sfx", vol_sfx)
	cf.save("user://surfer.cfg")

func load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://surfer.cfg") == OK:
		unlocked = clampi(int(cf.get_value("save", "unlocked", 1)), 1, NS)
		var b: Array = cf.get_value("save", "best", [])
		for i in range(mini(b.size(), NS)):
			best[i] = int(b[i])
		hi_inf = int(cf.get_value("save", "hi_inf", 0))
		var s: Array = cf.get_value("save", "stars", [])
		for i in range(mini(s.size(), NS)):
			stars[i] = int(s[i])
		top5 = cf.get_value("save", "top5", [])
		vol_mus = clampf(float(cf.get_value("save", "vol_mus", 0.70)), 0.0, 1.0)
		vol_sfx = clampf(float(cf.get_value("save", "vol_sfx", 0.80)), 0.0, 1.0)

## ¿este puntaje entra al top 5 del modo infinito?
func top5_qualifies(s: int) -> bool:
	if s <= 0:
		return false
	return top5.size() < 5 or s > int(top5[top5.size() - 1]["score"])

## borra todo el progreso (campana, estrellas, records) y guarda
func reset_progress() -> void:
	unlocked = 1
	best.fill(0)
	stars.fill(0)
	hi_inf = 0
	top5 = []
	clear_boss_checkpoint()
	sel = 0
	cur = 0
	save_game()


func top5_add(nm: String, s: int) -> void:
	top5.append({"name": nm, "score": s})
	top5.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	if top5.size() > 5:
		top5.resize(5)
	save_game()

# ============================================================
#   SINTETIZADOR DE EFECTOS
# ============================================================
# Todos los efectos eran ondas cuadradas (beep). Contra la musica de surf
# rock grabada sonaban a otro juego. Aqui se sintetizan sonidos con cuerpo:
# ruido filtrado para el agua, golpes con graves, metales para el parry.
# Se generan una sola vez al pedirlos y se quedan en cache; no hay archivos.

const SR := 22050

## Convierte muestras (-1..1) en un AudioStreamWAV listo para sonar.
func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var n := s.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 28000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.data = data
	return w

## AGUA: ruido blanco pasado por un filtro que se va cerrando. Es lo que
## convierte un "pip" en un chapuzon: el ruido da la textura y el filtro
## que se cierra da la sensacion de que el agua se calma.
func _sfx_agua(dur: float, brillo := 0.40, vol := 0.55) -> PackedFloat32Array:
	var n := int(SR * dur)
	var s := PackedFloat32Array(); s.resize(n)
	var lp := 0.0
	for i in range(n):
		var k := float(i) / n
		var a: float = lerpf(brillo, 0.04, k)      # el filtro se cierra
		lp += a * (randf_range(-1.0, 1.0) - lp)
		var env: float = (1.0 - k) * (1.0 - k)
		s[i] = lp * env * vol
	return s

## BARRIDO de tono: para saltos, rebotes y caidas.
##
## La envolvente ATACA DE GOLPE y luego cae. Antes usaba sin(PI*k), que
## entra suave: por eso el salto sonaba blando, como si empezara despues
## de haber saltado. Un salto tiene que sonar en el frame en que ocurre.
##   curva  1.0 = el barrido va lineal
##          2.0 = arranca rapido y se frena (sube "de golpe")
##          0.5 = arranca lento y se acelera (cae "cada vez mas rapido")
func _sfx_barrido(f0: float, f1: float, dur: float, vol := 0.42,
		curva := 2.0, decaida := 1.8, ondeo := 0.0) -> PackedFloat32Array:
	var n := int(SR * dur)
	var s := PackedFloat32Array(); s.resize(n)
	var fase := 0.0
	for i in range(n):
		var k := float(i) / n
		var f: float = lerpf(f0, f1, pow(k, curva))
		if ondeo > 0.0:
			f *= 1.0 + sin(TAU * 9.0 * k) * ondeo   # temblor: da vertigo
		fase += TAU * f / SR
		# ataque casi instantaneo (2% del sonido) y despues caida
		var env: float = minf(1.0, k * 50.0) * pow(1.0 - k, decaida)
		s[i] = (sin(fase) * 0.7 + sin(fase * 2.0) * 0.22 + sin(fase * 3.0) * 0.08) * env * vol
	return s

## PULSO estilo consola de 16 bits: onda cuadrada con ancho ajustable.
## Es la base del sonido de menu de los Mega Man X: corto, seco y brillante.
## `duty` 0.5 = cuadrada plena; 0.25 y 0.125 suenan mas nasales y finos.
func _sfx_pulso(f0: float, f1: float, dur: float, duty := 0.25,
		vol := 0.30, decaida := 2.2) -> PackedFloat32Array:
	var n := int(SR * dur)
	var s := PackedFloat32Array(); s.resize(n)
	var fase := 0.0
	for i in range(n):
		var k := float(i) / n
		fase += lerpf(f0, f1, k) / SR
		fase = fmod(fase, 1.0)
		var v: float = 1.0 if fase < duty else -1.0
		var env: float = minf(1.0, k * 80.0) * pow(1.0 - k, decaida)
		s[i] = v * env * vol
	return s

## GOLPE: un grave corto con pegada + un chasquido de ruido encima.
func _sfx_golpe(f: float, dur: float, aspero := 0.5, vol := 0.6) -> PackedFloat32Array:
	var n := int(SR * dur)
	var s := PackedFloat32Array(); s.resize(n)
	var fase := 0.0
	var lp := 0.0
	for i in range(n):
		var k := float(i) / n
		fase += TAU * lerpf(f, f * 0.45, k) / SR   # el tono cae: da peso
		lp += 0.5 * (randf_range(-1.0, 1.0) - lp)
		var env: float = pow(1.0 - k, 2.5)
		s[i] = (sin(fase) * (1.0 - aspero) + lp * aspero) * env * vol
	return s

## METAL: varios armonicos desafinados. Suena a campana, para el parry.
func _sfx_metal(f: float, dur: float, vol := 0.34) -> PackedFloat32Array:
	var n := int(SR * dur)
	var s := PackedFloat32Array(); s.resize(n)
	var arm := [1.0, 2.76, 5.40, 8.93]             # relaciones inarmonicas
	for i in range(n):
		var k := float(i) / n
		var v := 0.0
		for j in range(arm.size()):
			v += sin(TAU * f * arm[j] * i / SR) / (j + 1.6)
		s[i] = v * pow(1.0 - k, 3.0) * vol
	return s

## ACORDE: varias notas juntas, para victoria y fanfarrias.
func _sfx_acorde(notas: Array, dur: float, vol := 0.30) -> PackedFloat32Array:
	var n := int(SR * dur)
	var s := PackedFloat32Array(); s.resize(n)
	for i in range(n):
		var k := float(i) / n
		var v := 0.0
		for f in notas:
			v += sin(TAU * float(f) * i / SR) + sin(TAU * float(f) * 2.0 * i / SR) * 0.3
		var env: float = minf(1.0, k * 22.0) * pow(1.0 - k, 1.4)
		s[i] = v / notas.size() * env * vol
	return s

## Mezcla dos sonidos (el segundo puede entrar mas tarde).
func _mezcla(a: PackedFloat32Array, b: PackedFloat32Array, retraso := 0) -> PackedFloat32Array:
	var n: int = maxi(a.size(), b.size() + retraso)
	var s := PackedFloat32Array(); s.resize(n); s.fill(0.0)
	for i in range(a.size()):
		s[i] += a[i]
	for i in range(b.size()):
		s[i + retraso] += b[i]
	return s

## Construye el efecto que toque (solo la primera vez que se pide).
func _crear_sfx(nom: String) -> AudioStreamWAV:
	match nom:
		# SALTO: golpe de impulso al instante + subida rapida que se frena
		# arriba (curva 2.0), como el arco del propio salto. Encima, el
		# empujon del agua al despegar.
		"salto":     return _wav(_mezcla(
						_mezcla(_sfx_barrido(300, 900, 0.20, 0.40, 2.2, 2.4),
								_sfx_pulso(300, 880, 0.13, 0.22, 0.16, 2.6)),
						_sfx_agua(0.22, 0.55, 0.30)))
		# DOBLE SALTO: mas agudo y mas corto, se nota que es el segundo
		"salto2":    return _wav(_mezcla(
						_mezcla(_sfx_barrido(520, 1400, 0.16, 0.36, 2.2, 2.6),
								_sfx_pulso(520, 1350, 0.11, 0.18, 0.15, 2.8)),
						_sfx_agua(0.16, 0.65, 0.24)))
		"agua":      return _wav(_sfx_agua(0.26, 0.45, 0.50))
		"chapuzon":  return _wav(_sfx_agua(0.55, 0.60, 0.75))
		"remo":      return _wav(_sfx_agua(0.14, 0.55, 0.40))
		"golpe":     return _wav(_mezcla(_sfx_golpe(150, 0.34, 0.45), _sfx_agua(0.30, 0.5, 0.40)))
		"golpe_duro":return _wav(_mezcla(_sfx_golpe(95, 0.45, 0.35, 0.75), _sfx_agua(0.40, 0.4, 0.45)))
		"madera":    return _wav(_sfx_golpe(190, 0.24, 0.30, 0.55))
		"metal":     return _wav(_mezcla(_sfx_metal(760, 0.40), _sfx_golpe(300, 0.12, 0.4, 0.35)))
		"parry":     return _wav(_mezcla(_sfx_metal(1180, 0.36, 0.40), _sfx_barrido(700, 1800, 0.13, 0.30)))
		"castigo":   return _wav(_mezcla(_sfx_golpe(120, 0.40, 0.30, 0.80), _sfx_metal(520, 0.45, 0.26), 900))
		"truco":     return _wav(_mezcla(_sfx_barrido(660, 1320, 0.18, 0.34), _sfx_metal(1320, 0.22, 0.20), 1400))
		"bonus":     return _wav(_mezcla(_sfx_metal(1050, 0.16, 0.32), _sfx_metal(1570, 0.22, 0.30), 1600))
		"aviso":     return _wav(_sfx_golpe(210, 0.30, 0.25, 0.55))
		"jefe":      return _wav(_mezcla(_sfx_golpe(70, 0.75, 0.25, 0.80), _sfx_agua(0.70, 0.30, 0.50)))
		"furia":     return _wav(_mezcla(_sfx_golpe(58, 0.85, 0.30, 1.0), _sfx_barrido(180, 90, 0.55, 0.35)))
		# CAIDA: baja acelerando (curva 0.55) y con temblor, que es lo que
		# da sensacion de vertigo, y termina en el chapuzon de verdad.
		"caida":     return _wav(_mezcla(
						_sfx_barrido(700, 70, 0.70, 0.50, 0.55, 0.9, 0.05),
						_sfx_agua(0.55, 0.55, 0.80), 12000))
		"escudo":    return _wav(_mezcla(_sfx_metal(620, 0.30, 0.34), _sfx_golpe(160, 0.22, 0.4, 0.45)))
		"tiburon":   return _wav(_mezcla(_sfx_golpe(85, 0.55, 0.20, 0.75), _sfx_barrido(240, 130, 0.45, 0.28)))
		"victoria":  return _wav(_sfx_acorde([523, 659, 784, 1047], 0.90, 0.62))
		# --- MENUS, estilo Mega Man X ---
		# Pulso de ancho fino (12.5%), muy corto y con caida seca. Eso es lo
		# que suena "de consola": un seno queda blando y redondo, el pulso
		# tiene el filo del chip. El cursor cae un poco de tono; el confirmar
		# son dos notas subiendo, casi pegadas.
		"ui":        return _wav(_sfx_pulso(1180, 980, 0.055, 0.125, 0.26, 2.6))
		"ui_ok":     return _wav(_mezcla(
						_sfx_pulso(880, 880, 0.05, 0.25, 0.26, 2.4),
						_sfx_pulso(1320, 1320, 0.09, 0.25, 0.26, 2.2), 1100))
		# entrar a una playa: tres notas, mas ceremonioso
		"ui_entrar": return _wav(_mezcla(_mezcla(
						_sfx_pulso(660, 660, 0.05, 0.25, 0.24, 2.4),
						_sfx_pulso(880, 880, 0.05, 0.25, 0.24, 2.4), 1000),
						_sfx_pulso(1320, 1320, 0.13, 0.25, 0.26, 2.0), 2000))
		"ui_atras":  return _wav(_sfx_pulso(760, 560, 0.07, 0.125, 0.24, 2.6))
	return _wav(_sfx_barrido(440, 440, 0.08))

## Reproduce un efecto por nombre. `tono` lo sube o baja (1.0 = normal).
func sfx(nom: String, tono := 1.0) -> void:
	if not _beep_cache.has(nom):
		_beep_cache[nom] = _crear_sfx(nom)
	var p: AudioStreamPlayer = _sfx_pool[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_pool.size()
	p.stream = _beep_cache[nom]
	p.pitch_scale = clampf(tono, 0.3, 3.0)
	p.play()

## Genera un pitido cuadrado retro y lo reproduce (cacheado por frecuencia)
func beep(freq: float, dur := 0.08) -> void:
	var key := "%d_%d" % [int(freq), int(dur * 1000)]
	if not _beep_cache.has(key):
		var rate := 22050
		var n := int(rate * dur)
		var data := PackedByteArray()
		data.resize(n * 2)
		for i in range(n):
			var v := 1.0 if fmod(i * freq / rate, 1.0) < 0.5 else -1.0
			var env := 1.0 - float(i) / n
			data.encode_s16(i * 2, int(v * env * 6000.0))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = rate
		wav.data = data
		_beep_cache[key] = wav
	var p: AudioStreamPlayer = _sfx_pool[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_pool.size()
	p.stream = _beep_cache[key]
	p.pitch_scale = 1.0
	p.play()

func fanfare() -> void:
	# antes eran cuatro pitidos en escalera; ahora es un acorde con cuerpo
	sfx("victoria")
	await get_tree().create_timer(0.30).timeout
	sfx("victoria", 1.335)   # una quinta arriba


func fmt(s: float) -> String:
	return "%06d" % int(minf(s, 999999.0))

# ---------- CHECKPOINT DEL JEFE ----------
# El checkpoint guarda TAMBIEN de que playa es. Antes solo era un si/no:
# si morias contra el jefe de una playa y entrabas a otra distinta, esa
# otra playa arrancaba ya al 75% de la barra y con el puntaje regalado.

## activa el checkpoint del jefe, recordando en que playa se murio
func set_boss_checkpoint(stage: int) -> void:
	boss_checkpoint = true
	boss_checkpoint_stage = stage

## limpia el checkpoint (al ganarle al jefe o al entrar a otra playa)
func clear_boss_checkpoint() -> void:
	boss_checkpoint = false
	boss_checkpoint_stage = -1

## ¿hay checkpoint valido para la playa que se va a jugar?
func has_boss_checkpoint(stage: int) -> bool:
	return boss_checkpoint and boss_checkpoint_stage == stage
