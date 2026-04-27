class_name ItemArtCatalog
extends RefCounted

const ItemDataClass = preload("res://scripts/data/item_data.gd")

const ITEM_ART_DIR: String = "res://assets/art/items/wiki"
const ART_EXTENSIONS: Array[String] = [".png", ".jpg", ".jpeg", ".webp"]

static func get_item_texture_path(item: ItemDataClass) -> String:
	if item == null:
		return ""
	var source_path: String = get_item_texture_path_by_source_id(item.source_id)
	if not source_path.is_empty():
		return source_path
	return ""

static func get_item_texture_path_by_source_id(source_id: String) -> String:
	var item_id: String = source_id.strip_edges().to_lower()
	if item_id.is_empty():
		return ""
	item_id = item_id.replace(" ", "_")

	for extension in ART_EXTENSIONS:
		var texture_path: String = "%s/%s%s" % [ITEM_ART_DIR, item_id, extension]
		if ResourceLoader.exists(texture_path) or FileAccess.file_exists(texture_path):
			return texture_path
	return ""

static func load_texture(texture_path: String) -> Texture2D:
	if texture_path.is_empty():
		return null
	if ResourceLoader.exists(texture_path):
		var imported_texture: Texture2D = load(texture_path) as Texture2D
		if imported_texture != null:
			return imported_texture
	if not FileAccess.file_exists(texture_path):
		return null
	var image: Image = Image.new()
	var error: Error = image.load(texture_path)
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)
