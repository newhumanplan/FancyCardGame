class_name SkillArtCatalog
extends RefCounted

const PlayerSkillCatalogClass = preload("res://scripts/data/player_skill_catalog.gd")

const SKILL_ART_DIR: String = "res://assets/art/skills/wiki"
const ART_EXTENSIONS: Array[String] = [".png", ".jpg", ".jpeg", ".webp"]


static func get_skill_texture_path(skill_ref: Variant) -> String:
	var skill_id: String = ""
	if skill_ref is String:
		skill_id = str(skill_ref)
	else:
		var resolved: Dictionary = PlayerSkillCatalogClass.get_skill_entry(skill_ref)
		skill_id = str(resolved.get("id", ""))
	if skill_id.is_empty():
		return ""
	return get_skill_texture_path_by_source_id(skill_id)


static func get_skill_texture_path_by_source_id(source_id: String) -> String:
	var skill_id: String = source_id.strip_edges().to_lower()
	if skill_id.is_empty():
		return ""
	skill_id = skill_id.replace(" ", "_")

	for extension in ART_EXTENSIONS:
		var texture_path: String = "%s/%s%s" % [SKILL_ART_DIR, skill_id, extension]
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
