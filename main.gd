extends Node3D

# ======================= НАСТРОЙКИ =======================
const ROAD_LENGTH := 300.0
const ROAD_HALF := 6.0
const LANES := [-4.2, -2.1, 0.0, 2.1, 4.2]
const FIRST_ROW_Z := 40.0
const ROW_GAP_MIN := 20.0
const ROW_GAP_MAX := 30.0
const OBSTACLE_CHANCE := 0.5
const SHADOWS := true
const START_COINS := 0
const REWARD_EVERY_3 := 5000
const SAVE_PATH := "user://save.json"
const GAUGE_MAX_KMH := 300.0
const GRAVITY := 18.0
const MAX_HITS := 3
const UPGRADE_COST := 800
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

var mode := "menu"
var free_mode := false
var car: CharacterBody3D
var vis: Node3D
var wheel_spins: Array[Node3D] = []
var wheel_steers: Array[Node3D] = []
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

var speed := 0.0
var yaw := 0.0
var steer_vis := 0.0
var cam_back := Vector3(0, 0, 1)
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
var obstacles: Array = []
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
    var total := step_len * lead.size()
    var samples := PackedFloat32Array()
    samples.resize(total)
    for n in range(total):
        var s := int(n / step_len)
        var local := n - s * step_len
        var tg := float(n) / float(rate)
        var frac := float(local) / float(step_len)
        var env := (1.0 - frac) * (1.0 - frac)
        var lf: float = lead[s]
        var bf: float = bass[s]
        var sq := -1.0
        if fmod(tg * lf, 1.0) < 0.5:
            sq = 1.0
        var tri := absf(fmod(tg * bf, 1.0) * 2.0 - 1.0) * 2.0 - 1.0
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
    for p in [engine_player, brake_player, skid_player]:
        if on and not p.playing:
            p.play()
        elif not on and p.playing:
            p.stop()

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
    camera_3d.current = true
    camera_3d.near = 0.1
    camera_3d.far = 1500.0
    add_child(camera_3d)

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

func _touch_set(index: int, pos: Vector2) -> void:
    var action := _zone_at(pos)
    if action == "":
        touches.erase(index)
    else:
        touches[index] = action

func _zone_at(pos: Vector2) -> String:
    for action in touch_zones:
        var rect: Rect2 = touch_zones[action]
        if rect.grow(8.0).has_point(pos):
            return action
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
    var vb := VBoxContainer.new()
    vb.custom_minimum_size = Vector2(w, 0)
    vb.add_theme_constant_override("separation", 10)
    vb.alignment = BoxContainer.ALIGNMENT_CENTER
    ui.add_child(vb)
    vb.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE, Control.PRESET_MODE_MINSIZE, 30)
    return vb

func _center_box() -> VBoxContainer:
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.5)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(dim)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 12)
    vb.alignment = BoxContainer.ALIGNMENT_CENTER
    vb.custom_minimum_size = Vector2(460, 0)
    ui.add_child(vb)
    vb.set_anchors_preset(Control.PRESET_CENTER)
    vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
    vb.grow_vertical = Control.GROW_DIRECTION_BOTH
    return vb

func _clear_world() -> void:
    for c in world_root.get_children():
        c.queue_free()
    car = null
    vis = null
    smoke = null
    preview_car = null
    tail_mat = null
    body_mat = null
    obstacles.clear()
    wheel_spins.clear()
    wheel_steers.clear()

func _show_preview(id: int) -> void:
    _clear_world()
    var ground := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(80, 80)
    ground.mesh = pm
    ground.material_override = _mat(Color(0.35, 0.37, 0.4))
    world_root.add_child(ground)
    preview_car = Node3D.new()
    var mats := _build_car_visual(id, preview_car)
    preview_body_mat = mats["body"]
    var cd: Dictionary = CARS[id]
    var r := float(cd["wheel"])
    for i in range(4):
        var holder := Node3D.new()
        holder.position = _wheel_pos(i, float(cd["len"]), float(cd["wid"])) + Vector3(0, -0.2, 0)
        preview_car.add_child(holder)
        _add_wheel_mesh(holder, r)
    preview_car.position = Vector3(0, r + 0.2, 0)
    world_root.add_child(preview_car)
    preview_id = id
    camera_3d.fov = 70.0
    camera_3d.position = Vector3(5.5, 2.4, 7.5)
    camera_3d.look_at(Vector3(-1.8, 0.6, 0), Vector3.UP)
# ======================= ЭКРАНЫ МЕНЮ =======================

func show_menu() -> void:
    mode = "menu"
    free_mode = false
    held.clear()
    _engine_sounds(false)
    _update_music()
    _show_preview(current_car)
    _clear_ui()
    var box := _side_box(380)
    box.add_child(_label("ГОНКИ", 56, GOLD))
    coins_label = _label("Монеты: %d" % coins, 30)
    box.add_child(coins_label)
    box.add_child(_button("Играть", func(): start_run(false)))
    box.add_child(_button("Свободная езда", func(): start_run(true)))
    box.add_child(_button("Гараж", func(): garage_sel = current_car; show_garage()))
    box.add_child(_button("Управление", func(): show_controls()))
    box.add_child(_button("Настройки", func(): show_settings()))

func show_settings() -> void:
    mode = "settings"
    _engine_sounds(false)
    _update_music()
    _clear_ui()
    var box := _center_box()
    box.add_child(_clabel("Настройки", 44, GOLD))
    var items := [
        ["music_on", "Музыка"],
        ["engine_on", "Звук мотора"],
        ["brake_on", "Звук тормоза"],
        ["drift_on", "Звук дрифта"],
        ["click_on", "Клики кнопок"],
    ]
    for it in items:
        var cb := CheckButton.new()
        cb.text = str(it[1])
        cb.button_pressed = bool(settings[it[0]])
        cb.focus_mode = Control.FOCUS_NONE
        cb.add_theme_font_size_override("font_size", 26)
        cb.toggled.connect(_on_setting_toggled.bind(str(it[0])))
        box.add_child(cb)
    box.add_child(_label("Громкость", 26))
    var sl := HSlider.new()
    sl.min_value = 0.0
    sl.max_value = 1.0
    sl.step = 0.05
    sl.value = float(settings["volume"])
    sl.custom_minimum_size = Vector2(0, 30)
    sl.value_changed.connect(_on_volume_changed)
    box.add_child(sl)
    box.add_child(_button("Назад", func(): show_menu()))

func _on_setting_toggled(pressed: bool, key: String) -> void:
    settings[key] = pressed
    _save_game()
    _update_music()
    _play_click()

func _on_volume_changed(v: float) -> void:
    settings["volume"] = v
    _apply_volume()
    _save_game()

func show_controls() -> void:
    mode = "controls"
    held.clear()
    _engine_sounds(false)
    _update_music()
    _clear_ui()
    var box := _center_box()
    box.add_child(_clabel("Управление", 44, GOLD))
    for a in ["gas", "brake", "left", "right"]:
        var txt: String = str(ACTION_NAMES[a]) + ": "
        if waiting_key == a:
            txt += "нажми клавишу..."
        else:
            txt += OS.get_keycode_string(int(controls[a]) as Key)
        box.add_child(_button(txt, _start_rebind.bind(a), 340.0, 48.0))
    box.add_child(_clabel("Экранные кнопки (телефон):", 24))
    var items := [
        ["swap_sides", "Руль справа, педали слева"],
        ["swap_lr", "Поменять < и > местами"],
        ["swap_pedals", "Поменять газ и тормоз местами"],
    ]
    for it in items:
        var cb := CheckButton.new()
        cb.text = str(it[1])
        cb.button_pressed = bool(controls[it[0]])
        cb.focus_mode = Control.FOCUS_NONE
        cb.add_theme_font_size_override("font_size", 24)
        cb.toggled.connect(_on_control_toggled.bind(str(it[0])))
        box.add_child(cb)
    box.add_child(_button("Назад", func(): waiting_key = ""; show_menu(), 340.0, 48.0))

func _start_rebind(action: String) -> void:
    waiting_key = action
    show_controls()

func _on_control_toggled(pressed: bool, key: String) -> void:
    controls[key] = pressed
    _save_game()
    _play_click()
# ======================= ГАРАЖ =======================

func _car_text(id: int) -> String:
    var cd: Dictionary = CARS[id]
    var t := "%s — %s\n" % [str(cd["name"]), str(cd["info"])]
    t += "Мотор %d%%  Скорость %d%%  Сцепление %d%%\n" % [int(_car_f(id, "engine") * 100.0), int(_car_f(id, "speed") * 100.0), int(_car_f(id, "grip") * 100.0)]
    if owned[id]:
        t += "Куплена"
        if bool(car_turbo[id]):
            t += "  |  Турбо: ВКЛ"
    else:
        t += "Цена: %d" % int(cd["price"])
    return t

func show_garage() -> void:
    mode = "garage"
    _engine_sounds(false)
    _update_music()
    _show_preview(garage_sel)
    _clear_ui()
    var box := _side_box(440)
    box.add_child(_label("Гараж", 44, GOLD))
    coins_label = _label("Монеты: %d" % coins, 28)
    box.add_child(coins_label)
    detail_label = _label(_car_text(garage_sel), 22)
    detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_label.custom_minimum_size = Vector2(400, 0)
    box.add_child(detail_label)
    garage_msg = _label("", 22, Color(1, 0.6, 0.4))
    box.add_child(garage_msg)
    box.add_child(_pair(_button("<", func(): _garage_step(-1), 100, 48), _button(">", func(): _garage_step(1), 100, 48)))
    if owned[garage_sel]:
        if current_car == garage_sel:
            box.add_child(_label("Выбрана", 24, Color(0.5, 1, 0.5)))
        else:
            box.add_child(_button("Выбрать", func(): _select_car(), 340, 48))
        box.add_child(_pair(_button("Улучшения", func(): _open_upgrades(), 100, 48), _button("Покраска", func(): _open_paint(), 100, 48)))
        var tt := "Турбо: ВЫКЛ"
        if bool(car_turbo[garage_sel]):
            tt = "Турбо: ВКЛ (до 1000 км/ч)"
        box.add_child(_button(tt, func(): _toggle_turbo(), 340, 48))
    else:
        box.add_child(_button("Купить за %d" % int(CARS[garage_sel]["price"]), func(): _buy_car(), 340, 48))
    box.add_child(_button("Назад", func(): show_menu(), 340, 48))

func _garage_step(d: int) -> void:
    garage_sel = wrapi(garage_sel + d, 0, CARS.size())
    show_garage()

func _select_car() -> void:
    current_car = garage_sel
    _save_game()
    show_garage()

func _buy_car() -> void:
    var price := int(CARS[garage_sel]["price"])
    if coins >= price:
        coins -= price
        owned[garage_sel] = true
        current_car = garage_sel
        _save_game()
        show_garage()
    else:
        garage_msg.text = "Не хватает монет"

func _toggle_turbo() -> void:
    car_turbo[garage_sel] = not bool(car_turbo[garage_sel])
    _save_game()
    show_garage()

func _open_upgrades() -> void:
    current_car = garage_sel
    show_upgrades()

func _open_paint() -> void:
    current_car = garage_sel
    show_paint()

func _upgrade_cost(lv: int) -> int:
    return UPGRADE_COST * lv

func show_upgrades() -> void:
    mode = "upgrades"
    _engine_sounds(false)
    _show_preview(current_car)
    _clear_ui()
    var box := _side_box(460)
    box.add_child(_label("Улучшения", 44, GOLD))
    coins_label = _label("Монеты: %d" % coins, 28)
    box.add_child(coins_label)
    for n in UPGRADE_NAMES:
        var mark := "  "
        if n == selected_upgrade:
            mark = "> "
        box.add_child(_button("%s%s   ур. %d/5" % [mark, n, _lv(n)], _select_upgrade.bind(n), 400, 46))
    detail_label = _label(str(UPGRADE_INFO[selected_upgrade]), 24)
    box.add_child(detail_label)
    garage_msg = _label("", 22, Color(1, 0.6, 0.4))
    box.add_child(garage_msg)
    var lv := _lv(selected_upgrade)
    if lv >= 5:
        box.add_child(_label("Максимальный уровень", 24, Color(0.5, 1, 0.5)))
    else:
        box.add_child(_button("Улучшить за %d" % _upgrade_cost(lv), func(): _buy_upgrade(), 400, 48))
    box.add_child(_button("Назад", func(): garage_sel = current_car; show_garage(), 400, 48))

func _select_upgrade(n: String) -> void:
    selected_upgrade = n
    show_upgrades()

func _buy_upgrade() -> void:
    var lv := _lv(selected_upgrade)
    var cost := _upgrade_cost(lv)
    if lv >= 5:
        return
    if coins < cost:
        garage_msg.text = "Не хватает монет"
        return
    coins -= cost
    car_levels[current_car][selected_upgrade] = lv + 1
    _save_game()
    show_upgrades()

func show_paint() -> void:
    mode = "paint"
    _engine_sounds(false)
    _show_preview(current_car)
    _clear_ui()
    var c: Color = car_colors[current_car]
    paint_h = c.h
    paint_s = c.s
    paint_v = c.v
    var box := _side_box(460)
    box.add_child(_label("Покраска", 44, GOLD))
    _add_slider(box, "Оттенок", paint_h, "h")
    _add_slider(box, "Насыщенность", paint_s, "s")
    _add_slider(box, "Яркость", paint_v, "v")
    box.add_child(_button("Готово", func(): _save_game(); garage_sel = current_car; show_garage(), 400, 48))

func _add_slider(box: VBoxContainer, title: String, value: float, which: String) -> void:
    box.add_child(_label(title, 24))
    var sl := HSlider.new()
    sl.min_value = 0.0
    sl.max_value = 1.0
    sl.step = 0.01
    sl.value = value
    sl.custom_minimum_size = Vector2(400, 30)
    sl.value_changed.connect(_on_paint_changed.bind(which))
    box.add_child(sl)

func _on_paint_changed(v: float, which: String) -> void:
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
# ======================= МОДЕЛЬ МАШИНЫ =======================

func _mat(color: Color, rough: float = 0.7) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mat
    mi.position = pos
    parent.add_child(mi)
    return mi

func _build_car_visual(id: int, parent: Node3D) -> Dictionary:
    var cd: Dictionary = CARS[id]
    var ln := float(cd["len"])
    var wd := float(cd["wid"])
    var bmat := _mat(car_colors[id], 0.35)
    var glass := _mat(Color(0.08, 0.1, 0.14), 0.1)
    var tmat := _mat(Color(0.5, 0.0, 0.0), 0.4)
    tmat.emission_enabled = true
    tmat.emission = Color(0.9, 0.0, 0.0)
    tmat.emission_energy_multiplier = 0.6
    var head := _mat(Color(1, 0.95, 0.7), 0.3)
    _box(parent, Vector3(wd, 0.5, ln), Vector3(0, 0.1, 0), bmat)
    _box(parent, Vector3(wd * 0.82, 0.45, ln * 0.42), Vector3(0, 0.55, ln * 0.05), glass)
    _box(parent, Vector3(wd * 0.8, 0.06, ln * 0.38), Vector3(0, 0.8, ln * 0.05), bmat)
    _box(parent, Vector3(0.38, 0.15, 0.08), Vector3(-wd * 0.33, 0.2, ln * 0.5 + 0.02), tmat)
    _box(parent, Vector3(0.38, 0.15, 0.08), Vector3(wd * 0.33, 0.2, ln * 0.5 + 0.02), tmat)
    _box(parent, Vector3(0.38, 0.15, 0.08), Vector3(-wd * 0.33, 0.2, -ln * 0.5 - 0.02), head)
    _box(parent, Vector3(0.38, 0.15, 0.08), Vector3(wd * 0.33, 0.2, -ln * 0.5 - 0.02), head)
    if id == 1 or id == 4:
        _box(parent, Vector3(wd * 0.9, 0.08, 0.4), Vector3(0, 0.75, ln * 0.5 - 0.2), bmat)
        _box(parent, Vector3(0.1, 0.3, 0.1), Vector3(-wd * 0.3, 0.55, ln * 0.5 - 0.2), glass)
        _box(parent, Vector3(0.1, 0.3, 0.1), Vector3(wd * 0.3, 0.55, ln * 0.5 - 0.2), glass)
    return {"body": bmat, "tail": tmat}

func _wheel_pos(i: int, ln: float, wd: float) -> Vector3:
    var x := wd * 0.5 - 0.05
    if i % 2 == 0:
        x = -x
    var z := ln * 0.32
    if i < 2:
        z = -z
    return Vector3(x, 0.0, z)

func _add_wheel_mesh(holder: Node3D, r: float) -> Node3D:
    var spin := Node3D.new()
    holder.add_child(spin)
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = r
    cm.bottom_radius = r
    cm.height = 0.34
    cm.radial_segments = 16
    mi.mesh = cm
    mi.rotation_degrees = Vector3(0, 0, 90)
    mi.material_override = _mat(Color(0.05, 0.05, 0.05), 0.9)
    spin.add_child(mi)
    _box(spin, Vector3(0.36, r * 1.2, 0.08), Vector3.ZERO, _mat(Color(0.7, 0.7, 0.72)))
    return spin

func _spawn_car() -> void:
    var cd: Dictionary = CARS[current_car]
    var ln := float(cd["len"])
    var wd := float(cd["wid"])
    wheel_r = float(cd["wheel"])
    car = CharacterBody3D.new()
    vis = Node3D.new()
    car.add_child(vis)
    var mats := _build_car_visual(current_car, vis)
    body_mat = mats["body"]
    tail_mat = mats["tail"]
    for i in range(4):
        var holder := Node3D.new()
        holder.position = _wheel_pos(i, ln, wd) + Vector3(0, -0.2, 0)
        vis.add_child(holder)
        var spin := _add_wheel_mesh(holder, wheel_r)
        wheel_spins.append(spin)
        if i < 2:
            wheel_steers.append(holder)
    car.position = Vector3(0, wheel_r + 0.2, 0)
    car_half = Vector2(wd * 0.5, ln * 0.5)
    world_root.add_child(car)
    smoke = CPUParticles3D.new()
    smoke.position = Vector3(0, 0.1, ln * 0.5)
    smoke.amount = 40
    smoke.lifetime = 1.1
    smoke.emitting = false
    smoke.direction = Vector3(0, 1, 0)
    smoke.spread = 30.0
    smoke.initial_velocity_min = 1.0
    smoke.initial_velocity_max = 2.5
    smoke.gravity = Vector3(0, 0.6, 0)
    var sm := SphereMesh.new()
    sm.radius = 0.22
    sm.height = 0.44
    sm.radial_segments = 8
    sm.rings = 4
    var smat := _mat(Color(0.7, 0.7, 0.7, 0.5), 1.0)
    smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sm.material = smat
    smoke.mesh = sm
    car.add_child(smoke)
# ======================= МИР: ДОРОГА, ФИНИШ, ПРЕПЯТСТВИЯ =======================

func _build_world() -> void:
    var ground := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(2000, 2000)
    ground.mesh = pm
    ground.material_override = _mat(Color(0.18, 0.4, 0.18), 1.0)
    ground.position = Vector3(0, -0.1, -ROAD_LENGTH * 0.5)
    world_root.add_child(ground)
    if free_mode:
        _build_free_world()
    else:
        _build_race_world()

func _build_free_world() -> void:
    _box(world_root, Vector3(260, 0.1, 260), Vector3(0, -0.05, 0), _mat(Color(0.14, 0.15, 0.17)))
    for i in range(50):
        var a := randf() * TAU
        var d := randf_range(150.0, 260.0)
        _make_tree(Vector3(cos(a) * d, 0, sin(a) * d))

func _build_race_world() -> void:
    var total := ROAD_LENGTH + 80.0
    var cz := -ROAD_LENGTH * 0.5
    _box(world_root, Vector3(ROAD_HALF * 2.0, 0.1, total), Vector3(0, -0.05, cz), _mat(Color(0.14, 0.15, 0.17)))
    var curb := _mat(Color(0.55, 0.55, 0.58))
    _box(world_root, Vector3(0.4, 0.15, total), Vector3(-ROAD_HALF - 0.2, 0.0, cz), curb)
    _box(world_root, Vector3(0.4, 0.15, total), Vector3(ROAD_HALF + 0.2, 0.0, cz), curb)
    var white := _mat(Color(0.9, 0.9, 0.9))
    for lx in [-3.15, -1.05, 1.05, 3.15]:
        var z := 30.0
        while z > -(ROAD_LENGTH + 30.0):
            _box(world_root, Vector3(0.12, 0.03, 3.0), Vector3(lx, 0.015, z), white)
            z -= 8.0
    _box(world_root, Vector3(ROAD_HALF * 2.0, 0.03, 0.6), Vector3(0, 0.02, 3.0), white)
    _build_gate(-ROAD_LENGTH)
    for i in range(70):
        var side := 1.0
        if randf() < 0.5:
            side = -1.0
        _make_tree(Vector3(side * randf_range(9.0, 30.0), 0, randf_range(-ROAD_LENGTH - 60.0, 40.0)))
    _build_obstacles()

func _build_gate(z: float) -> void:
    var red := _mat(Color(0.75, 0.08, 0.08))
    _box(world_root, Vector3(0.7, 6.5, 0.7), Vector3(-ROAD_HALF - 0.6, 3.25, z), red)
    _box(world_root, Vector3(0.7, 6.5, 0.7), Vector3(ROAD_HALF + 0.6, 3.25, z), red)
    _box(world_root, Vector3(ROAD_HALF * 2.0 + 2.6, 1.3, 0.7), Vector3(0, 6.4, z), red)
    _box(world_root, Vector3(ROAD_HALF * 2.0, 0.03, 1.0), Vector3(0, 0.02, z), _mat(Color(0.95, 0.95, 0.95)))
    var lb := Label3D.new()
    lb.text = "ФИНИШ"
    lb.font_size = 128
    lb.pixel_size = 0.012
    lb.modulate = Color.WHITE
    lb.outline_size = 12
    lb.position = Vector3(0, 6.4, z + 0.4)
    world_root.add_child(lb)

func _make_tree(pos: Vector3) -> void:
    var tree := Node3D.new()
    var trunk := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.22
    cm.bottom_radius = 0.28
    cm.height = 2.4
    trunk.mesh = cm
    trunk.material_override = _mat(Color(0.35, 0.2, 0.1))
    trunk.position = Vector3(0, 1.2, 0)
    tree.add_child(trunk)
    var crown := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 1.4
    sm.height = 2.8
    crown.mesh = sm
    crown.material_override = _mat(Color(0.05, randf_range(0.35, 0.5), 0.1))
    crown.position = Vector3(0, 3.3, 0)
    tree.add_child(crown)
    tree.position = pos
    world_root.add_child(tree)

func _build_obstacles() -> void:
    obstacles.clear()
    var z := -FIRST_ROW_Z
    while z > -(ROAD_LENGTH - 25.0):
        var used: Array = []
        for lx in LANES:
            if randf() < OBSTACLE_CHANCE:
                used.append(float(lx))
        if used.size() >= LANES.size():
            used.remove_at(randi() % used.size())
        for ux in used:
            _add_obstacle(float(ux), z)
        z -= randf_range(ROW_GAP_MIN, ROW_GAP_MAX)

func _add_obstacle(x: float, z: float) -> void:
    var node := Node3D.new()
    var hw := 0.8
    var hl := 0.8
    if randi() % 2 == 0:
        _box(node, Vector3(1.6, 1.4, 1.6), Vector3(0, 0.7, 0), _mat(Color(0.55, 0.36, 0.16)))
    else:
        hw = 0.95
        hl = 0.3
        var red := _mat(Color(0.85, 0.15, 0.15))
        _box(node, Vector3(1.9, 0.5, 0.5), Vector3(0, 0.9, 0), red)
        _box(node, Vector3(0.15, 0.9, 0.15), Vector3(-0.7, 0.45, 0), _mat(Color(0.9, 0.9, 0.9)))
        _box(node, Vector3(0.15, 0.9, 0.15), Vector3(0.7, 0.45, 0), _mat(Color(0.9, 0.9, 0.9)))
    node.position = Vector3(x, 0, z)
    world_root.add_child(node)
    obstacles.append({"node": node, "x": x, "z": z, "hw": hw, "hl": hl, "hit": false})
# ======================= ИГРА: ЗАПУСК И ФИЗИКА =======================

func start_run(free: bool) -> void:
    free_mode = free
    mode = "playing"
    held.clear()
    _update_music()
    _clear_world()
    _build_world()
    _spawn_car()
    hits = 0
    speed = 0.0
    yaw = 0.0
    steer_vis = 0.0
    run_time = 0.0
    run_coins = 0
    invincible = 0.0
    shake = 0.0
    skid_amt = 0.0
    gas_amt = 0.0
    brake_amt = 0.0
    drifting = false
    cam_back = Vector3(0, 0, 1)
    _update_camera(0.0, true)
    _build_hud()
    _engine_sounds(true)

func _respawn_car(_reset: bool) -> void:
    if car == null:
        return
    car.position = Vector3(0, wheel_r + 0.2, 0)
    yaw = 0.0
    speed = 0.0
    cam_back = Vector3(0, 0, 1)

func _process(delta: float) -> void:
    var dt := minf(delta, 0.05)
    if mode == "playing" and car != null:
        _drive(dt)
        if mode == "playing":
            _update_camera(dt, false)
            _update_audio()
            _update_hud()
    elif preview_car != null and is_instance_valid(preview_car) and mode in ["menu", "garage", "upgrades", "paint"]:
        preview_car.rotate_y(dt * 0.6)

func _drive(dt: float) -> void:
    var gas := _pressed("gas")
    var brk := _pressed("brake")
    var steer_in := 0.0
    if _pressed("left"):
        steer_in += 1.0
    if _pressed("right"):
        steer_in -= 1.0
    var turbo: bool = bool(car_turbo[current_car])
    var lv_m := float(_lv("Мотор"))
    var lv_s := float(_lv("Подвеска"))
    var lv_w := float(_lv("Колёса"))
    var lv_v := float(_lv("Скорость"))
    var lv_b := float(_lv("Тормоза"))
    var top_kmh := NORMAL_MAX_KMH * _car_f(current_car, "speed") * (1.0 + 0.1 * (lv_v - 1.0))
    var accel := 12.0 * _car_f(current_car, "engine") * (1.0 + 0.12 * (lv_m - 1.0))
    if turbo:
        top_kmh = TURBO_MAX_KMH
        accel *= 5.0
    var top := top_kmh / 3.6
    var grip := _car_f(current_car, "grip") * (1.0 + 0.1 * (lv_w - 1.0))
    var brake_f := 28.0 * (1.0 + 0.15 * (lv_b - 1.0))
    # --- разгон, тормоз ---
    if gas:
        var ratio := maxf(speed, 0.0) / top
        var k := clampf(1.0 - ratio * ratio, 0.03, 1.0)
        speed = minf(speed + accel * k * dt, top)
    if brk:
        if speed > 0.5:
            speed = maxf(speed - brake_f * dt, 0.0)
        else:
            speed = maxf(speed - 6.0 * dt, -8.0)
    if not gas and not brk:
        speed = move_toward(speed, 0.0, (3.0 + absf(speed) * 0.05) * dt)
    # --- песок/трава ---
    if not free_mode and absf(car.position.x) > ROAD_HALF + 0.3:
        var lim := 14.0 * grip
        if speed > lim:
            speed = move_toward(speed, lim, 45.0 * dt)
    # --- руление ---
    var steer_rate := 1.7 * (0.8 + 0.2 * grip)
    var sp_factor := clampf(absf(speed) / 6.0, 0.0, 1.0) / (1.0 + absf(speed) / 45.0)
    var dirn := 1.0
    if speed < 0.0:
        dirn = -1.0
    yaw += steer_in * steer_rate * sp_factor * dirn * dt
    if not free_mode:
        if steer_in == 0.0:
            yaw = move_toward(yaw, 0.0, 1.2 * dt)
        yaw = clampf(yaw, -0.8, 0.8)
    steer_vis = lerpf(steer_vis, steer_in, minf(1.0, 10.0 * dt))
    # --- движение ---
    var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
    var prev_z := car.position.z
    car.position += fwd * speed * dt
    if not free_mode:
        car.position.x = clampf(car.position.x, -30.0, 30.0)
    car.position.y = wheel_r + 0.2
    car.rotation.y = yaw
    # --- визуальные эффекты ---
    var roll_target := -steer_vis * 0.07 * clampf(speed / 25.0, 0.0, 1.0) * (1.6 - 0.1 * lv_s)
    vis.rotation.z = lerpf(vis.rotation.z, roll_target, minf(1.0, 8.0 * dt))
    var pitch_target := 0.0
    if brk and speed > 3.0:
        pitch_target = 0.04
    elif gas:
        pitch_target = -0.015
    vis.rotation.x = lerpf(vis.rotation.x, pitch_target, minf(1.0, 6.0 * dt))
    for w in wheel_steers:
        w.rotation.y = steer_vis * 0.45
    for sp in wheel_spins:
        sp.rotation.x -= speed * dt / wheel_r
    var target := absf(steer_in) * clampf((absf(speed) - 20.0) / 50.0, 0.0, 1.0) * (1.3 - 0.1 * lv_w)
    if brk and speed > 25.0:
        target = maxf(target, 0.6)
    skid_amt = lerpf(skid_amt, clampf(target, 0.0, 1.0), minf(1.0, 8.0 * dt))
    drifting = skid_amt > 0.3
    if smoke != null:
        smoke.emitting = drifting or (hits >= 2 and not free_mode)
    rpm = 0.25 + 0.7 * (1.0 - exp(-absf(speed) / 40.0))
    var gas_t := 0.0
    if gas:
        gas_t = 1.0
    gas_amt = lerpf(gas_amt, gas_t, minf(1.0, 6.0 * dt))
    var brake_t := 0.0
    if brk and speed > 3.0:
        brake_t = 1.0
    brake_amt = lerpf(brake_amt, brake_t, minf(1.0, 10.0 * dt))
    if tail_mat != null:
        tail_mat.emission_energy_multiplier = 0.6 + 2.5 * brake_amt
    run_time += dt
    invincible -= dt
    # --- препятствия и финиш ---
    if not free_mode:
        _check_obstacles(prev_z, car.position.z)
        if mode != "playing":
            return
        if car.position.z <= -ROAD_LENGTH:
            _finish_run(true)

func _check_obstacles(pz: float, nz: float) -> void:
    if invincible > 0.0:
        return
    var zlo := minf(pz, nz) - car_half.y
    var zhi := maxf(pz, nz) + car_half.y
    for o in obstacles:
        if bool(o["hit"]):
            continue
        var oz := float(o["z"])
        var ohl := float(o["hl"])
        if oz + ohl < zlo or oz - ohl > zhi:
            continue
        if absf(car.position.x - float(o["x"])) < float(o["hw"]) + car_half.x * 0.92:
            _on_hit(o)
            return

func _on_hit(o: Dictionary) -> void:
    o["hit"] = true
    hits += 1
    invincible = 0.6
    speed *= 0.35
    shake = 1.0
    crash_player.play()
    var base: Color = car_colors[current_car]
    if body_mat != null:
        body_mat.albedo_color = base.lerp(Color(0.08, 0.08, 0.08), 0.28 * float(hits))
    var node: Node3D = o["node"]
    var tw := node.create_tween()
    tw.set_parallel(true)
    tw.tween_property(node, "position", node.position + Vector3(randf_range(-6.0, 6.0), 3.0, -randf_range(8.0, 14.0)), 0.8)
    tw.tween_property(node, "rotation", Vector3(randf() * 6.0, randf() * 6.0, randf() * 6.0), 0.8)
    tw.chain().tween_callback(node.hide)
    if hits >= MAX_HITS:
        _finish_run(false)

func _finish_run(win: bool) -> void:
    mode = "result"
    _engine_sounds(false)
    var reward := 0
    var bonus := false
    if win:
        finishes += 1
        reward = 400 + (MAX_HITS - hits) * 100
        if finishes % 3 == 0:
            reward += REWARD_EVERY_3
            bonus = true
        coins += reward
    _save_game()
    last_result = {"win": win, "time": run_time, "reward": reward, "hits": hits, "bonus": bonus}
    _show_result()

func _update_camera(dt: float, snap: bool) -> void:
    if car == null:
        return
    var back := Vector3(sin(yaw), 0.0, cos(yaw))
    if snap:
        cam_back = back
    else:
        cam_back = cam_back.lerp(back, minf(1.0, 5.0 * dt))
    if cam_back.length() < 0.01:
        cam_back = back
    cam_back = cam_back.normalized()
    var dist := 9.0 + clampf(speed, 0.0, 100.0) * 0.03
    var pos := car.position + cam_back * dist + Vector3(0, 3.8, 0)
    if shake > 0.0:
        pos += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 0.35
        shake = maxf(0.0, shake - 2.5 * dt)
    camera_3d.position = pos
    camera_3d.look_at(car.position + Vector3(0, 1.0, 0) - cam_back * 5.0, Vector3.UP)
    camera_3d.fov = lerpf(camera_3d.fov, 68.0 + clampf(speed, 0.0, 150.0) * 0.12, minf(1.0, 3.0 * dt))
# ======================= ИНТЕРФЕЙС ГОНКИ И РЕЗУЛЬТАТ =======================

func _pad_rects() -> Dictionary:
    var vp := _vp()
    var s := 150.0
    var gap := 20.0
    var m := 30.0
    var y := vp.y - s - m
    var left_x := m
    var right_x := vp.x - m - 2.0 * s - gap
    var steer_x := left_x
    var pedal_x := right_x
    if bool(controls["swap_sides"]):
        steer_x = right_x
        pedal_x = left_x
    var l_x := steer_x
    var r_x := steer_x + s + gap
    if bool(controls["swap_lr"]):
        l_x = steer_x + s + gap
        r_x = steer_x
    var b_x := pedal_x
    var g_x := pedal_x + s + gap
    if bool(controls["swap_pedals"]):
        b_x = g_x
        g_x = pedal_x
    return {
        "left": Rect2(l_x, y, s, s),
        "right": Rect2(r_x, y, s, s),
        "brake": Rect2(b_x, y, s, s),
        "gas": Rect2(g_x, y, s, s),
    }

func _build_hud() -> void:
    _clear_ui()
    var vp := _vp()
    coins_label = _label("Монеты: %d" % coins, 28)
    coins_label.position = Vector2(20, 12)
    ui.add_child(coins_label)
    status_label = _label("", 24)
    status_label.position = Vector2(20, 50)
    ui.add_child(status_label)
    hits_label = _label("", 24)
    hits_label.position = Vector2(20, 86)
    ui.add_child(hits_label)
    speed_label = _clabel("0 км/ч", 36)
    speed_label.custom_minimum_size = Vector2(240, 0)
    speed_label.position = Vector2(vp.x * 0.5 - 120.0, vp.y - 60.0)
    ui.add_child(speed_label)
    var mb := _button("Меню", func(): show_menu(), 150, 48)
    mb.position = Vector2(vp.x - 170.0, 16.0)
    ui.add_child(mb)
    if free_mode:
        var rb := _button("Сброс", func(): _respawn_car(true), 150, 48)
        rb.position = Vector2(vp.x - 170.0, 72.0)
        ui.add_child(rb)
    gauge = Control.new()
    gauge.size = Vector2(240, 240)
    gauge.position = Vector2(vp.x * 0.5 - 120.0, vp.y - 290.0)
    gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    gauge.draw.connect(_draw_gauge)
    ui.add_child(gauge)
    var rects := _pad_rects()
    for action in rects:
        var r: Rect2 = rects[action]
        touch_zones[action] = r
        var pad := ColorRect.new()
        pad.color = Color(1, 1, 1, 0.18)
        pad.position = r.position
        pad.size = r.size
        pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
        ui.add_child(pad)
        var tl := _clabel(str(PAD_TEXT[action]), 34)
        pad.add_child(tl)
        tl.set_anchors_preset(Control.PRESET_FULL_RECT)
        tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        touch_pads[action] = pad

func _draw_gauge() -> void:
    if not is_instance_valid(gauge):
        return
    var c := Vector2(120, 120)
    var gmax := GAUGE_MAX_KMH
    if bool(car_turbo[current_car]):
        gmax = TURBO_MAX_KMH
    gauge.draw_circle(c, 112.0, Color(0, 0, 0, 0.55))
    gauge.draw_arc(c, 100.0, deg_to_rad(135.0), deg_to_rad(405.0), 48, Color(1, 1, 1, 0.4), 6.0)
    var frac := clampf(absf(speed) * 3.6 / gmax, 0.0, 1.0)
    var ang := deg_to_rad(135.0 + 270.0 * frac)
    if frac > 0.01:
        gauge.draw_arc(c, 100.0, deg_to_rad(135.0), ang, 48, Color(1, 0.6, 0.1), 8.0)
    gauge.draw_line(c, c + Vector2(cos(ang), sin(ang)) * 85.0, Color(1, 0.2, 0.2), 5.0)
    gauge.draw_circle(c, 9.0, Color.WHITE)

func _update_hud() -> void:
    if not is_instance_valid(speed_label):
        return
    var txt := "%d км/ч" % int(absf(speed) * 3.6)
    if bool(car_turbo[current_car]):
        txt += "  ТУРБО"
    speed_label.text = txt
    coins_label.text = "Монеты: %d" % coins
    if free_mode:
        status_label.text = "Свободная езда (R — сброс)"
        hits_label.text = ""
    else:
        status_label.text = "До финиша: %d м" % maxi(0, int(ROAD_LENGTH + car.position.z))
        hits_label.text = "Удары: %d / %d" % [hits, MAX_HITS]
    for a in touch_pads:
        var pad: ColorRect = touch_pads[a]
        if _pressed(a):
            pad.color = Color(1, 1, 1, 0.45)
        else:
            pad.color = Color(1, 1, 1, 0.18)
    if is_instance_valid(gauge):
        gauge.queue_redraw()

func _show_result() -> void:
    mode = "result"
    _engine_sounds(false)
    _update_music()
    _clear_ui()
    var box := _center_box()
    var win: bool = bool(last_result.get("win", false))
    if win:
        box.add_child(_clabel("ФИНИШ!", 52, Color(0.5, 1, 0.5)))
    else:
        box.add_child(_clabel("Машина разбита!", 48, Color(1, 0.4, 0.4)))
    box.add_child(_clabel("Время: %.1f с" % float(last_result.get("time", 0.0)), 28))
    box.add_child(_clabel("Удары: %d / %d" % [int(last_result.get("hits", 0)), MAX_HITS], 28))
    if win:
        box.add_child(_clabel("Награда: +%d монет" % int(last_result.get("reward", 0)), 30, GOLD))
        if bool(last_result.get("bonus", false)):
            box.add_child(_clabel("Бонус за 3 финиша!", 26, GOLD))
    else:
        box.add_child(_clabel("Награды нет, попробуй ещё раз", 24))
    box.add_child(_clabel("Монеты: %d" % coins, 28))
    box.add_child(_button("Играть снова", func(): start_run(false)))
    box.add_child(_button("В меню", func(): show_menu()))
