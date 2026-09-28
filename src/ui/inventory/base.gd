# src/ui/inventory/base.gd
class_name BaseInventoryUI
extends PanelContainer

signal slot_dropped(data: Dictionary, target_slot: InventorySlotUI)
signal drag_started(item: InventoryItem)
signal drag_ended()

signal request_unload_magazine(weapon: Weapon)
signal request_extract_rounds(weapon: Item, number: int)
signal request_cycle_action(weapon: Weapon)
signal request_use_item(item: InventoryItem)
signal request_modify_weapon(weapon: Weapon)

var slot_size: int = 50
var item_displays: Array[InventoryItemUI] = []
var slot_displays: Array[InventorySlotUI] = []
var current_inventory_source: Resource = null

var context_menu: PopupMenu
var currently_hovered_slot: InventorySlotUI = null

func _ready():
    _setup_common_connections()
    _create_context_menu()

func setup_inventory(source: Resource):
    # Disconnect from previous source
    if current_inventory_source and current_inventory_source.has_signal("container_changed"):
        current_inventory_source.container_changed.disconnect(_on_container_changed)

    current_inventory_source = source

    # Connect to new source signals
    if source and source.has_signal("container_changed"):
        source.container_changed.connect(_on_container_changed)

    _setup_slots()
    _update_ui()

func _on_container_changed():
    _update_ui()

func _update_ui():
    _sync_item_displays()
    _update_slot_states()

func _setup_common_connections():
    # Common signal connections will be set up by subclasses
    pass

func _setup_slots():
    # To be implemented by subclasses
    push_error("_setup_slots must be implemented by subclass")

func _clear_item_displays():
    for display in item_displays:
        if is_instance_valid(display):
            # Leave the tree NOW. queue_free() alone keeps the node parented
            # until the end of the frame, so several refreshes inside one frame
            # (the arena's death-frame corpse open) piled duplicate widgets onto
            # the same parent and doubled the peak node count.
            var parent := display.get_parent()
            if parent != null:
                parent.remove_child(display)
            display.queue_free()
    item_displays.clear()

## Reuse the item widgets across refreshes instead of destroying and rebuilding
## them. _update_ui() runs on every container_changed, i.e. on every transfer,
## and a widget is a TextureRect (plus a stack label) per item, so the old
## clear-all/rebuild-all path made the raid inventory feel slow and made each
## corpse open pay for the whole carrier again. Measured on a 6x6 corpse
## container with 8 items: ~90 ms per open, ~1.1 ms after this change.
func _sync_item_displays():
    var items := _get_display_items()
    var live: Dictionary = {}
    for item in items:
        live[item] = true

    # 1) Keep only the widgets whose item is still in the container.
    var survivors: Array[InventoryItemUI] = []
    for display in item_displays:
        if is_instance_valid(display) and live.has(display.inventory_item):
            survivors.append(display)
        elif is_instance_valid(display):
            var parent := display.get_parent()
            if parent != null:
                parent.remove_child(display)
            display.queue_free()
    item_displays = survivors

    # 2) One widget per item, in container order, reusing what we kept.
    var ordered: Array[InventoryItemUI] = []
    for item in items:
        var display: InventoryItemUI = null
        for existing in item_displays:
            if is_instance_valid(existing) and existing.inventory_item == item:
                display = existing
                break
        if display == null:
            display = _create_item_display(item)
        else:
            var parent := display.get_parent()
            if parent != null:
                parent.move_child(display, -1)  # draw order follows item order
            display.setup(item, self)
        if is_instance_valid(display):
            ordered.append(display)
    item_displays = ordered

func _get_display_items() -> Array[InventoryItem]:
    # To be implemented by subclasses
    push_error("_get_display_items must be implemented by subclass")
    return []

## Build a fresh widget for one item. NOT appended to item_displays: the caller
## (the reuse loop above) owns the list. _add_item_display_to_scene() is free to
## free the node (equipment has no floating widgets), hence the validity check
## at the call site.
func _create_item_display(item: InventoryItem) -> InventoryItemUI:
    var display := InventoryItemUI.new()
    display.slot_size = slot_size
    display.setup(item, self)
    _add_item_display_to_scene(display)
    _position_item_display(display, item)
    return display

func _add_item_display_to_scene(display: InventoryItemUI):
    # To be implemented by subclasses
    push_error("_add_item_display_to_scene must be implemented by subclass")

func _position_item_display(display: InventoryItemUI, item: InventoryItem):
    # To be implemented by subclasses
    push_error("_position_item_display must be implemented by subclass")

func _update_slot_states():
    # To be implemented by subclasses
    push_error("_update_slot_states must be implemented by subclass")

# Common drag/drop handlers
func _on_drag_started(item: InventoryItem):
    drag_started.emit(item)

func _on_drag_ended():
    drag_ended.emit()

func _on_slot_dropped(data: Dictionary, target_slot: InventorySlotUI):
    slot_dropped.emit(data, target_slot)

func _create_context_menu():
    if not context_menu:
        context_menu = PopupMenu.new()
        context_menu.id_pressed.connect(_on_context_menu_selected)
        context_menu.popup_hide.connect(_on_context_menu_closed)
        add_child(context_menu)

func _gui_input(event):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        # Check if we're hovering over a slot with an item
        var local_pos = get_local_mouse_position()
        var clicked_slot = get_slot_at_position(local_pos)

        if clicked_slot and clicked_slot.associated_item:
            # If we have a slot with an item, show the context menu
            show_context_menu(clicked_slot)
            get_viewport().set_input_as_handled()  # Mark event as handled
            return

func show_context_menu(slot: InventorySlotUI):
    if not context_menu:
        _create_context_menu()

    # Clear any existing items
    context_menu.clear()
    currently_hovered_slot = slot

    # Add menu items based on the item type
    var item = slot.associated_item

    # For weapons
    if item.extra is Weapon:
        var weapon = item.extra as Weapon
        # Primary action: open the gunsmith for this weapon (range's UI).
        context_menu.add_item("Modificar", 105)
        # Gates for the magazine actions, and both of them are the MODEL's
        # predicates rather than tests re-derived here.
        #
        # UNLOAD detaches the feed, so it is offered only where the weapon model
        # permits a detach: WeaponSystem.change_magazine refuses an INTERNAL feed.
        # Offering it unconditionally would advertise an action the handler must
        # refuse, which from the player is indistinguishable from the dead
        # control this whole card is about.
        if weapon.feed_type == AmmoFeed.Type.EXTERNAL:
            context_menu.add_item("Unload Magazine", 101)
        # CYCLE is a property of the weapon's ACTION, not of its feed. The old
        # test was `weapon.feed_type in [Firemode.PUMP, Firemode.BOLT]`, which
        # compares an AmmoFeed.Type (INTERNAL=0, EXTERNAL=1) against Firemode bit
        # flags (PUMP=16, BOLT=32) -- a cross-enum comparison that is false for
        # every weapon in the game, so "Cycle Action" was never added to the menu
        # and request_cycle_action could never be emitted at all. is_firemode_
        # available() is the bitmask test the rest of the addon already uses.
        if weapon.is_firemode_available(Firemode.PUMP) or weapon.is_firemode_available(Firemode.BOLT):
            context_menu.add_item("Cycle Action", 104)
        # Add ammo extraction options for internal magazines
        if weapon.feed_type == AmmoFeed.Type.INTERNAL and weapon.ammo_feed and weapon.ammo_feed.capacity > 0:
            context_menu.add_item("Extract All Rounds", 102)
            context_menu.add_item("Extract 1 Round", 103)

    # For ammo feeds (magazines, clips, etc.)
    elif item.extra is AmmoFeed:
        if item.capacity > 0:
            context_menu.add_item("Unload All Ammo", 201)
            context_menu.add_item("Unload 1 Round", 202)

    # Medical / provisions: use straight from the inventory (use_time is
    # honoured by the player). 301 = consume.
    if item.extra is MedicalItem:
        var med := item.extra as MedicalItem
        context_menu.add_item("Use %s" % item.name, 301)
        context_menu.set_item_disabled(context_menu.get_item_count() - 1, not med.can_use())

    # Only show menu if there are items
    if context_menu.get_item_count() > 0:
        # Position the menu at the cursor
        context_menu.position = get_global_mouse_position()
        context_menu.popup()
    else:
        currently_hovered_slot = null

func _on_context_menu_closed():
    currently_hovered_slot = null

func _on_context_menu_selected(id: int):
    if not currently_hovered_slot or not currently_hovered_slot.associated_item:
        return

    var item = currently_hovered_slot.associated_item

    match id:
        101: # Unload magazine
            if item.extra is Weapon:
                request_unload_magazine.emit(item.extra as Weapon)
        102: # Extract all rounds
            if item.extra is Weapon:
                request_extract_rounds.emit(item.extra as Weapon, -1)
        103: # Extract one round
            if item.extra is Weapon:
                request_extract_rounds.emit(item.extra as Weapon, 1)
        104: # Cycle action
            if item.extra is Weapon:
                request_cycle_action.emit(item.extra as Weapon)
        105: # Open the gunsmith for this weapon
            if item.extra is Weapon:
                request_modify_weapon.emit(item.extra as Weapon)
        201: # Unload all ammo
            if item.extra is AmmoFeed:
                request_extract_rounds.emit(item.extra as AmmoFeed, -1)
        202: # Unload one round
            if item.extra is AmmoFeed:
                request_extract_rounds.emit(item.extra as AmmoFeed, 1)
        301: # Use a medical / provision item
            if item.extra is MedicalItem:
                request_use_item.emit(item)

    currently_hovered_slot = null

# Helper function to get a slot at a position
func get_slot_at_position(position: Vector2) -> InventorySlotUI:
    for slot in slot_displays:
        if slot.get_rect().has_point(position):
            return slot
    return null
