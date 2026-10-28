MuR.EditorMinExtent = 8
MuR.EditorMaxExtent = 8192
MuR.EditorMaxObjects = 512
MuR.EditorPickRadius = 128
MuR.EditorDrawRadius = 3000

MuR.EditorObjectTypes = {
	{id = "propclip", name = "editor_type_propclip", category = "clip", color = Color(224, 170, 64)},
	{id = "playerclip", name = "editor_type_playerclip", category = "clip", color = Color(64, 148, 224)},
	{id = "npcclip", name = "editor_type_npcclip", category = "clip", color = Color(176, 92, 224)},
	{id = "clip", name = "editor_type_clip", category = "clip", color = Color(128, 128, 128)},
	{id = "triggerkill", name = "editor_type_triggerkill", category = "trigger", color = Color(224, 68, 68)},
	{id = "trigger_teleport", name = "editor_type_trigger_teleport", category = "trigger", color = Color(64, 204, 152)},
}

MuR.EditorObjectTypeByID = {}
MuR.EditorObjectCategoryByID = {}

for _, objectType in ipairs(MuR.EditorObjectTypes) do
	MuR.EditorObjectTypeByID[objectType.id] = objectType
	MuR.EditorObjectCategoryByID[objectType.id] = objectType.category
end

function MuR.IsEditorObjectType(id)
	return MuR.EditorObjectTypeByID[id] ~= nil
end

function MuR.IsEditorObjectCategory(category)
	return category == "clip" or category == "trigger"
end

function MuR.IsEditorObjectTrigger(id)
	local objectType = MuR.EditorObjectTypeByID[id]
	return objectType and objectType.category == "trigger" or false
end

function MuR.IsEditorObjectClip(id)
	local objectType = MuR.EditorObjectTypeByID[id]
	return objectType and objectType.category == "clip" or false
end
