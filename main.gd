extends Node3D

const ROAD_LENGTH := 260.0
const UPGRADE_NAMES := ["Мотор", "Подвеска", "Колёса", "Скорость", "Тормоза"]

var coins := 0
var finishes := 0
var levels := {"Мотор": 1, "Подвеска": 1, "Колёса": 1, "Скорость": 1, "Тормоза": 1}
var selected_upgrade := "Мотор"
var mode := "menu"
var car: Node3D
var camera_3d: Camera3D
var world_root: Node3D
var ui: Control
var speed := 0.0
var distance := 0.0
var damage := 0.0
var held := {}
var tap_action := ""
var tap_left := 0.0
var road_obstacles: Array[Node3D] = []
var status_label: Label
var speed_label: Label
var coins_label: Label
var upgrade_detail: Label

func _ready() -> void:
    _build_camera()
    show_menu()

func _build_camera() -> void:
    camera_3d = Camera3D.new()
    camera_3d.position = Vector3(0, 7, -12)
    camera_3d.rotation_degrees = Vector3(-18, 0, 0)
    camera_3d.current = true
    add_child(camera_3d)

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

func _process(delta: float) -> void:
    if mode != "playing" or not is_instance_valid(car):
        return
    if tap_left > 0.0:
        tap_left -= delta
        if tap_left <= 0.0:
            tap_action = ""
    var gas := held.has("gas") or tap_action == "gas"
    var brake := held.has("brake") or tap_action == "brake"
    var left := held.has("left") or tap_action == "left"
    var right := held.has("right") or tap_action == "right"

    var motor_bonus: float = float(levels["Мотор"] - 1) * 2.2
    var max_speed: float = 29.0 + float(levels["Скорость"] - 1) * 4.0 + motor_bonus
    var accel: float = 15.0 + float(levels["Мотор"] - 1) * 2.5
    var braking: float = 25.0 + float(levels["Тормоза"] - 1) * 6.0

    if gas:
        speed += accel * delta
    elif brake:
        speed -= braking * delta
    else:
        speed -= 4.0 * delta
    speed = clampf(speed, 0.0, max_speed)

    var turn_strength := 1.7 + float(levels["Колёса"] - 1) * 0.22
    if left:
        car.position.x -= turn_strength * (0.3 + speed / max_speed) * delta * 4.0
    if right:
        car.position.x += turn_strength * (0.3 + speed / max_speed) * delta * 4.0
    car.position.x = clampf(car.position.x, -10.0, 10.0)
    car.position.z += speed * delta
    distance = car.position.z

    if absf(car.position.x) > 6.0:
        damage += delta * (0.8 + speed / 18.0)
        if damage > 1.7:
            finish_run(false, "Ты съехал с дороги и разбил машину!")
            return

    for obstacle in road_obstacles:
        if is_instance_valid(obstacle) and absf(car.position.z - obstacle.position.z) < 2.0 and absf(car.position.x - obstacle.position.x) < 1.5:
            finish_run(false, "Ты врезался в препятствие!")
            return

    if car.position.z >= ROAD_LENGTH:
        finish_run(true, "")
        return

    camera_3d.position = camera_3d.position.lerp(Vector3(car.position.x * 0.45, 7.5, car.position.z - 12.0), minf(1.0, delta * 4.0))
    camera_3d.look_at(Vector3(car.position.x, 0.5, car.position.z + 8.0), Vector3.UP)
    if is_instance_valid(status_label):
        status_label.text = "До финиша: %d м" % int(maxf(0.0, ROAD_LENGTH - car.position.z))
    if is_instance_valid(speed_label):
        speed_label.text = "%d км/ч" % int(speed * 3.6)
    if is_instance_valid(coins_label):
        coins_label.text = "Монеты: %d  |  Финиши: %d/3" % [coins, finishes % 3]

func _clear_ui() -> void:
    if is_instance_valid(ui):
        ui.queue_free()
    ui = Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(ui)

func _clear_world() -> void:
    if is_instance_valid(world_root):
        world_root.queue_free()
    world_root = Node3D.new()
    add_child(world_root)
    car = null
    road_obstacles.clear()

func _label(parent: Control, text: String, pos: Vector2, size: int = 28, color_value: Color = Color.WHITE) -> Label:
    var label := Label.new()
    label.text = text
    label.position = pos
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color_value)
    parent.add_child(label)
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
    _clear_world()
    _clear_ui()
    _label(ui, "DRIVE 3D", Vector2(80, 55), 58, Color(0.25, 0.75, 1.0))
    _label(ui, "3D заезды • препятствия • гараж", Vector2(85, 125), 25)
    _label(ui, "Монеты: %d     Финиши: %d/3" % [coins, finishes % 3], Vector2(85, 175), 25, Color.GOLD)
    _button(ui, "ИГРАТЬ", Vector2(90, 250), Vector2(300, 65), start_run)
    _button(ui, "ГАРАЖ / УЛУЧШЕНИЯ", Vector2(90, 335), Vector2(300, 65), show_upgrades)
    _label(ui, "Управление: WASD / стрелки или экранные кнопки", Vector2(85, 440), 21)
    # 3D car preview
    var preview := Node3D.new()
    preview.position = Vector3(3.5, 0.0, 4.0)
    world_root.add_child(preview)
    _make_car_mesh(preview)

func show_upgrades() -> void:
    mode = "upgrades"
    held.clear()
    _clear_ui()
    _label(ui, "ГАРАЖ — УЛУЧШЕНИЯ", Vector2(70, 35), 42, Color(0.25, 0.75, 1.0))
    _label(ui, "Монеты: %d" % coins, Vector2(75, 90), 27, Color.GOLD)
    for i in range(UPGRADE_NAMES.size()):
        var name: String = UPGRADE_NAMES[i]
        _button(ui, "%s  •  Ур. %d" % [name, levels[name]], Vector2(70, 145 + i * 65), Vector2(330, 52), func(): _select_upgrade(name))
    upgrade_detail = _label(ui, "", Vector2(470, 190), 26, Color.GOLD)
    _button(ui, "УЛУЧШИТЬ", Vector2(470, 300), Vector2(270, 60), buy_upgrade)
    _button(ui, "НАЗАД", Vector2(70, 535), Vector2(220, 55), show_menu)
    _refresh_upgrade_detail()

func _select_upgrade(name: String) -> void:
    selected_upgrade = name
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
    if level >= 5:
        upgrade_detail.text = "%s\nУровень %d — максимум" % [selected_upgrade, level]
    else:
        upgrade_detail.text = "%s\nУр. %d → %d\nЦена: %d монет" % [selected_upgrade, level, level + 1, _upgrade_cost(level)]

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
    distance = 0.0
    damage = 0.0
    held.clear()
    tap_action = ""
    _clear_world()
    _make_environment()
    car = Node3D.new()
    car.position = Vector3(0, 0.55, 0)
    world_root.add_child(car)
    _make_car_mesh(car)
    camera_3d.position = Vector3(0, 7, -12)
    camera_3d.look_at(Vector3(0, 1, 8), Vector3.UP)
    _clear_ui()
    _label(ui, "W/↑ газ  S/↓ тормоз  A/D поворот", Vector2(20, 12), 20)
    status_label = _label(ui, "До финиша: %d м" % int(ROAD_LENGTH), Vector2(25, 50), 24)
    speed_label = _label(ui, "0 км/ч", Vector2(1050, 40), 28, Color.GOLD)
    coins_label = _label(ui, "Монеты: %d  |  Финиши: %d/3" % [coins, finishes % 3], Vector2(25, 88), 20)
    _button(ui, "▲ ГАЗ", Vector2(25, 485), Vector2(155, 75), func(): _tap("gas"))
    _button(ui, "▼ ТОРМОЗ", Vector2(25, 570), Vector2(155, 65), func(): _tap("brake"))
    _button(ui, "◀", Vector2(1000, 515), Vector2(85, 85), func(): _tap("left"))
    _button(ui, "▶", Vector2(1095, 515), Vector2(85, 85), func(): _tap("right"))
    _button(ui, "МЕНЮ", Vector2(1060, 12), Vector2(150, 48), show_menu)

func _tap(action: String) -> void:
    tap_action = action
    tap_left = 0.22

func _make_environment() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = Sky.new()
    environment.sky.sky_material = ProceduralSkyMaterial.new()
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.72, 0.78, 0.86)
    environment.ambient_light_energy = 0.8
    env.environment = environment
    world_root.add_child(env)
    _box(world_root, Vector3(0, -0.5, ROAD_LENGTH / 2), Vector3(100, 0.5, ROAD_LENGTH + 50), Color(0.18, 0.42, 0.18))
    _box(world_root, Vector3(0, -0.15, ROAD_LENGTH / 2), Vector3(12, 0.25, ROAD_LENGTH + 25), Color(0.16, 0.17, 0.19))
    for x in [-6.15, 6.15]:
        _box(world_root, Vector3(x, 0.02, ROAD_LENGTH / 2), Vector3(0.18, 0.08, ROAD_LENGTH + 25), Color.WHITE)
    for z in range(0, int(ROAD_LENGTH), 12):
        _box(world_root, Vector3(0, 0.02, z), Vector3(0.16, 0.07, 5), Color(0.95, 0.86, 0.6))
    # Stylized roadside trees
    for side in [-1, 1]:
        for i in range(25):
            var z := randf_range(0, ROAD_LENGTH)
            var x: float = side * randf_range(10, 24)
            _box(world_root, Vector3(x, 0.8, z), Vector3(0.55, 1.6, 0.55), Color(0.32, 0.2, 0.1))
            var crown := _mesh_instance(world_root, Vector3(x, 2.2, z), Color(0.12, randf_range(0.28, 0.48), 0.1), "sphere")
            crown.scale = Vector3(1.5, 2.0, 1.5)
    # Obstacles
    for z in [42.0, 78.0, 115.0, 154.0, 193.0, 225.0]:
        var obstacle := Node3D.new()
        obstacle.position = Vector3([ -3.6, -1.8, 1.8, 3.6].pick_random(), 0.8, z)
        world_root.add_child(obstacle)
        _box(obstacle, Vector3.ZERO, Vector3(1.5, 1.6, 1.5), Color(0.95, 0.35, 0.08))
        road_obstacles.append(obstacle)
    _make_gate(85.0, Color(0.1, 0.7, 1.0))
    _make_gate(170.0, Color(0.1, 0.7, 1.0))
    _make_gate(ROAD_LENGTH - 7.0, Color(0.2, 1.0, 0.35))

func _make_gate(z: float, c: Color) -> void:
    var gate := Node3D.new()
    gate.position.z = z
    world_root.add_child(gate)
    _box(gate, Vector3(-5.2, 2.2, 0), Vector3(0.22, 4.4, 0.22), c)
    _box(gate, Vector3(5.2, 2.2, 0), Vector3(0.22, 4.4, 0.22), c)
    _box(gate, Vector3(0, 4.4, 0), Vector3(10.6, 0.22, 0.22), c)

func _box(parent: Node3D, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.position = pos
    var material := StandardMaterial3D.new()
    material.albedo_color = c
    material.roughness = 0.82
    instance.material_override = material
    parent.add_child(instance)
    return instance

func _mesh_instance(parent: Node3D, pos: Vector3, c: Color, shape: String) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    if shape == "sphere":
        instance.mesh = SphereMesh.new()
    else:
        instance.mesh = BoxMesh.new()
    var material := StandardMaterial3D.new()
    material.albedo_color = c
    instance.material_override = material
    instance.position = pos
    parent.add_child(instance)
    return instance

func _make_car_mesh(parent: Node3D) -> void:
    _box(parent, Vector3(0, 0, 0), Vector3(1.9, 0.55, 3.5), Color(0.04, 0.28, 0.88))
    _box(parent, Vector3(0, 0.5, -0.25), Vector3(1.32, 0.6, 1.55), Color(0.06, 0.09, 0.14))
    _box(parent, Vector3(0, 0.54, 0.55), Vector3(1.1, 0.32, 0.1), Color(0.35, 0.75, 0.95))
    _box(parent, Vector3(-0.58, -0.05, 1.78), Vector3(0.36, 0.14, 0.08), Color(1.0, 0.9, 0.55))
    _box(parent, Vector3(0.58, -0.05, 1.78), Vector3(0.36, 0.14, 0.08), Color(1.0, 0.9, 0.55))
    for x in [-0.98, 0.98]:
        for z in [-1.1, 1.1]:
            _box(parent, Vector3(x, -0.12, z), Vector3(0.32, 0.45, 0.62), Color(0.025, 0.025, 0.03))

func finish_run(success: bool, reason: String) -> void:
    mode = "result"
    held.clear()
    _clear_ui()
    if success:
        finishes += 1
        var reward := 0
        if finishes % 3 == 0:
            reward = 5000
            coins += reward
        _label(ui, "ФИНИШ!", Vector2(400, 120), 58, Color(0.2, 1.0, 0.35))
        _label(ui, "Ты успешно добрался до финиша!", Vector2(340, 205), 28)
        if reward > 0:
            _label(ui, "Награда за 3 финиша: +5000 монет!", Vector2(330, 260), 28, Color.GOLD)
        else:
            _label(ui, "Финиш %d/3 — до награды ещё %d" % [finishes % 3, 3 - finishes % 3], Vector2(330, 260), 25, Color.GOLD)
    else:
        _label(ui, "ЗАЕЗД ОКОНЧЕН", Vector2(350, 130), 48, Color(1, 0.2, 0.2))
        _label(ui, reason, Vector2(300, 215), 27)
    _label(ui, "Монеты: %d   |   Финиши: %d/3" % [coins, finishes % 3], Vector2(390, 325), 26, Color.GOLD)
    _button(ui, "ЕЩЁ ЗАЕЗД", Vector2(390, 405), Vector2(230, 60), start_run)
    _button(ui, "ГЛАВНОЕ МЕНЮ", Vector2(650, 405), Vector2(260, 60), show_menu)
