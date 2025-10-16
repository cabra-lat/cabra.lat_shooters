# ui/inventory/inventory_ui.gd
class_name InventoryUI
extends Window

@onready var equipment_panel: FoldableContainer = %EquipmentPanel
@onready var helmet_slot: InventoryUISlot = %HelmetSlot
@onready var vest_slot: InventoryUISlot = %VestSlot
@onready var primary_weapon_slot: InventoryUISlot = %PrimaryWeaponSlot
@onready var secondary_weapon_slot: InventoryUISlot = %SecondaryWeaponSlot

@onready var containers_scroll: ScrollContainer = %ContainersScroll
@onready var containers_vbox: VBoxContainer = %ContainersVBox  # child of ScrollContainer
@onready var close_button: Button = %CloseButton

var player_controller: PlayerController
var open_containers: Array[ContainerUI] = []

func _ready():
    _setup_equipment_slots()
    #close_button.pressed.connect(_on_close_button_pressed)

func _setup_equipment_slots():
    helmet_slot.gui_input.connect(_on_equipment_slot_input.bind(helmet_slot, "head"))
    vest_slot.gui_input.connect(_on_equipment_slot_input.bind(vest_slot, "torso"))
    primary_weapon_slot.gui_input.connect(_on_equipment_slot_input.bind(primary_weapon_slot, "primary"))
    secondary_weapon_slot.gui_input.connect(_on_equipment_slot_input.bind(secondary_weapon_slot, "secondary"))

func open_inventory(player: PlayerController, container: InventoryContainer = null):
    player_controller = player
    _update_equipment()
    if container:
        _open_container(container)
    show()

func _open_container(container: InventoryContainer):
    # Close existing if same
    for ui in open_containers:
        if ui.current_container == container:
            return  # already open

    # Create new ContainerUI
    var container_ui = preload("container_ui.tscn").instantiate()
    container_ui.item_drag_started.connect(_on_item_drag_started)
    container_ui.slot_clicked.connect(_on_container_slot_clicked)
    container_ui.container_closed.connect(_on_container_closed.bind(container_ui))
    containers_vbox.add_child(container_ui)
    open_containers.append(container_ui)
    container_ui.open_container(container)

func _update_equipment():
    _update_equipment_slot(helmet_slot, "head")
    _update_equipment_slot(vest_slot, "torso")
    _update_equipment_slot(primary_weapon_slot, "primary")
    _update_equipment_slot(secondary_weapon_slot, "secondary")

func _update_equipment_slot(slot: InventoryUISlot, slot_name: String):
    slot.clear()
    var equipped = player_controller.player_body.get_equipped(slot_name)
    if not equipped.is_empty():
        slot.item_icon = equipped[0].content.icon if equipped[0].content.icon else \
            preload("../../../assets/ui/inventory/placeholder.png")

# ─── DRAG & DROP ───────────────────────────────────
func _on_item_drag_started(item: InventoryItem, source: InventoryContainer):
    # Handle drag start (e.g., highlight)
    pass

func _on_equipment_slot_input(slot: InventoryUISlot, slot_name: String, event: InputEvent):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        # Handle equip drop
        pass

func _on_container_slot_clicked(container: InventoryContainer, position: Vector2i):
    # Handle container drop
    pass

func _on_container_closed(container_ui: ContainerUI):
    if container_ui in open_containers:
        open_containers.erase(container_ui)
        containers_vbox.remove_child(container_ui)
        container_ui.queue_free()

func _on_close_button_pressed():
    hide()
    # Close all container UIs
    for ui in open_containers:
        ui.queue_free()
    open_containers.clear()
