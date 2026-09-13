@tool
extends HSplitContainer
## The game's artwork as a contact sheet, with the details of whichever sprite is clicked.
##
## An [AlleyCatArtwork] is a hundred [AlleyCatSprite]s in a flat array, and the inspector draws an array of
## resources as a hundred rows with a name on each: finding a sprite means opening a row, looking at the
## picture inside, and closing it again. The sheet is how the sprites were identified in the first place -
## all of them at once, at a size a person can see - so this is that, with the naming and the replacing done
## in place rather than in a list somewhere else.

## The catalogue this opens with. Anything else is typed into the bar.
const DEFAULT_ARTWORK: String = "res://addons/godot_alleycat_gdextension/resources/artwork.tres"

## How big a sprite is drawn on the sheet. The game's own are between 8x5 and 32x15, which is unreadable at
## its own size on a modern screen, so they are blown up to a fixed cell and kept at their aspect.
const CELL: Vector2 = Vector2(104.0, 88.0)

## What the group dropdown calls "any of them", and what it calls the ones nobody has put in a group yet.
## Neither can be a real group name, so they are kept apart from the list rather than in it.
## The orders the sheet can be laid out in. The catalogue's own is most drawn first, which puts the cat and
## the scenery at the top and the rarities at the bottom - useful when hunting for something, useless when
## reading down a family, because the digits and the glyphs land wherever their draw counts put them.
const ORDERS: Array[String] = ["Most drawn", "Name", "Group, then name", "Address"]

const ANY_GROUP: String = "All groups"
const NO_GROUP: String = "Ungrouped"

## What a sprite that has a replacement is named in. The sheet is otherwise all one colour and there is no
## other way to see at a glance how much of a set is finished.
const REPLACED_COLOUR: Color = Color(0.55, 0.9, 0.55)

@onready var _path_field: LineEdit = $Browse/Bar/Artwork
@onready var _open_button: Button = $Browse/Bar/Open
@onready var _filter_field: LineEdit = $Browse/Bar/Filter
@onready var _sort_by: OptionButton = $Browse/Bar/SortBy
@onready var _group_filter: OptionButton = $Browse/Bar/GroupFilter
@onready var _replaced_only: CheckButton = $Browse/Bar/ReplacedOnly
@onready var _grid: GridContainer = $Browse/Sheet/Scroll/Grid
@onready var _title: Label = $Details/Title
@onready var _original: TextureRect = $Details/Previews/OriginalBox/Frame/Original
@onready var _replacement: TextureRect = $Details/Previews/ReplacementBox/Frame/Replacement
@onready var _label_edit: LineEdit = $Details/Fields/LabelEdit
@onready var _group_edit: LineEdit = $Details/Fields/GroupRow/GroupEdit
@onready var _group_pick: OptionButton = $Details/Fields/GroupRow/GroupPick
@onready var _picker_slot: HBoxContainer = $Details/Fields/PickerSlot
@onready var _facts: Label = $Details/Facts
@onready var _saved: Label = $Details/Saved

var _artwork: AlleyCatArtwork = null
var _selected: AlleyCatSprite = null
var _picker: Control = null ## An EditorResourcePicker, built here because it is an editor-only class.
var _tiles: ButtonGroup = ButtonGroup.new()


func _ready() -> void:
	_path_field.text = DEFAULT_ARTWORK
	_open_button.pressed.connect(_on_open_pressed)
	_path_field.text_submitted.connect(func(_text: String) -> void: _on_open_pressed())
	_filter_field.text_changed.connect(func(_text: String) -> void: _fill_the_sheet())
	for order: String in ORDERS:
		_sort_by.add_item(order)
	_sort_by.select(0)
	_sort_by.item_selected.connect(func(_index: int) -> void: _fill_the_sheet())
	_group_filter.item_selected.connect(func(_index: int) -> void: _fill_the_sheet())
	_replaced_only.toggled.connect(func(_on: bool) -> void: _fill_the_sheet())
	_group_edit.text_submitted.connect(func(_text: String) -> void: _write_the_group())
	_group_edit.focus_exited.connect(_write_the_group)
	_group_pick.item_selected.connect(_on_group_picked)
	_label_edit.text_submitted.connect(func(_text: String) -> void: _write_the_label())
	_label_edit.focus_exited.connect(_write_the_label)
	_build_the_picker()
	_show_the_details()
	_on_open_pressed()


## The replacement slot. [EditorResourcePicker] is what the inspector itself uses, so a texture can be
## dragged straight onto it from the FileSystem dock, which is how a person actually has the file to hand.
## It is built here rather than put in the scene because it only exists inside the editor.
func _build_the_picker() -> void:
	# Editor only, and asked that way rather than through ClassDB: the class is registered outside the editor
	# too, so asking whether it exists says yes and then instantiating it fails with an error of its own.
	if not Engine.is_editor_hint():
		return
	_picker = ClassDB.instantiate(&"EditorResourcePicker") as Control
	if _picker == null:
		return
	_picker.set(&"base_type", "Texture2D")
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.connect(&"resource_changed", _on_replacement_chosen)
	_picker_slot.add_child(_picker)


func _on_open_pressed() -> void:
	var loaded: Resource = ResourceLoader.load(_path_field.text) if ResourceLoader.exists(_path_field.text) else null
	_artwork = loaded as AlleyCatArtwork
	_selected = null
	if _artwork == null:
		_say("%s is not an AlleyCatArtwork" % _path_field.text)
	_fill_the_sheet()
	_show_the_details()


## Lays every sprite out, in the order the catalogue keeps them: most drawn first, which puts the cat and the
## scenery at the top and the rarities at the bottom.
func _fill_the_sheet() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	if _artwork == null:
		return
	_fill_the_group_lists()
	var wanted: String = _filter_field.text.strip_edges().to_lower()
	var group: String = _group_filter.get_item_text(maxi(_group_filter.selected, 0))
	var showing: Array = []
	for sprite: AlleyCatSprite in _artwork.sprites:
		if sprite == null:
			continue
		if _replaced_only.button_pressed and sprite.texture == null:
			continue
		if not _in_group(sprite, group):
			continue
		if not wanted.is_empty() and not _matches(sprite, wanted):
			continue
		showing.append(sprite)
	_put_in_order(showing)
	for sprite: AlleyCatSprite in showing:
		_grid.add_child(_make_tile(sprite))
	_columns_for_the_width()


## Lays [param showing] out in whichever order the bar is asking for. "Most drawn" is the catalogue's own
## order and is left exactly as it came, which is what makes it the one to come back to.
func _put_in_order(showing: Array) -> void:
	match _sort_by.selected:
		1:
			showing.sort_custom(func(a: AlleyCatSprite, b: AlleyCatSprite) -> bool:
				return _before(_name_of(a), _name_of(b)))
		2:
			showing.sort_custom(func(a: AlleyCatSprite, b: AlleyCatSprite) -> bool:
				if a.group != b.group:
					# Everything nobody has sorted yet goes to the end, where the work to do is.
					if a.group.is_empty() or b.group.is_empty():
						return b.group.is_empty()
					return a.group.naturalcasecmp_to(b.group) < 0
				return _before(_name_of(a), _name_of(b)))
		3:
			showing.sort_custom(func(a: AlleyCatSprite, b: AlleyCatSprite) -> bool:
				return a.source < b.source)


## Whether [param a] sorts before [param b] by name, counting the numbers in them as numbers. Plain string
## order puts "Font glyph 10" between "Font glyph 1" and "Font glyph 2", which is exactly the muddle the
## sheet is being sorted to get out of.
func _before(a: String, b: String) -> bool:
	return a.naturalcasecmp_to(b) < 0


## Whether [param sprite] is in the group the dropdown is showing. [constant ANY_GROUP] is everything and
## [constant NO_GROUP] is the ones nobody has sorted yet, which is the list to work through.
func _in_group(sprite: AlleyCatSprite, group: String) -> bool:
	if group == ANY_GROUP:
		return true
	if group == NO_GROUP:
		return sprite.group.strip_edges().is_empty()
	return sprite.group == group


## Rebuilds both group lists from what the catalogue actually holds, keeping whatever each was showing. The
## groups are not declared anywhere: a group exists because a sprite says it is in one.
func _fill_the_group_lists() -> void:
	var groups: PackedStringArray = PackedStringArray()
	var any_without: bool = false
	for sprite: AlleyCatSprite in _artwork.sprites:
		if sprite == null:
			continue
		var in_group: String = sprite.group.strip_edges()
		if in_group.is_empty():
			any_without = true
		elif not groups.has(in_group):
			groups.append(in_group)
	groups.sort()

	var showing: String = _group_filter.get_item_text(_group_filter.selected) if _group_filter.selected >= 0 else ANY_GROUP
	_group_filter.clear()
	_group_filter.add_item(ANY_GROUP)
	if any_without:
		_group_filter.add_item(NO_GROUP)
	for in_group: String in groups:
		_group_filter.add_item(in_group)
	for i: int in _group_filter.item_count:
		if _group_filter.get_item_text(i) == showing:
			_group_filter.select(i)
			break

	_group_pick.clear()
	_group_pick.add_item("")
	for in_group: String in groups:
		_group_pick.add_item(in_group)


## Whether [param sprite] answers to what was typed in the filter: any part of its name, or its address
## written as hex with or without the 0x.
func _matches(sprite: AlleyCatSprite, wanted: String) -> bool:
	if sprite.label.to_lower().contains(wanted):
		return true
	var hex: String = "0x%05x" % sprite.source
	return hex.contains(wanted) or hex.trim_prefix("0x").contains(wanted)


## One sprite on the sheet: its picture, its name under it, and the whole thing a button so that clicking
## anywhere on it selects it.
func _make_tile(sprite: AlleyCatSprite) -> Button:
	var tile: Button = Button.new()
	tile.toggle_mode = true
	tile.button_group = _tiles
	tile.custom_minimum_size = CELL
	tile.tooltip_text = "0x%05X\n%s" % [sprite.source, sprite.note]
	tile.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			_selected = sprite
			_show_the_details())

	var rows: VBoxContainer = VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 4)
	tile.add_child(rows)

	var picture: TextureRect = TextureRect.new()
	picture.texture = sprite.texture if sprite.texture != null else sprite.original
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(picture)

	var name_label: Label = Label.new()
	name_label.text = sprite.label if not sprite.label.is_empty() else "0x%05X" % sprite.source
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override(&"font_size", 10)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sprite.texture != null:
		name_label.add_theme_color_override(&"font_color", REPLACED_COLOUR)
	rows.add_child(name_label)
	return tile


## How many fit across. Godot's GridContainer takes a column count rather than filling the width itself, so
## it is worked out from the width and redone whenever that changes.
func _columns_for_the_width() -> void:
	if not is_instance_valid(_grid):
		return
	var across: int = int(maxf(1.0, floorf(_grid.size.x / (CELL.x + 6.0))))
	if _grid.columns != across:
		_grid.columns = across


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_columns_for_the_width()


## Puts whichever sprite is selected into the panel on the right, or says that none is.
func _show_the_details() -> void:
	var chosen: bool = _selected != null
	_title.text = _name_of(_selected) if chosen else "Nothing selected"
	_original.texture = _selected.original if chosen else null
	_replacement.texture = _selected.texture if chosen else null
	_label_edit.editable = chosen
	_label_edit.text = _selected.label if chosen else ""
	_group_edit.editable = chosen
	_group_edit.text = _selected.group if chosen else ""
	_group_pick.disabled = not chosen
	if _picker != null:
		_picker.set(&"editable", chosen)
		_picker.set(&"edited_resource", _selected.texture if chosen else null)
	if not chosen:
		_facts.text = "Click a sprite on the sheet."
		return
	_facts.text = "Address  0x%05X\n%s\nDrawn %d times, %d of them through the masking blitter." % [
		_selected.source, _selected.note, _selected.draws, _selected.masked_draws]


func _name_of(sprite: AlleyCatSprite) -> String:
	if sprite == null:
		return ""
	return sprite.label if not sprite.label.is_empty() else "0x%05X" % sprite.source


func _write_the_label() -> void:
	if _selected == null or _selected.label == _label_edit.text:
		return
	_selected.label = _label_edit.text
	_after_a_change()


func _write_the_group() -> void:
	if _selected == null or _selected.group == _group_edit.text.strip_edges():
		return
	_selected.group = _group_edit.text.strip_edges()
	_after_a_change()


## The dropdown beside the group box is a shortcut for the groups that already exist, so that putting the
## twelfth cat frame in with the other eleven does not mean spelling "Cat" a twelfth time.
func _on_group_picked(index: int) -> void:
	if _selected == null:
		return
	_group_edit.text = _group_pick.get_item_text(index)
	_write_the_group()


func _on_replacement_chosen(resource: Resource) -> void:
	if _selected == null:
		return
	var texture: Texture2D = resource as Texture2D
	if _selected.texture == texture:
		return
	_selected.texture = texture
	_after_a_change()


## Writes the catalogue back out. Saved rather than left dirty because the thing being edited is a file on
## disk that nothing else in the editor has open, so there is no other moment at which it would be written.
func _after_a_change() -> void:
	_fill_the_sheet()
	_reselect()
	_show_the_details()
	if _artwork == null or _artwork.resource_path.is_empty():
		return
	var failed: int = ResourceSaver.save(_artwork, _artwork.resource_path)
	_say("Saved %s" % _artwork.resource_path.get_file() if failed == OK else "Could not save: %d" % failed)


## Puts the selection back on the tile it was on, since the sheet is rebuilt whenever anything changes.
func _reselect() -> void:
	if _selected == null:
		return
	for tile: Node in _grid.get_children():
		if tile is Button and String(tile.tooltip_text).begins_with("0x%05X" % _selected.source):
			(tile as Button).set_pressed_no_signal(true)
			return


func _say(message: String) -> void:
	_saved.text = message
