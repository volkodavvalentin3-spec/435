MuR.EditorObjects = MuR.EditorObjects or {}
MuR.EditorNextID = MuR.EditorNextID or 1

util.AddNetworkString("MuR.EditorObject.Sync")
util.AddNetworkString("MuR.EditorObject.Edit")

local EDITOR_DIR = "bloodshed/editor"
local EDITOR_VERSION = 1
local EDITOR_CLASS = "mur_editor_volume"

file.CreateDir(EDITOR_DIR)

local function EditorFile()
	return EDITOR_DIR .. "/" .. game.GetMap() .. ".json"
end

local function FiniteNumber(value)
	return isnumber(value) and value == value and value > -1000000000 and value < 1000000000
end

local function VectorFromArray(value)
	if isvector(value) then
		if not FiniteNumber(value.x) or not FiniteNumber(value.y) or not FiniteNumber(value.z) then return nil end
		return Vector(value.x, value.y, value.z)
	end

	if not istable(value) then return nil end
	local x, y, z = value[1], value[2], value[3]
	if not FiniteNumber(x) or not FiniteNumber(y) or not FiniteNumber(z) then return nil end
	return Vector(x, y, z)
end

local function NormalizeBounds(mins, maxs)
	mins = VectorFromArray(mins)
	maxs = VectorFromArray(maxs)
	if not mins or not maxs then return nil end

	local low = Vector(
		math.min(mins.x, maxs.x),
		math.min(mins.y, maxs.y),
		math.min(mins.z, maxs.z)
	)
	local high = Vector(
		math.max(mins.x, maxs.x),
		math.max(mins.y, maxs.y),
		math.max(mins.z, maxs.z)
	)

	for _, axis in ipairs({"x", "y", "z"}) do
		local extent = high[axis] - low[axis]
		if extent < MuR.EditorMinExtent or extent > MuR.EditorMaxExtent then return nil end
	end

	return low, high
end

local function NormalizeObject(data, allowID)
	if not istable(data) or not MuR.IsEditorObjectType(data.type) then return nil end

	local mins, maxs = NormalizeBounds(data.mins, data.maxs)
	if not mins or not maxs then return nil end

	local object = {
		type = data.type,
		mins = mins,
		maxs = maxs,
	}

	if allowID then
		if not isnumber(data.id) or data.id < 1 or data.id % 1 ~= 0 or data.id > 2147483647 then return nil end
		object.id = data.id
	end

	if data.type == "trigger_teleport" then
		object.destination = VectorFromArray(data.destination)
		if not object.destination then return nil end
	end

	return object
end

local function SerializeVector(vector)
	return {vector.x, vector.y, vector.z}
end

local function SerializeObject(object)
	local result = {
		id = object.id,
		type = object.type,
		mins = SerializeVector(object.mins),
		maxs = SerializeVector(object.maxs),
	}

	if object.destination then
		result.destination = SerializeVector(object.destination)
	end

	return result
end

local function ObjectPayload()
	local payload = {}

	for _, object in ipairs(MuR.EditorObjects) do
		payload[#payload + 1] = SerializeObject(object)
	end

	return payload
end

function MuR:LoadEditorObjects()
	self.EditorObjects = {}
	self.EditorNextID = 1

	local raw = file.Read(EditorFile(), "DATA")
	if not raw or raw == "" then
		self:RebuildEditorEntities()
		return false
	end

	local decoded = util.JSONToTable(raw)
	if not istable(decoded) or decoded.version ~= EDITOR_VERSION or not istable(decoded.objects) then
		self:RebuildEditorEntities()
		return false
	end

	local used = {}
	for _, data in ipairs(decoded.objects) do
		local object = NormalizeObject(data, true)
		if object and not used[object.id] and #self.EditorObjects < MuR.EditorMaxObjects then
			used[object.id] = true
			self.EditorObjects[#self.EditorObjects + 1] = object
			self.EditorNextID = math.max(self.EditorNextID, object.id + 1)
		end
	end

	self:RebuildEditorEntities()
	return true
end

function MuR:SaveEditorObjects()
	file.CreateDir(EDITOR_DIR)
	local encoded = util.TableToJSON({version = EDITOR_VERSION, objects = ObjectPayload()}, true)
	if not encoded then return false end

	file.Write(EditorFile(), encoded)
	return true
end

function MuR:SyncEditorObjectsTo(target)
	net.Start("MuR.EditorObject.Sync")
	net.WriteUInt(#self.EditorObjects, 10)

	for _, object in ipairs(self.EditorObjects) do
		net.WriteUInt(object.id, 32)
		net.WriteString(object.type)
		net.WriteVector(object.mins)
		net.WriteVector(object.maxs)
		local hasDestination = object.destination ~= nil
		net.WriteBool(hasDestination)
		if hasDestination then net.WriteVector(object.destination) end
	end

	if target then net.Send(target) else net.Broadcast() end
end

local function RemoveRuntimeEntities()
	for _, entity in ipairs(ents.FindByClass(EDITOR_CLASS)) do
		if entity.EditorObjectID ~= nil then entity:Remove() end
	end
end

function MuR:RebuildEditorEntities()
	if not SERVER then return end

	RemoveRuntimeEntities()

	for _, object in ipairs(self.EditorObjects) do
		local entity = ents.Create(EDITOR_CLASS)
		if IsValid(entity) then
			entity.EditorObjectID = object.id
			entity.EditorType = object.type
			entity.EditorMins = object.mins
			entity.EditorMaxs = object.maxs
			entity.EditorDestination = object.destination
			entity:Spawn()
			entity:Activate()
		end
	end
end

function MuR:IsEditorOperator(ply)
	return IsValid(ply) and ply:IsSuperAdmin() and self.SpawnEditors[ply] == true
end

local function DistanceToBounds(position, mins, maxs)
	local x = math.max(mins.x - position.x, 0, position.x - maxs.x)
	local y = math.max(mins.y - position.y, 0, position.y - maxs.y)
	local z = math.max(mins.z - position.z, 0, position.z - maxs.z)
	return x * x + y * y + z * z
end

net.Receive("MuR.EditorObject.Edit", function(_, ply)
	if not MuR:IsEditorOperator(ply) then return end

	local action = net.ReadString()
	if action == "add" then
		if #MuR.EditorObjects >= MuR.EditorMaxObjects then return end

		local objectType = net.ReadString()
		local mins = net.ReadVector()
		local maxs = net.ReadVector()
		local destination = nil
		if objectType == "trigger_teleport" then destination = net.ReadVector() end

		local object = NormalizeObject({
			type = objectType,
			mins = mins,
			maxs = maxs,
			destination = destination,
		}, false)
		if not object then return end

		object.id = MuR.EditorNextID
		MuR.EditorNextID = MuR.EditorNextID + 1
		MuR.EditorObjects[#MuR.EditorObjects + 1] = object
	elseif action == "remove" then
		local position = net.ReadVector()
		local radiusSqr = MuR.EditorPickRadius * MuR.EditorPickRadius
		local bestIndex, bestDistance

		for index, object in ipairs(MuR.EditorObjects) do
			local distance = DistanceToBounds(position, object.mins, object.maxs)
			if distance <= radiusSqr and (not bestDistance or distance < bestDistance) then
				bestIndex, bestDistance = index, distance
			end
		end

		if not bestIndex then return end
		table.remove(MuR.EditorObjects, bestIndex)
	elseif action == "clear" then
		local category = net.ReadString()
		if not MuR.IsEditorObjectCategory(category) then return end

		for index = #MuR.EditorObjects, 1, -1 do
			if MuR.EditorObjectCategoryByID[MuR.EditorObjects[index].type] == category then
				table.remove(MuR.EditorObjects, index)
			end
		end
	else
		return
	end

	MuR:RebuildEditorEntities()
	MuR:SyncEditorObjectsTo()
end)

hook.Add("InitPostEntity", "MuR.EditorObjects.Load", function()
	MuR:LoadEditorObjects()
end)

hook.Add("PostCleanupMap", "MuR.EditorObjects.Rebuild", function()
	timer.Simple(0, function()
		if MuR and MuR.RebuildEditorEntities then MuR:RebuildEditorEntities() end
	end)
end)

hook.Add("PlayerDisconnected", "MuR.EditorObjects.Leave", function(ply)
	if MuR.SpawnEditors then MuR.SpawnEditors[ply] = nil end
end)
