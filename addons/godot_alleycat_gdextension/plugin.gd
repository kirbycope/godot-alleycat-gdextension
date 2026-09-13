@tool
extends EditorPlugin
## Puts the artwork browser in the editor's bottom panel.
##
## The catalogue is a hundred sprites in a flat array, and an array of resources in the inspector shows one
## row each with nothing on it but a name: to see what a sprite is you open it, look, and close it again.
## The browser shows them all at once the way the contact sheets do, and clicking one puts its details in
## reach - which is the whole job, because the useful thing to do with a sprite is name it and replace it.

const BROWSER: PackedScene = preload("res://addons/godot_alleycat_gdextension/editor/artwork_browser.tscn")

var _browser: Control = null


func _enter_tree() -> void:
	_browser = BROWSER.instantiate()
	add_control_to_bottom_panel(_browser, "Alley Cat Artwork")


func _exit_tree() -> void:
	if _browser == null:
		return
	remove_control_from_bottom_panel(_browser)
	_browser.queue_free()
	_browser = null
