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
var run_time := 0.0
var run_coins := 0

var status_label: Label
var speed_label: Label
var coins_label: Label
var garage_msg: Label
var detail_label: Label
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
        holder.position = _wheel_pos(i, float(cd["len"]), float(cd["wid"])) + Vector3(0, -0.2, 0)
        preview_car.add_child(holder)
        _add_wheel_mesh(holder, r)
    preview_car.position = Vector3(0, r + 0.2, 0)
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
    var vs := HSlider.new()
    vs.min_value = 0.0
    vs.max_value = 1.0
    vs.step = 0.05
    vs.value = float(settings["volume"])
    vs.custom_minimum_size = Vector2(380, 36)
    vs.value_changed.connect(_on_volume_changed)
    box.add_child(vs)
    box.add_child(_button("Назад", func(): _save_game(); show_menu()))

func _on_setting_toggled(pressed: bool, key: String) -> void:
    settings[key] = pressed
    _play_click()
    _update_music()
    _save_game()

func _on_volume_changed(v: float) -> void:
    settings["volume"] = v
    _apply_volume()

func _bar(v: float, vmax: float) -> String:
    var n := clampi(int(round(v / vmax * 5.0)), 1, 5)
    return "#".repeat(n) + "-".repeat(5 - n)

func _garage_step(d: int) -> void:
    garage_sel = posmod(garage_sel + d, CARS.size())
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
        garage_msg.text = "Не хватает монет!"

func show_garage() -> void:
    mode = "garage"
    _engine_sounds(false)
    _update_music()
    _show_preview(garage_sel)
    _clear_ui()
    var cd: Dictionary = CARS[garage_sel]
    var box := _side_box(440)
    box.add_child(_label("Гараж", 44, Color(1, 0.85, 0.2)))
    coins_label = _label("Монеты: %d" % coins, 28)
    box.add_child(coins_label)
    box.add_child(_label(str(cd["name"]), 34, Color(0.6, 0.9, 1.0)))
    box.add_child(_label(str(cd["info"]), 22))
    var stats := "Разгон     %s\nСкорость   %s\nСцепление  %s" % [
        _bar(float(cd["engine"]), 1.7), _bar(float(cd["speed"]), 1.5), _bar(float(cd["grip"]), 1.3)]
    box.add_child(_label(stats, 24))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    row.add_child(_button("<", func(): _garage_step(-1), 100, 46))
    row.add_child(_button(">", func(): _garage_step(1), 100, 46))
    box.add_child(row)
    if owned[garage_sel]:
        if current_car == garage_sel:
            box.add_child(_label("Выбрана", 26, Color(0.5, 1, 0.5)))
        else:
            box.add_child(_button("Выбрать", func(): current_car = garage_sel; _save_game(); show_garage(), 340, 46))
        box.add_child(_button("Улучшения", func(): show_upgrades(), 340, 46))
        box.add_child(_button("Покраска", func(): show_paint(), 340, 46))
    else:
        box.add_child(_button("Купить: %d" % int(cd["price"]), func(): _buy_car(), 340, 46))
    garage_msg = _label("", 22, Color(1, 0.5, 0.5))
    box.add_child(garage_msg)
    box.add_child(_button("Назад", func(): show_menu(), 340, 46))

func _upgrade_cost(lvl: int) -> int:
    return 500 * lvl

func _do_upgrade() -> void:
    var lvl := int(car_levels[garage_sel][selected_upgrade])
    var cost := _upgrade_cost(lvl)
    if lvl >= 5:
        return
    if coins >= cost:
        coins -= cost
        car_levels[garage_sel][selected_upgrade] = lvl + 1
        _save_game()
        show_upgrades()
    else:
        garage_msg.text = "Не хватает монет!"

func show_upgrades() -> void:
    mode = "upgrades"
    _clear_ui()
    var box := _side_box(460)
    box.add_child(_label("Улучшения", 40, Color(1, 0.85, 0.2)))
    coins_label = _label("Монеты: %d" % coins, 28)
    box.add_child(coins_label)
    for n in UPGRADE_NAMES:
        var lvl := int(car_levels[garage_sel][n])
        var prefix := "> " if n == selected_upgrade else ""
        box.add_child(_button("%s%s  ур. %d/5" % [prefix, n, lvl], func(): selected_upgrade = n; show_upgrades(), 400, 46))
    var cur := int(car_levels[garage_sel][selected_upgrade])
    var txt := "%s\nУровень %d/5" % [str(UPGRADE_INFO[selected_upgrade]), cur]
    if cur < 5:
        txt += "\nЦена: %d" % _upgrade_cost(cur)
    else:
        txt += "\nМаксимум"
    detail_label = _label(txt, 24)
    box.add_child(detail_label)
    if cur < 5:
        box.add_child(_button("Улучшить", func(): _do_upgrade(), 340, 46))
    garage_msg = _label("", 22, Color(1, 0.5, 0.5))
    box.add_child(garage_msg)
    box.add_child(_button("Назад", func(): show_garage(), 340, 46))

func _slider(v: float, which: String) -> HSlider:
    var s := HSlider.new()
    s.min_value = 0.0
    s.max_value = 1.0
    s.step = 0.01
    s.value = v
    s.custom_minimum_size = Vector2(380, 36)
    s.value_changed.connect(_on_paint_changed.bind(which))
    return s

func _on_paint_changed(v: float, which: String) -> void:
    match which:
        "h": paint_h = v
        "s": paint_s = v
        "v": paint_v = v
    if preview_body_mat != null:
        preview_body_mat.albedo_color = Color.from_hsv(paint_h, paint_s, paint_v)

func show_paint() -> void:
    mode = "paint"
    _clear_ui()
    var c: Color = car_colors[garage_sel]
    paint_h = c.h
    paint_s = c.s
    paint_v = c.v
    var box := _side_box(440)
    box.add_child(_label("Покраска", 40, Color(1, 0.85, 0.2)))
    box.add_child(_label("Оттенок", 24))
    box.add_child(_slider(paint_h, "h"))
    box.add_child(_label("Насыщенность", 24))
    box.add_child(_slider(paint_s, "s"))
    box.add_child(_label("Яркость", 24))
    box.add_child(_slider(paint_v, "v"))
    box.add_child(_button("Сохранить", func(): _save_paint(), 340, 46))
    box.add_child(_button("Отмена", func(): show_garage(), 340, 46))

func _save_paint() -> void:
    car_colors[garage_sel] = Color.from_hsv(paint_h, paint_s, paint_v)
    _save_game()
    show_garage()
# ======================= МИР И МАШИНА =======================

func _mat(c: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    return m

func _box_mesh(size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = m
    mi.position = pos
    return mi

func _static_box(size: Vector3, pos: Vector3, c: Color, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
    var sb := StaticBody3D.new()
    sb.position = pos
    sb.rotation_degrees = rot_deg
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = size
    cs.shape = bs
    sb.add_child(cs)
    sb.add_child(_box_mesh(size, Vector3.ZERO, _mat(c)))
    world_root.add_child(sb)
    return sb

func _wheel_pos(i: int, L: float, W: float) -> Vector3:
    var sx := -1.0 if i % 2 == 0 else 1.0
    var sz := -1.0 if i < 2 else 1.0
    return Vector3(sx * (W * 0.5 - 0.12), 0.0, sz * L * 0.34)

func _add_wheel_mesh(holder: Node3D, r: float) -> void:
    var tire := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = r
    cm.bottom_radius = r
    cm.height = 0.3
    cm.radial_segments = 20
    tire.mesh = cm
    tire.material_override = _mat(Color(0.08, 0.08, 0.08))
    tire.rotation_degrees = Vector3(0, 0, 90)
    holder.add_child(tire)
    var hub := MeshInstance3D.new()
    var hm := CylinderMesh.new()
    hm.top_radius = r * 0.55
    hm.bottom_radius = r * 0.55
    hm.height = 0.32
    hm.radial_segments = 12
    hub.mesh = hm
    hub.material_override = _mat(Color(0.75, 0.75, 0.8))
    hub.rotation_degrees = Vector3(0, 0, 90)
    holder.add_child(hub)

func _build_car_visual(id: int, parent: Node3D) -> Dictionary:
    var cd: Dictionary = CARS[id]
    var L := float(cd["len"])
    var W := float(cd["wid"])
    var body_mat := _mat(car_colors[id])
    body_mat.metallic = 0.5
    body_mat.roughness = 0.35
    var glass := _mat(Color(0.1, 0.15, 0.22))
    glass.metallic = 0.8
    glass.roughness = 0.1
    parent.add_child(_box_mesh(Vector3(W - 0.1, 0.5, L), Vector3(0, 0.3, 0), body_mat))
    var cab_size := Vector3(W - 0.3, 0.5, L * 0.5)
    var cab_pos := Vector3(0, 0.8, 0.1)
    match id:
        1:
            cab_size = Vector3(W - 0.4, 0.4, L * 0.4)
            cab_pos = Vector3(0, 0.75, 0.2)
        2:
            cab_size = Vector3(W - 0.2, 0.65, L * 0.65)
            cab_pos = Vector3(0, 0.9, 0.15)
        3:
            cab_size = Vector3(W - 0.2, 0.6, L * 0.35)
            cab_pos = Vector3(0, 0.85, -L * 0.2)
            parent.add_child(_box_mesh(Vector3(W - 0.15, 0.25, L * 0.4), Vector3(0, 0.65, L * 0.28), _mat(Color(0.2, 0.2, 0.22))))
        4:
            cab_size = Vector3(W - 0.5, 0.35, L * 0.35)
            cab_pos = Vector3(0, 0.7, 0.1)
    parent.add_child(_box_mesh(cab_size, cab_pos, glass))
    parent.add_child(_box_mesh(Vector3(cab_size.x - 0.05, 0.06, cab_size.z - 0.3), cab_pos + Vector3(0, cab_size.y * 0.5, 0), body_mat))
    if id == 1 or id == 4:
        parent.add_child(_box_mesh(Vector3(W - 0.2, 0.06, 0.4), Vector3(0, 0.95, L * 0.5 - 0.2), body_mat))
    var head := _mat(Color(1, 1, 0.85))
    head.emission_enabled = true
    head.emission = Color(1, 1, 0.8)
    head.emission_energy_multiplier = 1.5
    tail_mat = _mat(Color(0.8, 0.05, 0.05))
    tail_mat.emission_enabled = true
    tail_mat.emission = Color(1, 0.05, 0.05)
    tail_mat.emission_energy_multiplier = 0.5
    var hx := W * 0.5 - 0.4
    for s in [-1.0, 1.0]:
        parent.add_child(_box_mesh(Vector3(0.35, 0.15, 0.06), Vector3(s * hx, 0.38, -L * 0.5), head))
        parent.add_child(_box_mesh(Vector3(0.35, 0.15, 0.06), Vector3(s * hx, 0.38, L * 0.5), tail_mat))
    return {"body": body_mat}

func _add_coin(x: float, z: float) -> void:
    var a := Area3D.new()
    a.position = Vector3(x, 1.0, z)
    var cs := CollisionShape3D.new()
    var sh := SphereShape3D.new()
    sh.radius = 1.0
    cs.shape = sh
    a.add_child(cs)
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.5
    cm.bottom_radius = 0.5
    cm.height = 0.12
    mi.mesh = cm
    mi.rotation_degrees = Vector3(90, 0, 0)
    var m := _mat(Color(1, 0.85, 0.1))
    m.emission_enabled = true
    m.emission = Color(1, 0.7, 0)
    m.emission_energy_multiplier = 0.6
    mi.material_override = m
    a.add_child(mi)
    a.add_to_group("coins")
    a.body_entered.connect(_on_coin_entered.bind(a))
    world_root.add_child(a)

func _on_coin_entered(body: Node3D, a: Area3D) -> void:
    if body != car or a.is_queued_for_deletion():
        return
    run_coins += 50
    _play_click()
    a.queue_free()

func _add_obstacle(x: float, z: float) -> void:
    if randf() < 0.5:
        _static_box(Vector3(1.9, 0.9, 0.6), Vector3(x, 0.45, z), Color(0.9, 0.35, 0.1))
    else:
        _static_box(Vector3(1.3, 1.3, 1.3), Vector3(x, 0.65, z), Color(0.6, 0.4, 0.2))

func _build_world(is_free: bool) -> void:
    if is_free:
        _static_box(Vector3(800, 2, 800), Vector3(0, -1, 0), Color(0.78, 0.7, 0.45))
        for i in range(28):
            var a := randf() * TAU
            var d := randf_range(25.0, 160.0)
            var p := Vector3(cos(a) * d, 0.0, sin(a) * d)
            if i % 3 == 0:
                _static_box(Vector3(6, 0.4, 10), p + Vector3(0, 0.9, 0), Color(0.55, 0.55, 0.6), Vector3(-14, randf() * 360.0, 0))
            else:
                var h := randf_range(1.0, 2.5)
                _static_box(Vector3(randf_range(2, 4), h, randf_range(2, 4)), p + Vector3(0, h * 0.5, 0), Color(0.6, 0.4, 0.25), Vector3(0, randf() * 360.0, 0))
        return
    var z_min := -(ROAD_LENGTH + 400.0)
    var z_max := 100.0
    _static_box(Vector3(600, 2, z_max - z_min), Vector3(0, -1, (z_max + z_min) * 0.5), Color(0.25, 0.55, 0.25))
    var r0 := 40.0
    var r1 := -(ROAD_LENGTH + 80.0)
    var rlen := r0 - r1
    var rc := (r0 + r1) * 0.5
    world_root.add_child(_box_mesh(Vector3(12.6, 0.04, rlen), Vector3(0, 0.02, rc), _mat(Color(0.18, 0.18, 0.2))))
    for s in [-1.0, 1.0]:
        _static_box(Vector3(0.6, 1.2, rlen), Vector3(s * 6.6, 0.6, rc), Color(0.8, 0.8, 0.85))
    _static_box(Vector3(13.8, 3.0, 0.6), Vector3(0, 1.5, r0), Color(0.8, 0.8, 0.85))
    _static_box(Vector3(13.8, 3.0, 0.6), Vector3(0, 1.5, r1), Color(0.8, 0.8, 0.85))
    # разметка
    var xs := [-3.15, -1.05, 1.05, 3.15]
    var count_z := int((r0 - r1) / 8.0)
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    var dash := BoxMesh.new()
    dash.size = Vector3(0.15, 0.02, 2.5)
    mm.mesh = dash
    mm.instance_count = count_z * xs.size()
    var idx := 0
    for k in range(count_z):
        for x in xs:
            mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY, Vector3(x, 0.05, r0 - 4.0 - k * 8.0)))
            idx += 1
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = _mat(Color(0.95, 0.95, 0.95))
    world_root.add_child(mmi)
    # препятствия и монеты
    var z := -FIRST_ROW_Z
    while z > -ROAD_LENGTH + 15.0:
        var lane_ids := range(LANES.size())
        lane_ids.shuffle()
        var used := 0
        if randf() < OBSTACLE_CHANCE:
            used = 1 + randi() % 2
            for j in range(used):
                _add_obstacle(float(LANES[lane_ids[j]]), z)
        var coin_lane := float(LANES[lane_ids[used]])
        for k in range(4):
            _add_coin(coin_lane, z - 5.0 - k * 3.0)
        z -= randf_range(ROW_GAP_MIN, ROW_GAP_MAX)
    # финиш
    world_root.add_child(_box_mesh(Vector3(12.6, 0.05, 1.5), Vector3(0, 0.06, -ROAD_LENGTH), _mat(Color(1, 1, 1))))
    var post_mat := _mat(Color(0.9, 0.1, 0.1))
    for s in [-1.0, 1.0]:
        world_root.add_child(_box_mesh(Vector3(0.5, 6.0, 0.5), Vector3(s * 6.0, 3.0, -ROAD_LENGTH), post_mat))
    world_root.add_child(_box_mesh(Vector3(12.5, 1.4, 0.4), Vector3(0, 5.6, -ROAD_LENGTH), post_mat))
    var fl := Label3D.new()
    fl.text = "ФИНИШ"
    fl.font_size = 128
    fl.pixel_size = 0.008
    fl.outline_size = 12
    fl.position = Vector3(0, 5.6, -ROAD_LENGTH + 0.25)
    world_root.add_child(fl)
    # деревья
    for i in range(36):
        var side := -1.0 if i % 2 == 0 else 1.0
        var tree := Node3D.new()
        tree.position = Vector3(side * randf_range(10.0, 25.0), 0, -randf_range(0.0, ROAD_LENGTH + 60.0))
        var trunk := MeshInstance3D.new()
        var tm := CylinderMesh.new()
        tm.top_radius = 0.25
        tm.bottom_radius = 0.3
        tm.height = 2.0
        trunk.mesh = tm
        trunk.material_override = _mat(Color(0.4, 0.25, 0.1))
        trunk.position = Vector3(0, 1.0, 0)
        tree.add_child(trunk)
        var crown := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = 1.6
        sm.height = 3.2
        crown.mesh = sm
        crown.material_override = _mat(Color(0.12, 0.45, 0.15))
        crown.position = Vector3(0, 3.2, 0)
        tree.add_child(crown)
        world_root.add_child(tree)

func _spawn_car() -> void:
    var cd: Dictionary = CARS[current_car]
    var r := float(cd["wheel"])
    var L := float(cd["len"])
    var W := float(cd["wid"])
    var grip := float(cd["grip"])
    var lv_w := float(_lv("Колёса"))
    var lv_s := float(_lv("Подвеска"))
    car = VehicleBody3D.new()
    car.mass = float(cd["mass"])
    car.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    car.center_of_mass = Vector3(0, -0.15, 0)
    car.linear_damp = 0.05
    car.angular_damp = 1.0
    car.position = Vector3(0, 1.2, 0)
    var col := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = Vector3(W - 0.1, 0.7, L)
    col.shape = bs
    col.position = Vector3(0, 0.35, 0)
    car.add_child(col)
    _build_car_visual(current_car, car)
    wheels.clear()
    for i in range(4):
        var w := VehicleWheel3D.new()
        w.position = _wheel_pos(i, L, W)
        w.use_as_traction = true
        w.use_as_steering = i < 2
        w.wheel_radius = r
        w.wheel_rest_length = 0.2
        w.suspension_travel = 0.25
        w.suspension_stiffness = 40.0 + 4.0 * lv_s
        w.suspension_max_force = 8000.0
        w.damping_compression = 0.88
        w.damping_relaxation = 1.0
        w.wheel_roll_influence = 0.16 - 0.02 * lv_s
        w.wheel_friction_slip = 8.0 * grip * (0.92 + 0.04 * lv_w)
        _add_wheel_mesh(w, r)
        car.add_child(w)
        wheels.append(w)
    smoke = CPUParticles3D.new()
    smoke.emitting = false
    smoke.amount = 40
    smoke.lifetime = 1.2
    smoke.local_coords = false
    smoke.direction = Vector3(0, 1, 0)
    smoke.spread = 25.0
    smoke.initial_velocity_min = 0.5
    smoke.initial_velocity_max = 1.5
    smoke.gravity = Vector3(0, 0.4, 0)
    smoke.scale_amount_min = 0.6
    smoke.scale_amount_max = 1.2
    var sph := SphereMesh.new()
    sph.radius = 0.25
    sph.height = 0.5
    var smat := StandardMaterial3D.new()
    smat.albedo_color = Color(0.85, 0.85, 0.85, 0.45)
    smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sph.material = smat
    smoke.mesh = sph
    smoke.position = Vector3(0, 0.15, L * 0.45)
    car.add_child(smoke)
    world_root.add_child(car)
# ======================= ЗАЕЗД =======================

func start_run(is_free: bool) -> void:
    mode = "playing"
    free_mode = is_free
    run_time = 0.0
    run_coins = 0
    speed = 0.0
    flip_timer = 0.0
    gas_amt = 0.0
    brake_amt = 0.0
    skid_amt = 0.0
    rpm = 0.2
    cam_back = Vector3(0, 0, 1)
    _clear_world()
    _build_world(is_free)
    _spawn_car()
    _build_hud()
    _engine_sounds(true)
    _update_music()
    _snap_camera()

func _make_pad(action: String, txt: String, rect: Rect2, col: Color) -> void:
    var p := ColorRect.new()
    p.color = col
    p.position = rect.position
    p.size = rect.size
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(p)
    var l := _label(txt, 44)
    l.position = Vector2.ZERO
    l.size = rect.size
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    p.add_child(l)
    touch_zones[action] = rect
    touch_pads[action] = p

func _build_hud() -> void:
    _clear_ui()
    var vp := _vp()
    var mb := _button("Меню", func(): show_menu(), 150, 48)
    mb.position = Vector2(20, 16)
    ui.add_child(mb)
    if free_mode:
        var rb := _button("Сброс", func(): _respawn_car(true), 150, 48)
        rb.position = Vector2(20, 76)
        ui.add_child(rb)
    status_label = _label("", 28)
    status_label.position = Vector2(vp.x * 0.5 - 250, 14)
    status_label.size = Vector2(500, 40)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ui.add_child(status_label)
    coins_label = _label("", 28, Color(1, 0.85, 0.2))
    coins_label.position = Vector2(vp.x - 320, 14)
    coins_label.size = Vector2(300, 40)
    coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    ui.add_child(coins_label)
    gauge = Control.new()
    gauge.size = Vector2(190, 190)
    gauge.position = Vector2(vp.x * 0.5 - 95, vp.y - 205)
    gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    gauge.draw.connect(_draw_gauge)
    ui.add_child(gauge)
    speed_label = _label("0", 30)
    speed_label.position = Vector2(0, 112)
    speed_label.size = Vector2(190, 44)
    speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    gauge.add_child(speed_label)
    var base := Color(1, 1, 1, 0.35)
    _make_pad("left", "<", Rect2(30, vp.y - 170, 130, 140), base)
    _make_pad("right", ">", Rect2(180, vp.y - 170, 130, 140), base)
    _make_pad("brake", "СТОП", Rect2(vp.x - 360, vp.y - 170, 160, 140), Color(1, 0.3, 0.3, 0.35))
    _make_pad("gas", "ГАЗ", Rect2(vp.x - 180, vp.y - 190, 150, 160), Color(0.3, 1, 0.3, 0.35))

func _draw_gauge() -> void:
    var c := gauge.size / 2.0
    var r := minf(c.x, c.y) - 6.0
    var a0 := deg_to_rad(135.0)
    var a1 := deg_to_rad(405.0)
    var frac := clampf(absf(speed) * 3.6 / GAUGE_MAX_KMH, 0.0, 1.0)
    var ang := a0 + (a1 - a0) * frac
    gauge.draw_circle(c, r, Color(0, 0, 0, 0.55))
    gauge.draw_arc(c, r - 6.0, a0, a1, 48, Color(1, 1, 1, 0.45), 4.0)
    gauge.draw_arc(c, r - 6.0, a0, ang, 48, Color(1, 0.6, 0.1), 7.0)
    gauge.draw_line(c, c + Vector2(cos(ang), sin(ang)) * (r - 18.0), Color(1, 0.2, 0.2), 4.0)
    gauge.draw_circle(c, 7.0, Color.WHITE)

func _update_hud() -> void:
    var kmh := absf(speed) * 3.6
    speed_label.text = "%d км/ч" % int(kmh)
    gauge.queue_redraw()
    coins_label.text = "Монеты: %d" % (coins + run_coins)
    if free_mode:
        status_label.text = "Свободная езда"
    else:
        var left := maxf(0.0, ROAD_LENGTH + car.global_position.z)
        status_label.text = "До финиша: %d м   %.1f с" % [int(left), run_time]
    for a in touch_pads:
        var p: ColorRect = touch_pads[a]
        p.color.a = 0.75 if _pressed(a) else 0.35

func _process(delta: float) -> void:
    if mode == "playing" and is_instance_valid(car):
        _update_audio()
        _update_hud()
        for c in get_tree().get_nodes_in_group("coins"):
            c.rotation.y += delta * 3.0
    elif is_instance_valid(preview_car):
        preview_car.rotation.y += delta * 0.6

func _physics_process(delta: float) -> void:
    if mode != "playing" or not is_instance_valid(car):
        return
    if not free_mode:
        run_time += delta
    _drive(delta)
    if car.global_transform.basis.y.y < 0.25:
        flip_timer += delta
    else:
        flip_timer = 0.0
    if flip_timer > 2.0 or car.global_position.y < -20.0:
        _respawn_car(false)
    if tail_mat != null:
        tail_mat.emission_energy_multiplier = 4.0 if _pressed("brake") else 0.5
    _update_camera(delta)
    if not free_mode and car.global_position.z < -ROAD_LENGTH:
        _finish()

# ======================= ЕЗДА =======================
# Газ отпущен -> тяги и тормоза нет, машина катится (накат).
# Тормоз включается ТОЛЬКО кнопкой "СТОП" / S.

func _drive(delta: float) -> void:
    var gas := _pressed("gas")
    var brk := _pressed("brake")
    var steer_in := 0.0
    if _pressed("left"):
        steer_in += 1.0
    if _pressed("right"):
        steer_in -= 1.0
    var bs := car.global_transform.basis
    var vel := car.linear_velocity
    speed = vel.dot(-bs.z)
    var kmh := absf(speed) * 3.6
    var m := car.mass
    var eng := _car_f(current_car, "engine") * (0.85 + 0.06 * float(_lv("Мотор")))
    var vmax := (150.0 / 3.6) * _car_f(current_car, "speed") * (0.88 + 0.06 * float(_lv("Скорость")))
    var lv_b := float(_lv("Тормоза"))
    var lv_w := float(_lv("Колёса"))

    var force := 0.0
    var brake_val := 0.0
    if brk:
        if speed > 1.0:
            brake_val = m * 0.03 * (0.75 + 0.1 * lv_b)
        elif speed > -8.0:
            force = -m * 0.04 * eng
    elif gas:
        if speed < -1.0:
            brake_val = m * 0.03
        else:
            var ratio := clampf(speed / vmax, 0.0, 1.0)
            force = m * 0.05 * eng * (1.0 - ratio * ratio * ratio)
    car.engine_force = force
    car.brake = brake_val

    var max_steer := maxf(0.55 / (1.0 + kmh / 80.0), 0.12)
    car.steering = move_toward(car.steering, steer_in * max_steer, delta * (3.0 + 0.4 * lv_w))

    # прижимная сила для устойчивости
    car.apply_central_force(-bs.y * speed * speed * 1.0)

    # дрифт и дым
    var lat := vel.dot(bs.x)
    var target_skid := 0.0
    if wheels.size() > 2 and wheels[2].is_in_contact():
        target_skid = clampf((absf(lat) - 1.5) / 5.0, 0.0, 1.0)
    skid_amt = move_toward(skid_amt, target_skid, delta * 4.0)
    drifting = absf(lat) > 3.0
    if smoke != null:
        smoke.emitting = drifting or (brk and kmh > 40.0)

    gas_amt = move_toward(gas_amt, 1.0 if gas else 0.0, delta * 3.0)
    brake_amt = clampf(speed / 20.0, 0.0, 1.0) if brk else 0.0
    rpm = lerpf(rpm, clampf(absf(speed) / vmax, 0.05, 1.0), delta * 5.0)

# ======================= КАМЕРА, СБРОС, ФИНИШ =======================

func _snap_camera() -> void:
    if not is_instance_valid(car):
        return
    camera_3d.global_position = car.global_position + Vector3(0, 3.4, 8.5)
    camera_3d.look_at(car.global_position + Vector3(0, 1.0, -4.0), Vector3.UP)

func _update_camera(delta: float) -> void:
    var pos := car.global_position
    var back := car.global_transform.basis.z
    back.y = 0.0
    if back.length() > 0.01:
        back = back.normalized()
        var mixed := cam_back.lerp(back, clampf(delta * 3.0, 0.0, 1.0))
        if mixed.length() > 0.01:
            cam_back = mixed.normalized()
    var dist := 8.5 + minf(absf(speed) * 0.05, 2.5)
    var target := pos + cam_back * dist + Vector3(0, 3.4, 0)
    camera_3d.global_position = camera_3d.global_position.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
    var look_at_pos := pos + Vector3(0, 1.0, 0) - cam_back * 4.0
    if camera_3d.global_position.distance_to(look_at_pos) > 0.1:
        camera_3d.look_at(look_at_pos, Vector3.UP)

func _respawn_car(reset: bool) -> void:
    if not is_instance_valid(car):
        return
    var p := car.global_position
    if reset:
        p = Vector3(0, 1.2, 0)
    else:
        p.y = 1.5
        if not free_mode:
            p.x = clampf(p.x, -4.5, 4.5)
    car.linear_velocity = Vector3.ZERO
    car.angular_velocity = Vector3.ZERO
    car.steering = 0.0
    car.global_transform = Transform3D(Basis.IDENTITY, p)
    flip_timer = 0.0
    cam_back = Vector3(0, 0, 1)
    _snap_camera()

func _finish() -> void:
    finishes += 1
    var base := 300 + int(maxf(0.0, 90.0 - run_time) * 10.0)
    var bonus := 0
    if finishes % 3 == 0:
        bonus = REWARD_EVERY_3
    var total := run_coins + base + bonus
    coins += total
    last_result = {"time": run_time, "collected": run_coins, "base": base, "bonus": bonus, "total": total}
    _save_game()
    car.engine_force = 0.0
    car.brake = car.mass * 0.03
    _engine_sounds(false)
    mode = "result"
    _update_music()
    _show_result()

func _show_result() -> void:
    mode = "result"
    _clear_ui()
    var box := _center_box()
    var t := _label("ФИНИШ!", 52, Color(1, 0.85, 0.2))
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(t)
    var txt := "Время: %.1f с\nСобрано монет: %d\nЗа финиш: %d" % [
        float(last_result.get("time", 0.0)), int(last_result.get("collected", 0)), int(last_result.get("base", 0))]
    if int(last_result.get("bonus", 0)) > 0:
        txt += "\nНаграда за 3 финиша: %d" % int(last_result["bonus"])
    txt += "\nИтого: %d" % int(last_result.get("total", 0))
    var l := _label(txt, 30)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(l)
    box.add_child(_button("Ещё раз", func(): start_run(false)))
    box.add_child(_button("Меню", func(): show_menu()))
