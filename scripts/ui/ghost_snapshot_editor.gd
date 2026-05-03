class_name GhostSnapshotEditor
extends PanelContainer

signal closed()
signal saved(snapshot_id: String, path: String)
signal validation_failed(errors: Array[String])

const PvpGhostServiceClass = preload("res://scripts/services/pvp_ghost_service.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")

var _document_path: String = PvpGhostServiceClass.DEFAULT_CURATED_PATH
var _document_archetypes: Array[Dictionary] = []
var _selected_snapshot_id: String = ""

var _file_path_edit: LineEdit = null
var _selector: OptionButton = null
var _id_edit: LineEdit = null
var _name_edit: LineEdit = null
var _hero_option: OptionButton = null
var _day_spin: SpinBox = null
var _level_spin: SpinBox = null
var _slot_capacity_spin: SpinBox = null
var _prestige_spin: SpinBox = null
var _max_health_spin: SpinBox = null
var _health_spin: SpinBox = null
var _regeneration_spin: SpinBox = null
var _skills_box: VBoxContainer = null
var _items_box: VBoxContainer = null
var _status_label: RichTextLabel = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_reload_document()

func set_document_path(path: String) -> void:
	_document_path = path
	if _file_path_edit != null:
		_file_path_edit.text = path

func _build_ui() -> void:
	name = "GhostSnapshotEditor"
	anchor_left = 0.08
	anchor_top = 0.08
	anchor_right = 0.92
	anchor_bottom = 0.92
	add_theme_stylebox_override("panel", _create_panel_style())

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(_create_header_row())
	root.add_child(_create_toolbar_row())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	content.add_child(_create_section_title("Snapshot Fields"))
	content.add_child(_create_core_fields())
	content.add_child(_create_section_title("Skills"))
	content.add_child(_create_skills_section())
	content.add_child(_create_section_title("Items"))
	content.add_child(_create_items_section())
	content.add_child(_create_status_section())

func _create_header_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)

	var title: Label = Label.new()
	title.text = "Curated Ghost Archetype Editor"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	var close_button: Button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_close_editor)
	row.add_child(close_button)
	return row

func _create_toolbar_row() -> Control:
	var toolbar: VBoxContainer = VBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)

	var path_row: HBoxContainer = HBoxContainer.new()
	path_row.add_theme_constant_override("separation", 8)
	toolbar.add_child(path_row)

	var path_label: Label = Label.new()
	path_label.text = "JSON Path"
	path_row.add_child(path_label)

	_file_path_edit = LineEdit.new()
	_file_path_edit.text = _document_path
	_file_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_row.add_child(_file_path_edit)

	var reload_button: Button = Button.new()
	reload_button.text = "Reload"
	reload_button.pressed.connect(_reload_document)
	path_row.add_child(reload_button)

	var selector_row: HBoxContainer = HBoxContainer.new()
	selector_row.add_theme_constant_override("separation", 8)
	toolbar.add_child(selector_row)

	var selector_label: Label = Label.new()
	selector_label.text = "Archetype"
	selector_row.add_child(selector_label)

	_selector = OptionButton.new()
	_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selector.item_selected.connect(_on_selector_changed)
	selector_row.add_child(_selector)

	var new_button: Button = Button.new()
	new_button.text = "New"
	new_button.pressed.connect(_create_new_archetype)
	selector_row.add_child(new_button)

	var validate_button: Button = Button.new()
	validate_button.text = "Validate"
	validate_button.pressed.connect(_validate_current_archetype)
	selector_row.add_child(validate_button)

	var save_button: Button = Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_save_current_archetype)
	selector_row.add_child(save_button)

	return toolbar

func _create_core_fields() -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)

	_id_edit = _add_labeled_line_edit(grid, "ID")
	_name_edit = _add_labeled_line_edit(grid, "Name")
	_hero_option = _add_labeled_option(grid, "Hero", PvpGhostServiceClass.get_known_hero_ids())
	_day_spin = _add_labeled_spin_box(grid, "Day", 1, 20, 1, 1)
	_level_spin = _add_labeled_spin_box(grid, "Level", 1, 20, 1, 1)
	_slot_capacity_spin = _add_labeled_spin_box(
		grid,
		"Slot Capacity",
		1,
		10,
		1,
		LinearInventoryClass.TOTAL_SLOTS
	)
	_prestige_spin = _add_labeled_spin_box(grid, "Prestige", 0, 20, 1, 20)
	_max_health_spin = _add_labeled_spin_box(grid, "Max Health", 1, 9999, 1, 100)
	_health_spin = _add_labeled_spin_box(grid, "Health", 1, 9999, 1, 100)
	_regeneration_spin = _add_labeled_spin_box(grid, "Regeneration", 0, 999, 1, 0)
	return grid

func _create_skills_section() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var add_button: Button = Button.new()
	add_button.text = "Add Skill"
	add_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_button.pressed.connect(_add_skill_row)
	box.add_child(add_button)

	_skills_box = VBoxContainer.new()
	_skills_box.add_theme_constant_override("separation", 6)
	box.add_child(_skills_box)
	return box

func _create_items_section() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var add_button: Button = Button.new()
	add_button.text = "Add Item"
	add_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_button.pressed.connect(_add_item_row)
	box.add_child(add_button)

	_items_box = VBoxContainer.new()
	_items_box.add_theme_constant_override("separation", 6)
	box.add_child(_items_box)
	return box

func _create_status_section() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _create_status_style())

	_status_label = RichTextLabel.new()
	_status_label.bbcode_enabled = true
	_status_label.fit_content = true
	_status_label.scroll_active = false
	_status_label.custom_minimum_size = Vector2(0.0, 100.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("normal_font_size", 14)
	_status_label.text = "[color=#d8c7a0]Waiting for validation.[/color]"
	panel.add_child(_status_label)
	return panel

func _reload_document() -> void:
	_document_path = _file_path_edit.text.strip_edges() if _file_path_edit != null else _document_path
	var loaded: Dictionary = PvpGhostServiceClass.load_curated_file(_document_path)
	if not bool(loaded.get("success", false)):
		_document_archetypes.clear()
		_set_status("Load failed:\n%s" % "\n".join(loaded.get("errors", [])), true)
		_refresh_selector()
		_create_new_archetype()
		return

	_document_archetypes = loaded.get("archetypes", [])
	_refresh_selector()
	if _document_archetypes.is_empty():
		_create_new_archetype()
		return

	var target_id: String = _selected_snapshot_id
	if target_id.is_empty():
		target_id = str(_document_archetypes[0].get("id", ""))
	_select_archetype_by_id(target_id)
	_set_status("Loaded %d curated archetypes." % _document_archetypes.size(), false)

func _refresh_selector() -> void:
	_selector.clear()
	for archetype in _document_archetypes:
		var label: String = "%s (Day %d)" % [
			str(archetype.get("id", "")),
			int(archetype.get("day", 1)),
		]
		_selector.add_item(label)
		_selector.set_item_metadata(_selector.item_count - 1, str(archetype.get("id", "")))

func _on_selector_changed(index: int) -> void:
	if index < 0 or index >= _selector.item_count:
		return
	var target_id: String = str(_selector.get_item_metadata(index))
	_select_archetype_by_id(target_id)

func _select_archetype_by_id(target_id: String) -> void:
	for index in range(_document_archetypes.size()):
		var archetype: Dictionary = _document_archetypes[index]
		if str(archetype.get("id", "")) != target_id:
			continue
		_selected_snapshot_id = target_id
		if index < _selector.item_count:
			_selector.select(index)
		_apply_archetype_to_fields(archetype)
		return

func _create_new_archetype() -> void:
	var archetype: Dictionary = PvpGhostServiceClass.get_default_archetype()
	var suffix: int = _document_archetypes.size() + 1
	archetype["id"] = "ghost_day01_custom_%02d" % suffix
	archetype["name"] = "Custom Ghost %02d" % suffix
	_selected_snapshot_id = str(archetype.get("id", ""))
	_apply_archetype_to_fields(archetype)
	_set_status("Editing unsaved archetype %s." % _selected_snapshot_id, false)

func _apply_archetype_to_fields(archetype: Dictionary) -> void:
	_id_edit.text = str(archetype.get("id", ""))
	_name_edit.text = str(archetype.get("name", ""))
	_select_option_value(_hero_option, str(archetype.get("hero_id", "mak")))
	_day_spin.value = float(int(archetype.get("day", 1)))
	_level_spin.value = float(int(archetype.get("level", 1)))
	_slot_capacity_spin.value = float(int(archetype.get("slot_capacity", 10)))
	_prestige_spin.value = float(int(archetype.get("prestige", 20)))
	_max_health_spin.value = float(int(archetype.get("max_health", 100)))
	_health_spin.value = float(int(archetype.get("health", 100)))
	_regeneration_spin.value = float(archetype.get("regeneration", 0.0))
	_rebuild_skill_rows(archetype.get("skills", []))
	_rebuild_item_rows(archetype.get("items", []))
	_validate_current_archetype()

func _rebuild_skill_rows(skill_entries: Variant) -> void:
	for child in _skills_box.get_children():
		child.queue_free()
	if skill_entries is Array:
		for skill_entry in skill_entries:
			_add_skill_row(skill_entry)
	if _skills_box.get_child_count() == 0:
		_add_skill_row()

func _rebuild_item_rows(item_entries: Variant) -> void:
	for child in _items_box.get_children():
		child.queue_free()
	if item_entries is Array:
		for item_entry in item_entries:
			_add_item_row(item_entry)
	if _items_box.get_child_count() == 0:
		_add_item_row()

func _add_skill_row(skill_entry: Variant = null) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var id_edit: LineEdit = LineEdit.new()
	id_edit.placeholder_text = "skill_id"
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(id_edit)
	row.set_meta("skill_id_edit", id_edit)

	var tier_option: OptionButton = _create_option_button(PvpGhostServiceClass.get_tier_options())
	tier_option.custom_minimum_size = Vector2(100, 0)
	row.add_child(tier_option)
	row.set_meta("tier_option", tier_option)

	var remove_button: Button = Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(_remove_row.bind(row))
	row.add_child(remove_button)

	_skills_box.add_child(row)
	if skill_entry is Dictionary:
		id_edit.text = str(skill_entry.get("id", skill_entry.get("skill_id", "")))
		_select_option_value(tier_option, str(skill_entry.get("tier", "bronze")))

func _add_item_row(item_entry: Variant = null) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var item_id_edit: LineEdit = LineEdit.new()
	item_id_edit.placeholder_text = "item_id"
	item_id_edit.custom_minimum_size = Vector2(160, 0)
	item_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(item_id_edit)
	row.set_meta("item_id_edit", item_id_edit)

	var tier_option: OptionButton = _create_option_button(PvpGhostServiceClass.get_tier_options())
	tier_option.custom_minimum_size = Vector2(90, 0)
	row.add_child(tier_option)
	row.set_meta("tier_option", tier_option)

	var size_spin: SpinBox = _create_compact_spin_box(1, 3, 1, 1)
	row.add_child(_wrap_labeled_small("Slots", size_spin))
	row.set_meta("size_spin", size_spin)

	var slot_spin: SpinBox = _create_compact_spin_box(0, 9, 1, 0)
	row.add_child(_wrap_labeled_small("Start", slot_spin))
	row.set_meta("slot_spin", slot_spin)

	var enchant_option: OptionButton = _create_option_button(
		PvpGhostServiceClass.get_enchantment_options(),
		true
	)
	enchant_option.custom_minimum_size = Vector2(120, 0)
	row.add_child(enchant_option)
	row.set_meta("enchant_option", enchant_option)

	var cooldown_spin: SpinBox = _create_compact_spin_box(0, 99, 1, 0)
	row.add_child(_wrap_labeled_small("CD", cooldown_spin))
	row.set_meta("cooldown_spin", cooldown_spin)

	var ammo_spin: SpinBox = _create_compact_spin_box(0, 99, 1, 0)
	row.add_child(_wrap_labeled_small("Ammo", ammo_spin))
	row.set_meta("ammo_spin", ammo_spin)

	var charges_spin: SpinBox = _create_compact_spin_box(0, 99, 1, 0)
	row.add_child(_wrap_labeled_small("Charges", charges_spin))
	row.set_meta("charges_spin", charges_spin)

	var remove_button: Button = Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(_remove_row.bind(row))
	row.add_child(remove_button)

	_items_box.add_child(row)
	if item_entry is Dictionary:
		item_id_edit.text = str(item_entry.get("item_id", item_entry.get("id", "")))
		_select_option_value(tier_option, str(item_entry.get("tier", "bronze")))
		size_spin.value = float(int(item_entry.get("size", 1)))
		slot_spin.value = float(int(item_entry.get("slot_index", 0)))
		_select_option_value(enchant_option, str(item_entry.get("enchantment", "")), true)
		cooldown_spin.value = float(item_entry.get("cooldown", 0.0))
		ammo_spin.value = float(int(item_entry.get("ammo", 0)))
		charges_spin.value = float(int(item_entry.get("charges", 0)))

func _remove_row(row: Control) -> void:
	if row != null:
		row.queue_free()
	call_deferred("_ensure_minimum_rows")

func _ensure_minimum_rows() -> void:
	if _skills_box.get_child_count() == 0:
		_add_skill_row()
	if _items_box.get_child_count() == 0:
		_add_item_row()

func _validate_current_archetype() -> void:
	var archetype: Dictionary = _collect_current_archetype()
	var validation: Dictionary = PvpGhostServiceClass.validate_curated_archetype(archetype)
	if bool(validation.get("valid", false)):
		var snapshot = PvpGhostServiceClass.curated_archetype_to_snapshot(
			validation.get("normalized", {})
		)
		_set_status(
			"Valid snapshot.\nPower Score: %d\nPower Bucket: %s"
			% [int(snapshot.power_score), str(snapshot.power_bucket)],
			false
		)
		return

	var errors: Array[String] = validation.get("errors", [])
	validation_failed.emit(errors)
	_set_status("Validation failed:\n%s" % "\n".join(errors), true)

func _save_current_archetype() -> void:
	var result: Dictionary = PvpGhostServiceClass.save_curated_archetype(
		_file_path_edit.text.strip_edges(),
		_collect_current_archetype()
	)
	if not bool(result.get("success", false)):
		var errors: Array[String] = result.get("errors", [])
		validation_failed.emit(errors)
		_set_status("Save failed:\n%s" % "\n".join(errors), true)
		return

	_selected_snapshot_id = str(result.get("archetype", {}).get("id", ""))
	_reload_document()
	saved.emit(_selected_snapshot_id, str(result.get("path", "")))
	var snapshot: Dictionary = result.get("snapshot", {})
	_set_status(
		"Saved %s.\nPower Score: %d\nPower Bucket: %s"
		% [
			_selected_snapshot_id,
			int(snapshot.get("power_score", 0)),
			str(snapshot.get("power_bucket", "")),
		],
		false
	)

func _collect_current_archetype() -> Dictionary:
	var archetype: Dictionary = PvpGhostServiceClass.get_default_archetype()
	var existing: Dictionary = _find_document_archetype_by_id(_selected_snapshot_id)
	if not existing.is_empty():
		for key in existing.keys():
			archetype[key] = existing[key]

	archetype["id"] = _id_edit.text.strip_edges().to_lower()
	archetype["name"] = _name_edit.text.strip_edges()
	archetype["hero_id"] = _get_selected_option_value(_hero_option)
	archetype["day"] = int(_day_spin.value)
	archetype["level"] = int(_level_spin.value)
	archetype["slot_capacity"] = int(_slot_capacity_spin.value)
	archetype["prestige"] = int(_prestige_spin.value)
	archetype["max_health"] = int(_max_health_spin.value)
	archetype["health"] = int(_health_spin.value)
	archetype["regeneration"] = float(_regeneration_spin.value)
	archetype["skills"] = _collect_skills()
	archetype["items"] = _collect_items()
	return archetype

func _find_document_archetype_by_id(target_id: String) -> Dictionary:
	for archetype in _document_archetypes:
		if str(archetype.get("id", "")) == target_id:
			return (archetype as Dictionary).duplicate(true)
	return {}

func _collect_skills() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in _skills_box.get_children():
		var id_edit: LineEdit = row.get_meta("skill_id_edit", null) as LineEdit
		var tier_option: OptionButton = row.get_meta("tier_option", null) as OptionButton
		if id_edit == null or tier_option == null:
			continue
		var skill_id: String = id_edit.text.strip_edges().to_lower()
		if skill_id.is_empty():
			continue
		result.append({
			"id": skill_id,
			"tier": _get_selected_option_value(tier_option),
		})
	return result

func _collect_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in _items_box.get_children():
		var item_id_edit: LineEdit = row.get_meta("item_id_edit", null) as LineEdit
		var tier_option: OptionButton = row.get_meta("tier_option", null) as OptionButton
		var size_spin: SpinBox = row.get_meta("size_spin", null) as SpinBox
		var slot_spin: SpinBox = row.get_meta("slot_spin", null) as SpinBox
		var enchant_option: OptionButton = row.get_meta("enchant_option", null) as OptionButton
		var cooldown_spin: SpinBox = row.get_meta("cooldown_spin", null) as SpinBox
		var ammo_spin: SpinBox = row.get_meta("ammo_spin", null) as SpinBox
		var charges_spin: SpinBox = row.get_meta("charges_spin", null) as SpinBox
		if item_id_edit == null or tier_option == null:
			continue
		var item_id: String = item_id_edit.text.strip_edges().to_lower()
		if item_id.is_empty():
			continue
		result.append({
			"item_id": item_id,
			"tier": _get_selected_option_value(tier_option),
			"size": int(size_spin.value),
			"slot_index": int(slot_spin.value),
			"enchantment": _get_selected_option_value(enchant_option, true),
			"cooldown": float(cooldown_spin.value),
			"ammo": int(ammo_spin.value),
			"charges": int(charges_spin.value),
		})
	return result

func _set_status(message: String, is_error: bool) -> void:
	if _status_label == null:
		return
	var color: String = "#ff8f8f" if is_error else "#d8f0b0"
	_status_label.text = "[color=%s]%s[/color]" % [color, message]

func _close_editor() -> void:
	closed.emit()
	queue_free()

func _create_section_title(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.56, 1.0))
	return label

func _add_labeled_line_edit(parent: GridContainer, label_text: String) -> LineEdit:
	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.add_child(_make_label(label_text))
	var edit: LineEdit = LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(edit)
	parent.add_child(wrapper)
	return edit

func _add_labeled_option(
	parent: GridContainer,
	label_text: String,
	values: Array[String]
) -> OptionButton:
	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.add_child(_make_label(label_text))
	var option: OptionButton = _create_option_button(values)
	wrapper.add_child(option)
	parent.add_child(wrapper)
	return option

func _add_labeled_spin_box(
	parent: GridContainer,
	label_text: String,
	min_value: float,
	max_value: float,
	step: float,
	default_value: float
) -> SpinBox:
	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.add_child(_make_label(label_text))
	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = default_value
	spin.rounded = true
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(spin)
	parent.add_child(wrapper)
	return spin

func _make_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.80, 0.95))
	return label

func _create_option_button(
	values: Array[String],
	show_empty_as_none: bool = false
) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	for value in values:
		var label: String = value
		if show_empty_as_none and value.is_empty():
			label = "none"
		option.add_item(label)
		option.set_item_metadata(option.item_count - 1, value)
	return option

func _select_option_value(
	option: OptionButton,
	target_value: String,
	show_empty_as_none: bool = false
) -> void:
	var normalized_target: String = target_value.to_lower()
	for index in range(option.item_count):
		var value: String = str(option.get_item_metadata(index))
		if value.to_lower() == normalized_target:
			option.select(index)
			return
	if show_empty_as_none and normalized_target.is_empty() and option.item_count > 0:
		option.select(0)

func _get_selected_option_value(
	option: OptionButton,
	show_empty_as_none: bool = false
) -> String:
	if option == null or option.selected < 0 or option.selected >= option.item_count:
		return "" if show_empty_as_none else "bronze"
	return str(option.get_item_metadata(option.selected))

func _create_compact_spin_box(
	min_value: float,
	max_value: float,
	step: float,
	default_value: float
) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = default_value
	spin.rounded = true
	spin.custom_minimum_size = Vector2(70, 0)
	return spin

func _wrap_labeled_small(text: String, control: Control) -> Control:
	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(74, 0)
	wrapper.add_child(_make_label(text))
	wrapper.add_child(control)
	return wrapper

func _create_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.12, 0.96)
	style.border_color = Color(0.92, 0.68, 0.30, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0, 8)
	return style

func _create_status_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.16, 0.92)
	style.border_color = Color(0.40, 0.42, 0.48, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style
