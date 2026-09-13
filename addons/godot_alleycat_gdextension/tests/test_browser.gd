extends GutTest

## Purpose: The Alley Cat Artwork panel lays the catalogue out as a sheet of tiles, and the sheet has to be
## readable on any screen. The sprites are eight to forty pixels wide, so the size they are drawn at is a
## setting rather than a constant: zoom scales every tile and both previews together and stays in range.
##
## Run outside the editor the panel has no replacement picker (an editor-only class) and no memory of the
## last zoom, which is fine: the sheet and the zoom are what is under test.

const BROWSER: PackedScene = preload("res://addons/godot_alleycat_gdextension/editor/artwork_browser.tscn")

var browser: HSplitContainer


func before_each() -> void:
	browser = BROWSER.instantiate()
	add_child_autofree(browser)
	await wait_process_frames(2)


func _tiles() -> Array:
	var tiles: Array = []
	for child: Node in browser._grid.get_children():
		if child is Button:
			tiles.append(child)
	return tiles


func test_the_sheet_opens_on_the_catalogue_at_a_zoom_of_one() -> void:
	assert_not_null(browser._artwork, "the default catalogue loads")
	assert_gt(_tiles().size(), 100, "and every sprite gets a tile")
	assert_eq(browser.get_zoom(), 1.0)
	assert_eq((_tiles()[0] as Button).custom_minimum_size, browser.CELL, "a tile is one cell")
	assert_eq(browser._original_frame.custom_minimum_size.y, browser.PREVIEW_HEIGHT)


## Zooming scales the tiles and the previews by the same factor, and the columns give way so the sheet
## stays as wide as the panel rather than growing off the side of it.
func test_zoom_scales_the_tiles_and_the_previews_together() -> void:
	var columns_before: int = browser._grid.columns
	browser.set_zoom(2.0)
	await wait_process_frames(2)
	assert_eq(browser.get_zoom(), 2.0)
	assert_eq((_tiles()[0] as Button).custom_minimum_size, browser.CELL * 2.0, "a tile is two cells")
	assert_eq(browser._original_frame.custom_minimum_size.y, browser.PREVIEW_HEIGHT * 2.0, "so is the original's frame")
	assert_eq(browser._replacement_frame.custom_minimum_size.y, browser.PREVIEW_HEIGHT * 2.0, "and the replacement's")
	assert_eq(browser._zoom_slider.value, 2.0, "and the slider shows it")
	assert_lte(browser._grid.columns, columns_before, "fewer fit across")
	browser.set_zoom(0.5)
	await wait_process_frames(2)
	assert_eq((_tiles()[0] as Button).custom_minimum_size, browser.CELL * 0.5, "half size fits twice as many")


## The range is a real range: past either end the zoom stops, and the button for that direction goes grey.
func test_zoom_stays_in_range() -> void:
	browser.set_zoom(99.0)
	assert_eq(browser.get_zoom(), browser.ZOOM_MAX, "no bigger than the ceiling")
	assert_true(browser._zoom_in.disabled, "and the + says so")
	assert_false(browser._zoom_out.disabled)
	browser.set_zoom(-3.0)
	assert_eq(browser.get_zoom(), browser.ZOOM_MIN, "no smaller than the floor")
	assert_true(browser._zoom_out.disabled, "and the - says so")
	browser.set_zoom(1.1)
	assert_eq(browser.get_zoom(), 1.0, "and it lands on the nearest step, the way the slider does")


## The buttons step it, and so do Ctrl and the wheel over the sheet, the way the editor's 2D view zooms;
## the plain wheel is left to scroll.
func test_the_buttons_and_ctrl_wheel_step_the_zoom() -> void:
	browser._zoom_in.pressed.emit()
	assert_eq(browser.get_zoom(), 1.0 + browser.ZOOM_STEP, "+ is one step up")
	browser._zoom_out.pressed.emit()
	browser._zoom_out.pressed.emit()
	assert_eq(browser.get_zoom(), 1.0 - browser.ZOOM_STEP, "- is one step down")
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.ctrl_pressed = true
	browser._on_sheet_input(wheel)
	assert_eq(browser.get_zoom(), 1.0, "Ctrl and the wheel up is a step up")
	wheel.ctrl_pressed = false
	browser._on_sheet_input(wheel)
	assert_eq(browser.get_zoom(), 1.0, "the wheel on its own is for scrolling, not zooming")
