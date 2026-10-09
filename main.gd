extends Node3D

# ======= ЭТАП 2: езда, гараж, сохранение =======
const ROAD_LENGTH := 300.0
const LANES := [-4.2, -2.1, 0.0, 2.1, 4.2]
const FIRST_ROW_Z := 40.0
const ROW_GAP_MIN := 20.0
const ROW_GAP_MAX := 30.0
const OBSTACLE_CHANCE := 0.5
const SHADOWS := true
const START_COINS := 0          # стартовые монеты (для проверки гаража можно поставить 5000)
const SAVE_PATH := "user://save.json"

const UPGRADE_NAMES := ["Мотор", "Подвеска", "Колёса", "Скорость", "Тормоза"]
const UPGRADE_INFO := {
    "Мотор": "Сильнее разгон",
    "Подвеска": "Устойчивее в поворотах",
    "Колёса": "Лучше сцепление и руление",
    "Скорость": "Выше максимальная скорость",
    "Тормоза": "Короче тормозной путь",
}

var coins := START_COINS
var finishes := 0
var levels := {"Мотор": 1, "Подвеска": 1, "Колёса": 1, "Скорость": 1, "Тормоза": 1}
var selected_upgrade := "Мотор"
var mode := "menu"
var car: VehicleBody3D
var wheels: Array[VehicleWheel3D] = []
var preview_car: Node3D
var camera_3d: Camera3D
var world_root: Node3D
var ui: Control
var speed := 0.0
var flip_timer := 0.0
var cam_back := Vector3(0, 0, 1)
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

func _ready() -> void:
    randomize()
    _load_game()
    _setup_screen()
    _build_camera()
    get_viewport().size_changed.connect(_on_viewport_resized)
    _update_camera_aspect()
    show_menu()

# ======================= СОХРАНЕНИЕ =======================

func _save_game() -> void:
    var data := {"coins": coins, "finishes": finishes, "levels": levels}
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
    coins = int(parsed.get("coins", 0))
    finishes = int(parsed.get("finishes", 0))
    var saved_levels = parsed.get("levels", {})
    if typeof(saved_levels) == TYPE_DICTIONARY:
        for n in UPGRADE_NAMES:
            if saved_levels.has(n):
                levels[n] = clampi(int(saved_levels[n]), 1, 5)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        _save_game()

# ======================= ЭКРАН =======================

func _setup_screen() -> void:
    var window := get_window()
    window.content_scale_size = Vector2i(1280, 720)
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
    if OS.has_feature("android") or OS.has_feature("ios"):
        DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

func _vp() -> Vector2:
    return get_viewport().get_visible_rect().size

func _update_camera_aspect() -> void:
    var vp := _vp()
    if vp.x < vp.y:
        camera_3d.keep_aspect = Camera3D.KEEP_WIDTH
    else:
        camera_3d.keep_aspect = Camera3D.KEEP_HEIGHT

func _on_viewport_resized() -> void:
    _update_camera_aspect()
    match mode:
        "menu":
            show_menu()
        "upgrades":
            show_upgrades()
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

    # Будим машину, если она "уснула" (из-за этого она раньше не ехала)
    if gas or brake or left or right:
        car.sleeping = false

    var engine_max: float = 42.0 + float(levels["Мотор"] - 1) * 7.0
    var max_speed: float = 38.0 + float(levels["Скорость"] - 1) * 4.5 + float(levels["Мотор"] - 1) * 1.5
    var brake_max: float = 22.0 + float(levels["Тормоза"] - 1) * 4.0
    var steer_rate: float = 3.0 + float(levels["Колёса"] - 1) * 0.3

    var p := car.global_position
    var fwd := -car.global_transform.basis.z
    var fwd_speed := fwd.dot(car.linear_velocity)
    speed = car.linear_velocity.length()

    var engine := 0.0
    var brake_force := 0.0
    if gas:
        var ratio := clampf(maxf(fwd_speed, 0.0) / max_speed, 0.0, 1.0)
        engine = engine_max * (1.0 - ratio * ratio)
    elif brake:
        if fwd_speed > 1.5:
            brake_force = brake_max
        else:
            engine = -engine_max * 0.3
    else:
        brake_force = 1.0
    car.engine_force = -engine   # в Godot +engine_force толкает по +Z, а мы едем по -Z
    car.brake = brake_force

    # В Godot положительный угол руля = поворот налево
    var steer_in := 0.0
    if left:
        steer_in += 1.0
    if right:
        steer_in -= 1.0
    var speed_factor := clampf(absf(fwd_speed) / max_speed, 0.0, 1.0)
    var max_steer := lerpf(0.55, 0.16, speed_factor)
    car.steering = move_toward(car.steering, steer_in * max_steer, delta * steer_rate)

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
    if mode == "menu" or mode == "upgrades":
        if is_instance_valid(preview_car):
            preview_car.rotation.y += delta * 0.45
        return
    if mode != "playing" or not is_instance_valid(car):
        return

    for action in touch_pads:
        var pad: Control = touch_pads[action]
        if is_instance_valid(pad):
            pad.modulate.a = 1.0 if _pressed(action) else 0.6

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
        status_label.text = "До финиша: %d м" % int(maxf(0.0, ROAD_LENGTH + pos.z))
    if is_instance_valid(speed_label):
        speed_label.text = "%d км/ч" % int(speed * 3.6)
    if is_instance_valid(coins_label):
        coins_label.text = "Монеты: %d  |  Финиши: %d/3" % [coins, finishes % 3]
    if is_instance_valid(debug_label):
        var contact := 0
        for w in wheels:
            if w.is_in_contact():
                contact += 1
        debug_label.text = "колёса на земле: %d/4" % contact

func _on_car_body_entered(body: Node) -> void:
    if mode != "playing" or not is_instance_valid(car):
        return
    # speed — скорость ДО удара (после столкновения машина уже почти стоит)
    if body.is_in_group("obstacle") and speed > 5.0:
        call_deferred("finish_run", false, "Ты врезался в препятствие!")

# ======================= ИНТЕРФЕЙС =======================

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
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func show_menu() -> void:
    mode = "menu"
    held.clear()
    touches.clear()
    _clear_world()
    _clear_ui()
    var vp := _vp()
    _dim(Rect2(0, 0, 520, vp.y), 0.35)
    _label(ui, "DRIVE 3D", Vector2(80, 55), 58, Color(0.25, 0.75, 1.0))
    _label(ui, "Пустыня • препятствия • гараж", Vector2(85, 125), 25)
    _label(ui, "Монеты: %d     Финиши: %d/3" % [coins, finishes % 3], Vector2(85, 175), 25, Color.GOLD)
    _button(ui, "ИГРАТЬ", Vector2(90, 250), Vector2(300, 65), start_run)
    _button(ui, "ГАРАЖ / УЛУЧШЕНИЯ", Vector2(90, 335), Vector2(300, 65), show_upgrades)
    _label(ui, "Поверни телефон горизонтально", Vector2(85, 430), 21)
    camera_3d.fov = 55.0
    camera_3d.position = Vector3(4.2, 2.0, 7.0)
    camera_3d.look_at(Vector3(-1.6, 0.7, 0.0), Vector3.UP)
    _make_menu_world()

func show_upgrades() -> void:
    mode = "upgrades"
    held.clear()
    touches.clear()
    _clear_ui()
    var vp := _vp()
    _dim(Rect2(0, 0, 960, vp.y), 0.6)
    _label(ui, "ГАРАЖ — УЛУЧШЕНИЯ", Vector2(70, 35), 42, Color(0.25, 0.75, 1.0))
    _label(ui, "Монеты: %d" % coins, Vector2(75, 90), 27, Color.GOLD)
    for i in range(UPGRADE_NAMES.size()):
        var upgrade_name: String = UPGRADE_NAMES[i]
        _button(ui, "%s  •  Ур. %d" % [upgrade_name, levels[upgrade_name]], Vector2(70, 145 + i * 65), Vector2(330, 52), func(): _select_upgrade(upgrade_name))
    upgrade_detail = _label(ui, "", Vector2(450, 170), 24, Color.GOLD)
    _button(ui, "УЛУЧШИТЬ", Vector2(450, 330), Vector2(270, 60), buy_upgrade)
    _button(ui, "НАЗАД", Vector2(70, 535), Vector2(220, 55), show_menu)
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
    var level: int = levels[selected_upgrade]
    var info: String = UPGRADE_INFO[selected_upgrade]
    if level >= 5:
        upgrade_detail.text = "%s\n%s\nУровень %d — максимум" % [selected_upgrade, info, level]
    else:
        upgrade_detail.text = "%s\n%s\nУр. %d → %d\nЦена: %d монет" % [selected_upgrade, info, level, level + 1, _upgrade_cost(level)]

func buy_upgrade() -> void:
    var level: int = levels[selected_upgrade]
    if level >= 5:
        upgrade_detail.text = "Достигнут максимальный уровень!"
        return
    var cost := _upgrade_cost(level)
    if coins < cost:
        upgrade_detail.text = "Не хватает монет! Нужно: %d" % cost
        return
    coins -= cost
    levels[selected_upgrade] = level + 1
    _save_game()
    show_upgrades()

func start_run() -> void:
    mode = "playing"
    speed = 0.0
    flip_timer = 0.0
    held.clear()
    touches.clear()
    _clear_world()
    _build_hud()
    cam_back = Vector3(0, 0, 1)
    camera_3d.fov = 62.0
    camera_3d.position = Vector3(0, 4.4, 8.5)
    camera_3d.look_at(Vector3(0, 1.0, -5.0), Vector3.UP)
    _make_environment()
    car = _create_car()
    car.position = Vector3(0, 1.1, 0)
    world_root.add_child(car)
    _apply_upgrades()

func _build_hud() -> void:
    var vp := _vp()
    touches.clear()
    touch_zones.clear()
    touch_pads.clear()
    _clear_ui()
    status_label = _label(ui, "До финиша: %d м" % int(ROAD_LENGTH), Vector2(25, 20), 24)
    coins_label = _label(ui, "Монеты: %d  |  Финиши: %d/3" % [coins, finishes % 3], Vector2(25, 55), 20)
    debug_label = _label(ui, "", Vector2(25, 85), 16, Color(0.8, 0.8, 0.8))
    speed_label = _label(ui, "%d км/ч" % int(speed * 3.6), Vector2(vp.x - 200, 72), 28, Color.GOLD)
    _button(ui, "МЕНЮ", Vector2(vp.x - 170, 12), Vector2(150, 48), show_menu)
    _touch_pad("gas", "▲ ГАЗ", Rect2(30, vp.y - 260, 200, 120))
    _touch_pad("brake", "▼ ТОРМОЗ", Rect2(30, vp.y - 125, 200, 95))
    _touch_pad("left", "◀", Rect2(vp.x - 270, vp.y - 170, 115, 140))
    _touch_pad("right", "▶", Rect2(vp.x - 145, vp.y - 170, 115, 140))

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
    _add_mesa(Vector3(90, 0, -80), Vector3(46, 22, 40))
    _add_mesa(Vector3(-110, 0, -140), Vector3(50, 34, 44))
    preview_car = Node3D.new()
    preview_car.position = Vector3(-1.6, 0.52, 0)
    world_root.add_child(preview_car)
    _build_car_visual(preview_car, true)

func _static_box(pos: Vector3, size: Vector3, mat: Material, group: String = "") -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = pos
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)
    _box(body, Vector3.ZERO, size, mat)
    if group != "":
        body.add_to_group(group)
    world_root.add_child(body)
    return body

func _make_environment() -> void:
    _make_sky_and_light()
    var total_len := ROAD_LENGTH + 220.0
    var center_z := 60.0 - total_len / 2.0
    # песок и дорога (со столкновениями)
    _static_box(Vector3(0, -0.6, 0), Vector3(1200, 1.0, 1200), _mat(Color(0.85, 0.71, 0.48), 0.0, 1.0))
    _static_box(Vector3(0, -0.5, center_z), Vector3(11.2, 1.0, total_len), _mat(Color(0.14, 0.14, 0.16), 0.0, 0.95))
    # разметка
    var white := _mat(Color(0.95, 0.95, 0.95), 0.0, 0.9)
    for side in [-1.0, 1.0]:
        var edge := _box(world_root, Vector3(side * 5.3, 0.011, center_z), Vector3(0.25, 0.02, total_len), white)
        edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for dx in [-3.15, -1.05, 1.05, 3.15]:
        var z := 50.0
        while z > -(ROAD_LENGTH + 150.0):
            var dash := _box(world_root, Vector3(dx, 0.011, z), Vector3(0.15, 0.02, 3.0), white)
            dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            z -= 8.0
    # скалы-мезы по сторонам
    var mz := 0.0
    while mz > -(ROAD_LENGTH + 200.0):
        _add_mesa(Vector3(-randf_range(45.0, 95.0), 0, mz + randf_range(-20.0, 20.0)), Vector3(randf_range(26.0, 50.0), randf_range(14.0, 34.0), randf_range(26.0, 44.0)))
        _add_mesa(Vector3(randf_range(45.0, 95.0), 0, mz + randf_range(-20.0, 20.0)), Vector3(randf_range(26.0, 50.0), randf_range(14.0, 34.0), randf_range(26.0, 44.0)))
        mz -= 90.0
    _make_obstacles()
    _make_finish()

func _make_obstacles() -> void:
    var crate_colors := [Color(0.9, 0.45, 0.1), Color(0.8, 0.2, 0.15), Color(0.9, 0.7, 0.15)]
    var z := -FIRST_ROW_Z
    while z > -(ROAD_LENGTH - 25.0):
        var free: Array = LANES.duplicate()
        free.shuffle()
        var blocked := 0
        for lane in free:
            if blocked >= 3:
                break
            if randf() < OBSTACLE_CHANCE:
                var c: Color = crate_colors[randi() % crate_colors.size()]
                _static_box(Vector3(lane, 0.7, z), Vector3(1.6, 1.4, 1.6), _mat(c, 0.0, 0.7), "obstacle")
                blocked += 1
        z -= randf_range(ROW_GAP_MIN, ROW_GAP_MAX)

func _make_finish() -> void:
    var z := -ROAD_LENGTH
    var white := _mat(Color(0.95, 0.95, 0.95), 0.0, 0.8)
    var black := _mat(Color(0.05, 0.05, 0.05), 0.0, 0.8)
    for i in range(14):
        for j in range(2):
            var m := white if (i + j) % 2 == 0 else black
            var tile := _box(world_root, Vector3(-5.2 + i * 0.8, 0.02, z - 0.5 + j), Vector3(0.8, 0.02, 1.0), m)
            tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var post := _mat(Color(0.8, 0.1, 0.1), 0.0, 0.6)
    _box(world_root, Vector3(-6.3, 4.0, z), Vector3(0.7, 8.0, 0.7), post)
    _box(world_root, Vector3(6.3, 4.0, z), Vector3(0.7, 8.0, 0.7), post)
    _box(world_root, Vector3(0, 8.0, z), Vector3(13.3, 1.2, 0.7), _mat(Color(0.1, 0.1, 0.12), 0.0, 0.6, 0.0))

# ======================= МАШИНА =======================

const CAR_MASS := 12.0
const WHEEL_RADIUS := 0.42
const WHEEL_X := 0.95
const WHEEL_Z := 1.3

func _add_wheel_mesh(parent: Node3D) -> void:
    var mesh := _cyl(parent, Vector3.ZERO, WHEEL_RADIUS, 0.32, _mat(Color(0.06, 0.06, 0.07), 0.0, 0.9), 18)
    mesh.rotation_degrees = Vector3(0, 0, 90)
    var hub := _cyl(parent, Vector3.ZERO, 0.2, 0.34, _mat(Color(0.7, 0.7, 0.75), 0.6, 0.4), 12)
    hub.rotation_degrees = Vector3(0, 0, 90)

func _build_car_visual(parent: Node3D, with_wheels: bool) -> void:
    var body_mat := _mat(Color(0.12, 0.25, 0.9), 0.3, 0.45)
    var glass := _mat(Color(0.05, 0.07, 0.12), 0.1, 0.4)
    _box(parent, Vector3(0, 0.25, 0), Vector3(1.9, 0.6, 4.2), body_mat)
    _box(parent, Vector3(0, 0.78, 0.25), Vector3(1.6, 0.5, 2.1), glass)
    _box(parent, Vector3(0, 1.06, 0.25), Vector3(1.7, 0.1, 2.0), body_mat)
    var red := _mat(Color(1.0, 0.1, 0.1), 0.0, 0.5, 2.0)
    var yellow := _mat(Color(1.0, 0.95, 0.7), 0.0, 0.5, 1.5)
    for sx in [-0.65, 0.65]:
        _box(parent, Vector3(sx, 0.35, 2.11), Vector3(0.4, 0.18, 0.05), red)
        _box(parent, Vector3(sx, 0.35, -2.11), Vector3(0.4, 0.18, 0.05), yellow)
    if with_wheels:
        for sx in [-WHEEL_X, WHEEL_X]:
            for sz in [-WHEEL_Z, WHEEL_Z]:
                var w := Node3D.new()
                w.position = Vector3(sx, -0.1, sz)
                parent.add_child(w)
                _add_wheel_mesh(w)

func _create_car() -> VehicleBody3D:
    var c := VehicleBody3D.new()
    c.mass = CAR_MASS
    c.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    c.center_of_mass = Vector3(0, -0.35, 0)
    c.can_sleep = false
    c.linear_damp = 0.03
    c.angular_damp = 1.5
    c.contact_monitor = true
    c.max_contacts_reported = 6
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(1.9, 0.8, 4.2)
    shape.shape = box
    shape.position = Vector3(0, 0.35, 0)
    c.add_child(shape)
    _build_car_visual(c, false)
    wheels.clear()
    var idx := 0
    for sz in [-WHEEL_Z, WHEEL_Z]:
        for sx in [-WHEEL_X, WHEEL_X]:
            var w := VehicleWheel3D.new()
            w.position = Vector3(sx, 0.0, sz)
            w.wheel_radius = WHEEL_RADIUS
            w.wheel_rest_length = 0.1
            w.suspension_travel = 0.25
            w.suspension_max_force = 4000.0
            w.use_as_steering = (sz < 0.0)   # передние колёса рулят
            w.use_as_traction = true         # привод на все колёса
            c.add_child(w)
            _add_wheel_mesh(w)
            wheels.append(w)
            idx += 1
    c.body_entered.connect(_on_car_body_entered)
    return c

func _apply_upgrades() -> void:
    var sus: float = float(levels["Подвеска"] - 1)
    var grip: float = float(levels["Колёса"] - 1)
    for w in wheels:
        w.suspension_stiffness = 45.0 + sus * 8.0
        w.damping_compression = 0.8
        w.damping_relaxation = 0.9
        w.wheel_roll_influence = clampf(0.4 - sus * 0.08, 0.05, 0.4)
        w.wheel_friction_slip = 3.0 + grip * 0.5

# ======================= КОНЕЦ ЗАЕЗДА =======================

func finish_run(success: bool, reason: String) -> void:
    if mode != "playing":
        return
    mode = "result"
    var dist := 0
    if is_instance_valid(car):
        dist = int(maxf(0.0, -car.global_position.z))
        dist = mini(dist, int(ROAD_LENGTH))
        car.engine_force = 0.0
        car.brake = 30.0
    var reward := 0
    var bonus := 0
    if success:
        finishes += 1
        reward = 600
        if finishes % 3 == 0:
            bonus = 1500
    else:
        reward = int(dist * 1.5)
    coins += reward + bonus
    last_result = {"success": success, "reason": reason, "dist": dist, "reward": reward, "bonus": bonus}
    held.clear()
    touches.clear()
    _save_game()
    _show_result()

func _show_result() -> void:
    _clear_ui()
    var vp := _vp()
    _dim(Rect2(0, 0, vp.x, vp.y), 0.55)
    var ok: bool = last_result.get("success", false)
    var title := "ФИНИШ!" if ok else "АВАРИЯ"
    var title_color := Color(0.4, 1.0, 0.5) if ok else Color(1.0, 0.45, 0.4)
    var y := vp.y * 0.5 - 190.0
    _label_c(title, y, 64, title_color)
    if not ok:
        _label_c(str(last_result.get("reason", "")), y + 85.0, 28)
    _label_c("Проехал: %d м" % int(last_result.get("dist", 0)), y + 135.0, 28)
    var reward: int = int(last_result.get("reward", 0))
    var bonus: int = int(last_result.get("bonus", 0))
    var line := "Награда: +%d монет" % reward
    if bonus > 0:
        line += "  (бонус за 3 финиша: +%d)" % bonus
    _label_c(line, y + 180.0, 28, Color.GOLD)
    _label_c("Всего монет: %d" % coins, y + 225.0, 28, Color.GOLD)
    _button(ui, "ЕЩЁ РАЗ", Vector2(vp.x * 0.5 - 320.0, y + 295.0), Vector2(300, 65), start_run)
    _button(ui, "МЕНЮ", Vector2(vp.x * 0.5 + 20.0, y + 295.0), Vector2(300, 65), show_menu)
