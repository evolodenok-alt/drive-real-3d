extends Node3D

# ======================= НАСТРОЙКИ =======================
const ROAD_HALF := 6.0
const LANES := [-4.2, -2.1, 0.0, 2.1, 4.2]
const STEP := 4.0
const TRACK_LEN := 3000.0
const FREE_HALF := 1000.0
const SHADOWS := true
const START_COINS := 0
const REWARD_EVERY_3 := 5000
const COIN_VALUE := 25
const SAVE_PATH := "user://save.json"
const GAUGE_MAX_KMH := 300.0
const GRAVITY := 18.0
const MAX_HITS := 3
const UPGRADE_COST := 800
const TURBO_COST := 20000
const NORMAL_MAX_KMH := 170.0
const TURBO_MAX_KMH := 1000.0
const GOLD := Color(1, 0.85, 0.2)

const ACTION_NAMES := {"gas": "Газ", "brake": "Тормоз", "left": "Влево", "right": "Вправо"}
const ALT_KEYS := {"gas": KEY_UP, "brake": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT}
const PAD_TEXT := {"gas": "ГАЗ", "brake": "ТОРМ", "left": "<", "right": ">"}

const UPGRADE_NAMES := ["Мотор", "Подвеска", "Колёса", "Скорость", "Тормоза"]
const UPGRADE_INFO := {
    "Мотор": "Сильнее разгон",
    "Подвеска": "Устойчивее в поворотах",
    "Колёса": "Лучше сцепление и руление",
    "Скорость": "Выше максимальная скорость",
    "Тормоза": "Короче тормозной путь",
}

const CARS := [
    {"name": "Городской", "info": "Лёгкий и манёвренный", "price": 0, "mass": 800.0, "engine": 1.0, "speed": 1.0, "grip": 1.0, "wheel": 0.38, "len": 4.2, "wid": 1.9, "color": "1f5fe0"},
    {"name": "Спорткар", "info": "Быстрый и цепкий", "price": 15000, "mass": 850.0, "engine": 1.35, "speed": 1.25, "grip": 1.15, "wheel": 0.36, "len": 4.5, "wid": 2.0, "color": "e02020"},
    {"name": "Внедорожник", "info": "Тяжёлый, любит песок", "price": 15000, "mass": 1200.0, "engine": 1.55, "speed": 1.0, "grip": 1.25, "wheel": 0.48, "len": 4.4, "wid": 2.0, "color": "3a7d2a"},
    {"name": "Пикап", "info": "Мощный грузовичок", "price": 15000, "mass": 1100.0, "engine": 1.4, "speed": 1.05, "grip": 1.1, "wheel": 0.44, "len": 4.8, "wid": 2.0, "color": "e08a1a"},
    {"name": "Суперкар", "info": "Самый быстрый", "price": 15000, "mass": 900.0, "engine": 1.7, "speed": 1.5, "grip": 1.3, "wheel": 0.36, "len": 4.6, "wid": 2.1, "color": "f2d11b"},
]

# Карты для заработка монет (каждая 3 км, с поворотами влево/вправо)
const MAPS := [
    {"name": "Зелёная долина", "info": "Плавные повороты, зелёные поля", "reward": 1000, "seed": 11, "ground": "2f7d32", "trees": "1f6d24", "curve": 0.5, "a_min": 20.0, "a_max": 45.0, "c_min": 25, "c_max": 40, "obst": 0.40},
    {"name": "Жаркая пустыня", "info": "Повороты резче, больше препятствий", "reward": 2000, "seed": 22, "ground": "d8b66a", "trees": "8a9a3a", "curve": 0.65, "a_min": 35.0, "a_max": 70.0, "c_min": 28, "c_max": 42, "obst": 0.50},
    {"name": "Снежный серпантин", "info": "Крутые повороты. Для опытных!", "reward": 3500, "seed": 33, "ground": "e8eef5", "trees": "dfeaf2", "curve": 0.75, "a_min": 50.0, "a_max": 85.0, "c_min": 32, "c_max": 50, "obst": 0.55},
]
# ======================= ДАННЫЕ ИГРЫ =======================
var coins := START_COINS
var finishes := 0
var owned := [true, false, false, false, false]
var current_car := 0
var garage_sel := 0
var car_levels: Array = []
var car_colors: Array = []
var car_turbo: Array = []
var settings := {"music_on": true, "engine_on": true, "brake_on": true, "drift_on": true, "click_on": true, "volume": 0.8}
var controls := {"gas": KEY_W, "brake": KEY_S, "left": KEY_A, "right": KEY_D, "swap_sides": false, "swap_lr": false, "swap_pedals": false}
var waiting_key := ""
var selected_upgrade := "Мотор"
var paint_h := 0.6
var paint_s := 0.8
var paint_v := 0.9
var flash := ""

var mode := "menu"
var scene_kind := ""
var free_mode := false
var map_id := 0
var car: CharacterBody3D
var vis: Node3D
var wheel_spins: Array = []
var wheel_steers: Array = []
var preview_car: Node3D
var preview_id := -1
var camera_3d: Camera3D
var world_root: Node3D
var ui_layer: CanvasLayer
var ui: Control
var smoke: CPUParticles3D
var tail_mat: StandardMaterial3D
var body_mat: StandardMaterial3D
var preview_body_mat: StandardMaterial3D

# движение
var pos := Vector3.ZERO
var prev_pos := Vector3.ZERO
var vel := Vector3.ZERO
var y := 0.0
var vy := 0.0
var grounded := true
var climb_rate := 0.0
var pitch := 0.0
var roll := 0.0
var speed := 0.0
var yaw := 0.0
var cam_yaw := 0.0
var steer_vis := 0.0
var drifting := false
var rpm := 0.3
var gas_amt := 0.0
var brake_amt := 0.0
var skid_amt := 0.0
var held := {}
var touches := {}
var touch_zones := {}
var touch_pads := {}
var last_result := {}
var run_time := 0.0
var run_coins := 0
var hits := 0
var invincible := 0.0
var shake := 0.0
var best_jump := 0.0
var takeoff_pos := Vector3.ZERO
var obstacles: Array = []
var coin_nodes: Array = []
var ramps: Array = []
var boosts: Array = []
var tpos := PackedVector3Array()
var thead := PackedFloat32Array()
var prog_i := 3
var progress := 0.0
var car_half := Vector2(1.0, 2.0)
var wheel_r := 0.4

var status_label: Label
var speed_label: Label
var coins_label: Label
var hits_label: Label
var garage_msg: Label
var detail_label: Label
var gauge: Control

var music_player: AudioStreamPlayer
var click_player: AudioStreamPlayer
var engine_player: AudioStreamPlayer
var brake_player: AudioStreamPlayer
var skid_player: AudioStreamPlayer
var crash_player: AudioStreamPlayer
func _ready() -> void:
    randomize()
    _init_cars()
    _load_game()
    _setup_screen()
    _setup_audio()
    _setup_env()
    world_root = Node3D.new()
    add_child(world_root)
    ui_layer = CanvasLayer.new()
    add_child(ui_layer)
    _build_camera()
    get_viewport().size_changed.connect(_on_viewport_resized)
    _update_camera_aspect()
    show_menu()

func _init_cars() -> void:
    car_levels.clear()
    car_colors.clear()
    car_turbo.clear()
    for i in range(CARS.size()):
        car_levels.append({"Мотор": 1, "Подвеска": 1, "Колёса": 1, "Скорость": 1, "Тормоза": 1})
        car_colors.append(Color.html(str(CARS[i]["color"])))
        car_turbo.append(false)

func _car_f(id: int, key: String) -> float:
    return float(CARS[id][key])

func _lv(n: String) -> int:
    return int(car_levels[current_car][n])

func _db(v: float) -> float:
    if v < 0.001:
        return -80.0
    return linear_to_db(v)
# ======================= СОХРАНЕНИЕ =======================

func _save_game() -> void:
    var color_list: Array = []
    for c in car_colors:
        color_list.append(c.to_html(false))
    var data := {
        "coins": coins,
        "finishes": finishes,
        "owned": owned,
        "current_car": current_car,
        "car_levels": car_levels,
        "car_colors": color_list,
        "car_turbo": car_turbo,
        "controls": controls,
        "settings": settings,
    }
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f == null:
        return
    f.store_string(JSON.stringify(data))
    f.close()

func _load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return
    var parsed = JSON.parse_string(f.get_as_text())
    f.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    coins = int(parsed.get("coins", coins))
    finishes = int(parsed.get("finishes", 0))
    var o = parsed.get("owned", [])
    if typeof(o) == TYPE_ARRAY:
        for i in range(mini(o.size(), CARS.size())):
            owned[i] = bool(o[i])
    owned[0] = true
    var cl = parsed.get("car_levels", [])
    if typeof(cl) == TYPE_ARRAY:
        for i in range(mini(cl.size(), CARS.size())):
            if typeof(cl[i]) == TYPE_DICTIONARY:
                for n in UPGRADE_NAMES:
                    if cl[i].has(n):
                        car_levels[i][n] = clampi(int(cl[i][n]), 1, 5)
    var cc = parsed.get("car_colors", [])
    if typeof(cc) == TYPE_ARRAY:
        for i in range(mini(cc.size(), CARS.size())):
            car_colors[i] = Color.html(str(cc[i]))
    var tl = parsed.get("car_turbo", [])
    if typeof(tl) == TYPE_ARRAY:
        for i in range(mini(tl.size(), CARS.size())):
            car_turbo[i] = bool(tl[i])
    var ct = parsed.get("controls", {})
    if typeof(ct) == TYPE_DICTIONARY:
        for k in ["gas", "brake", "left", "right"]:
            if ct.has(k):
                controls[k] = int(ct[k])
        for k in ["swap_sides", "swap_lr", "swap_pedals"]:
            if ct.has(k):
                controls[k] = bool(ct[k])
    var st = parsed.get("settings", {})
    if typeof(st) == TYPE_DICTIONARY:
        for k in settings.keys():
            if st.has(k):
                settings[k] = st[k]
    current_car = clampi(int(parsed.get("current_car", 0)), 0, CARS.size() - 1)
    if not owned[current_car]:
        current_car = 0
    garage_sel = current_car

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        _save_game()
# ======================= ЗВУК (синтез кодом) =======================

func _make_wav(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
    var data := PackedByteArray()
    data.resize(samples.size() * 2)
    for i in range(samples.size()):
        var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
        data.encode_s16(i * 2, v)
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = rate
    wav.stereo = false
    wav.data = data
    if loop:
        wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
        wav.loop_begin = 0
        wav.loop_end = samples.size()
    return wav

func _make_music() -> AudioStreamWAV:
    var rate := 11025
    var step_len := 5512
    var lead := [440.0, 523.25, 659.25, 523.25, 587.33, 659.25, 783.99, 659.25, 440.0, 523.25, 659.25, 880.0, 783.99, 659.25, 587.33, 523.25]
    var bass := [110.0, 110.0, 130.81, 130.81, 98.0, 98.0, 146.83, 146.83, 110.0, 110.0, 130.81, 130.81, 98.0, 98.0, 87.31, 87.31]
    var total: int = step_len * lead.size()
    var samples := PackedFloat32Array()
    samples.resize(total)
    for n in range(total):
        var s: int = n / step_len
        var local: int = n - s * step_len
        var tg: float = float(n) / float(rate)
        var frac: float = float(local) / float(step_len)
        var env: float = (1.0 - frac) * (1.0 - frac)
        var lf: float = lead[s]
        var bf: float = bass[s]
        var sq: float = -1.0
        if fmod(tg * lf, 1.0) < 0.5:
            sq = 1.0
        var tri: float = absf(fmod(tg * bf, 1.0) * 2.0 - 1.0) * 2.0 - 1.0
        samples[n] = sq * 0.16 * env + tri * 0.28 * (0.6 + 0.4 * env)
    return _make_wav(samples, rate, true)

func _make_engine() -> AudioStreamWAV:
    var rate := 22050
    var period := 210
    var total := period * 24
    var samples := PackedFloat32Array()
    samples.resize(total)
    for n in range(total):
        var ph := float(n % period) / float(period)
        var saw := ph * 2.0 - 1.0
        var s1 := sin(TAU * ph)
        var s2 := sin(TAU * ph * 2.0)
        var s3 := sin(TAU * ph * 3.0)
        var pulse := 0.8 + 0.2 * sin(TAU * float(n) / float(total) * 6.0)
        samples[n] = (saw * 0.35 + s1 * 0.35 + s2 * 0.2 + s3 * 0.1) * 0.6 * pulse
    return _make_wav(samples, rate, true)

func _make_noise_stream(squeal: bool) -> AudioStreamWAV:
    var rate := 22050
    var total := 22050
    var samples := PackedFloat32Array()
    samples.resize(total)
    var lp := 0.0
    for n in range(total):
        var t := float(n) / float(rate)
        var noise := randf() * 2.0 - 1.0
        if squeal:
            samples[n] = noise * 0.25 + sin(TAU * 1180.0 * t) * 0.25 * (0.7 + 0.3 * sin(TAU * 7.0 * t))
        else:
            lp = lp + 0.25 * (noise - lp)
            samples[n] = lp * 0.9 + sin(TAU * 620.0 * t) * 0.18
    return _make_wav(samples, rate, true)

func _make_click() -> AudioStreamWAV:
    var rate := 22050
    var total := 1500
    var samples := PackedFloat32Array()
    samples.resize(total)
    for n in range(total):
        var t := float(n) / float(rate)
        samples[n] = sin(TAU * 1100.0 * t) * exp(-t * 55.0) * 0.8 + (randf() * 2.0 - 1.0) * exp(-t * 120.0) * 0.3
    return _make_wav(samples, rate, false)

func _make_crash() -> AudioStreamWAV:
    var rate := 22050
    var total := 9000
    var samples := PackedFloat32Array()
    samples.resize(total)
    var lp := 0.0
    for n in range(total):
        var t := float(n) / float(rate)
        var noise := randf() * 2.0 - 1.0
        lp = lp + 0.35 * (noise - lp)
        samples[n] = (lp * 0.9 + sin(TAU * 90.0 * t) * 0.5) * exp(-t * 7.0)
    return _make_wav(samples, rate, false)
func _new_player(stream: AudioStream, db: float) -> AudioStreamPlayer:
    var p := AudioStreamPlayer.new()
    p.stream = stream
    p.volume_db = db
    add_child(p)
    return p

func _setup_audio() -> void:
    music_player = _new_player(_make_music(), -6.0)
    click_player = _new_player(_make_click(), -4.0)
    engine_player = _new_player(_make_engine(), -80.0)
    brake_player = _new_player(_make_noise_stream(false), -80.0)
    skid_player = _new_player(_make_noise_stream(true), -80.0)
    crash_player = _new_player(_make_crash(), -2.0)
    _apply_volume()

func _apply_volume() -> void:
    AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(settings["volume"]))))

func _play_click() -> void:
    if bool(settings["click_on"]):
        click_player.pitch_scale = 1.0
        click_player.play()

func _update_music() -> void:
    var want: bool = bool(settings["music_on"]) and mode != "playing"
    if want and not music_player.playing:
        music_player.play()
    elif not want and music_player.playing:
        music_player.stop()

func _engine_sounds(on: bool) -> void:
    var list: Array = [engine_player, brake_player, skid_player]
    for p in list:
        var pl: AudioStreamPlayer = p
        if on and not pl.playing:
            pl.play()
        elif not on and pl.playing:
            pl.stop()

func _update_audio() -> void:
    var eng_on: bool = bool(settings["engine_on"])
    var bk_on: bool = bool(settings["brake_on"])
    var dr_on: bool = bool(settings["drift_on"])
    engine_player.pitch_scale = 0.7 + (rpm + gas_amt * 0.1) * 2.0
    var ev := 0.0
    if eng_on:
        ev = 0.22 + 0.5 * gas_amt
    engine_player.volume_db = _db(ev)
    var bv := 0.0
    if bk_on:
        bv = brake_amt * 0.8
    brake_player.volume_db = _db(bv)
    brake_player.pitch_scale = 0.8
    var sv := 0.0
    if dr_on:
        sv = skid_amt * 0.7
    skid_player.volume_db = _db(sv)
    skid_player.pitch_scale = 0.9 + skid_amt * 0.3
# ======================= ЭКРАН =======================

func _setup_screen() -> void:
    var window := get_window()
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
    window.content_scale_size = Vector2i(1280, 720)
    if OS.has_feature("android") or OS.has_feature("ios"):
        DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

func _vp() -> Vector2:
    return get_viewport().get_visible_rect().size

func _update_camera_aspect() -> void:
    if camera_3d == null:
        return
    var vp := _vp()
    if vp.x < vp.y:
        camera_3d.keep_aspect = Camera3D.KEEP_WIDTH
    else:
        camera_3d.keep_aspect = Camera3D.KEEP_HEIGHT

func _on_viewport_resized() -> void:
    if camera_3d == null:
        return
    _update_camera_aspect()
    match mode:
        "menu":
            show_menu()
        "maps":
            show_maps()
        "settings":
            show_settings()
        "controls":
            show_controls()
        "garage":
            show_garage()
        "upgrades":
            show_upgrades()
        "paint":
            show_paint()
        "playing":
            _build_hud()
        "result":
            _show_result()

func _build_camera() -> void:
    camera_3d = Camera3D.new()
    camera_3d.position = Vector3(0, 7, 12)
    camera_3d.near = 0.1
    camera_3d.far = 1500.0
    add_child(camera_3d)
    camera_3d.current = true

func _setup_env() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    sky.sky_material = ProceduralSkyMaterial.new()
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.9
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -30, 0)
    sun.shadow_enabled = SHADOWS
    sun.directional_shadow_max_distance = 120.0
    add_child(sun)
# ======================= ВВОД =======================

func _key_action(code: int) -> String:
    for a in ["gas", "brake", "left", "right"]:
        if int(controls[a]) == code or int(ALT_KEYS[a]) == code:
            return a
    return ""

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key := event as InputEventKey
        var code: int = int(key.physical_keycode)
        if code == 0:
            code = int(key.keycode)
        if waiting_key != "":
            if key.pressed and not key.echo:
                if code != KEY_ESCAPE:
                    controls[waiting_key] = code
                waiting_key = ""
                _save_game()
                show_controls()
            get_viewport().set_input_as_handled()
            return
        if key.pressed and not key.echo:
            var act := _key_action(code)
            if act != "":
                held[act] = true
            if code == KEY_R and mode == "playing" and free_mode:
                _respawn_car(true)
            if code == KEY_ESCAPE and mode == "playing":
                show_menu()
        elif not key.pressed:
            var act2 := _key_action(code)
            if act2 != "":
                held.erase(act2)
        return
    if mode != "playing":
        return
    if event is InputEventScreenTouch:
        var t := event as InputEventScreenTouch
        if t.pressed:
            _touch_set(t.index, t.position)
        else:
            touches.erase(t.index)
    elif event is InputEventScreenDrag:
        var d := event as InputEventScreenDrag
        _touch_set(d.index, d.position)
    elif event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT:
            if mb.pressed:
                _touch_set(-1, mb.position)
            else:
                touches.erase(-1)
    elif event is InputEventMouseMotion:
        var mm := event as InputEventMouseMotion
        if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
            _touch_set(-1, mm.position)

func _touch_set(index: int, p2: Vector2) -> void:
    var action := _zone_at(p2)
    if action == "":
        touches.erase(index)
    else:
        touches[index] = action

func _zone_at(p2: Vector2) -> String:
    for action in touch_zones:
        var rect: Rect2 = touch_zones[action]
        if rect.grow(8.0).has_point(p2):
            return str(action)
    return ""

func _pressed(action: String) -> bool:
    return held.has(action) or touches.values().has(action)
# ======================= ПОМОЩНИКИ ИНТЕРФЕЙСА =======================

func _clear_ui() -> void:
    if is_instance_valid(ui):
        ui.queue_free()
    ui = Control.new()
    ui.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_layer.add_child(ui)
    touch_zones.clear()
    touch_pads.clear()
    touches.clear()

func _label(text: String, fs: int = 28, color: Color = Color.WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", fs)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_outline_color", Color.BLACK)
    l.add_theme_constant_override("outline_size", 6)
    return l

func _clabel(text: String, fs: int = 28, color: Color = Color.WHITE) -> Label:
    var l := _label(text, fs, color)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return l

func _button(text: String, cb: Callable, w: float = 340.0, h: float = 56.0) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(w, h)
    b.add_theme_font_size_override("font_size", int(h * 0.46))
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(_on_button_pressed.bind(cb))
    return b

func _on_button_pressed(cb: Callable) -> void:
    _play_click()
    cb.call()

func _pair(a: Button, b: Button) -> HBoxContainer:
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 10)
    a.custom_minimum_size.x = 100
    b.custom_minimum_size.x = 100
    a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hb.add_child(a)
    hb.add_child(b)
    return hb

func _side_box(w: float) -> VBoxContainer:
    var mc := MarginContainer.new()
    mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(mc)
    mc.set_anchors_preset(Control.PRESET_FULL_RECT)
    for s in ["left", "right", "top", "bottom"]:
        mc.add_theme_constant_override("margin_" + str(s), 40)
    var vb := VBoxContainer.new()
    vb.custom_minimum_size = Vector2(w, 0)
    vb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    vb.add_theme_constant_override("separation", 10)
    mc.add_child(vb)
    return vb

func _center_box() -> VBoxContainer:
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.45)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(dim)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    var cc := CenterContainer.new()
    cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(cc)
    cc.set_anchors_preset(Control.PRESET_FULL_RECT)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 12)
    cc.add_child(vb)
    return vb
# ======================= ГЕОМЕТРИЯ =======================

func _rvec(h: float) -> Vector3:
    return Vector3(cos(h), 0.0, -sin(h))

func _tvec(h: float) -> Vector3:
    return Vector3(-sin(h), 0.0, -cos(h))

func _mat(col: Color, metal: float = 0.0, rough: float = 0.8) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.metallic = metal
    m.roughness = rough
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
    if (b - a).cross(c - a).dot(n) > 0.0:
        var t: Vector3 = b
        b = c
        c = t
    var vs: Array = [a, b, c]
    for v in vs:
        st.set_normal(n)
        st.add_vertex(v)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
    _tri(st, a, b, c, n)
    _tri(st, a, c, d, n)

func _add_box(parent: Node, size: Vector3, p: Vector3, mat: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mat
    mi.position = p
    parent.add_child(mi)
    return mi

func _add_mesh(st: SurfaceTool, col: Color) -> void:
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    mi.material_override = _mat(col, 0.0, 0.9)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world_root.add_child(mi)

func _add_multi(mm: MultiMesh, mat: Material) -> void:
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = mat
    world_root.add_child(mmi)

func _make_trees(positions: Array, crown_col: Color, rng: RandomNumberGenerator) -> void:
    var cnt: int = positions.size()
    if cnt == 0:
        return
    var trunk := MultiMesh.new()
    trunk.transform_format = MultiMesh.TRANSFORM_3D
    var cm := CylinderMesh.new()
    cm.top_radius = 0.25
    cm.bottom_radius = 0.38
    cm.height = 3.0
    trunk.mesh = cm
    trunk.instance_count = cnt
    var crown := MultiMesh.new()
    crown.transform_format = MultiMesh.TRANSFORM_3D
    var sm := SphereMesh.new()
    sm.radius = 2.0
    sm.height = 3.6
    crown.mesh = sm
    crown.instance_count = cnt
    for i in range(cnt):
        var p: Vector3 = positions[i]
        var s: float = rng.randf_range(0.8, 1.6)
        var bs := Basis.from_scale(Vector3(s, s, s))
        trunk.set_instance_transform(i, Transform3D(bs, p + Vector3(0, 1.5 * s, 0)))
        crown.set_instance_transform(i, Transform3D(bs, p + Vector3(0, 4.2 * s, 0)))
    _add_multi(trunk, _mat(Color(0.3, 0.18, 0.1)))
    _add_multi(crown, _mat(crown_col, 0.0, 0.9))
# ======================= МОДЕЛЬ МАШИНЫ =======================

func _build_car(id: int, col: Color, with_smoke: bool) -> Dictionary:
    var L: float = _car_f(id, "len")
    var W: float = _car_f(id, "wid")
    var R: float = _car_f(id, "wheel")
    var profs: Array = [
        [0.6, 0.55, 0.55, 0.05],
        [0.5, 0.42, 0.45, 0.08],
        [0.75, 0.65, 0.65, 0.1],
        [0.7, 0.6, 0.35, -0.12],
        [0.45, 0.38, 0.42, 0.02],
    ]
    var prof: Array = profs[id]
    var bh: float = prof[0]
    var ch: float = prof[1]
    var cl: float = prof[2]
    var cz: float = prof[3]
    var root := Node3D.new()
    var bmat := _mat(col, 0.5, 0.35)
    var glass := _mat(Color(0.07, 0.09, 0.13), 0.8, 0.1)
    var tail := _mat(Color(0.7, 0.0, 0.0))
    tail.emission_enabled = true
    tail.emission = Color(1, 0.05, 0.05)
    tail.emission_energy_multiplier = 0.6
    var head := _mat(Color(1, 0.95, 0.7))
    head.emission_enabled = true
    head.emission = Color(1, 0.95, 0.7)
    var tire := _mat(Color(0.05, 0.05, 0.05))
    var hub := _mat(Color(0.7, 0.7, 0.75), 0.8, 0.3)
    var by: float = R * 0.9
    _add_box(root, Vector3(W, bh, L), Vector3(0, by + bh * 0.5, 0), bmat)
    _add_box(root, Vector3(W * 0.82, ch, L * cl), Vector3(0, by + bh + ch * 0.5, L * cz), glass)
    _add_box(root, Vector3(W * 0.84, 0.06, L * cl), Vector3(0, by + bh + ch, L * cz), bmat)
    for sxv in [-1.0, 1.0]:
        var sx: float = sxv
        _add_box(root, Vector3(0.4, 0.18, 0.08), Vector3(sx * W * 0.34, by + bh * 0.7, L * 0.5), tail)
        _add_box(root, Vector3(0.4, 0.16, 0.08), Vector3(sx * W * 0.34, by + bh * 0.7, -L * 0.5), head)
    if id == 1 or id == 4:
        _add_box(root, Vector3(W * 0.9, 0.06, 0.4), Vector3(0, by + bh + 0.25, L * 0.46), bmat)
        for sxv2 in [-1.0, 1.0]:
            var sx2: float = sxv2
            _add_box(root, Vector3(0.06, 0.25, 0.1), Vector3(sx2 * W * 0.3, by + bh + 0.12, L * 0.46), bmat)
    if id == 3:
        _add_box(root, Vector3(W * 0.8, 0.03, L * 0.34), Vector3(0, by + bh + 0.016, L * 0.3), glass)
    var spins: Array = []
    var steers: Array = []
    for sxv3 in [-1.0, 1.0]:
        var sx3: float = sxv3
        for fzv in [-1.0, 1.0]:
            var fz: float = fzv
            var steer := Node3D.new()
            steer.position = Vector3(sx3 * (W * 0.5 - 0.12), R, fz * L * 0.32)
            var spin := Node3D.new()
            steer.add_child(spin)
            var mi := MeshInstance3D.new()
            var cyl := CylinderMesh.new()
            cyl.top_radius = R
            cyl.bottom_radius = R
            cyl.height = 0.32
            cyl.radial_segments = 20
            mi.mesh = cyl
            mi.rotation_degrees = Vector3(0, 0, 90)
            mi.material_override = tire
            spin.add_child(mi)
            _add_box(spin, Vector3(0.34, R * 1.5, 0.1), Vector3.ZERO, hub)
            root.add_child(steer)
            spins.append(spin)
            if fz < 0.0:
                steers.append(steer)
    var sm: CPUParticles3D = null
    if with_smoke:
        sm = CPUParticles3D.new()
        sm.amount = 24
        sm.lifetime = 1.2
        sm.emitting = false
        var sph := SphereMesh.new()
        sph.radius = 0.28
        sph.height = 0.56
        sph.radial_segments = 8
        sph.rings = 4
        var smat := StandardMaterial3D.new()
        smat.albedo_color = Color(0.75, 0.75, 0.75, 0.5)
        smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        sph.material = smat
        sm.mesh = sph
        sm.direction = Vector3(0, 0.4, 1)
        sm.spread = 25.0
        sm.initial_velocity_min = 1.0
        sm.initial_velocity_max = 2.5
        sm.gravity = Vector3(0, 0.6, 0)
        sm.scale_amount_min = 0.6
        sm.scale_amount_max = 1.5
        sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        sm.position = Vector3(0, by + 0.2, L * 0.5)
        root.add_child(sm)
    return {"root": root, "body": bmat, "tail": tail, "spins": spins, "steers": steers, "smoke": sm}
# ======================= СЦЕНЫ И МЕНЮ =======================

func _clear_world() -> void:
    for c in world_root.get_children():
        c.queue_free()
    car = null
    vis = null
    smoke = null
    tail_mat = null
    body_mat = null
    preview_car = null
    preview_id = -1
    preview_body_mat = null
    wheel_spins = []
    wheel_steers = []
    obstacles = []
    coin_nodes = []
    ramps = []
    boosts = []
    scene_kind = ""

func _enter_showroom() -> void:
    if scene_kind != "showroom":
        _clear_world()
        scene_kind = "showroom"
        var fl := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 7.0
        cm.bottom_radius = 7.0
        cm.height = 0.2
        fl.mesh = cm
        fl.position = Vector3(0, -0.1, 0)
        fl.material_override = _mat(Color(0.22, 0.24, 0.3), 0.3, 0.5)
        world_root.add_child(fl)
    camera_3d.fov = 55.0
    camera_3d.position = Vector3(1.0, 2.2, 8.0)
    camera_3d.look_at(Vector3(-1.6, 0.7, 0.0), Vector3.UP)

func _show_preview(id: int) -> void:
    if preview_car != null and is_instance_valid(preview_car) and preview_id == id:
        preview_body_mat.albedo_color = car_colors[id]
        return
    if preview_car != null and is_instance_valid(preview_car):
        preview_car.queue_free()
    var d: Dictionary = _build_car(id, car_colors[id], false)
    preview_car = d["root"]
    preview_body_mat = d["body"]
    preview_id = id
    preview_car.rotation.y = 0.5
    world_root.add_child(preview_car)

func _fmt_time(t: float) -> String:
    return "%d:%02d.%d" % [floori(t / 60.0), int(t) % 60, int(fmod(t, 1.0) * 10.0)]

func _take_flash() -> Label:
    garage_msg = _label(flash, 22, GOLD)
    flash = ""
    return garage_msg

# ---------- Главное меню ----------
func show_menu() -> void:
    mode = "menu"
    _enter_showroom()
    _show_preview(current_car)
    _engine_sounds(false)
    _update_music()
    _clear_ui()
    var vb := _center_box()
    vb.add_child(_clabel("ГОНКИ", 68, GOLD))
    vb.add_child(_clabel("Монеты: %d" % coins, 30))
    vb.add_child(_button("Играть", show_maps, 380, 62))
    vb.add_child(_button("Свободная игра", start_free, 380, 62))
    vb.add_child(_button("Гараж", show_garage, 380, 62))
    vb.add_child(_button("Настройки", show_settings, 380, 62))

# ---------- Выбор карты ----------
func show_maps() -> void:
    mode = "maps"
    _enter_showroom()
    _show_preview(current_car)
    _clear_ui()
    var vb := _center_box()
    vb.add_child(_clabel("ВЫБЕРИ КАРТУ", 46, GOLD))
    vb.add_child(_clabel("Монеты: %d" % coins, 28))
    for i in range(MAPS.size()):
        var m: Dictionary = MAPS[i]
        vb.add_child(_button("%s  •  3 км  •  награда %d" % [m["name"], m["reward"]], start_race.bind(i), 600, 62))
        vb.add_child(_clabel(str(m["info"]), 20))
    vb.add_child(_button("Назад", show_menu, 600, 56))

# ---------- Настройки ----------
func show_settings() -> void:
    mode = "settings"
    _enter_showroom()
    _show_preview(current_car)
    _clear_ui()
    var vb := _center_box()
    vb.add_child(_clabel("НАСТРОЙКИ", 44))
    var items: Array = [["music_on", "Музыка"], ["engine_on", "Звук двигателя"], ["brake_on", "Звук тормоза"], ["drift_on", "Звук заноса"], ["click_on", "Звук кнопок"]]
    for it in items:
        var on: bool = bool(settings[it[0]])
        var state_txt: String = "ВКЛ" if on else "ВЫКЛ"
        vb.add_child(_button("%s: %s" % [it[1], state_txt], _toggle_setting.bind(it[0]), 440, 50))
    vb.add_child(_clabel("Громкость", 24))
    var sl := HSlider.new()
    sl.min_value = 0.0
    sl.max_value = 1.0
    sl.step = 0.05
    sl.value = float(settings["volume"])
    sl.custom_minimum_size = Vector2(440, 32)
    sl.value_changed.connect(_on_volume)
    sl.drag_ended.connect(_on_volume_end)
    vb.add_child(sl)
    vb.add_child(_button("Управление", show_controls, 440, 52))
    vb.add_child(_button("Назад", show_menu, 440, 52))

func _toggle_setting(key: String) -> void:
    settings[key] = not bool(settings[key])
    _save_game()
    _update_music()
    show_settings()

func _on_volume(v: float) -> void:
    settings["volume"] = v
    _apply_volume()

func _on_volume_end(_changed: bool) -> void:
    _save_game()

# ---------- Управление ----------
func show_controls() -> void:
    mode = "controls"
    _enter_showroom()
    _show_preview(current_car)
    _clear_ui()
    var vb := _center_box()
    vb.add_child(_clabel("УПРАВЛЕНИЕ", 44))
    vb.add_child(_clabel("Стрелки тоже работают", 20))
    for a in ["gas", "brake", "left", "right"]:
        var t: String = str(ACTION_NAMES[a]) + ": "
        if waiting_key == a:
            t += "нажми клавишу..."
        else:
            t += OS.get_keycode_string(int(controls[a]))
        vb.add_child(_button(t, _start_rebind.bind(a), 440, 50))
    vb.add_child(_button("Педали: " + ("слева" if bool(controls["swap_sides"]) else "справа"), _toggle_control.bind("swap_sides"), 440, 50))
    vb.add_child(_button("Влево/вправо: " + ("поменяны" if bool(controls["swap_lr"]) else "обычные"), _toggle_control.bind("swap_lr"), 440, 50))
    vb.add_child(_button("Газ/тормоз: " + ("поменяны" if bool(controls["swap_pedals"]) else "обычные"), _toggle_control.bind("swap_pedals"), 440, 50))
    vb.add_child(_button("Назад", show_settings, 440, 52))

func _start_rebind(a: String) -> void:
    waiting_key = a
    show_controls()

func _toggle_control(k: String) -> void:
    controls[k] = not bool(controls[k])
    _save_game()
    show_controls()
# ---------- Гараж ----------
func show_garage() -> void:
    mode = "garage"
    _enter_showroom()
    _show_preview(garage_sel)
    _engine_sounds(false)
    _update_music()
    _clear_ui()
    var c: Dictionary = CARS[garage_sel]
    var vb := _side_box(380)
    vb.add_child(_label("ГАРАЖ", 40))
    vb.add_child(_label("Монеты: %d" % coins, 28, GOLD))
    vb.add_child(_label(str(c["name"]), 34))
    vb.add_child(_label(str(c["info"]), 22))
    vb.add_child(_label("Мотор: %d%%" % int(float(c["engine"]) * 100.0), 22))
    vb.add_child(_label("Скорость: %d%%" % int(float(c["speed"]) * 100.0), 22))
    vb.add_child(_label("Сцепление: %d%%" % int(float(c["grip"]) * 100.0), 22))
    vb.add_child(_pair(_button("<", _garage_step.bind(-1), 100, 50), _button(">", _garage_step.bind(1), 100, 50)))
    var b: Button
    if owned[garage_sel]:
        var sel: bool = current_car == garage_sel
        b = _button("• Выбрана" if sel else "Выбрать", _garage_action, 380, 52)
        b.disabled = sel
    else:
        b = _button("Купить за %d" % int(c["price"]), _garage_action, 380, 52)
    vb.add_child(b)
    vb.add_child(_button("Улучшения", _open_upgrades, 380, 52))
    vb.add_child(_button("Покраска", _open_paint, 380, 52))
    vb.add_child(_take_flash())
    vb.add_child(_button("Назад", show_menu, 380, 52))

func _garage_step(d: int) -> void:
    garage_sel = wrapi(garage_sel + d, 0, CARS.size())
    show_garage()

func _garage_action() -> void:
    var c: Dictionary = CARS[garage_sel]
    if owned[garage_sel]:
        current_car = garage_sel
        flash = "Машина выбрана"
    elif coins >= int(c["price"]):
        coins -= int(c["price"])
        owned[garage_sel] = true
        current_car = garage_sel
        flash = "Куплено!"
    else:
        flash = "Не хватает монет"
    _save_game()
    show_garage()

func _open_upgrades() -> void:
    if not owned[garage_sel]:
        flash = "Сначала купи машину"
        show_garage()
        return
    current_car = garage_sel
    show_upgrades()

func _open_paint() -> void:
    if not owned[garage_sel]:
        flash = "Сначала купи машину"
        show_garage()
        return
    current_car = garage_sel
    show_paint()

# ---------- Улучшения ----------
func show_upgrades() -> void:
    mode = "upgrades"
    _enter_showroom()
    _show_preview(current_car)
    _clear_ui()
    var vb := _side_box(400)
    vb.add_child(_label("УЛУЧШЕНИЯ", 40))
    vb.add_child(_label("Монеты: %d" % coins, 28, GOLD))
    for n in UPGRADE_NAMES:
        var bt := _button("%s   %d/5" % [n, _lv(n)], _select_upgrade.bind(n), 380, 48)
        if n == selected_upgrade:
            bt.add_theme_color_override("font_color", GOLD)
        vb.add_child(bt)
    var lv: int = _lv(selected_upgrade)
    detail_label = _label(str(UPGRADE_INFO[selected_upgrade]), 22)
    vb.add_child(detail_label)
    if lv < 5:
        vb.add_child(_button("Улучшить: %d" % (UPGRADE_COST * lv), _buy_upgrade, 380, 52))
    else:
        var mx := _button("Максимум", _buy_upgrade, 380, 52)
        mx.disabled = true
        vb.add_child(mx)
    if bool(car_turbo[current_car]):
        var tb := _button("Турбо куплено (свободная игра)", _buy_turbo, 380, 48)
        tb.disabled = true
        vb.add_child(tb)
    else:
        vb.add_child(_button("Турбо 1000 км/ч: %d" % TURBO_COST, _buy_turbo, 380, 48))
    vb.add_child(_take_flash())
    vb.add_child(_button("Назад", show_garage, 380, 52))

func _select_upgrade(n: String) -> void:
    selected_upgrade = n
    show_upgrades()

func _buy_upgrade() -> void:
    var lv: int = _lv(selected_upgrade)
    if lv >= 5:
        return
    var cost: int = UPGRADE_COST * lv
    if coins >= cost:
        coins -= cost
        car_levels[current_car][selected_upgrade] = lv + 1
        flash = "Улучшено!"
        _save_game()
    else:
        flash = "Не хватает монет"
    show_upgrades()

func _buy_turbo() -> void:
    if bool(car_turbo[current_car]):
        return
    if coins >= TURBO_COST:
        coins -= TURBO_COST
        car_turbo[current_car] = true
        flash = "Турбо куплено!"
        _save_game()
    else:
        flash = "Не хватает монет"
    show_upgrades()

# ---------- Покраска ----------
func show_paint() -> void:
    mode = "paint"
    _enter_showroom()
    _show_preview(current_car)
    _clear_ui()
    var col: Color = car_colors[current_car]
    paint_h = col.h
    paint_s = col.s
    paint_v = col.v
    var vb := _side_box(380)
    vb.add_child(_label("ПОКРАСКА", 40))
    vb.add_child(_label(str(CARS[current_car]["name"]), 28))
    var vals := {"h": paint_h, "s": paint_s, "v": paint_v}
    var rows: Array = [["Оттенок", "h"], ["Насыщенность", "s"], ["Яркость", "v"]]
    for it in rows:
        vb.add_child(_label(str(it[0]), 24))
        var sl := HSlider.new()
        sl.min_value = 0.0
        sl.max_value = 1.0
        sl.step = 0.01
        sl.value = float(vals[it[1]])
        sl.custom_minimum_size = Vector2(360, 32)
        sl.value_changed.connect(_on_paint.bind(str(it[1])))
        vb.add_child(sl)
    vb.add_child(_button("Цвет по умолчанию", _paint_default, 380, 50))
    vb.add_child(_button("Готово", _paint_done, 380, 52))

func _on_paint(v: float, which: String) -> void:
    match which:
        "h":
            paint_h = v
        "s":
            paint_s = v
        "v":
            paint_v = v
    var col := Color.from_hsv(paint_h, paint_s, paint_v)
    car_colors[current_car] = col
    if preview_body_mat != null:
        preview_body_mat.albedo_color = col

func _paint_default() -> void:
    car_colors[current_car] = Color.html(str(CARS[current_car]["color"]))
    show_paint()

func _paint_done() -> void:
    _save_game()
    show_garage()
# ======================= ТРАССА (повороты влево/вправо) =======================

func _gen_track(id: int) -> void:
    var m: Dictionary = MAPS[id]
    var rng := RandomNumberGenerator.new()
    rng.seed = int(m["seed"])
    var n: int = int(TRACK_LEN / STEP)
    var dh := PackedFloat32Array()
    dh.resize(n)
    var i: int = 18
    var hsum: float = 0.0
    while i < n - 18:
        if rng.randf() < float(m["curve"]):
            var cl: int = rng.randi_range(int(m["c_min"]), int(m["c_max"]))
            var ang: float = deg_to_rad(rng.randf_range(float(m["a_min"]), float(m["a_max"])))
            var sgn: float = 1.0 if rng.randf() < 0.5 else -1.0
            if absf(hsum) > deg_to_rad(100.0):
                sgn = -signf(hsum)
            for k in range(cl):
                if i + k < n - 18:
                    dh[i + k] = sgn * ang / float(cl)
            hsum += sgn * ang
            i += cl
        else:
            i += rng.randi_range(4, 12)
    tpos = PackedVector3Array()
    thead = PackedFloat32Array()
    var p := Vector3.ZERO
    var h: float = 0.0
    tpos.append(p)
    thead.append(h)
    for k in range(n):
        h += dh[k]
        p += _tvec(h) * STEP
        tpos.append(p)
        thead.append(h)

func _build_race_world(id: int) -> void:
    var m: Dictionary = MAPS[id]
    _gen_track(id)
    var mn := Vector2(1.0e9, 1.0e9)
    var mx := Vector2(-1.0e9, -1.0e9)
    for i in range(tpos.size()):
        var tp0: Vector3 = tpos[i]
        mn.x = minf(mn.x, tp0.x)
        mn.y = minf(mn.y, tp0.z)
        mx.x = maxf(mx.x, tp0.x)
        mx.y = maxf(mx.y, tp0.z)
    var ground := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(9000, 9000)
    ground.mesh = pm
    ground.position = Vector3((mn.x + mx.x) * 0.5, -0.02, (mn.y + mx.y) * 0.5)
    ground.material_override = _mat(Color.html(str(m["ground"])), 0.0, 1.0)
    ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world_root.add_child(ground)
    _build_road_meshes()
    _gate(1, "СТАРТ", Color(0.1, 0.65, 0.2))
    _gate(tpos.size() - 1, "ФИНИШ", Color(0.85, 0.1, 0.1))
    _place_items(m)
    var rng := RandomNumberGenerator.new()
    rng.seed = int(m["seed"]) + 99
    var tp: Array = []
    for i in range(0, tpos.size(), 4):
        for sv in [-1.0, 1.0]:
            var s: float = sv
            var lat: float = s * rng.randf_range(11.0, 45.0)
            var along: float = rng.randf_range(-6.0, 6.0)
            tp.append(tpos[i] + _rvec(thead[i]) * lat + _tvec(thead[i]) * along)
    _make_trees(tp, Color.html(str(m["trees"])), rng)

func _build_road_meshes() -> void:
    var st_road := SurfaceTool.new()
    var st_line := SurfaceTool.new()
    var st_wa := SurfaceTool.new()
    var st_wb := SurfaceTool.new()
    var all_st: Array = [st_road, st_line, st_wa, st_wb]
    for s in all_st:
        var sst: SurfaceTool = s
        sst.begin(Mesh.PRIMITIVE_TRIANGLES)
    var up := Vector3(0, 0.01, 0)
    var up2 := Vector3(0, 0.02, 0)
    var wh := Vector3(0, 0.9, 0)
    for i in range(tpos.size() - 1):
        var a: Vector3 = tpos[i]
        var b: Vector3 = tpos[i + 1]
        var ra: Vector3 = _rvec(thead[i])
        var rb: Vector3 = _rvec(thead[i + 1])
        _quad(st_road, a - ra * ROAD_HALF + up, a + ra * ROAD_HALF + up, b + rb * ROAD_HALF + up, b - rb * ROAD_HALF + up, Vector3.UP)
        var edge_offs: Array = [-ROAD_HALF + 0.5, ROAD_HALF - 0.5]
        for offv in edge_offs:
            var off: float = offv
            _quad(st_line, a + ra * (off - 0.1) + up2, a + ra * (off + 0.1) + up2, b + rb * (off + 0.1) + up2, b + rb * (off - 0.1) + up2, Vector3.UP)
        if i % 2 == 0:
            var mid: Vector3 = a.lerp(b, 0.5)
            var rm: Vector3 = ra.lerp(rb, 0.5).normalized()
            var dash_offs: Array = [-3.15, -1.05, 1.05, 3.15]
            for off2v in dash_offs:
                var off2: float = off2v
                _quad(st_line, a + ra * (off2 - 0.09) + up2, a + ra * (off2 + 0.09) + up2, mid + rm * (off2 + 0.09) + up2, mid + rm * (off2 - 0.09) + up2, Vector3.UP)
        var stw: SurfaceTool = st_wa if ((i >> 1) & 1) == 0 else st_wb
        var sides: Array = [-1.0, 1.0]
        for sdv in sides:
            var sd: float = sdv
            var e0: Vector3 = a + ra * sd * (ROAD_HALF + 0.35)
            var e1: Vector3 = b + rb * sd * (ROAD_HALF + 0.35)
            _quad(stw, e0, e1, e1 + wh, e0 + wh, -ra * sd)
            _quad(stw, e0 + wh - ra * sd * 0.2, e1 + wh - rb * sd * 0.2, e1 + wh + rb * sd * 0.2, e0 + wh + ra * sd * 0.2, Vector3.UP)
    _add_mesh(st_road, Color(0.13, 0.14, 0.17))
    _add_mesh(st_line, Color(0.9, 0.9, 0.9))
    _add_mesh(st_wa, Color(0.95, 0.95, 0.95))
    _add_mesh(st_wb, Color(0.85, 0.12, 0.12))

func _gate(i: int, txt: String, col: Color) -> void:
    var g := Node3D.new()
    g.position = tpos[i]
    g.rotation.y = thead[i]
    var m := _mat(col, 0.2, 0.6)
    _add_box(g, Vector3(0.6, 7.0, 0.6), Vector3(-ROAD_HALF - 0.8, 3.5, 0), m)
    _add_box(g, Vector3(0.6, 7.0, 0.6), Vector3(ROAD_HALF + 0.8, 3.5, 0), m)
    _add_box(g, Vector3(ROAD_HALF * 2.0 + 2.2, 1.4, 0.6), Vector3(0, 7.2, 0), m)
    _add_box(g, Vector3(ROAD_HALF * 2.0, 0.03, 1.4), Vector3(0, 0.035, 0), _mat(Color.WHITE))
    var l := Label3D.new()
    l.text = txt
    l.font_size = 96
    l.pixel_size = 0.012
    l.outline_size = 12
    l.position = Vector3(0, 7.2, 0.35)
    g.add_child(l)
    world_root.add_child(g)

func _place_items(m: Dictionary) -> void:
    obstacles = []
    coin_nodes = []
    var rng := RandomNumberGenerator.new()
    rng.seed = int(m["seed"]) + 7
    var n: int = tpos.size()
    var i: int = 22
    while i < n - 20:
        var lanes: Array = [0, 1, 2, 3, 4]
        lanes.shuffle()
        var base: Vector3 = tpos[i]
        var rv: Vector3 = _rvec(thead[i])
        if rng.randf() < float(m["obst"]):
            var cnt: int = rng.randi_range(1, 3)
            for k in range(cnt):
                var lane_x: float = float(LANES[int(lanes[k])])
                var is_crate: bool = rng.randi_range(0, 1) == 0
                _add_obstacle(base + rv * lane_x, is_crate, thead[i])
        elif rng.randf() < 0.45:
            var ln: int = int(lanes[0])
            for k in range(4):
                var j: int = mini(i + k, n - 1)
                _add_coin(tpos[j] + _rvec(thead[j]) * float(LANES[ln]))
        i += rng.randi_range(5, 8)

func _add_obstacle(p: Vector3, crate: bool, h: float) -> void:
    var nd := Node3D.new()
    nd.position = p
    nd.rotation.y = h
    if crate:
        _add_box(nd, Vector3(1.5, 1.5, 1.5), Vector3(0, 0.75, 0), _mat(Color(0.55, 0.35, 0.15)))
    else:
        _add_box(nd, Vector3(2.0, 0.9, 0.45), Vector3(0, 0.75, 0), _mat(Color(0.85, 0.1, 0.1)))
        _add_box(nd, Vector3(0.15, 0.7, 0.15), Vector3(-0.8, 0.35, 0), _mat(Color.WHITE))
        _add_box(nd, Vector3(0.15, 0.7, 0.15), Vector3(0.8, 0.35, 0), _mat(Color.WHITE))
    world_root.add_child(nd)
    obstacles.append({"pos": p, "node": nd, "alive": true})

func _add_coin(p: Vector3) -> void:
    var nd := Node3D.new()
    nd.position = p + Vector3(0, 1.0, 0)
    var mi := MeshInstance3D.new()
    var cy := CylinderMesh.new()
    cy.top_radius = 0.5
    cy.bottom_radius = 0.5
    cy.height = 0.12
    mi.mesh = cy
    mi.rotation_degrees = Vector3(90, 0, 0)
    var gm := _mat(GOLD, 0.8, 0.3)
    gm.emission_enabled = true
    gm.emission = GOLD
    gm.emission_energy_multiplier = 0.5
    mi.material_override = gm
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    nd.add_child(mi)
    world_root.add_child(nd)
    coin_nodes.append({"pos": nd.position, "node": nd, "alive": true})

# ======================= СВОБОДНАЯ КАРТА (трамплины) =======================

func _free_road(size: Vector3, p: Vector3, mat: Material) -> void:
    var mi := _add_box(world_root, size, p, mat)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _add_ramp(p: Vector3, yw: float, L: float, W: float, H: float) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var A := Vector3(-W * 0.5, 0, 0)
    var B := Vector3(W * 0.5, 0, 0)
    var C := Vector3(-W * 0.5, H, -L)
    var D := Vector3(W * 0.5, H, -L)
    var E := Vector3(-W * 0.5, 0, -L)
    var F := Vector3(W * 0.5, 0, -L)
    _quad(st, A, B, D, C, Vector3(0, L, H).normalized())
    _quad(st, E, F, D, C, Vector3(0, 0, -1))
    _tri(st, A, C, E, Vector3(-1, 0, 0))
    _tri(st, B, D, F, Vector3(1, 0, 0))
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    var hue: float = clampf(H / 16.0, 0.0, 1.0)
    mi.material_override = _mat(Color.from_hsv(0.08 + hue * 0.7, 0.85, 0.95), 0.1, 0.6)
    mi.position = p
    mi.rotation.y = yw
    world_root.add_child(mi)
    ramps.append({"pos": p, "yaw": yw, "L": L, "W": W, "H": H, "rad": sqrt(L * L + W * W * 0.25) + 1.0})

func _add_boost(p: Vector3) -> void:
    boosts.append(p)
    var bm := _mat(Color(1.0, 0.6, 0.1), 0.0, 0.5)
    bm.emission_enabled = true
    bm.emission = Color(1.0, 0.5, 0.0)
    bm.emission_energy_multiplier = 1.5
    var mi := _add_box(world_root, Vector3(6, 0.04, 8), p + Vector3(0, 0.03, 0), bm)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_free_world() -> void:
    ramps = []
    boosts = []
    var ground := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(2600, 2600)
    ground.mesh = pm
    ground.position.y = -0.02
    ground.material_override = _mat(Color.html("3b8f3b"), 0.0, 1.0)
    ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world_root.add_child(ground)
    var road := _mat(Color(0.14, 0.15, 0.18), 0.0, 0.9)
    for k in range(-7, 8):
        var c: float = float(k) * 130.0
        _free_road(Vector3(2000, 0.02, 7), Vector3(0, -0.005, c), road)
        _free_road(Vector3(7, 0.02, 2000), Vector3(c, -0.005, 0), road)
    var wm := _mat(Color(0.6, 0.25, 0.2))
    for sv in [-1.0, 1.0]:
        var s: float = sv
        _add_box(world_root, Vector3(2000, 8, 2), Vector3(0, 4, s * FREE_HALF), wm)
        _add_box(world_root, Vector3(2, 8, 2000), Vector3(s * FREE_HALF, 4, 0), wm)
    var rng := RandomNumberGenerator.new()
    rng.seed = 4242
    # ряд трамплинов вперёд (растут по высоте) + ускорители перед ними
    for k in range(10):
        var h: float = 1.5 + float(k) * 0.6
        var rz: float = -80.0 - float(k) * 60.0
        _add_ramp(Vector3(0, 0, rz), 0.0, 10.0 + h * 3.0, 9.0, h)
        _add_boost(Vector3(0, 0, rz + 22.0))
    # мега-трамплин
    _add_boost(Vector3(0, 0, -668))
    _add_ramp(Vector3(0, 0, -700), 0.0, 48.0, 16.0, 15.0)
    # стена трамплинов позади
    for k in range(-3, 4):
        _add_ramp(Vector3(float(k) * 20.0, 0, 200), PI, 24.0, 12.0, 5.0)
    # кольцо трамплинов вокруг старта
    for k in range(12):
        var a: float = TAU * float(k) / 12.0
        var rp := Vector3(cos(a), 0, sin(a)) * 150.0
        _add_ramp(rp, atan2(rp.x, rp.z), 20.0, 10.0, 4.5)
    # случайные трамплины по всей карте
    var made: int = 0
    while made < 60:
        var p := Vector3(rng.randf_range(-900, 900), 0, rng.randf_range(-900, 900))
        if Vector2(p.x, p.z).length() < 90.0:
            continue
        var h2: float = rng.randf_range(2.0, 7.0)
        _add_ramp(p, rng.randf_range(0.0, TAU), 10.0 + h2 * 2.5, rng.randf_range(7.0, 12.0), h2)
        made += 1
    # деревья за стенами
    var tp: Array = []
    for k in range(160):
        var t: float = rng.randf_range(-1000.0, 1000.0)
        var d: float = FREE_HALF + rng.randf_range(15.0, 80.0)
        match rng.randi_range(0, 3):
            0:
                tp.append(Vector3(t, 0, d))
            1:
                tp.append(Vector3(t, 0, -d))
            2:
                tp.append(Vector3(d, 0, t))
            _:
                tp.append(Vector3(-d, 0, t))
    _make_trees(tp, Color.html("1f6d24"), rng)

func _ground_h(p: Vector3) -> float:
    var best: float = 0.0
    for r in ramps:
        var rp: Vector3 = r["pos"]
        var dx: float = p.x - rp.x
        var dz: float = p.z - rp.z
        var rad: float = r["rad"]
        if dx * dx + dz * dz > rad * rad:
            continue
        var loc: Vector3 = Vector3(dx, 0.0, dz).rotated(Vector3.UP, -float(r["yaw"]))
        var u: float = -loc.z / float(r["L"])
        if u >= 0.0 and u <= 1.0 and absf(loc.x) <= float(r["W"]) * 0.5:
            best = maxf(best, float(r["H"]) * u)
    return best
# ======================= СТАРТ ЗАЕЗДА =======================

func start_race(id: int) -> void:
    free_mode = false
    map_id = id
    _clear_world()
    scene_kind = "race"
    _build_race_world(id)
    _spawn_car()
    _reset_run()
    _begin_run()

func start_free() -> void:
    free_mode = true
    _clear_world()
    scene_kind = "free"
    _build_free_world()
    _spawn_car()
    _reset_run()
    _begin_run()

func _spawn_car() -> void:
    var d: Dictionary = _build_car(current_car, car_colors[current_car], true)
    car = CharacterBody3D.new()
    vis = d["root"]
    car.add_child(vis)
    world_root.add_child(car)
    body_mat = d["body"]
    tail_mat = d["tail"]
    wheel_spins = d["spins"]
    wheel_steers = d["steers"]
    smoke = d["smoke"]
    car_half = Vector2(_car_f(current_car, "wid") * 0.5, _car_f(current_car, "len") * 0.5)
    wheel_r = _car_f(current_car, "wheel")

func _reset_run() -> void:
    speed = 0.0
    vel = Vector3.ZERO
    y = 0.0
    vy = 0.0
    grounded = true
    climb_rate = 0.0
    pitch = 0.0
    roll = 0.0
    steer_vis = 0.0
    gas_amt = 0.0
    brake_amt = 0.0
    skid_amt = 0.0
    hits = 0
    invincible = 0.0
    shake = 0.0
    run_time = 0.0
    run_coins = 0
    best_jump = 0.0
    if free_mode:
        pos = Vector3(0, 0, 60)
        yaw = 0.0
    else:
        pos = tpos[3]
        yaw = thead[3]
        prog_i = 3
        progress = 12.0
    prev_pos = pos
    cam_yaw = yaw

func _begin_run() -> void:
    mode = "playing"
    _apply_car_transform()
    _update_camera(1.0)
    _build_hud()
    _engine_sounds(true)
    _update_music()

func _respawn_car(_reset_all: bool = true) -> void:
    if car == null:
        return
    _reset_run()
    _apply_car_transform()
    _update_camera(1.0)

func _apply_car_transform() -> void:
    car.position = Vector3(pos.x, y, pos.z)
    car.rotation.y = yaw
    vis.rotation.x = pitch
    vis.rotation.z = roll

# ======================= ХАРАКТЕРИСТИКИ =======================

func _vmax() -> float:
    if free_mode and bool(car_turbo[current_car]):
        return TURBO_MAX_KMH / 3.6
    return NORMAL_MAX_KMH / 3.6 * _car_f(current_car, "speed") * (1.0 + 0.05 * float(_lv("Скорость") - 1))

func _acc() -> float:
    var a: float = 13.0 * _car_f(current_car, "engine") * (1.0 + 0.12 * float(_lv("Мотор") - 1)) * pow(1000.0 / _car_f(current_car, "mass"), 0.3)
    if free_mode and bool(car_turbo[current_car]):
        a *= 3.5
    return a

# ======================= ГЛАВНЫЙ ЦИКЛ =======================

func _process(delta: float) -> void:
    var dt: float = minf(delta, 0.05)
    if mode == "playing":
        _update_race(dt)
        if mode == "playing":
            _update_hud()
            _update_audio()
            for c in coin_nodes:
                if c["alive"]:
                    (c["node"] as Node3D).rotation.y += dt * 3.0
    elif preview_car != null and is_instance_valid(preview_car):
        preview_car.rotation.y += dt * 0.5

func _update_race(dt: float) -> void:
    run_time += dt
    invincible = maxf(0.0, invincible - dt)
    shake = maxf(0.0, shake - dt * 2.5)
    var vmax: float = _vmax()
    var g: bool = _pressed("gas")
    var b: bool = _pressed("brake")
    var st_in: float = 0.0
    if _pressed("left"):
        st_in += 1.0
    if _pressed("right"):
        st_in -= 1.0
    gas_amt = move_toward(gas_amt, 1.0 if g else 0.0, dt * 4.0)
    brake_amt = move_toward(brake_amt, 1.0 if b else 0.0, dt * 6.0)
    steer_vis = move_toward(steer_vis, st_in, dt * 4.0)
    var brk: float = 30.0 * (1.0 + 0.12 * float(_lv("Тормоза") - 1))
    if grounded:
        if g:
            if speed < -0.5:
                speed = move_toward(speed, 0.0, brk * dt)
            else:
                speed += _acc() * gas_amt * (1.0 - pow(clampf(speed / vmax, 0.0, 1.0), 3.0)) * dt
        if b:
            if speed > 0.5:
                speed = maxf(0.0, speed - brk * brake_amt * dt)
            elif not g:
                speed = move_toward(speed, -8.0, 6.0 * dt)
    if speed > 0.0:
        var drag: float = (0.8 + 0.0006 * speed * speed) * (0.3 if g else 1.0)
        speed = maxf(0.0, speed - drag * dt)
    elif speed < 0.0:
        speed = minf(0.0, speed + 3.0 * dt)
    if speed > vmax:
        speed = move_toward(speed, vmax, 20.0 * dt)
    # РУЛЕНИЕ: машина по-настоящему поворачивается
    var grip: float = _car_f(current_car, "grip") * (1.0 + 0.08 * float(_lv("Колёса") - 1))
    var stab: float = 1.0 + 0.07 * float(_lv("Подвеска") - 1)
    var av: float = absf(speed)
    var rate: float = 2.1 * grip / (1.0 + av / 28.0)
    if av < 2.0:
        rate *= av / 2.0
    if not grounded:
        rate *= 0.3
    var dir_sign: float = 1.0 if speed >= 0.0 else -1.0
    yaw += steer_vis * rate * dir_sign * dt
    # скольжение
    var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
    var desired: Vector3 = fwd * speed
    var gk: float = 9.0 * grip * stab
    if not grounded:
        gk = 0.8
    vel = vel.lerp(desired, clampf(gk * dt, 0.0, 1.0))
    var slip: float = (vel - desired).length()
    skid_amt = 0.0
    if av > 8.0 and grounded:
        skid_amt = clampf((slip - 1.5) / 6.0, 0.0, 1.0)
    drifting = skid_amt > 0.2
    prev_pos = pos
    pos += vel * dt
    # границы
    if free_mode:
        var lim: float = FREE_HALF - 3.0
        if absf(pos.x) > lim:
            pos.x = clampf(pos.x, -lim, lim)
            vel.x = 0.0
            speed *= 0.7
            shake = 0.3
        if absf(pos.z) > lim:
            pos.z = clampf(pos.z, -lim, lim)
            vel.z = 0.0
            speed *= 0.7
            shake = 0.3
        for bpv in boosts:
            var bp: Vector3 = bpv
            if absf(pos.x - bp.x) < 3.5 and absf(pos.z - bp.z) < 4.5 and grounded:
                speed = maxf(speed, vmax * 1.3)
    else:
        _track_constrain(dt)
    # вертикаль (трамплины)
    var gh: float = 0.0
    if free_mode:
        gh = _ground_h(pos)
        if gh - y > 0.9:
            pos = prev_pos
            vel = Vector3.ZERO
            speed = 0.0
            shake = 0.5
            gh = _ground_h(pos)
    if grounded:
        if gh < y - 0.08:
            grounded = false
            vy = maxf(climb_rate, 0.0)
            takeoff_pos = pos
        else:
            climb_rate = (gh - y) / maxf(dt, 0.0001)
            y = gh
    else:
        vy -= GRAVITY * dt
        y += vy * dt
        if y <= gh:
            if vy < -5.0:
                shake = clampf(-vy * 0.04, 0.2, 0.9)
            best_jump = maxf(best_jump, Vector2(pos.x - takeoff_pos.x, pos.z - takeoff_pos.z).length())
            y = gh
            vy = 0.0
            grounded = true
            climb_rate = 0.0
    var pt: float = 0.0
    if grounded:
        pt = atan2(climb_rate, maxf(av, 6.0))
    else:
        pt = atan2(vy, maxf(av, 8.0))
    pitch = lerpf(pitch, pt, minf(1.0, 8.0 * dt))
    roll = lerpf(roll, -steer_vis * clampf(av / vmax, 0.0, 1.0) * 0.12 / stab, minf(1.0, 6.0 * dt))
    if not free_mode:
        _check_items()
        if mode != "playing":
            return
        if progress >= TRACK_LEN - 2.0:
            _finish_race(true)
            return
    # визуал и звук
    for w in wheel_spins:
        (w as Node3D).rotation.x -= speed / wheel_r * dt
    for w2 in wheel_steers:
        (w2 as Node3D).rotation.y = steer_vis * 0.45
    tail_mat.emission_energy_multiplier = 3.0 if brake_amt > 0.1 else 0.6
    smoke.emitting = skid_amt > 0.25 or hits >= 2
    vis.visible = invincible <= 0.0 or (int(run_time * 12.0) % 2 == 0)
    var ratio: float = clampf(av / vmax, 0.0, 1.0)
    var gf: float = ratio * 5.0
    rpm = lerpf(rpm, 0.25 + 0.5 * (gf - floorf(gf)) + 0.2 * ratio, minf(1.0, 6.0 * dt))
    _apply_car_transform()
    _update_camera(dt)

func _track_constrain(dt: float) -> void:
    var n: int = tpos.size()
    var best: int = prog_i
    var bd: float = 1.0e18
    for i in range(maxi(0, prog_i - 6), mini(n - 1, prog_i + 10) + 1):
        var dx: float = pos.x - tpos[i].x
        var dz: float = pos.z - tpos[i].z
        var d: float = dx * dx + dz * dz
        if d < bd:
            bd = d
            best = i
    prog_i = best
    var h: float = thead[best]
    var rd: Vector3 = _rvec(h)
    var td: Vector3 = _tvec(h)
    var rel := Vector3(pos.x - tpos[best].x, 0.0, pos.z - tpos[best].z)
    var lat: float = rel.dot(rd)
    progress = float(best) * STEP + rel.dot(td)
    var lim: float = ROAD_HALF - car_half.x - 0.15
    if absf(lat) > lim:
        var s: float = signf(lat)
        pos -= rd * s * (absf(lat) - lim)
        var vl: float = vel.dot(rd)
        if vl * s > 0.0:
            vel -= rd * vl
        speed *= maxf(0.0, 1.0 - 1.5 * dt)
        yaw = lerp_angle(yaw, h, minf(1.0, 3.0 * dt))
        shake = maxf(shake, 0.12)

func _check_items() -> void:
    var f := Vector3(-sin(yaw), 0.0, -cos(yaw))
    var off: float = maxf(car_half.y - 0.7, 0.3)
    var pf: Vector3 = pos + f * off
    var pb: Vector3 = pos - f * off
    for c in coin_nodes:
        if not c["alive"]:
            continue
        var cp: Vector3 = c["pos"]
        if Vector2(cp.x - pos.x, cp.z - pos.z).length() < 1.9:
            c["alive"] = false
            (c["node"] as Node3D).visible = false
            run_coins += COIN_VALUE
            if bool(settings["click_on"]):
                click_player.pitch_scale = 1.7
                click_player.play()
    if invincible > 0.0 or y > 1.6:
        return
    for o in obstacles:
        if not o["alive"]:
            continue
        var op: Vector3 = o["pos"]
        if absf(op.x - pos.x) > 6.0 or absf(op.z - pos.z) > 6.0:
            continue
        var dd: float = minf(Vector2(pf.x - op.x, pf.z - op.z).length(), Vector2(pb.x - op.x, pb.z - op.z).length())
        if dd < car_half.x * 0.85 + 0.85:
            o["alive"] = false
            (o["node"] as Node3D).visible = false
            hits += 1
            speed *= 0.35
            vel *= 0.35
            invincible = 1.5
            shake = 0.8
            crash_player.play()
            if hits >= MAX_HITS:
                _finish_race(false)
            return

func _update_camera(dt: float) -> void:
    cam_yaw = lerp_angle(cam_yaw, yaw, minf(1.0, 3.5 * dt))
    var back := Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))
    var ratio: float = clampf(speed / _vmax(), 0.0, 1.0)
    var target := Vector3(pos.x, y, pos.z)
    var cp: Vector3 = target + back * (8.0 + ratio * 2.5) + Vector3(0.0, 3.4 + y * 0.3, 0.0)
    if shake > 0.0:
        cp += Vector3(randf() - 0.5, randf() - 0.5, 0.0) * shake * 0.6
    camera_3d.position = cp
    camera_3d.look_at(target + Vector3(0, 1.2, 0) - back * 6.0, Vector3.UP)
    camera_3d.fov = lerpf(camera_3d.fov, 68.0 + ratio * 20.0, minf(1.0, 3.0 * dt))
# ======================= ФИНИШ / РЕЗУЛЬТАТ =======================

func _finish_race(ok: bool) -> void:
    var reward: int = 0
    var bonus: int = 0
    if ok:
        finishes += 1
        reward = int(MAPS[map_id]["reward"])
        if finishes % 3 == 0:
            bonus = REWARD_EVERY_3
    coins += run_coins + reward + bonus
    last_result = {"ok": ok, "time": run_time, "coins": run_coins, "reward": reward, "bonus": bonus, "map": map_id}
    _save_game()
    mode = "result"
    _engine_sounds(false)
    _update_music()
    if not ok:
        crash_player.play()
    _show_result()

func _show_result() -> void:
    _clear_ui()
    var ok: bool = bool(last_result.get("ok", false))
    var vb := _center_box()
    if ok:
        vb.add_child(_clabel("ФИНИШ!", 56, GOLD))
    else:
        vb.add_child(_clabel("Машина разбита!", 52, Color(1, 0.4, 0.4)))
        vb.add_child(_clabel("Попробуй ещё раз", 30))
    vb.add_child(_clabel("Время: %s" % _fmt_time(float(last_result.get("time", 0.0))), 28))
    vb.add_child(_clabel("Собрано монет: %d" % int(last_result.get("coins", 0)), 28))
    if ok:
        vb.add_child(_clabel("Награда за финиш: %d" % int(last_result.get("reward", 0)), 28))
        if int(last_result.get("bonus", 0)) > 0:
            vb.add_child(_clabel("Бонус за 3 финиша: %d" % int(last_result.get("bonus", 0)), 28, GOLD))
    vb.add_child(_clabel("Монеты: %d" % coins, 34, GOLD))
    vb.add_child(_button("Играть снова", start_race.bind(int(last_result.get("map", 0))), 420, 58))
    vb.add_child(_button("Выбор карты", show_maps, 420, 58))
    vb.add_child(_button("В меню", show_menu, 420, 58))

# ======================= HUD =======================

func _build_hud() -> void:
    _clear_ui()
    var vp := _vp()
    coins_label = _label("", 26, GOLD)
    coins_label.position = Vector2(24, 14)
    ui.add_child(coins_label)
    hits_label = _label("", 26)
    hits_label.position = Vector2(24, 50)
    ui.add_child(hits_label)
    status_label = _clabel("", 24)
    status_label.custom_minimum_size = Vector2(640, 0)
    status_label.position = Vector2(vp.x * 0.5 - 320.0, 14)
    ui.add_child(status_label)
    var mb := _button("Меню", show_menu, 130, 48)
    mb.position = Vector2(vp.x - 154.0, 12)
    ui.add_child(mb)
    if free_mode:
        var rb := _button("Респавн", _respawn_car.bind(true), 130, 48)
        rb.position = Vector2(vp.x - 154.0, 68)
        ui.add_child(rb)
    gauge = Control.new()
    gauge.custom_minimum_size = Vector2(190, 190)
    gauge.size = Vector2(190, 190)
    gauge.position = Vector2(vp.x * 0.5 - 95.0, vp.y - 205.0)
    gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    gauge.draw.connect(_draw_gauge)
    ui.add_child(gauge)
    speed_label = _clabel("0", 38)
    speed_label.custom_minimum_size = Vector2(190, 0)
    speed_label.position = Vector2(0, 78)
    gauge.add_child(speed_label)
    var kl := _clabel("км/ч", 18)
    kl.custom_minimum_size = Vector2(190, 0)
    kl.position = Vector2(0, 126)
    gauge.add_child(kl)
    var sz: float = 128.0
    var gap: float = 14.0
    var mg: float = 24.0
    var steer_acts: Array = ["left", "right"]
    if bool(controls["swap_lr"]):
        steer_acts.reverse()
    var pedal_acts: Array = ["brake", "gas"]
    if bool(controls["swap_pedals"]):
        pedal_acts.reverse()
    var steer_x: float = mg
    var pedal_x: float = vp.x - mg - sz * 2.0 - gap
    if bool(controls["swap_sides"]):
        steer_x = pedal_x
        pedal_x = mg
    var py: float = vp.y - sz - mg
    for k in range(2):
        _add_pad(str(steer_acts[k]), Rect2(steer_x + float(k) * (sz + gap), py, sz, sz))
        _add_pad(str(pedal_acts[k]), Rect2(pedal_x + float(k) * (sz + gap), py, sz, sz))
    _update_hud()

func _add_pad(action: String, rect: Rect2) -> void:
    var p := ColorRect.new()
    p.position = rect.position
    p.size = rect.size
    p.color = Color(0, 0, 0, 0.35)
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(p)
    var l := _clabel(str(PAD_TEXT[action]), 30)
    l.custom_minimum_size = Vector2(rect.size.x, 0)
    l.position = Vector2(0, rect.size.y * 0.5 - 22.0)
    p.add_child(l)
    touch_zones[action] = rect
    touch_pads[action] = p

func _update_hud() -> void:
    if status_label == null or not is_instance_valid(status_label):
        return
    coins_label.text = "Монеты: %d" % (coins + run_coins)
    if free_mode:
        hits_label.text = ""
        status_label.text = "Свободная игра   Лучший прыжок: %d м" % int(best_jump)
    else:
        hits_label.text = "Удары: %d / %d" % [hits, MAX_HITS]
        status_label.text = "%s   %.2f / %.1f км   %s" % [MAPS[map_id]["name"], maxf(progress, 0.0) / 1000.0, TRACK_LEN / 1000.0, _fmt_time(run_time)]
    speed_label.text = str(int(absf(speed) * 3.6))
    for a in touch_pads:
        var pad: ColorRect = touch_pads[a]
        pad.color = Color(1, 1, 1, 0.4) if _pressed(str(a)) else Color(0, 0, 0, 0.35)
    gauge.queue_redraw()

func _draw_gauge() -> void:
    var c := Vector2(95, 95)
    gauge.draw_circle(c, 92.0, Color(0, 0, 0, 0.45))
    var a0: float = deg_to_rad(135.0)
    var sweep: float = deg_to_rad(270.0)
    gauge.draw_arc(c, 78.0, a0, a0 + sweep, 64, Color(1, 1, 1, 0.25), 10.0)
    var f: float = clampf(absf(speed) * 3.6 / GAUGE_MAX_KMH, 0.0, 1.0)
    if f > 0.01:
        gauge.draw_arc(c, 78.0, a0, a0 + sweep * f, 64, Color(0.2, 1.0, 0.3).lerp(Color(1, 0.2, 0.1), f), 10.0)
    var ang: float = a0 + sweep * f
    gauge.draw_line(c, c + Vector2(cos(ang), sin(ang)) * 70.0, Color.WHITE, 4.0)
