extends Node3D

# ======================= НАСТРОЙКИ =======================
const ROAD_LENGTH := 300.0
const LANES := [-4.2, -2.1, 0.0, 2.1, 4.2]
const FIRST_ROW_Z := 40.0
const ROW_GAP_MIN := 20.0
const ROW_GAP_MAX := 30.0
const OBSTACLE_CHANCE := 0.5
const SHADOWS := true
const START_COINS := 0           # стартовые монеты (для проверки можно поставить 20000)
const REWARD_EVERY_3 := 5000     # награда за каждый 3-й финиш
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
    return held.has(actio# ======================= ИГРОВОЙ ЦИКЛ =======================

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
    var drift_cmd := brake and steer_in != 0.0 and fwd_speed > 10.0
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
            tail_mat.emission_energy_multiplier = 0.5
            tail_mat.albedo_color = Color(0.45, 0.02, 0.02)

    var pos := car.global_position
    var back := car.global_transform.basis.z
    back.y = 0.0
    if back.length() < 0.01:
        back = Vector3(0, 0, 1)
    back = back.normalized()
    cam_back = cam_back.slerp(back, minf(1.0, delta * 3.0)).normalized()
    var target := pos + cam_back * 8.5 + Vector3(0, 3.4, 0)
    camera_3d.position = camera_3d.position.lerp(target, minf(1.0, delta * 6.0))
    camera_3d.look_at(pos - cam_back * 5.0 + Vector3(0, 1.0, 0), Vector3.UP)
    var fov_target := 62.0 + clampf(speed / 45.0, 0.0, 1.0) * 24.0
    camera_3d.fov = lerpf(camera_3d.fov, fov_target, minf(1.0, delta * 3.0))

    if is_instance_valid(status_label):
        if free_mode:
            status_label.text = "Свободная езда  (R — на старт)"
        else:
            var d := clampf(-pos.z, 0.0, ROAD_LENGTH)
            status_label.text = "%d / %d м" % [int(d), int(ROAD_LENGTH)]
    if is_instance_valid(speed_label):
        speed_label.text = "%d км/ч" % int(speed * 3.6)
    if is_instance_valid(coins_label):
        coins_label.text = "Монеты: %d" % coins
    if is_instance_valid(gauge):
        gauge.queue_redraw()
    _update_audio()n) or touches.values().has(action)
# ======================= МИР И МАШИНА =======================

func _set_mode(m: String) -> void:
    mode = m
    if m != "playing":
        held.clear()
        touches.clear()
    _update_music()
    _engine_sounds(m == "playing")

func _clear_world() -> void:
    for c in world_root.get_children():
        c.queue_free()
    preview_car = null
    car = null
    wheels.clear()
    smoke = null
    tail_mat = null
    preview_body_mat = null
    last_body_mat = null

func _mat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = rough
    m.metallic = metal
    return m

func _mesh_box(parent: Node, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mat
    mi.position = pos
    parent.add_child(mi)
    return mi

func _static_box(parent: Node, size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
    var sb := StaticBody3D.new()
    sb.position = pos
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = size
    cs.shape = sh
    sb.add_child(cs)
    _mesh_box(sb, size, Vector3.ZERO, mat)
    parent.add_child(sb)
    return sb

func _wheel_pos(id: int, i: int) -> Vector3:
    var ln := _car_f(id, "len")
    var wd := _car_f(id, "wid")
    var sx := -1.0 if i % 2 == 0 else 1.0
    var sz := -1.0 if i < 2 else 1.0
    return Vector3(sx * (wd * 0.5 - 0.1), 0.0, sz * ln * 0.32)

func _make_wheel_mesh(r: float) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = r
    cm.bottom_radius = r
    cm.height = 0.3
    mi.mesh = cm
    mi.material_override = _mat(Color(0.08, 0.08, 0.09), 0.9)
    mi.rotation_degrees = Vector3(0, 0, 90)
    return mi

func _add_body_visual(parent: Node3D, id: int, color: Color, real: bool) -> StandardMaterial3D:
    var ln := _car_f(id, "len")
    var wd := _car_f(id, "wid")
    var body_mat := _mat(color, 0.35, 0.4)
    _mesh_box(parent, Vector3(wd, 0.5, ln), Vector3(0, 0.35, 0), body_mat)
    _mesh_box(parent, Vector3(wd * 0.82, 0.42, ln * 0.45), Vector3(0, 0.81, ln * 0.08), _mat(Color(0.1, 0.12, 0.16), 0.2, 0.2))
    var head := _mat(Color(1, 1, 0.8))
    head.emission_enabled = true
    head.emission = Color(1, 1, 0.8)
    head.emission_energy_multiplier = 1.5
    var tail := StandardMaterial3D.new()
    tail.albedo_color = Color(0.45, 0.02, 0.02)
    tail.emission_enabled = true
    tail.emission = Color(1, 0.05, 0.05)
    tail.emission_energy_multiplier = 0.5
    for sx in [-1.0, 1.0]:
        _mesh_box(parent, Vector3(0.4, 0.16, 0.08), Vector3(sx * wd * 0.32, 0.42, -ln * 0.5), head)
        _mesh_box(parent, Vector3(0.4, 0.16, 0.08), Vector3(sx * wd * 0.32, 0.42, ln * 0.5), tail)
    if real:
        tail_mat = tail
    return body_mat

func _set_preview_camera() -> void:
    camera_3d.fov = 50.0
    camera_3d.position = Vector3(4.5, 2.2, 7.0)
    camera_3d.look_at(Vector3(-1.4, 0.5, 0.0), Vector3.UP)

func _show_preview(id: int) -> void:
    _clear_world()
    _mesh_box(world_root, Vector3(40, 0.1, 40), Vector3(0, -0.05, 0), _mat(Color(0.28, 0.3, 0.33)))
    preview_id = id
    var r := _car_f(id, "wheel")
    preview_car = Node3D.new()
    preview_car.position = Vector3(0, r, 0)
    preview_body_mat = _add_body_visual(preview_car, id, car_colors[id], false)
    for i in range(4):
        var wm := _make_wheel_mesh(r)
        wm.position = _wheel_pos(id, i)
        preview_car.add_child(wm)
    world_root.add_child(preview_car)
    _set_preview_camera()

func _build_world() -> void:
    var z_max := 40.0
    var z_min := -(ROAD_LENGTH + 60.0)
    if free_mode:
        z_max = 900.0
        z_min = -900.0
    var length := z_max - z_min
    var z_mid := (z_max + z_min) * 0.5
    var sand_w := 320.0
    if free_mode:
        sand_w = 1800.0
    # Песок и дорога
    _static_box(world_root, Vector3(sand_w, 1.0, length), Vector3(0, -0.55, z_mid), _mat(Color(0.86, 0.74, 0.5), 1.0))
    _static_box(world_root, Vector3(10.5, 1.0, length), Vector3(0, -0.5, z_mid), _mat(Color(0.2, 0.2, 0.22), 0.9))
    # Линии по краям
    var white := _mat(Color(0.95, 0.95, 0.95), 0.8)
    for ex in [-5.0, 5.0]:
        _mesh_box(world_root, Vector3(0.18, 0.02, length), Vector3(ex, 0.012, z_mid), white)
    # Разметка полос (пунктир)
    var dz_start := 30.0
    var dz_end := -(ROAD_LENGTH + 50.0)
    if free_mode:
        dz_start = 300.0
        dz_end = -300.0
    for lx in [-3.15, -1.05, 1.05, 3.15]:
        var z := dz_start
        while z > dz_end:
            _mesh_box(world_root, Vector3(0.12, 0.02, 3.0), Vector3(lx, 0.012, z), white)
            z -= 8.0
    if free_mode:
        return
    # Столбики вдоль дороги
    var red := _mat(Color(0.9, 0.15, 0.15))
    for i in range(0, 31):
        for sx in [-6.0, 6.0]:
            var m := white
            if i % 2 == 0:
                m = red
            _mesh_box(world_root, Vector3(0.25, 1.5, 0.25), Vector3(sx, 0.75, -float(i) * 10.0), m)
    # Финиш
    _mesh_box(world_root, Vector3(10.5, 0.03, 2.0), Vector3(0, 0.02, -ROAD_LENGTH), white)
    for sx in [-5.4, 5.4]:
        _mesh_box(world_root, Vector3(0.4, 5.0, 0.4), Vector3(sx, 2.5, -ROAD_LENGTH), red)
    _mesh_box(world_root, Vector3(11.2, 0.6, 0.4), Vector3(0, 5.1, -ROAD_LENGTH), red)
    # Препятствия
    var z := -FIRST_ROW_Z
    while z > -ROAD_LENGTH + 15.0:
        var free_lane := randi() % LANES.size()
        for li in range(LANES.size()):
            if li != free_lane and randf() < OBSTACLE_CHANCE:
                _static_box(world_root, Vector3(1.5, 1.4, 1.5), Vector3(float(LANES[li]), 0.7, z), _mat(Color(0.95, 0.5, 0.1), 0.7))
        z -= randf_range(ROW_GAP_MIN, ROW_GAP_MAX)

func _build_car() -> void:
    var cd: Dictionary = CARS[current_car]
    var mass: float = float(cd["mass"])
    var r: float = float(cd["wheel"])
    var ln: float = float(cd["len"])
    var wd: float = float(cd["wid"])
    var susp_lv := _lv("Подвеска")
    var roll := maxf(0.1, 0.30 - float(susp_lv - 1) * 0.05)

    car = VehicleBody3D.new()
    car.mass = mass
    car.can_sleep = false
    car.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    car.center_of_mass = Vector3(0, -0.1, 0)
    car.linear_damp = 0.05
    car.angular_damp = 0.5
    car.position = Vector3(0, r + 0.3, 0)

    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(wd, 0.5, ln)
    cs.shape = sh
    cs.position = Vector3(0, 0.35, 0)
    car.add_child(cs)

    last_body_mat = _add_body_visual(car, current_car, car_colors[current_car], true)

    wheels.clear()
    for i in range(4):
        var w := VehicleWheel3D.new()
        w.position = _wheel_pos(current_car, i)
        w.wheel_radius = r
        w.wheel_rest_length = 0.15
        w.suspension_travel = 0.4
        w.suspension_stiffness = 50.0
        w.suspension_max_force = 20000.0
        w.wheel_roll_influence = roll
        w.wheel_friction_slip = 9.0 * float(cd["grip"])
        w.use_as_traction = i >= 2      # задний привод
        w.use_as_steering = i < 2       # рулят передние
        w.add_child(_make_wheel_mesh(r))
        car.add_child(w)
        wheels.append(w)

    # Дым от дрифта
    smoke = CPUParticles3D.new()
    smoke.amount = 40
    smoke.lifetime = 0.9
    smoke.emitting = false
    smoke.local_coords = false
    smoke.position = Vector3(0, 0.1, ln * 0.45)
    smoke.direction = Vector3(0, 1, 0)
    smoke.spread = 25.0
    smoke.initial_velocity_min = 0.8
    smoke.initial_velocity_max = 1.8
    smoke.gravity = Vector3(0, 0.5, 0)
    smoke.scale_amount_min = 0.6
    smoke.scale_amount_max = 1.4
    var sm := SphereMesh.new()
    sm.radius = 0.25
    sm.height = 0.5
    var smat := StandardMaterial3D.new()
    smat.albedo_color = Color(0.85, 0.85, 0.85, 0.5)
    smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sm.material = smat
    smoke.mesh = sm
    car.add_child(smoke)

    world_root.add_child(car)

func start_run(is_free: bool) -> void:
    free_mode = is_free
    _clear_world()
    held.clear()
    touches.clear()
    speed = 0.0
    flip_timer = 0.0
    gas_amt = 0.0
    brake_amt = 0.0
    skid_amt = 0.0
    rpm = 0.3
    cam_back = Vector3(0, 0, 1)
    _build_world()
    _build_car()
    camera_3d.position = Vector3(0, 4.2, 8.5)
    camera_3d.fov = 62.0
    _set_mode("playing")
    _build_hud()

func _respawn_car(_to_origin: bool) -> void:
    if not is_instance_valid(car):
        return
    car.linear_velocity = Vector3.ZERO
    car.angular_velocity = Vector3.ZERO
    car.global_transform = Transform3D(Basis(), Vector3(0, float(CARS[current_car]["wheel"]) + 0.3, 0))
    cam_back = Vector3(0, 0, 1)

func finish_run(win: bool, msg: String) -> void:
    if mode != "playing":
        return
    var dist := 0.0
    if is_instance_valid(car):
        dist = clampf(-car.global_position.z, 0.0, ROAD_LENGTH)
        car.engine_force = 0.0
        car.brake = 20.0
    var earned := int(dist / ROAD_LENGTH * 500.0)
    var bonus := 0
    if win:
        finishes += 1
        earned += 1000
        if finishes % 3 == 0:
            bonus = REWARD_EVERY_3
    coins += earned + bonus
    last_result = {"win": win, "msg": msg, "earned": earned, "bonus": bonus}
    _save_game()
    _set_mode("result")
    _show_result()
# ======================= ИНТЕРФЕЙС =======================

func _on_btn(cb: Callable) -> void:
    _play_click()
    cb.call()

func _mk_button(text: String, cb: Callable, size := Vector2(320, 64), fs := 28) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = size
    b.add_theme_font_size_override("font_size", fs)
    b.pressed.connect(_on_btn.bind(cb))
    return b

func _mk_label(text: String, fs := 28, col := Color.WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", fs)
    l.add_theme_color_override("font_color", col)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    l.add_theme_constant_override("outline_size", 6)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return l

func _mk_slider(value: float, cb: Callable) -> HSlider:
    var s := HSlider.new()
    s.min_value = 0.0
    s.max_value = 1.0
    s.step = 0.01
    s.value = value
    s.custom_minimum_size = Vector2(320, 36)
    s.value_changed.connect(cb)
    return s

func _new_ui() -> void:
    if is_instance_valid(ui):
        ui.queue_free()
    touch_zones.clear()
    touch_pads.clear()
    status_label = null
    speed_label = null
    coins_label = null
    gauge = null
    ui = Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_layer.add_child(ui)

func _menu_box() -> VBoxContainer:
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 12)
    ui.add_child(vb)
    return vb

func _place_box(vb: VBoxContainer, left: bool) -> void:
    if left:
        vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 30)
    else:
        vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)

func show_menu() -> void:
    _set_mode("menu")
    _show_preview(current_car)
    _new_ui()
    var vb := _menu_box()
    vb.add_child(_mk_label("ГОНКА", 56, Color(1, 0.85, 0.2)))
    vb.add_child(_mk_label("Монеты: %d   Финишей: %d" % [coins, finishes], 24))
    vb.add_child(_mk_button("Играть", start_run.bind(false)))
    vb.add_child(_mk_button("Свободная езда", start_run.bind(true)))
    vb.add_child(_mk_button("Гараж", show_garage))
    vb.add_child(_mk_button("Настройки", show_settings))
    _place_box(vb, true)

# ---------- Настройки ----------

func _on_off(title: String, v: bool) -> String:
    return "%s: %s" % [title, "ВКЛ" if v else "ВЫКЛ"]

func _toggle_setting(key: String) -> void:
    settings[key] = not bool(settings[key])
    _update_music()
    _save_game()
    show_settings()

func _on_volume(v: float) -> void:
    settings["volume"] = v
    _apply_volume()

func _settings_back() -> void:
    _save_game()
    show_menu()

func show_settings() -> void:
    _set_mode("settings")
    _show_preview(current_car)
    _new_ui()
    var vb := _menu_box()
    vb.add_child(_mk_label("Настройки", 44))
    var items := [["music_on", "Музыка"], ["engine_on", "Двигатель"], ["brake_on", "Торможение"], ["drift_on", "Дрифт"], ["click_on", "Клики"]]
    for it in items:
        var key: String = it[0]
        var title: String = it[1]
        vb.add_child(_mk_button(_on_off(title, bool(settings[key])), _toggle_setting.bind(key), Vector2(320, 52), 24))
    vb.add_child(_mk_label("Громкость", 22))
    vb.add_child(_mk_slider(float(settings["volume"]), _on_volume))
    vb.add_child(_mk_button("Назад", _settings_back))
    _place_box(vb, true)

# ---------- HUD ----------

func _add_pad(action: String, text: String, pos: Vector2, size: Vector2) -> void:
    var p := Panel.new()
    p.position = pos
    p.size = size
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0, 0, 0, 0.45)
    sb.set_corner_radius_all(18)
    sb.border_color = Color(1, 1, 1, 0.8)
    sb.set_border_width_all(3)
    p.add_theme_stylebox_override("panel", sb)
    var l := _mk_label(text, 30)
    l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_child(l)
    ui.add_child(p)
    touch_zones[action] = Rect2(pos, size)
    touch_pads[action] = p

func _build_hud() -> void:
    _new_ui()
    var vp := _vp()
    var ps := clampf(vp.y * 0.2, 100.0, 150.0)
    var mg := 20.0

    coins_label = _mk_label("Монеты: %d" % coins, 26)
    coins_label.position = Vector2(16, 10)
    ui.add_child(coins_label)

    status_label = _mk_label("", 26)
    status_label.position = Vector2(vp.x * 0.5 - 250.0, 10)
    status_label.size = Vector2(500, 40)
    ui.add_child(status_label)

    var menu_btn := _mk_button("Меню", show_menu, Vector2(110, 48), 22)
    menu_btn.position = Vector2(vp.x - 126.0, 10)
    ui.add_child(menu_btn)

    _add_pad("left", "<", Vector2(mg, vp.y - ps - mg), Vector2(ps, ps))
    _add_pad("right", ">", Vector2(mg * 2.0 + ps, vp.y - ps - mg), Vector2(ps, ps))
    _add_pad("brake", "СТОП", Vector2(vp.x - ps * 2.0 - mg * 2.0, vp.y - ps - mg), Vector2(ps, ps))
    _add_pad("gas", "ГАЗ", Vector2(vp.x - ps - mg, vp.y - ps - mg), Vector2(ps, ps))

    var gs := 160.0
    gauge = Control.new()
    gauge.position = Vector2(vp.x - gs - 16.0, 70)
    gauge.size = Vector2(gs, gs)
    gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    gauge.draw.connect(_draw_gauge)
    ui.add_child(gauge)

    speed_label = _mk_label("0 км/ч", 22)
    speed_label.position = Vector2(0, gs * 0.62)
    speed_label.size = Vector2(gs, 30)
    gauge.add_child(speed_label)

func _draw_gauge() -> void:
    if not is_instance_valid(gauge):
        return
    var c := gauge.size * 0.5
    var r := gauge.size.x * 0.42
    var a0 := deg_to_rad(135.0)
    var sweep := deg_to_rad(270.0)
    var ratio := clampf(speed * 3.6 / GAUGE_MAX_KMH, 0.0, 1.0)
    gauge.draw_circle(c, r + 12.0, Color(0, 0, 0, 0.4))
    gauge.draw_arc(c, r, a0, a0 + sweep, 48, Color(1, 1, 1, 0.25), 10.0, true)
    if ratio > 0.01:
        var col := Color(0.2, 0.9, 0.4).lerp(Color(1, 0.2, 0.1), ratio)
        gauge.draw_arc(c, r, a0, a0 + sweep * ratio, 48, col, 10.0, true)
    var ang := a0 + sweep * ratio
    gauge.draw_line(c, c + Vector2(cos(ang), sin(ang)) * (r - 6.0), Color.WHITE, 4.0, true)
    gauge.draw_circle(c, 7.0, Color.WHITE)

# ---------- Результат ----------

func _show_result() -> void:
    _new_ui()
    var vb := _menu_box()
    var win: bool = bool(last_result.get("win", false))
    if win:
        vb.add_child(_mk_label("ФИНИШ!", 52, Color(0.4, 1, 0.5)))
    else:
        vb.add_child(_mk_label("Заезд окончен", 48, Color(1, 0.5, 0.4)))
        vb.add_child(_mk_label(str(last_result.get("msg", "")), 26))
    vb.add_child(_mk_label("Заработано: %d" % int(last_result.get("earned", 0)), 28))
    var bonus := int(last_result.get("bonus", 0))
    if bonus > 0:
        vb.add_child(_mk_label("Бонус за 3 финиша: +%d" % bonus, 28, Color(1, 0.85, 0.2)))
    vb.add_child(_mk_label("Всего монет: %d" % coins, 26))
    vb.add_child(_mk_button("Ещё раз", start_run.bind(false)))
    vb.add_child(_mk_button("В меню", show_menu))
    _place_box(vb, false)
# ======================= ГАРАЖ =======================

func _garage_move(d: int) -> void:
    garage_sel = posmod(garage_sel + d, CARS.size())
    show_garage()

func _garage_select() -> void:
    current_car = garage_sel
    _save_game()
    show_garage()

func _garage_buy() -> void:
    var price := int(CARS[garage_sel]["price"])
    if coins < price:
        garage_msg.text = "Не хватает монет: нужно %d" % price
        return
    coins -= price
    owned[garage_sel] = true
    current_car = garage_sel
    _save_game()
    show_garage()

func _open_upgrades() -> void:
    current_car = garage_sel
    show_upgrades()

func _open_paint() -> void:
    current_car = garage_sel
    show_paint()

func show_garage() -> void:
    _set_mode("garage")
    _show_preview(garage_sel)
    _new_ui()
    var cd: Dictionary = CARS[garage_sel]
    var vb := _menu_box()
    vb.add_child(_mk_label("Гараж", 44))
    vb.add_child(_mk_label("Монеты: %d" % coins, 24))
    vb.add_child(_mk_label("%s — %s" % [cd["name"], cd["info"]], 24))
    vb.add_child(_mk_label("Мощность %.2f  Скорость %.2f  Сцепление %.2f" % [float(cd["engine"]), float(cd["speed"]), float(cd["grip"])], 18))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    row.add_child(_mk_button("<", _garage_move.bind(-1), Vector2(154, 60)))
    row.add_child(_mk_button(">", _garage_move.bind(1), Vector2(154, 60)))
    vb.add_child(row)
    if owned[garage_sel]:
        if garage_sel == current_car:
            vb.add_child(_mk_label("Выбрана", 24, Color(0.4, 1, 0.5)))
        else:
            vb.add_child(_mk_button("Выбрать", _garage_select, Vector2(320, 56), 24))
        vb.add_child(_mk_button("Улучшения", _open_upgrades, Vector2(320, 56), 24))
        vb.add_child(_mk_button("Покраска", _open_paint, Vector2(320, 56), 24))
    else:
        vb.add_child(_mk_button("Купить за %d" % int(cd["price"]), _garage_buy, Vector2(320, 56), 24))
    garage_msg = _mk_label("", 22, Color(1, 0.85, 0.2))
    vb.add_child(garage_msg)
    vb.add_child(_mk_button("Назад", show_menu, Vector2(320, 56), 24))
    _place_box(vb, true)

# ======================= УЛУЧШЕНИЯ =======================

func _upgrade_cost(n: String) -> int:
    return 600 * _lv(n)

func _select_upgrade(n: String) -> void:
    selected_upgrade = n
    show_upgrades()

func _buy_upgrade() -> void:
    var n := selected_upgrade
    var lvl := _lv(n)
    if lvl >= 5:
        upgrade_detail.text = "Уже максимальный уровень"
        return
    var cost := _upgrade_cost(n)
    if coins < cost:
        upgrade_detail.text = "Не хватает монет: нужно %d" % cost
        return
    coins -= cost
    car_levels[current_car][n] = lvl + 1
    _save_game()
    show_upgrades()

func show_upgrades() -> void:
    _set_mode("upgrades")
    _show_preview(current_car)
    _new_ui()
    var vb := _menu_box()
    vb.add_child(_mk_label("Улучшения: " + str(CARS[current_car]["name"]), 34))
    vb.add_child(_mk_label("Монеты: %d" % coins, 24))
    for n in UPGRADE_NAMES:
        var lvl := _lv(n)
        var b := _mk_button("%s  (ур. %d/5)" % [n, lvl], _select_upgrade.bind(n), Vector2(320, 50), 24)
        if n == selected_upgrade:
            b.modulate = Color(1, 0.9, 0.4)
        vb.add_child(b)
    var sel_lvl := _lv(selected_upgrade)
    var txt := str(UPGRADE_INFO[selected_upgrade])
    if sel_lvl < 5:
        txt += "\nСледующий уровень: %d монет" % _upgrade_cost(selected_upgrade)
    else:
        txt += "\nМаксимальный уровень"
    upgrade_detail = _mk_label(txt, 20)
    vb.add_child(upgrade_detail)
    vb.add_child(_mk_button("Улучшить", _buy_upgrade, Vector2(320, 54), 24))
    vb.add_child(_mk_button("Назад", show_garage, Vector2(320, 54), 24))
    _place_box(vb, true)

# ======================= ПОКРАСКА =======================

func _apply_paint() -> void:
    var c := Color.from_hsv(paint_h, paint_s, paint_v)
    car_colors[current_car] = c
    if preview_body_mat != null:
        preview_body_mat.albedo_color = c

func _on_paint_h(v: float) -> void:
    paint_h = v
    _apply_paint()

func _on_paint_s(v: float) -> void:
    paint_s = v
    _apply_paint()

func _on_paint_v(v: float) -> void:
    paint_v = v
    _apply_paint()

func _paint_done() -> void:
    _save_game()
    show_garage()

func show_paint() -> void:
    _set_mode("paint")
    _show_preview(current_car)
    var c: Color = car_colors[current_car]
    paint_h = c.h
    paint_s = c.s
    paint_v = c.v
    _new_ui()
    var vb := _menu_box()
    vb.add_child(_mk_label("Покраска", 44))
    vb.add_child(_mk_label("Оттенок", 22))
    vb.add_child(_mk_slider(paint_h, _on_paint_h))
    vb.add_child(_mk_label("Насыщенность", 22))
    vb.add_child(_mk_slider(paint_s, _on_paint_s))
    vb.add_child(_mk_label("Яркость", 22))
    vb.add_child(_mk_slider(paint_v, _on_paint_v))
    vb.add_child(_mk_button("Готово", _paint_done, Vector2(320, 56), 24))
    _place_box(vb, true)
