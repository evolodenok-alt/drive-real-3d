extends Node3D

var cube: MeshInstance3D

func _ready() -> void:
    var window := get_window()
    window.content_scale_size = Vector2i(1280, 720)
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
    var cam := Camera3D.new()
    cam.position = Vector3(0, 1, 4)
    add_child(cam)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45, 30, 0)
    add_child(light)
    cube = MeshInstance3D.new()
    cube.mesh = BoxMesh.new()
    add_child(cube)
    var ui := Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(ui)
    var label := Label.new()
    label.text = "main.gd работает"
    label.position = Vector2(40, 40)
    label.add_theme_font_size_override("font_size", 48)
    ui.add_child(label)

func _process(delta: float) -> void:
    cube.rotation.y += delta
