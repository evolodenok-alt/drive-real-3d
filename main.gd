extends Node3D

const ROAD_LENGTH := 400.0
const UPGRADE_NAMES := ["Мотор", "Подвеска", "Колёса", "Скорость", "Тормоза"]
const UPGRADE_INFO := {
    "Мотор": "Сильнее разгон",
    "Подвеска": "Устойчивее в поворотах",
    "Колёса": "Лучше сцепление и руление",
    "Скорость": "Выше максимальная скорость",
    "Тормоза": "Короче тормозной путь",
}

const SHADOWS := true          # false = выключить тени (если телефон тормозит)
const TERRAIN_HALF_W := 96.0

# Препятствия: полосы по X и настройки генерации
const LANES := [-4.8, -2.4, 0.0, 2.4, 4.8]
const FIRST_ROW_Z := 45.0
const ROW_GAP_MIN := 20.0
const ROW_GAP_MAX := 30.0
const OBSTACLE_CHANCE := 0.55

var coins := 0
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
var terrain_noise: FastNoiseLite
var speed := 0.0
var damage := 0.0
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
var upgrade_detail: Label

func _ready() -> void:
    randomize()
    _setup_screen()
    _build_camera()
    get_viewport().size_changed.connect(_on_viewport_resized)
    _update_camera_aspect()
    show_menu()

func _setup_screen() -> void:
    var window := get_window()
    window.content_scale_size = Vector2i(1280, 720)
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
    get_viewport().msaa_3d = Viewport.MSAA_2X
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
    camera_3d.far = 1500.0
    add_child(camera_3d)

# ---------------------------------------------------------------- ввод

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

# ---------------------------------------------------------------- игровой цикл

func _physics_process(delta: float) -> void:
    if mode != "playing" or not is_instance_valid(car):
        return
    var gas := _pressed("gas")
    var brake := _pressed("brake")
    var left := _pressed("left")
    var right := _pressed("right")

    var engine_max: float = 36.0 + float(levels["Мотор"] - 1) * 7.0
    var max_speed: float = 32.0 + float(levels["Скорость"] - 1) * 4.5 + float(levels["Мотор"] - 1) * 1.5
    var brake_max: float = 18.0 + float(levels["Тормоза"] - 1) * 4.0

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
    car.engine_force = engine
    car.brake = brake_force

    # В Godot положительный угол руля = поворот налево
    var steer_in := 0.0
    if left:
        steer_in += 1.0
    if right:
        steer_in -= 1.0
    var speed_factor := clampf(absf(fwd_speed) / max_speed, 0.0, 1.0)
    var max_steer := lerpf(0.55, 0.16, speed_factor)
    var steer_rate := 2.6 + float(levels["Колёса"] - 1) * 0.25
    car.steering = move_toward(car.steering, steer_in * max_steer, delta * steer_rate)

    # Сцепление: на траве хуже
    var offroad := absf(car.global_position.x) > 6.5
    var grip := (3.2 + float(levels["Колёса"] - 1) * 0.5) * (0.55 if offroad else 1.0)
    for w in wheels:
        w.wheel_friction_slip = grip
    car.linear_damp = 0.6 if offroad else 0.05

    if absf(car.global_position.x) > 7.0:
        damage += delta * (0.6 + speed / 25.0)
        if damage > 1.7:
            finish_run(false, "Ты съехал с дороги и разбил машину!")
            return

    if car.global_transform.basis.y.y < 0.3:
        flip_timer += delta
        if flip_timer > 1.5:
            finish_run(false, "Машина перевернулась!")
            return
    else:
        flip_timer = 0.0

    if car.global_position.y < -20.0:
        finish_run(false, "Ты улетел с трассы!")
        return

    if car.global_position.z <= -ROAD_LENGTH:
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

func _on_car_body_entered(body: Node) -> void:
    if mode != "playing" or not is_instance_valid(car):
        return
    if body.is_in_group("obstacle") and car.linear_velocity.length() > 5.0:
        call_deferred("finish_run", false, "Ты врезался в препятствие!")

# ---------------------------------------------------------------- интерфейс

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

func _toggle_fullscreen() -> void:
    var m := DisplayServer.window_get_mode()
    if m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func show_menu() -> void:
    mode = "menu"
    held.clear()
    touches.clear()
    _clear_world()
    _clear_ui()
    var vp := _vp()
    _make_menu_world()
    camera_3d.fov = 55.0
    camera_3d.position = Vector3(4.2, 2.0, 7.0)
    camera_3d.look_at(Vector3(-1.6, 0.7, 0.0), Vector3.UP)
    _dim(Rect2(0, 0, 520, vp.y), 0.35)
    _label(ui, "DRIVE 3D", Vector2(80, 55), 58, Color(0.25, 0.75, 1.0))
    _label(ui, "3D заезды • препятствия • гараж", Vector2(85, 125), 25)
    _label(ui, "Монеты: %d     Финиши: %d/3" % [coins, finishes % 3], Vector2(85, 175), 25, Color.GOLD)
    _button(ui, "ИГРАТЬ", Vector2(90, 250), Vector2(300, 65), start_run)
    _button(ui, "ГАРАЖ / УЛУЧШЕНИЯ", Vector2(90, 335), Vector2(300, 65), show_upgrades)
    _button(ui, "НА ВЕСЬ ЭКРАН", Vector2(90, 420), Vector2(300, 55), _toggle_fullscreen)
    _label(ui, "Управление: WASD / стрелки или экранные кнопки", Vector2(85, 500), 21)

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
    show_upgrades()

func start_run() -> void:
    mode = "playing"
    speed = 0.0
    damage = 0.0
    flip_timer = 0.0
    held.clear()
    touches.clear()
    _clear_world()
    _make_environment()
    car = _create_car()
    car.position = Vector3(0, 1.1, 0)
    world_root.add_child(car)
    _apply_upgrades()
    cam_back = Vector3(0, 0, 1)
    camera_3d.fov = 62.0
    camera_3d.position = Vector3(0, 4.4, 8.5)
    camera_3d.look_at(Vector3(0, 1.0, -5.0), Vector3.UP)
    _build_hud()

func _build_hud() -> void:
    var vp := _vp()
    touches.clear()
    touch_zones.clear()
    touch_pads.clear()
    _clear_ui()
    _label(ui, "W/↑ газ  S/↓ тормоз  A/D поворот", Vector2(20, 12), 20)
    status_label = _label(ui, "До финиша: %d м" % int(ROAD_LENGTH), Vector2(25, 50), 24)
    coins_label = _label(ui, "Монеты: %d  |  Финиши: %d/3" % [coins, finishes % 3], Vector2(25, 88), 20)
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

# ---------------------------------------------------------------- материалы и примитивы

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
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = segs
    mesh.rings = 1
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.position = pos
    instance.material_override = mat
    parent.add_child(instance)
    return instance

func _add_multimesh(mesh: Mesh, mat: Material, xforms: Array) -> void:
    if xforms.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = xforms.size()
    for i in range(xforms.size()):
        mm.set_instance_transform(i, xforms[i])
    var inst := MultiMeshInstance3D.new()
    inst.multimesh = mm
    inst.material_override = mat
    world_root.add_child(inst)

# ---------------------------------------------------------------- мир

func _make_sky_and_light() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.22, 0.45, 0.82)
    sky_mat.sky_horizon_color = Color(0.68, 0.78, 0.9)
    sky_mat.ground_horizon_color = Color(0.68, 0.78, 0.9)
    sky_mat.ground_bottom_color = Color(0.3, 0.4, 0.3)
    environment.sky = Sky.new()
    environment.sky.sky_material = sky_mat
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.6, 0.67, 0.78)
    environment.ambient_light_energy = 0.55
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.7, 0.78, 0.88)
    environment.fog_density = 0.003
    env.environment = environment
    world_root.add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, 35, 0)
    sun.light_energy = 1.25
    sun.light_color = Color(1.0, 0.95, 0.85)
    sun.shadow_enabled = SHADOWS
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    sun.directional_shadow_max_distance = 90.0
    world_root.add_child(sun)

func _make_menu_world() -> void:
    _make_sky_and_light()
    _box(world_root, Vector3(0, -0.12, 0), Vector3(400, 0.2, 400), _mat(Color(0.17, 0.36, 0.15), 0.0, 1.0))
    _box(world_root, Vector3(0, -0.05, 0), Vector3(16, 0.1, 40), _mat(Color(0.12, 0.12, 0.14), 0.0, 0.95))
    preview_car = Node3D.new()
    preview_car.position = Vector3(0, 0.7, 0)
    world_root.add_child(preview_car)
    _build_car_visual(preview_car)
    for p in [Vector3(-0.93, -0.3, -1.3), Vector3(0.93, -0.3, -1.3), Vector3(-0.93, -0.3, 1.25), Vector3(0.93, -0.3, 1.25)]:
        _make_wheel_mesh(preview_car, p)

func _make_environment() ->
