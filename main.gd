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
            status_label.text = "Свободный режим"
        else:
            status_label.text = "До финиша: %d м" % int(maxf(0.0, ROAD_LENGTH + pos.z))
    if is_instance_valid(coins_label):
        if free_mode:
            coins_label.text = "Катайся, прыгай с трамплинов!"
        else:
            coins_label.text = "Монеты: %d  |  Финиши: %d/3" % [coins, finishes % 3]
    if is_instance_valid(speed_label):
        speed_label.text = "%d" % int(speed * 3.6)
    if is_instance_valid(gauge):
        gauge.queue_redraw()
    if is_instance_valid(debug_label):
        var contact := 0
        for w in wheels:
            if w.is_in_contact():
                contact += 1
        debug_label.text = "колёса на земле: %d/4" % contact
    _update_audio()

func _on_car_body_entered(body: Node) -> void:
    if mode != "playing" or not is_instance_valid(car) or free_mode:
        return
    if body.is_in_group("obstacle") and car.linear_velocity.length() > 5.0:
        call_deferred("finish_run", false, "Ты врезался в препятствие!")

func _respawn_car(to_start: bool) -> void:
    if not is_instance_valid(car):
        return
    var yaw := car.global_rotation.y
    var pos := car.global_position + Vector3(0, 2.0, 0)
    if to_start:
        pos = Vector3(0, 2.0, 0)
        yaw = 0.0
    car.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
    car.linear_velocity = Vector3.ZERO
    car.angular_velocity = Vector3.ZERO

# ======================= ИНТЕРФЕЙС: общее =======================

func _clear_ui() -> void:
    if is_instance_valid(ui):
        ui.queue_free()
    ui = Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(ui)

func _clear_world() -> void:
    if is_instance_valid(world_root):
        world_root.queue_free()
    world_root = Node3D.new()
    add_child(world_root)
    car = null
    preview_car = null
    smoke = null
    wheels.clear()

func _dim(rect: Rect2, alpha: float) -> void:
    var r := ColorRect.new()
    r.color = Color(0, 0, 0, alpha)
    r.position = rect.position
    r.size = rect.size
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(r)

func _label(parent: Control, text: String, pos: Vector2, size: int = 28, color_value: Color = Color.WHITE) -> Label:
    var label := Label.new()
    label.text = text
    label.position = pos
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color_value)
    parent.add_child(label)
    return label

func _label_c(text: String, y: float, size: int = 28, color_value: Color = Color.WHITE) -> Label:
    var label := Label.new()
    label.text = text
    label.position = Vector2(0, y)
    label.size = Vector2(_vp().x, size + 20)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color_value)
    ui.add_child(label)
    return label

func _button(parent: Control, text: String, pos: Vector2, size: Vector2, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.position = pos
    button.size = size
    button.add_theme_font_size_override("font_size", 24)
    button.pressed.connect(_play_click)
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

# ======================= ИНТЕРФЕЙС: игра =======================

func _build_hud() -> void:
    var vp := _vp()
    touches.clear()
    touch_zones.clear()
    touch_pads.clear()
    _clear_ui()
    status_label = _label(ui, "", Vector2(25, 20), 24)
    coins_label = _label(ui, "", Vector2(25, 55), 20)
    debug_label = _label(ui, "", Vector2(25, 85), 16, Color(0.8, 0.8, 0.8))

    # Спидометр (внизу по центру)
    gauge = Control.new()
    gauge.position = Vector2(vp.x / 2.0 - 120.0, vp.y - 250.0)
    gauge.size = Vector2(240, 240)
    gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    gauge.draw.connect(_draw_gauge)
    ui.add_child(gauge)
    speed_label = Label.new()
    speed_label.position = Vector2(0, 140)
    speed_label.size = Vector2(240, 54)
    speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    speed_label.add_theme_font_size_override("font_size", 44)
    speed_label.add_theme_color_override("font_color", Color.WHITE)
    speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    speed_label.text = "0"
    gauge.add_child(speed_label)
    var unit := Label.new()
    unit.position = Vector2(0, 192)
    unit.size = Vector2(240, 30)
    unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    unit.add_theme_font_size_override("font_size", 20)
    unit.add_theme_color_override("font_color", Color.GOLD)
    unit.mouse_filter = Control.MOUSE_FILTER_IGNORE
    unit.text = "км/ч"
    gauge.add_child(unit)

    if free_mode:
        _button(ui, "ВЫЙТИ", Vector2(vp.x - 170, 12), Vector2(150, 48), show_menu)
        _button(ui, "СБРОС", Vector2(vp.x - 340, 12), Vector2(150, 48), _reset_pressed)
    else:
        _button(ui, "МЕНЮ", Vector2(vp.x - 170, 12), Vector2(150, 48), show_menu)
    _touch_pad("gas", "▲ ГАЗ", Rect2(30, vp.y - 260, 200, 120))
    _touch_pad("brake", "▼ ТОРМОЗ", Rect2(30, vp.y - 125, 200, 95))
    _touch_pad("left", "◀", Rect2(vp.x - 270, vp.y - 170, 115, 140))
    _touch_pad("right", "▶", Rect2(vp.x - 145, vp.y - 170, 115, 140))

func _reset_pressed() -> void:
    _respawn_car(false)

func _draw_gauge() -> void:
    if not is_instance_valid(gauge):
        return
    var c := Vector2(120, 120)
    gauge.draw_circle(c, 112.0, Color(0, 0, 0, 0.45))
    gauge.draw_arc(c, 104.0, deg_to_rad(135.0), deg_to_rad(405.0), 64, Color(1, 1, 1, 0.5), 4.0, true)
    gauge.draw_arc(c, 98.0, deg_to_rad(135.0 + 0.8 * 270.0), deg_to_rad(405.0), 24, Color(1.0, 0.2, 0.2, 0.8), 6.0, true)
    for i in range(13):
        var a := deg_to_rad(135.0 + float(i) * 22.5)
        var d := Vector2(cos(a), sin(a))
        gauge.draw_line(c + d * 88.0, c + d * 104.0, Color(1, 1, 1, 0.85), 3.0, true)
    var ratio := clampf(speed * 3.6 / GAUGE_MAX_KMH, 0.0, 1.0)
    var na := deg_to_rad(135.0 + ratio * 270.0)
    var nd := Vector2(cos(na), sin(na))
    gauge.draw_line(c - nd * 12.0, c + nd * 86.0, Color(1.0, 0.25, 0.2), 5.0, true)
    gauge.draw_circle(c, 9.0, Color(0.9, 0.9, 0.9))

func _touch_pad(action: String, text: String, rect: Rect2) -> void:
    var pad := Panel.new()
    pad.position = rect.position
    pad.size = rect.size
    pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.1, 0.12, 0.16, 0.8)
    style.set_corner_radius_all(18)
    style.set_border_width_all(3)
    style.border_color = Color(1, 1, 1, 0.6)
    pad.add_theme_stylebox_override("panel", style)
    ui.add_child(pad)
    var label := Label.new()
    label.text = text
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 30)
    pad.add_child(label)
    label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    touch_zones[action] = rect
    touch_pads[action] = pad
    pad.modulate.a = 0.6
# ======================= МЕНЮ =======================

func show_menu() -> void:
    mode = "menu"
    free_mode = false
    held.clear()
    touches.clear()
    _engine_sounds(false)
    _clear_world()
    _clear_ui()
    _update_music()
    var vp := _vp()
    _dim(Rect2(0, 0, 520, vp.y), 0.35)
    _label(ui, "DRIVE 3D", Vector2(80, 30), 58, Color(0.25, 0.75, 1.0))
    _label(ui, "Монеты: %d     Финиши: %d/3" % [coins, finishes % 3], Vector2(85, 105), 25, Color.GOLD)
    _label(ui, "Машина: %s" % CARS[current_car]["name"], Vector2(85, 140), 22)
    _button(ui, "ЗАЕЗД ДО ФИНИША", Vector2(90, 190), Vector2(340, 60), start_race)
    _button(ui, "СВОБОДНЫЙ РЕЖИМ", Vector2(90, 265), Vector2(340, 60), start_free)
    _button(ui, "ГАРАЖ", Vector2(90, 340), Vector2(340, 60), open_garage)
    _button(ui, "НАСТРОЙКИ ЗВУКА", Vector2(90, 415), Vector2(340, 60), show_settings)
    _label(ui, "Поверни телефон горизонтально", Vector2(85, 500), 21)
    camera_3d.fov = 55.0
    camera_3d.position = Vector3(4.2, 2.0, 7.0)
    camera_3d.look_at(Vector3(-1.6, 0.7, 0.0), Vector3.UP)
    _make_menu_world()

# ======================= НАСТРОЙКИ ЗВУКА =======================

func show_settings() -> void:
    mode = "settings"
    _clear_ui()
    var vp := _vp()
    _dim(Rect2(0, 0, 700, vp.y), 0.6)
    _label(ui, "НАСТРОЙКИ ЗВУКА", Vector2(70, 30), 42, Color(0.25, 0.75, 1.0))
    var items := [["music_on", "Музыка меню"], ["engine_on", "Звук газа"], ["brake_on", "Звук тормоза"], ["drift_on", "Звук дрифта"], ["click_on", "Звуки кнопок"]]
    for i in range(items.size()):
        var key: String = items[i][0]
        var title: String = items[i][1]
        var state := "ВЫКЛ"
        if bool(settings[key]):
            state = "ВКЛ"
        _button(ui, "%s: %s" % [title, state], Vector2(70, 105 + i * 68), Vector2(520, 56), func(): _toggle_setting(key))
    _label(ui, "Общая громкость", Vector2(70, 455), 24)
    var s := HSlider.new()
    s.min_value = 0.0
    s.max_value = 1.0
    s.step = 0.05
    s.value = float(settings["volume"])
    s.position = Vector2(70, 495)
    s.custom_minimum_size = Vector2(520, 40)
    s.size = Vector2(520, 40)
    s.value_changed.connect(_on_volume_changed)
    s.drag_ended.connect(_volume_saved)
    ui.add_child(s)
    _button(ui, "НАЗАД", Vector2(70, 570), Vector2(220, 55), show_menu)

func _toggle_setting(key: String) -> void:
    settings[key] = not bool(settings[key])
    _save_game()
    _update_music()
    show_settings()

func _on_volume_changed(v: float) -> void:
    settings["volume"] = v
    _apply_volume()

func _volume_saved(_changed: bool) -> void:
    _save_game()

# ======================= ГАРАЖ =======================

func open_garage() -> void:
    garage_sel = current_car
    show_garage()

func show_garage() -> void:
    mode = "garage"
    held.clear()
    touches.clear()
    _clear_ui()
    if not is_instance_valid(preview_car) or preview_id != garage_sel:
        _rebuild_preview(garage_sel)
    var vp := _vp()
    _dim(Rect2(0, 0, 820, vp.y), 0.6)
    _label(ui, "ГАРАЖ", Vector2(70, 25), 42, Color(0.25, 0.75, 1.0))
    _label(ui, "Монеты: %d" % coins, Vector2(75, 80), 27, Color.GOLD)
    for i in range(CARS.size()):
        var tag := ""
        if i == current_car:
            tag = "  [едет]"
        elif owned[i]:
            tag = "  [куплена]"
        else:
            tag = "  [%d]" % CARS[i]["price"]
        var idx := i
        _button(ui, "%d. %s%s" % [i + 1, CARS[i]["name"], tag], Vector2(70, 130 + i * 62), Vector2(400, 52), func(): _select_car(idx))
    var cd: Dictionary = CARS[garage_sel]
    var top_kmh := int(38.0 * float(cd["speed"]) * 3.6)
    var txt := "%s\n%s\nМакс. скорость: %d км/ч\nРазгон: %d%%\nСцепление: %d%%" % [cd["name"], cd["info"], top_kmh, int(float(cd["engine"]) * 100.0), int(float(cd["grip"]) * 100.0)]
    _label(ui, txt, Vector2(500, 130), 22, Color.WHITE)
    garage_msg = _label(ui, "", Vector2(500, 300), 22, Color.GOLD)
    if owned[garage_sel]:
        if garage_sel != current_car:
            _button(ui, "ВЫБРАТЬ ЭТУ МАШИНУ", Vector2(500, 335), Vector2(290, 52), equip_car)
        _button(ui, "УЛУЧШЕНИЯ", Vector2(500, 400), Vector2(290, 52), show_upgrades)
        _button(ui, "ПОКРАСИТЬ", Vector2(500, 465), Vector2(290, 52), show_paint)
    else:
        _button(ui, "КУПИТЬ ЗА %d" % int(cd["price"]), Vector2(500, 335), Vector2(290, 52), buy_car)
    _button(ui, "НАЗАД", Vector2(70, 570), Vector2(220, 55), show_menu)

func _select_car(i: int) -> void:
    garage_sel = i
    _rebuild_preview(i)
    show_garage()

func equip_car() -> void:
    current_car = garage_sel
    _save_game()
    show_garage()

func buy_car() -> void:
    var price := int(CARS[garage_sel]["price"])
    if coins < price:
        garage_msg.text = "Не хватает монет! Нужно: %d" % price
        return
    coins -= price
    owned[garage_sel] = true
    current_car = garage_sel
    _save_game()
    show_garage()

# ======================= УЛУЧШЕНИЯ =======================

func show_upgrades() -> void:
    mode = "upgrades"
    _clear_ui()
    var vp := _vp()
    _dim(Rect2(0, 0, 820, vp.y), 0.6)
    var lv: Dictionary = car_levels[garage_sel]
    _label(ui, "УЛУЧШЕНИЯ: %s" % CARS[garage_sel]["name"], Vector2(70, 25), 38, Color(0.25, 0.75, 1.0))
    _label(ui, "Монеты: %d" % coins, Vector2(75, 85), 27, Color.GOLD)
    for i in range(UPGRADE_NAMES.size()):
        var upgrade_name: String = UPGRADE_NAMES[i]
        _button(ui, "%s  •  Ур. %d" % [upgrade_name, lv[upgrade_name]], Vector2(70, 140 + i * 65), Vector2(360, 52), func(): _select_upgrade(upgrade_name))
    upgrade_detail = _label(ui, "", Vector2(470, 160), 24, Color.GOLD)
    _button(ui, "УЛУЧШИТЬ", Vector2(470, 330), Vector2(290, 60), buy_upgrade)
    _button(ui, "НАЗАД", Vector2(70, 535), Vector2(220, 55), show_garage)
    _refresh_upgrade_detail()

func _select_upgrade(upgrade_name: String) -> void:
    selected_upgrade = upgrade_name
    _refresh_upgrade_detail()

func _upgrade_cost(level: int) -> int:
    if level == 1:
        return 1000
    if level == 2:
        return 1800
    return 1800 + (level - 2) * 1200

func _refresh_upgrade_detail() -> void:
    if not is_instance_valid(upgrade_detail):
        return
    var level: int = car_levels[garage_sel][selected_upgrade]
    var info: String = UPGRADE_INFO[selected_upgrade]
    if level >= 5:
        upgrade_detail.text = "%s\n%s\nУровень %d — максимум" % [selected_upgrade, info, level]
    else:
        upgrade_detail.text = "%s\n%s\nУр. %d → %d\nЦена: %d монет" % [selected_upgrade, info, level, level + 1, _upgrade_cost(level)]

func buy_upgrade() -> void:
    var level: int = car_levels[garage_sel][selected_upgrade]
    if level >= 5:
        upgrade_detail.text = "Достигнут максимальный уровень!"
        return
    var cost := _upgrade_cost(level)
    if coins < cost:
        upgrade_detail.text = "Не хватает монет! Нужно: %d" % cost
        return
    coins -= cost
    car_levels[garage_sel][selected_upgrade] = level + 1
    _save_game()
    show_upgrades()

# ======================= ПОКРАСКА =======================

func show_paint() -> void:
    mode = "paint"
    _clear_ui()
    var vp := _vp()
    _dim(Rect2(0, 0, 820, vp.y), 0.6)
    _label(ui, "ПОКРАСКА: %s" % CARS[garage_sel]["name"], Vector2(70, 25), 38, Color(0.25, 0.75, 1.0))
    var col: Color = car_colors[garage_sel]
    paint_h = col.h
    paint_s = col.s
    paint_v = col.v
    _paint_slider(100, "Оттенок", paint_h, _set_paint_h)
    _paint_slider(190, "Насыщенность", paint_s, _set_paint_s)
    _paint_slider(280, "Яркость", paint_v, _set_paint_v)
    _label(ui, "Готовые цвета", Vector2(70, 375), 24)
    var presets := [Color(0.9, 0.1, 0.1), Color(0.95, 0.5, 0.05), Color(0.95, 0.85, 0.1), Color(0.15, 0.7, 0.2), Color(0.1, 0.75, 0.85), Color(0.1, 0.3, 0.9), Color(0.6, 0.2, 0.8), Color(0.95, 0.4, 0.7), Color(0.95, 0.95, 0.95), Color(0.1, 0.1, 0.1)]
    for i in range(presets.size()):
        _swatch(Vector2(70 + (i % 5) * 76, 415 + int(i / 5) * 72), presets[i])
    _button(ui, "НАЗАД", Vector2(70, 570), Vector2(220, 55), show_garage)

func _paint_slider(y: float, title: String, value: float, cb: Callable) -> void:
    _label(ui, title, Vector2(70, y), 24)
    var sl := HSlider.new()
    sl.min_value = 0.0
    sl.max_value = 1.0
    sl.step = 0.01
    sl.value = value
    sl.position = Vector2(70, y + 38)
    sl.custom_minimum_size = Vector2(440, 40)
    sl.size = Vector2(440, 40)
    sl.value_changed.connect(cb)
    sl.drag_ended.connect(_paint_saved)
    ui.add_child(sl)

func _set_paint_h(v: float) -> void:
    paint_h = v
    _apply_paint()

func _set_paint_s(v: float) -> void:
    paint_s = v
    _apply_paint()

func _set_paint_v(v: float) -> void:
    paint_v = v
    _apply_paint()

func _paint_saved(_changed: bool) -> void:
    _save_game()

func _apply_paint() -> void:
    var c := Color.from_hsv(paint_h, paint_s, paint_v)
    car_colors[garage_sel] = c
    if preview_body_mat != null:
        preview_body_mat.albedo_color = c

func _swatch(pos: Vector2, c: Color) -> void:
    var b := Button.new()
    b.position = pos
    b.size = Vector2(60, 60)
    for st in ["normal", "hover", "pressed"]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = c
        sb.set_corner_radius_all(10)
        sb.set_border_width_all(3)
        sb.border_color = Color(1, 1, 1, 0.8)
        b.add_theme_stylebox_override(st, sb)
    b.pressed.connect(_play_click)
    b.pressed.connect(func(): _pick_swatch(c))
    ui.add_child(b)

func _pick_swatch(c: Color) -> void:
    paint_h = c.h
    paint_s = c.s
    paint_v = c.v
    _apply_paint()
    _save_game()
    show_paint()

# ======================= ЗАПУСК ИГРЫ =======================

func start_race() -> void:
    free_mode = false
    _start_run()

func start_free() -> void:
    free_mode = true
    _start_run()

func _start_run() -> void:
    mode = "playing"
    speed = 0.0
    flip_timer = 0.0
    gas_amt = 0.0
    held.clear()
    touches.clear()
    _clear_world()
    _build_hud()
    cam_back = Vector3(0, 0, 1)
    camera_3d.fov = 62.0
    camera_3d.position = Vector3(0, 4.4, 8.5)
    camera_3d.look_at(Vector3(0, 1.0, -5.0), Vector3.UP)
    if free_mode:
        _make_free_world()
    else:
        _make_environment()
    car = _create_car()
    car.position = Vector3(0, 1.1, 0)
    world_root.add_child(car)
    _apply_upgrades()
    _engine_sounds(true)
    _update_music()

# ======================= ПРИМИТИВЫ =======================

func _mat(c: Color, metallic: float = 0.0, rough: float = 0.8, emission: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.metallic = metallic
    m.roughness = rough
    if emission > 0.0:
        m.emission_enabled = true
        m.emission = c
        m.emission_energy_multiplier = emission
    return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.position = pos
    instance.material_override = mat
    parent.add_child(instance)
    return instance

func _cyl(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, segs: int = 16) -> MeshInstance3D:
    var m := CylinderMesh.new()
    m.top_radius = radius
    m.bottom_radius = radius
    m.height = height
    m.radial_segments = segs
    m.rings = 1
    var instance := MeshInstance3D.new()
    instance.mesh = m
    instance.position = pos
    instance.material_override = mat
    parent.add_child(instance)
    return instance

func _static_box(pos: Vector3, size: Vector3, mat: Material, rot_deg: Vector3) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = pos
    body.rotation_degrees = rot_deg
    world_root.add_child(body)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = size
    cs.shape = sh
    body.add_child(cs)
    _box(body, Vector3.ZERO, size, mat)
    return body
# ======================= МИР =======================

func _make_sky_and_light() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.28, 0.5, 0.85)
    sky_mat.sky_horizon_color = Color(0.86, 0.8, 0.7)
    sky_mat.ground_horizon_color = Color(0.86, 0.8, 0.7)
    sky_mat.ground_bottom_color = Color(0.6, 0.5, 0.38)
    environment.sky = Sky.new()
    environment.sky.sky_material = sky_mat
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.75, 0.72, 0.68)
    environment.ambient_light_energy = 0.6
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.88, 0.8, 0.68)
    environment.fog_density = 0.0035
    env.environment = environment
    world_root.add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-38, 40, 0)
    sun.light_energy = 1.35
    sun.light_color = Color(1.0, 0.93, 0.78)
    sun.shadow_enabled = SHADOWS
    sun.directional_shadow_max_distance = 110.0
    world_root.add_child(sun)

func _add_mesa(pos: Vector3, size: Vector3) -> void:
    _box(world_root, Vector3(pos.x, size.y / 2.0 - 0.5, pos.z), size, _mat(Color(0.64, 0.4, 0.26), 0.0, 1.0))
    _box(world_root, Vector3(pos.x, size.y - 0.2, pos.z), Vector3(size.x * 0.9, 1.0, size.z * 0.9), _mat(Color(0.72, 0.52, 0.34), 0.0, 1.0))

func _make_menu_world() -> void:
    _make_sky_and_light()
    _box(world_root, Vector3(0, -0.15, 0), Vector3(1200, 0.2, 1200), _mat(Color(0.85, 0.71, 0.48), 0.0, 1.0))
    _box(world_root, Vector3(0, -0.04, 0), Vector3(10, 0.06, 120), _mat(Color(0.14, 0.14, 0.16), 0.0, 0.95))
    _add_mesa(Vector3(-70, 0, -60), Vector3(40, 28, 36))
    _add_mesa(Vector3(90, 0, -90), Vector3(55, 36, 45))
    _rebuild_preview(current_car)

func _rebuild_preview(id: int) -> void:
    if is_instance_valid(preview_car):
        preview_car.queue_free()
    preview_id = id
    preview_car = Node3D.new()
    preview_car.position = Vector3(0, 0.7, 0)
    world_root.add_child(preview_car)
    _build_car_visual(preview_car, id, car_colors[id])
    preview_body_mat = last_body_mat
    var r := _car_f(id, "wheel")
    var wx := _car_f(id, "wid") / 2.0 - 0.02
    var len_ := _car_f(id, "len")
    var wy := r - 0.7
    _make_wheel_mesh(preview_car, Vector3(-wx, wy, -len_ * 0.31), r)
    _make_wheel_mesh(preview_car, Vector3(wx, wy, -len_ * 0.31), r)
    _make_wheel_mesh(preview_car, Vector3(-wx, wy, len_ * 0.30), r)
    _make_wheel_mesh(preview_car, Vector3(wx, wy, len_ * 0.30), r)

# ---------- Заезд до финиша ----------

func _make_environment() -> void:
    _make_sky_and_light()
    var sand := _mat(Color(0.85, 0.71, 0.48), 0.0, 1.0)
    var gz := -ROAD_LENGTH / 2.0
    var gl := ROAD_LENGTH + 800.0
    _static_box(Vector3(0, -1.0, gz), Vector3(600.0, 2.0, gl), sand, Vector3.ZERO)
    var rz := -ROAD_LENGTH / 2.0 - 20.0
    var rl := ROAD_LENGTH + 240.0
    _box(world_root, Vector3(0, 0.02, rz), Vector3(10.0, 0.04, rl), _mat(Color(0.13, 0.13, 0.15), 0.0, 0.95))
    var white := _mat(Color(0.92, 0.92, 0.92), 0.0, 0.7)
    _box(world_root, Vector3(-4.6, 0.06, rz), Vector3(0.18, 0.04, rl), white)
    _box(world_root, Vector3(4.6, 0.06, rz), Vector3(0.18, 0.04, rl), white)
    var dash := _mat(Color(0.95, 0.85, 0.5), 0.0, 0.7)
    var dz := 95.0
    while dz > -(ROAD_LENGTH + 100.0):
        _box(world_root, Vector3(0, 0.06, dz), Vector3(0.2, 0.04, 3.0), dash)
        dz -= 9.0
    for i in range(8):
        var side := 1.0
        if randf() < 0.5:
            side = -1.0
        _add_mesa(Vector3(side * randf_range(120.0, 260.0), 0.0, randf_range(-ROAD_LENGTH - 200.0, 60.0)), Vector3(randf_range(30.0, 60.0), randf_range(18.0, 45.0), randf_range(30.0, 60.0)))
    var fm := _mat(Color(0.2, 1.0, 0.35), 0.3, 0.4, 0.6)
    var fz := -(ROAD_LENGTH - 8.0)
    _box(world_root, Vector3(-6.4, 2.5, fz), Vector3(0.3, 5.0, 0.3), fm)
    _box(world_root, Vector3(6.4, 2.5, fz), Vector3(0.3, 5.0, 0.3), fm)
    _box(world_root, Vector3(0, 5.0, fz), Vector3(13.1, 0.35, 0.35), fm)
    _box(world_root, Vector3(0, 0.07, -ROAD_LENGTH), Vector3(10.0, 0.04, 0.7), white)
    _spawn_obstacles()

# Ряды препятствий: в каждом ряду есть свободная полоса, и она смещается
# не более чем на 2 полосы — проехать можно всегда, но нужно маневрировать.
func _spawn_obstacles() -> void:
    var path_lane := randi_range(1, 3)
    var d := FIRST_ROW_Z
    while d < ROAD_LENGTH - 30.0:
        path_lane = clampi(path_lane + randi_range(-2, 2), 0, LANES.size() - 1)
        var placed := 0
        for lane in range(LANES.size()):
            if lane == path_lane:
                continue
            if randf() < OBSTACLE_CHANCE:
                _spawn_obstacle(LANES[lane] + randf_range(-0.15, 0.15), -(d + randf_range(-2.0, 2.0)))
                placed += 1
        if placed == 0:
            var other := (path_lane + randi_range(1, LANES.size() - 1)) % LANES.size()
            _spawn_obstacle(LANES[other], -d)
        d += randf_range(ROW_GAP_MIN, ROW_GAP_MAX)

func _spawn_obstacle(x: float, z: float) -> void:
    var body := StaticBody3D.new()
    body.position = Vector3(x, 0.0, z)
    body.add_to_group("obstacle")
    world_root.add_child(body)
    var size := Vector3(1.4, 1.4, 1.4)
    match randi() % 3:
        0:
            size = Vector3(1.4, 1.4, 1.4)
            _box(body, Vector3(0, 0.7, 0), size, _mat(Color(0.55, 0.36, 0.17), 0.0, 0.9))
            var band := _mat(Color(0.3, 0.19, 0.09), 0.0, 0.9)
            _box(body, Vector3(0, 1.2, 0), Vector3(1.44, 0.14, 1.44), band)
            _box(body, Vector3(0, 0.2, 0), Vector3(1.44, 0.14, 1.44), band)
        1:
            size = Vector3(1.25, 1.3, 1.25)
            _cyl(body, Vector3(0, 0.65, 0), 0.62, 1.3, _mat(Color(0.85, 0.15, 0.1), 0.2, 0.5))
            _cyl(body, Vector3(0, 0.65, 0), 0.64, 0.2, _mat(Color(0.95, 0.95, 0.95), 0.0, 0.6))
        2:
            size = Vector3(1.6, 1.0, 1.4)
            _box(body, Vector3(0, 0.5, 0), size, _mat(Color(0.6, 0.6, 0.58), 0.0, 0.95))
            _box(body, Vector3(0, 0.7, 0), Vector3(1.62, 0.18, 1.42), _mat(Color(0.95, 0.5, 0.05), 0.0, 0.7))
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    shape.position = Vector3(0, size.y / 2.0, 0)
    body.add_child(shape)

# ---------- Свободный режим ----------

func _add_dune(pos: Vector3, radius: float, height: float) -> void:
    var body := StaticBody3D.new()
    body.position = Vector3(pos.x, height - radius, pos.z)
    world_root.add_child(body)
    var cs := CollisionShape3D.new()
    var sh := SphereShape3D.new()
    sh.radius = radius
    cs.shape = sh
    body.add_child(cs)
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = radius
    sm.height = radius * 2.0
    sm.radial_segments = 40
    sm.rings = 20
    mi.mesh = sm
    mi.material_override = _mat(Color(0.82, 0.68, 0.44), 0.0, 1.0)
    body.add_child(mi)

func _add_ramp(pos: Vector3, yaw_deg: float, length: float, width: float, tilt_deg: float) -> void:
    var pivot := Node3D.new()
    pivot.position = Vector3(pos.x, 0.0, pos.z)
    pivot.rotation_degrees = Vector3(0, yaw_deg, 0)
    world_root.add_child(pivot)
    var body := StaticBody3D.new()
    var half_h := length / 2.0 * sin(deg_to_rad(tilt_deg))
    var off := 0.3 * cos(deg_to_rad(tilt_deg))
    body.position = Vector3(0, half_h - off, 0)
    body.rotation_degrees = Vector3(tilt_deg, 0, 0)
    pivot.add_child(body)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(width, 0.6, length)
    cs.shape = sh
    body.add_child(cs)
    _box(body, Vector3.ZERO, Vector3(width, 0.6, length), _mat(Color(0.55, 0.38, 0.2), 0.0, 0.9))
    var yellow := _mat(Color(0.95, 0.8, 0.1), 0.0, 0.6)
    _box(body, Vector3(-width / 2.0 + 0.2, 0.31, 0), Vector3(0.3, 0.04, length), yellow)
    _box(body, Vector3(width / 2.0 - 0.2, 0.31, 0), Vector3(0.3, 0.04, length), yellow)

func _add_boulder(pos: Vector3, r: float) -> void:
    var body := StaticBody3D.new()
    body.position = Vector3(pos.x, r * 0.3, pos.z)
    world_root.add_child(body)
    var cs := CollisionShape3D.new()
    var sh := SphereShape3D.new()
    sh.radius = r
    cs.shape = sh
    body.add_child(cs)
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = r
    sm.height = r * 2.0
    sm.radial_segments = 12
    sm.rings = 6
    mi.mesh = sm
    mi.material_override = _mat(Color(0.5, 0.45, 0.4), 0.0, 1.0)
    body.add_child(mi)

func _add_cactus(pos: Vector3) -> void:
    var body := StaticBody3D.new()
    body.position = Vector3(pos.x, 0.0, pos.z)
    world_root.add_child(body)
    var cs := CollisionShape3D.new()
    var sh := CylinderShape3D.new()
    sh.radius = 0.35
    sh.height = 3.0
    cs.shape = sh
    cs.position = Vector3(0, 1.5, 0)
    body.add_child(cs)
    var green := _mat(Color(0.2, 0.42, 0.2), 0.0, 0.9)
    _cyl(body, Vector3(0, 1.5, 0), 0.3, 3.0, green, 8)
    _cyl(body, Vector3(0.6, 2.0, 0), 0.18, 1.2, green, 8)

func _make_free_world() -> void:
    _make_sky_and_light()
    var sand := _mat(Color(0.85, 0.71, 0.48), 0.0, 1.0)
    _static_box(Vector3(0, -1.0, 0), Vector3(2000.0, 2.0, 2000.0), sand, Vector3.ZERO)
    # Дорога
    _box(world_root, Vector3(0, 0.02, 0), Vector3(10.0, 0.04, 2000.0), _mat(Color(0.13, 0.13, 0.15), 0.0, 0.95))
    var white := _mat(Color(0.92, 0.92, 0.92), 0.0, 0.7)
    _box(world_root, Vector3(-4.6, 0.06, 0), Vector3(0.18, 0.04, 2000.0), white)
    _box(world_root, Vector3(4.6, 0.06, 0), Vector3(0.18, 0.04, 2000.0), white)
    var dash := _mat(Color(0.95, 0.85, 0.5), 0.0, 0.7)
    var dz := 400.0
    while dz > -400.0:
        _box(world_root, Vector3(0, 0.06, dz), Vector3(0.2, 0.04, 3.0), dash)
        dz -= 9.0
    # Барханы
    for i in range(12):
        var sx := 1.0
        if randf() < 0.5:
            sx = -1.0
        _add_dune(Vector3(sx * randf_range(110.0, 450.0), 0.0, randf_range(-700.0, 250.0)), randf_range(80.0, 110.0), randf_range(5.0, 9.0))
    # Трамплины
    var rz := -90.0
    for i in range(5):
        _add_ramp(Vector3(randf_range(-30.0, 30.0), 0.0, rz), randf_range(-25.0, 25.0), 14.0, 8.0, 20.0)
        rz -= randf_range(90.0, 130.0)
    _add_ramp(Vector3(0, 0.0, rz - 40.0), 0.0, 34.0, 12.0, 24.0)
    # Камни и кактусы
    for i in range(24):
        var bx := randf_range(-300.0, 300.0)
        var bz := randf_range(-500.0, 150.0)
        if absf(bx) < 15.0:
            continue
        _add_boulder(Vector3(bx, 0.0, bz), randf_range(1.0, 3.0))
    for i in range(30):
        var cx := randf_range(-300.0, 300.0)
        var cz := randf_range(-500.0, 150.0)
        if absf(cx) < 12.0:
            continue
        _add_cactus(Vector3(cx, 0.0, cz))
    # Скалы на горизонте
    for i in range(10):
        var a := randf() * TAU
        var dist := randf_range(750.0, 950.0)
        _add_mesa(Vector3(cos(a) * dist, 0.0, sin(a) * dist), Vector3(randf_range(100.0, 200.0), randf_range(50.0, 110.0), randf_range(100.0, 200.0)))

# ======================= МАШИНА =======================

func _build_car_visual(parent: Node3D, id: int, col: Color) -> void:
    var L := _car_f(id, "len")
    var W := _car_f(id, "wid")
    var body_mat := _mat(col, 0.65, 0.28)
    var dark := _mat(Color(0.07, 0.07, 0.08), 0.0, 0.6)
    var glass := _mat(Color(0.08, 0.1, 0.14), 0.8, 0.15)
    var head := _mat(Color(1.0, 0.95, 0.7), 0.0, 0.3, 2.0)
    var tail := _mat(Color(0.45, 0.02, 0.02), 0.0, 0.3, 0.5)
    last_body_mat = body_mat
    tail_mat = tail
    var ly := -0.02
    match id:
        0:
            # Городской хэтчбек
            _box(parent, Vector3(0, -0.15, 0), Vector3(W, 0.5, L), body_mat)
            _box(parent, Vector3(0, 0.35, 0.3), Vector3(W - 0.3, 0.5, L * 0.5), glass)
            _box(parent, Vector3(0, 0.62, 0.3), Vector3(W - 0.26, 0.07, L * 0.44), body_mat)
            _box(parent, Vector3(0, -0.3, -L / 2.0), Vector3(W + 0.06, 0.28, 0.18), dark)
            _box(parent, Vector3(0, -0.3, L / 2.0), Vector3(W + 0.06, 0.28, 0.18), dark)
            ly = -0.02
        1:
            # Спорткар: низкий, со спойлером
            _box(parent, Vector3(0, -0.22, 0), Vector3(W, 0.4, L), body_mat)
            _box(parent, Vector3(0, 0.16, 0.4), Vector3(W - 0.45, 0.36, L * 0.38), glass)
            _box(parent, Vector3(0, 0.36, 0.4), Vector3(W - 0.5, 0.06, L * 0.3), body_mat)
            _box(parent, Vector3(0, 0.0, -1.1), Vector3(0.5, 0.08, 0.7), dark)
            _box(parent, Vector3(0, -0.45, -L / 2.0), Vector3(W + 0.1, 0.05, 0.4), dark)
            _box(parent, Vector3(-0.6, 0.2, L / 2.0 - 0.2), Vector3(0.08, 0.3, 0.1), dark)
            _box(parent, Vector3(0.6, 0.2, L / 2.0 - 0.2), Vector3(0.08, 0.3, 0.1), dark)
            _box(parent, Vector3(0, 0.4, L / 2.0 - 0.2), Vector3(W, 0.05, 0.5), body_mat)
            ly = -0.1
        2:
            # Внедорожник: высокий и квадратный
            _box(parent, Vector3(0, 0.0, 0), Vector3(W, 0.7, L), body_mat)
            _box(parent, Vector3(0, 0.65, 0.35), Vector3(W - 0.1, 0.7, L * 0.62), glass)
            _box(parent, Vector3(0, 1.03, 0.35), Vector3(W - 0.06, 0.08, L * 0.6), body_mat)
            _box(parent, Vector3(0, -0.25, -L / 2.0), Vector3(W + 0.1, 0.3, 0.2), dark)
            _box(parent, Vector3(0, -0.25, L / 2.0), Vector3(W + 0.1, 0.3, 0.2), dark)
            _box(parent, Vector3(0, 0.2, L / 2.0 + 0.15), Vector3(0.9, 0.9, 0.3), dark)
            _box(parent, Vector3(-0.7, 1.12, 0.35), Vector3(0.06, 0.06, L * 0.55), dark)
            _box(parent, Vector3(0.7, 1.12, 0.35), Vector3(0.06, 0.06, L * 0.55), dark)
            ly = 0.05
        3:
            # Пикап: кабина спереди, кузов сзади
            _box(parent, Vector3(0, -0.1, 0), Vector3(W, 0.55, L), body_mat)
            _box(parent, Vector3(0, 0.5, -0.7), Vector3(W - 0.15, 0.55, 1.5), glass)
            _box(parent, Vector3(0, 0.82, -0.7), Vector3(W - 0.1, 0.07, 1.4), body_mat)
            _box(parent, Vector3(-(W / 2.0 - 0.05), 0.35, 1.35), Vector3(0.1, 0.35, 2.0), body_mat)
            _box(parent, Vector3(W / 2.0 - 0.05, 0.35, 1.35), Vector3(0.1, 0.35, 2.0), body_mat)
            _box(parent, Vector3(0, 0.35, L / 2.0 - 0.05), Vector3(W, 0.35, 0.1), body_mat)
            _box(parent, Vector3(0, 0.35, 0.35), Vector3(W, 0.35, 0.1), body_mat)
            _box(parent, Vector3(0, -0.3, -L / 2.0), Vector3(W + 0.06, 0.28, 0.18), dark)
            ly = 0.0
        _:
            # Суперкар: очень низкий клин с большим крылом
            _box(parent, Vector3(0, -0.27, 0), Vector3(W, 0.32, L), body_mat)
            _box(parent, Vector3(0, 0.02, 0.25), Vector3(W - 0.7, 0.32, L * 0.32), glass)
            _box(parent, Vector3(0, 0.2, 0.25), Vector3(W - 0.8, 0.05, L * 0.26), body_mat)
            _box(parent, Vector3(-W / 2.0, -0.2, 0.6), Vector3(0.1, 0.18, 0.8), dark)
            _box(parent, Vector3(W / 2.0, -0.2, 0.6), Vector3(0.1, 0.18, 0.8), dark)
            _box(parent, Vector3(0, -0.45, -L / 2.0), Vector3(W + 0.2, 0.05, 0.5), dark)
            _box(parent, Vector3(-0.7, 0.1, L / 2.0 - 0.15), Vector3(0.07, 0.45, 0.1), dark)
            _box(parent, Vector3(0.7, 0.1, L / 2.0 - 0.15), Vector3(0.07, 0.45, 0.1), dark)
            _box(parent, Vector3(0, 0.35, L / 2.0 - 0.2), Vector3(W + 0.1, 0.05, 0.65), body_mat)
            ly = -0.18
    # Фары спереди и задние фонари
    for sx in [-1.0, 1.0]:
        _box(parent, Vector3(sx * W * 0.32, ly, -L / 2.0), Vector3(0.42, 0.14, 0.06), head)
        _box(parent, Vector3(sx * W * 0.34, ly, L / 2.0), Vector3(0.5, 0.12, 0.06), tail)

func _make_wheel_mesh(parent: Node3D, pos: Vector3, r: float) -> void:
    var holder := Node3D.new()
    holder.position = pos
    holder.rotation_degrees = Vector3(0, 0, 90)
    parent.add_child(holder)
    _cyl(holder, Vector3.ZERO, r, 0.3, _mat(Color(0.03, 0.03, 0.035), 0.0, 0.9), 20)
    _cyl(holder, Vector3.ZERO, r * 0.58, 0.32, _mat(Color(0.75, 0.77, 0.8), 0.9, 0.3), 12)

func _make_wheel(parent: VehicleBody3D, pos: Vector3, front: bool, r: float) -> void:
    var w := VehicleWheel3D.new()
    w.position = pos
    w.wheel_radius = r
    w.wheel_rest_length = 0.15
    w.suspension_travel = 0.25
    w.suspension_max_force = 9000.0
    w.suspension_stiffness = 40.0
    w.damping_compression = 0.4
    w.damping_relaxation = 0.6
    w.wheel_roll_influence = 0.08
    w.wheel_friction_slip = 9.0
    w.use_as_steering = front
    w.use_as_traction = not front
    parent.add_child(w)
    _make_wheel_mesh(w, Vector3.ZERO, r)
    wheels.append(w)

func _create_car() -> VehicleBody3D:
    var id := current_car
    var r := _car_f(id, "wheel")
    var L := _car_f(id, "len")
    var W := _car_f(id, "wid")
    var v := VehicleBody3D.new()
    v.mass = _car_f(id, "mass")
    v.can_sleep = false
    v.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    v.center_of_mass = Vector3(0, -0.45, 0)
    v.angular_damp = 0.5
    v.linear_damp = 0.05
    v.contact_monitor = true
    v.max_contacts_reported = 6
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = Vector3(W, 0.9, L)
    cs.shape = bs
    v.add_child(cs)
    _build_car_visual(v, id, car_colors[id])
    var wx := W / 2.0 - 0.02
    var cy := r - 0.55
    _make_wheel(v, Vector3(-wx, cy, -L * 0.31), true, r)
    _make_wheel(v, Vector3(wx, cy, -L * 0.31), true, r)
    _make_wheel(v, Vector3(-wx, cy, L * 0.30), false, r)
    _make_wheel(v, Vector3(wx, cy, L * 0.30), false, r)
    v.body_entered.connect(_on_car_body_entered)

    # Дым от дрифта (включается в _physics_process через smoke.emitting)
    smoke = CPUParticles3D.new()
    smoke.position = Vector3(0, -0.4, L * 0.3)
    smoke.emitting = false
    smoke.amount = 40
    smoke.lifetime = 1.0
    smoke.local_coords = false
    smoke.direction = Vector3(0, 1, 0)
    smoke.spread = 35.0
    smoke.initial_velocity_min = 1.0
    smoke.initial_velocity_max = 2.5
    smoke.gravity = Vector3(0, 0.5, 0)
    smoke.color = Color(0.9, 0.9, 0.9, 0.5)
    var sm := SphereMesh.new()
    sm.radius = 0.35
    sm.height = 0.7
    sm.radial_segments = 8
    sm.rings = 4
    smoke.mesh = sm
    var smat := StandardMaterial3D.new()
    smat.albedo_color = Color(0.9, 0.9, 0.9, 0.45)
    smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    smat.vertex_color_use_as_albedo = true
    smoke.material_override = smat
    v.add_child(smoke)
    return v

# Улучшение «Подвеска» влияет на устойчивость в поворотах
func _apply_upgrades() -> void:
    var sl := _lv("Подвеска")
    for w in wheels:
        w.suspension_stiffness = 40.0 + float(sl - 1) * 4.0
        w.damping_compression = 0.4 + float(sl - 1) * 0.05
        w.damping_relaxation = 0.6 + float(sl - 1) * 0.05
        w.wheel_roll_influence = maxf(0.02, 0.08 - float(sl - 1) * 0.015)
    if is_instance_valid(car):
        car.angular_damp = 0.5 + float(sl - 1) * 0.15

# ======================= ФИНИШ И РЕЗУЛЬТАТ =======================

func finish_run(success: bool, reason: String) -> void:
    if mode != "playing":
        return
    var reward := 0
    if success:
        finishes += 1
        if finishes % 3 == 0:
            reward = REWARD_EVERY_3
            coins += reward
    last_result = {"success": success, "reason": reason, "reward": reward}
    mode = "result"
    held.clear()
    touches.clear()
    if is_instance_valid(car):
        car.engine_force = 0.0
        car.brake = 20.0
    if is_instance_valid(smoke):
        smoke.emitting = false
    _engine_sounds(false)
    _save_game()
    _update_music()
    _show_result()

func _show_result() -> void:
    _clear_ui()
    var vp := _vp()
    _dim(Rect2(0, 0, vp.x, vp.y), 0.5)
    var ok: bool = bool(last_result.get("success", false))
    if ok:
        _label_c("ФИНИШ!", vp.y * 0.18, 64, Color(0.3, 1.0, 0.4))
        var reward: int = int(last_result.get("reward", 0))
        if reward > 0:
            _label_c("Награда: +%d монет!" % reward, vp.y * 0.18 + 90.0, 34, Color.GOLD)
        else:
            _label_c("Финишей до награды: %d" % (3 - finishes % 3), vp.y * 0.18 + 90.0, 30, Color.GOLD)
    else:
        _label_c("ЗАЕЗД ПРОВАЛЕН", vp.y * 0.18, 56, Color(1.0, 0.35, 0.3))
        _label_c(str(last_result.get("reason", "")), vp.y * 0.18 + 85.0, 30, Color.WHITE)
    _label_c("Монеты: %d     Финиши: %d/3" % [coins, finishes % 3], vp.y * 0.18 + 140.0, 26, Color.GOLD)
    _button(ui, "ЕЩЁ РАЗ", Vector2(vp.x / 2.0 - 170.0, vp.y * 0.55), Vector2(340, 60), start_race)
    _button(ui, "МЕНЮ", Vector2(vp.x / 2.0 - 170.0, vp.y * 0.55 + 80.0), Vector2(340, 60), show_menu)
