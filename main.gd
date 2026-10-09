extends Node3D

# ======================= НАСТРОЙКИ =======================
const ROAD_LENGTH := 300.0
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
var settings := {"music_on": true, "engine_on": true, "brake_on": true, "drift_on": true, "click_on": true, "volume": 0.8}
var selected_upgrade := "Мотор"
var paint_h := 0.6
var paint_s := 0.8
var paint_v := 0.9

var mode := "menu"
var free_mode := false
var car: VehicleBody3D
var wheels: Array[VehicleWheel3D] = []
var preview_car: Node3D
var preview_id := -1
var camera_3d: Camera3D
var world_root: Node3D
var ui_layer: CanvasLayer
var ui: Control
var smoke: CPUParticles3D
var tail_mat: StandardMaterial3D
var last_body_mat: StandardMaterial3D
var preview_body_mat: StandardMaterial3D

var speed := 0.0
var flip_timer := 0.0
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

var status_label: Label
var speed_label: Label
var coins_label: Label
var debug_label: Label
var upgrade_detail: Label
var garage_msg: Label
var gauge: Control

var music_player: AudioStreamPlayer
var click_player: AudioStreamPlayer
var engine_player: AudioStreamPlayer
var brake_player: AudioStreamPlayer
var skid_player: AudioStreamPlayer

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
    for i in range(CARS.size()):
        car_levels.append({"Мотор": 1, "Подвеска": 1, "Колёса": 1, "Скорость": 1, "Тормоза": 1})
        car_colors.append(Color.html(str(CARS[i]["color"])))

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
    _apply_volume()

func _apply_volume() -> void:
    AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(settings["volume"]))))

func _play_click() -> void:
    if bool(settings["click_on"]):
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

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key := event as InputEventKey
        if key.pressed and not key.echo:
            match key.keycode:
                KEY_W, KEY_UP: held["gas"] = true
                KEY_S, KEY_DOWN: held["brake"] = true
                KEY_A, KEY_LEFT: held["left"] = true
                KEY_D, KEY_RIGHT: held["right"] = true
                KEY_R:
                    if mode == "playing" and free_mode:
                        _respawn_car(true)
                KEY_ESCAPE:
                    if mode == "playing":
                        show_menu()
        elif not key.pressed:
            match key.keycode:
                KEY_W, KEY_UP: held.erase("gas")
                KEY_S, KEY_DOWN: held.erase("brake")
                KEY_A, KEY_LEFT: held.erase("left")
                KEY_D, KEY_RIGHT: held.erase("right")

func _input(event: InputEvent) -> void:
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

func _button(text: String, cb: Callable, w: float = 340.0, h: float = 56.0) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(w, h)
    b.add_theme_font_size_override("font_size", 26)
    b.pressed.connect(_on_button_pressed.bind(cb))
    return b

func _on_button_pressed(cb: Callable) -> void:
    _play_click()
    cb.call()

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
    vb.add_theme_constant_override("separation", 14)
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
    smoke = null
    preview_car = null
    tail_mat = null
    wheels.clear()

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
        holder.position = _wheel_pos(i, float(cd["len"]), float(cd["wid"])) + Vector3(0, -0.1, 0)
        preview_car.add_child(holder)
        _add_wheel_mesh(holder, r)
    preview_car.position = Vector3(0, r + 0.1, 0)
    world_root.add_child(preview_car)
    preview_id = id
    camera_3d.position = Vector3(5.5, 2.4, 7.5)
    camera_3d.look_at(Vector3(-1.8, 0.6, 0), Vector3.UP)
# ======================= ЭКРАНЫ МЕНЮ =======================

func show_menu() -> void:
    mode = "menu"
    free_mode = false
    _engine_sounds(false)
    _update_music()
    _show_preview(current_car)
    _clear_ui()
    var box := _side_box(380)
    box.add_child(_label("ГОНКИ", 56, Color(1, 0.85, 0.2)))
    coins_label = _label("Монеты: %d" % coins, 30)
    box.add_child(coins_label)
    box.add_child(_button("Играть", func(): start_run(false)))
    box.add_child(_button("Свободная езда", func(): start_run(true)))
    box.add_child(_button("Гараж", func(): garage_sel = current_car; show_garage()))
    box.add_child(_button("Настройки", func(): show_settings()))

func show_settings() -> void:
    mode = "settings"
    _engine_sounds(false)
    _update_music()
    _clear_ui()
    var box := _center_box()
    box.add_child(_label("Настройки", 44, Color(1, 0.85, 0.2)))
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
        cb.add_theme_font_size_override("font_size", 26)
        cb.toggled.connect(_on_setting_toggled.bind(str(it[0])))
        box.add_child(cb)
    box.add_child(_label("Громкость", 26))
    var sl := HSlider.new()
    sl.min_value = 0.0
    sl.max_value = 1.0
    sl.step = 0.05
    sl.value = float(settings["volume"])
    sl.custom_minimum_size = Vector2(360, 30)
    sl.value_changed.connect(_on_volume_changed)
    box.add_child(sl)
    box.add_child(_button("Назад", func(): _save_game(); show_menu()))

func _on_setting_toggled(on: bool, key: String) -> void:
    settings[key] = on
    _update_music()
    _save_game()

func _on_volume_changed(v: float) -> void:
    settings["volume"] = v
    _apply_volume()

# ---------- Гараж ----------

func show_garage() -> void:
    mode = "garage"
    _engine_sounds(false)
    _update_music()
    _show_preview(garage_sel)
    _clear_ui()
    var cd: Dictionary = CARS[garage_sel]
    var box := _side_box(440)
    box.add_child(_label("Гараж", 38, Color(1, 0.85, 0.2)))
    coins_label = _label("Монеты: %d" % coins, 26)
    box.add_child(coins_label)
    box.add_child(_label(str(cd["name"]), 34))
    box.add_child(_label(str(cd["info"]), 22))
    box.add_child(_label("Мотор %d%% | Скорость %d%% | Сцепл. %d%%" % [int(float(cd["engine"]) * 100.0), int(float(cd["speed"]) * 100.0), int(float(cd["grip"]) * 100.0)], 20))
    var nav := HBoxContainer.new()
    nav.add_theme_constant_override("separation", 12)
    nav.add_child(_button("<", func(): _garage_step(-1), 100.0))
    nav.add_child(_button(">", func(): _garage_step(1), 100.0))
    box.add_child(nav)
    if owned[garage_sel]:
        if current_car == garage_sel:
            box.add_child(_label("Выбрана", 26, Color(0.4, 1, 0.5)))
        else:
            box.add_child(_button("Выбрать", func(): _garage_select()))
        box.add_child(_button("Улучшения", func(): show_upgrades()))
        box.add_child(_button("Покраска", func(): show_paint()))
    else:
        box.add_child(_button("Купить за %d" % int(cd["price"]), func(): _garage_buy()))
    garage_msg = _label("", 24, Color(1, 0.5, 0.4))
    box.add_child(garage_msg)
    box.add_child(_button("Назад", func(): _save_game(); show_menu()))

func _garage_step(d: int) -> void:
    garage_sel = posmod(garage_sel + d, CARS.size())
    show_garage()

func _garage_select() -> void:
    current_car = garage_sel
    _save_game()
    show_garage()

func _garage_buy() -> void:
    var price := int(CARS[garage_sel]["price"])
    if coins >= price:
        coins -= price
        owned[garage_sel] = true
        _save_game()
        show_garage()
    else:
        garage_msg.text = "Не хватает монет!"

# ---------- Улучшения ----------

func _upgrade_cost(level: int) -> int:
    return 1500 * level

func show_upgrades() -> void:
    mode = "upgrades"
    _show_preview(garage_sel)
    _clear_ui()
    var box := _side_box(440)
    box.add_child(_label("Улучшения", 38, Color(1, 0.85, 0.2)))
    coins_label = _label("Монеты: %d" % coins, 26)
    box.add_child(coins_label)
    for n in UPGRADE_NAMES:
        var lv := int(car_levels[garage_sel][n])
        var mark := ""
        if n == selected_upgrade:
            mark = "> "
        box.add_child(_button("%s%s  ур. %d/5" % [mark, n, lv], func(): _select_upgrade(n), 400.0, 46.0))
    var lv_sel := int(car_levels[garage_sel][selected_upgrade])
    var txt := "%s: %s\n" % [selected_upgrade, str(UPGRADE_INFO[selected_upgrade])]
    if lv_sel >= 5:
        txt += "Максимальный уровень"
    else:
        txt += "Цена: %d" % _upgrade_cost(lv_sel)
    upgrade_detail = _label(txt, 22)
    box.add_child(upgrade_detail)
    box.add_child(_button("Улучшить", func(): _do_upgrade(), 400.0, 50.0))
    garage_msg = _label("", 22, Color(1, 0.5, 0.4))
    box.add_child(garage_msg)
    box.add_child(_button("Назад", func(): show_garage(), 400.0, 50.0))

func _select_upgrade(n: String) -> void:
    selected_upgrade = n
    show_upgrades()

func _do_upgrade() -> void:
    var lv := int(car_levels[garage_sel][selected_upgrade])
    if lv >= 5:
        garage_msg.text = "Уже максимум!"
        return
    var cost := _upgrade_cost(lv)
    if coins < cost:
        garage_msg.text = "Не хватает монет!"
        return
    coins -= cost
    car_levels[garage_sel][selected_upgrade] = lv + 1
    _save_game()
    show_upgrades()

# ---------- Покраска ----------

func show_paint() -> void:
    mode = "paint"
    _show_preview(garage_sel)
    var c: Color = car_colors[garage_sel]
    paint_h = c.h
    paint_s = c.s
    paint_v = c.v
    _clear_ui()
    var box := _side_box(440)
    box.add_child(_label("Покраска", 38, Color(1, 0.85, 0.2)))
    var names := ["Цвет", "Насыщенность", "Яркость"]
    var vals := [paint_h, paint_s, paint_v]
    for i in range(3):
        box.add_child(_label(str(names[i]), 24))
        var sl := HSlider.new()
        sl.min_value = 0.0
        sl.max_value = 1.0
        sl.step = 0.01
        sl.value = float(vals[i])
        sl.custom_minimum_size = Vector2(400, 34)
        sl.value_changed.connect(_on_paint_changed.bind(i))
        box.add_child(sl)
    box.add_child(_button("Готово", func(): _save_game(); show_garage(), 400.0, 56.0))

func _on_paint_changed(v: float, which: int) -> void:
    match which:
        0: paint_h = v
        1: paint_s = v
        2: paint_v = v
    var c := Color.from_hsv(paint_h, paint_s, paint_v)
    car_colors[garage_sel] = c
    if preview_body_mat != null:
        preview_body_mat.albedo_color = c

# ---------- Результат заезда ----------

func _show_result() -> void:
    mode = "result"
    _clear_ui()
    var box := _center_box()
    var win: bool = bool(last_result.get("win", false))
    if win:
        box.add_child(_label("ФИНИШ!", 56, Color(0.4, 1, 0.5)))
        box.add_child(_label("Награда: +%d монет" % int(last_result.get("reward", 0)), 30))
    else:
        box.add_child(_label("Заезд окончен", 48, Color(1, 0.4, 0.4)))
        box.add_child(_label(str(last_result.get("msg", "")), 28))
    box.add_child(_label("Монеты: %d" % coins, 28))
    box.add_child(_button("Ещё раз", func(): start_run(false), 400.0))
    box.add_child(_button("В меню", func(): show_menu(), 400.0))
# ======================= ИГРОВОЙ ЦИКЛ =======================

func _physics_process(delta: float) -> void:
    if mode != "playing" or not is_instance_valid(car):
        return
    var gas := _pressed("gas")
    var brake := _pressed("brake")
    var left := _pressed("left")
    var right := _pressed("right")

    # Будим машину, если она "уснула"
    if gas or brake or left or right:
        car.sleeping = false

    var cd: Dictionary = CARS[current_car]
    var m_lv := _lv("Мотор")
    var engine_max: float = 42.0 * float(cd["engine"]) + float(m_lv - 1) * 7.0
    var max_speed: float = 38.0 * float(cd["speed"]) + float(_lv("Скорость") - 1) * 4.5 + float(m_lv - 1) * 1.5
    var brake_max: float = 22.0 + float(_lv("Тормоза") - 1) * 4.0
    var steer_rate: float = 3.0 + float(_lv("Колёса") - 1) * 0.3
    var base_grip: float = 9.0 * float(cd["grip"]) + float(_lv("Колёса") - 1) * 0.9

    var p := car.global_position
    var fwd := -car.global_transform.basis.z
    var fwd_speed := fwd.dot(car.linear_velocity)
    var side := car.global_transform.basis.x.dot(car.linear_velocity)
    speed = car.linear_velocity.length()
    var on_sand := absf(p.x) > 5.2

    # В Godot положительный угол руля = поворот налево
    var steer_in := 0.0
    if left:
        steer_in += 1.0
    if right:
        steer_in -= 1.0

    # Дрифт: на скорости тормоз + поворот
    var drift_cmd: bool = brake and steer_in != 0.0 and fwd_speed > 10.0
    drifting = drift_cmd or (absf(side) > 4.5 and speed > 10.0)

    var engine := 0.0
    var brake_force := 0.0
    if gas:
        var ratio := clampf(maxf(fwd_speed, 0.0) / max_speed, 0.0, 1.0)
        engine = engine_max * (1.0 - ratio * ratio)
    if brake:
        if fwd_speed > 1.5:
            brake_force = brake_max
            if drift_cmd:
                brake_force = brake_max * 0.25
        elif not gas:
            engine = -engine_max * 0.3
    if not gas and not brake:
        # Накат: тормоза нет, только лёгкое сопротивление
        car.apply_central_force(-fwd * fwd_speed * 40.0)
    car.engine_force = engine
    car.brake = brake_force

    var speed_factor := clampf(absf(fwd_speed) / max_speed, 0.0, 1.0)
    var max_steer := lerpf(0.55, 0.16, speed_factor)
    car.steering = move_toward(car.steering, steer_in * max_steer, delta * steer_rate)

    # Сцепление: на песке хуже, при дрифте задние колёса скользят
    var grip := base_grip
    if on_sand:
        grip = base_grip * 0.6
    for i in range(wheels.size()):
        var g := grip
        if i >= 2 and drift_cmd:
            g = grip * 0.3
        wheels[i].wheel_friction_slip = g
    if drift_cmd:
        car.apply_torque(Vector3(0.0, steer_in * 4500.0, 0.0))

    # Данные для звука
    var ratio_s := clampf(speed / max_speed, 0.0, 1.0)
    var gear_pos := minf(ratio_s, 0.999) * 5.0
    rpm = 0.3 + (gear_pos - floorf(gear_pos)) * 0.7
    var gas_target := 0.0
    if gas:
        gas_target = 1.0
    gas_amt = move_toward(gas_amt, gas_target, delta * 4.0)
    brake_amt = 0.0
    if brake and fwd_speed > 6.0:
        brake_amt = clampf(fwd_speed / 25.0, 0.25, 1.0)
    skid_amt = 0.0
    if speed > 6.0:
        skid_amt = clampf(absf(side) / 7.0, 0.0, 1.0)
    if drift_cmd:
        skid_amt = maxf(skid_amt, 0.7)

    if is_instance_valid(smoke):
        smoke.emitting = drifting

    if free_mode:
        if p.y < -30.0 or Vector2(p.x, p.z).length() > 900.0:
            _respawn_car(true)
        return

    if p.y < -15.0:
        finish_run(false, "Ты улетел с трассы!")
        return
    if absf(p.x) > 150.0:
        finish_run(false, "Ты уехал за пределы карты!")
        return
    if car.global_transform.basis.y.y < 0.3:
        flip_timer += delta
        if flip_timer > 1.5:
            finish_run(false, "Машина перевернулась!")
            return
    else:
        flip_timer = 0.0
    if p.z <= -ROAD_LENGTH:
        finish_run(true, "")

func _process(delta: float) -> void:
    if is_instance_valid(preview_car):
        preview_car.rotation.y += delta * 0.45
    if mode != "playing" or not is_instance_valid(car):
        return

    for action in touch_pads:
        var pad: Control = touch_pads[action]
        if is_instance_valid(pad):
            pad.modulate.a = 1.0 if _pressed(action) else 0.6

    # Задние фары: красные при торможении
    if tail_mat != null:
        if _pressed("brake"):
            tail_mat.emission_energy_multiplier = 5.0
            tail_mat.albedo_color = Color(1.0, 0.05, 0.05)
        else:
            tail_mat.emission_energy_multiplier = 1.0
            tail_mat.albedo_color = Color(0.5, 0.0, 0.0)

    # Камера за машиной
    var back := car.global_transform.basis.z
    back.y = 0.0
    if back.length() > 0.1:
        var nb := cam_back.lerp(back.normalized(), clampf(delta * 2.5, 0.0, 1.0))
        if nb.length() > 0.01:
            cam_back = nb.normalized()
    var target := car.global_position + cam_back * 9.0 + Vector3(0, 4.5, 0)
    camera_3d.global_position = camera_3d.global_position.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
    camera_3d.look_at(car.global_position + Vector3(0, 1.2, 0) - cam_back * 4.0, Vector3.UP)

    # HUD
    if is_instance_valid(coins_label):
        coins_label.text = "Монеты: %d" % coins
    if is_instance_valid(speed_label):
        speed_label.text = "%d\nкм/ч" % int(speed * 3.6)
    if is_instance_valid(debug_label):
        if free_mode:
            debug_label.text = ""
        else:
            debug_label.text = "До финиша: %d м" % maxi(0, int(ROAD_LENGTH + car.global_position.z))
    if is_instance_valid(gauge):
        gauge.queue_redraw()
    _update_audio()

# ======================= HUD =======================

func _build_hud() -> void:
    _clear_ui()
    var vp := _vp()
    coins_label = _label("Монеты: %d" % coins, 28)
    coins_label.position = Vector2(20, 12)
    ui.add_child(coins_label)
    var st := "Свободная езда (R — вернуть машину)"
    if not free_mode:
        st = "Заезд"
    status_label = _label(st, 22)
    status_label.position = Vector2(20, 50)
    ui.add_child(status_label)
    debug_label = _label("", 24, Color(1, 0.9, 0.4))
    debug_label.position = Vector2(20, 82)
    ui.add_child(debug_label)

    var menu_btn := _button("Меню", func(): show_menu(), 120.0, 46.0)
    menu_btn.position = Vector2(vp.x * 0.5 - 60.0, 10.0)
    ui.add_child(menu_btn)

    gauge = Control.new()
    gauge.size = Vector2(190, 190)
    gauge.position = Vector2(vp.x - 210.0, 10.0)
    gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    gauge.draw.connect(_draw_gauge)
    ui.add_child(gauge)
    speed_label = _label("0\nкм/ч", 28)
    speed_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    gauge.add_child(speed_label)

    var s := Vector2(150, 150)
    _add_pad("left", "<", Vector2(20, vp.y - 170.0), s)
    _add_pad("right", ">", Vector2(190, vp.y - 170.0), s)
    _add_pad("brake", "ТОРМОЗ", Vector2(vp.x - 340.0, vp.y - 170.0), s)
    _add_pad("gas", "ГАЗ", Vector2(vp.x - 170.0, vp.y - 170.0), s)

func _add_pad(action: String, text: String, pos: Vector2, sz: Vector2) -> void:
    var pad := ColorRect.new()
    pad.color = Color(1, 1, 1, 0.28)
    pad.position = pos
    pad.size = sz
    pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var l := _label(text, 28)
    l.set_anchors_preset(Control.PRESET_FULL_RECT)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    pad.add_child(l)
    ui.add_child(pad)
    touch_pads[action] = pad
    touch_zones[action] = Rect2(pos, sz)

func _draw_gauge() -> void:
    if not is_instance_valid(gauge):
        return
    var c := gauge.size * 0.5
    var r := 80.0
    gauge.draw_circle(c, r + 8.0, Color(0, 0, 0, 0.5))
    gauge.draw_arc(c, r, deg_to_rad(135.0), deg_to_rad(405.0), 64, Color(1, 1, 1, 0.3), 6.0)
    var t := clampf(speed * 3.6 / GAUGE_MAX_KMH, 0.0, 1.0)
    var ang := deg_to_rad(135.0 + 270.0 * t)
    if t > 0.01:
        gauge.draw_arc(c, r, deg_to_rad(135.0), ang, 64, Color(0.2, 0.9, 0.4), 8.0)
    gauge.draw_line(c, c + Vector2(cos(ang), sin(ang)) * (r - 10.0), Color(1, 0.2, 0.2), 4.0)
# ======================= МИР И МАШИНА =======================

func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    return m

func _box_mesh(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.position = pos
    mi.material_override = mat
    parent.add_child(mi)
    return mi

func _add_static_box(size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
    var sb := StaticBody3D.new()
    sb.position = pos
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = size
    cs.shape = bs
    sb.add_child(cs)
    _box_mesh(sb, size, Vector3.ZERO, mat)
    world_root.add_child(sb)
    return sb

func _wheel_pos(i: int, car_len: float, car_wid: float) -> Vector3:
    var sx := 1.0
    if i % 2 == 0:
        sx = -1.0
    var sz := 1.0
    if i < 2:
        sz = -1.0
    return Vector3(sx * (car_wid * 0.5 - 0.05), 0.0, sz * car_len * 0.32)

func _add_wheel_mesh(parent: Node3D, r: float) -> void:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = r
    cm.bottom_radius = r
    cm.height = 0.3
    mi.mesh = cm
    mi.material_override = _mat(Color(0.08, 0.08, 0.08))
    mi.rotation_degrees = Vector3(0, 0, 90)
    parent.add_child(mi)

func _build_car_visual(id: int, root: Node3D) -> Dictionary:
    var cd: Dictionary = CARS[id]
    var cl := float(cd["len"])
    var cw := float(cd["wid"])
    var body_mat := _mat(car_colors[id])
    body_mat.metallic = 0.5
    body_mat.roughness = 0.35
    var glass := _mat(Color(0.1, 0.15, 0.2))
    glass.metallic = 0.8
    glass.roughness = 0.1
    var head := _mat(Color(1, 1, 0.8))
    head.emission_enabled = true
    head.emission = Color(1, 1, 0.8)
    head.emission_energy_multiplier = 1.5
    var tail := _mat(Color(0.5, 0, 0))
    tail.emission_enabled = true
    tail.emission = Color(1, 0, 0)
    tail.emission_energy_multiplier = 1.0
    _box_mesh(root, Vector3(cw, 0.5, cl), Vector3(0, 0.3, 0), body_mat)
    _box_mesh(root, Vector3(cw * 0.86, 0.42, cl * 0.45), Vector3(0, 0.78, cl * 0.08), glass)
    _box_mesh(root, Vector3(cw * 0.86, 0.06, cl * 0.45), Vector3(0, 1.01, cl * 0.08), body_mat)
    for sx in [-1.0, 1.0]:
        _box_mesh(root, Vector3(0.35, 0.15, 0.05), Vector3(sx * cw * 0.33, 0.38, -cl * 0.5), head)
        _box_mesh(root, Vector3(0.35, 0.15, 0.05), Vector3(sx * cw * 0.33, 0.38, cl * 0.5), tail)
    return {"body": body_mat, "tail": tail}

func _spawn_car() -> void:
    var cd: Dictionary = CARS[current_car]
    var cl := float(cd["len"])
    var cw := float(cd["wid"])
    var r := float(cd["wheel"])
    car = VehicleBody3D.new()
    car.mass = float(cd["mass"])
    car.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    car.center_of_mass = Vector3(0, -0.2, 0)
    car.position = Vector3(0, 1.3, 0)
    world_root.add_child(car)

    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = Vector3(cw, 0.9, cl)
    cs.shape = bs
    cs.position = Vector3(0, 0.5, 0)
    car.add_child(cs)

    var mats := _build_car_visual(current_car, car)
    last_body_mat = mats["body"]
    tail_mat = mats["tail"]

    wheels.clear()
    var grip := float(cd["grip"])
    var sus_lv := _lv("Подвеска")
    var whl_lv := _lv("Колёса")
    for i in range(4):
        var wl := VehicleWheel3D.new()
        wl.position = _wheel_pos(i, cl, cw)
        wl.wheel_radius = r
        wl.wheel_rest_length = 0.2
        wl.suspension_travel = 0.3
        wl.suspension_stiffness = 50.0 + float(sus_lv - 1) * 6.0
        wl.suspension_max_force = 10000.0
        wl.wheel_roll_influence = maxf(0.1, 0.3 - float(sus_lv - 1) * 0.05)
        wl.wheel_friction_slip = 9.0 * grip + float(whl_lv - 1) * 0.9
        wl.use_as_steering = i < 2
        wl.use_as_traction = true
        car.add_child(wl)
        _add_wheel_mesh(wl, r)
        wheels.append(wl)

    smoke = CPUParticles3D.new()
    smoke.emitting = false
    smoke.amount = 40
    smoke.lifetime = 0.9
    smoke.direction = Vector3(0, 1, 0)
    smoke.spread = 25.0
    smoke.initial_velocity_min = 0.5
    smoke.initial_velocity_max = 1.5
    smoke.gravity = Vector3(0, 0.3, 0)
    smoke.local_coords = false
    var sm := SphereMesh.new()
    sm.radius = 0.35
    sm.height = 0.7
    var smat := StandardMaterial3D.new()
    smat.albedo_color = Color(0.8, 0.8, 0.8, 0.45)
    smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sm.material = smat
    smoke.mesh = sm
    smoke.position = Vector3(0, 0.2, cl * 0.5)
    car.add_child(smoke)

func _build_world(free: bool) -> void:
    var total_len := ROAD_LENGTH + 100.0
    var cz := -(ROAD_LENGTH + 40.0) * 0.5
    var sand_size := Vector3(320, 0.2, total_len)
    var sand_pos := Vector3(0, -0.12, cz)
    if free:
        sand_size = Vector3(1800, 0.2, 1800)
        sand_pos = Vector3(0, -0.12, 0)
    _add_static_box(sand_size, sand_pos, _mat(Color(0.85, 0.72, 0.45)))
    _add_static_box(Vector3(10.6, 0.2, total_len), Vector3(0, -0.1, cz), _mat(Color(0.22, 0.22, 0.24)))

    var white := _mat(Color(0.95, 0.95, 0.95))
    var yellow := _mat(Color(0.95, 0.8, 0.1))
    for x in [-3.15, -1.05, 1.05, 3.15]:
        _box_mesh(world_root, Vector3(0.12, 0.02, total_len), Vector3(x, 0.012, cz), white)
    for x in [-5.0, 5.0]:
        _box_mesh(world_root, Vector3(0.15, 0.02, total_len), Vector3(x, 0.012, cz), yellow)

    if free:
        return

    # Финишные ворота
    var red := _mat(Color(0.85, 0.1, 0.1))
    _box_mesh(world_root, Vector3(10.6, 0.02, 1.0), Vector3(0, 0.014, -ROAD_LENGTH), white)
    for x in [-5.4, 5.4]:
        _box_mesh(world_root, Vector3(0.4, 6.0, 0.4), Vector3(x, 3.0, -ROAD_LENGTH), red)
    _box_mesh(world_root, Vector3(11.2, 0.8, 0.4), Vector3(0, 6.0, -ROAD_LENGTH), red)

    # Препятствия: в каждом ряду минимум одна свободная полоса
    var omat := _mat(Color(0.9, 0.35, 0.1))
    var z := -FIRST_ROW_Z
    while z > -ROAD_LENGTH + 20.0:
        var free_lane := randi() % LANES.size()
        for li in range(LANES.size()):
            if li == free_lane:
                continue
            if randf() < OBSTACLE_CHANCE:
                _add_static_box(Vector3(1.7, 1.2, 1.7), Vector3(LANES[li], 0.6, z), omat)
        z -= randf_range(ROW_GAP_MIN, ROW_GAP_MAX)

# ======================= СТАРТ / ФИНИШ / РЕСПАУН =======================

func start_run(free: bool) -> void:
    free_mode = free
    _clear_world()
    _build_world(free)
    _spawn_car()
    speed = 0.0
    flip_timer = 0.0
    rpm = 0.3
    gas_amt = 0.0
    brake_amt = 0.0
    skid_amt = 0.0
    drifting = false
    held.clear()
    touches.clear()
    cam_back = Vector3(0, 0, 1)
    camera_3d.global_position = car.global_position + Vector3(0, 4.5, 9)
    mode = "playing"
    _build_hud()
    _update_music()
    _engine_sounds(true)

func _respawn_car(reset_pos: bool) -> void:
    if not is_instance_valid(car):
        return
    var pos := Vector3(0, 1.3, 0)
    if not reset_pos:
        pos = car.global_position + Vector3(0, 2, 0)
    car.global_transform = Transform3D(Basis(), pos)
    car.linear_velocity = Vector3.ZERO
    car.angular_velocity = Vector3.ZERO
    car.steering = 0.0
    cam_back = Vector3(0, 0, 1)
    flip_timer = 0.0

func finish_run(win: bool, msg: String) -> void:
    if mode != "playing":
        return
    var reward := 0
    if win:
        finishes += 1
        reward = 500
        if finishes % 3 == 0:
            reward += REWARD_EVERY_3
        coins += reward
    last_result = {"win": win, "msg": msg, "reward": reward}
    mode = "result"
    if is_instance_valid(car):
        car.engine_force = 0.0
        car.brake = 5.0
    _engine_sounds(false)
    _update_music()
    _save_game()
    _show_result()
