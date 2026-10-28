local bloodpools = {}
for i=1,34 do bloodpools[i] = "decals/bloodpool/bloodpool"..i end
local blooddrops = {}
for i=1,23 do blooddrops[i] = "decals/denseblood/blood"..i end
local ENABLED = true
local MAXSIZE_MULT = 1
local DECAY = true
local DETAIL = 2
local DEPTH_OVERRIDE = true
local CONVERT_TO_DECAL_ON_STABLE = false
local GORE_KIND = "pool"

local function SpendRender(particleCost, decalCost)
	return MuR
		and MuR.SpendGoreRenderBudget
		and MuR:SpendGoreRenderBudget(GORE_KIND, particleCost, decalCost, false)
end

local function TryDecal(pos, cooldown)
	return MuR
		and MuR.TryGoreDecalCell
		and MuR:TryGoreDecalCell(pos, cooldown or 0.18)
end

local function GetProfileDetail(profile)
	if profile.particleScale <= 0.5 then return math.min(DETAIL, 0) end
	if profile.particleScale < 1 then return math.min(DETAIL, 1) end
	return math.Clamp(DETAIL, 0, 2)
end

local poolSizeCache = {}
local CACHE_LIFETIME = 5

local function IsSolid(pos)
	return bit.band(util.PointContents(pos), CONTENTS_SOLID) == CONTENTS_SOLID
end

local function GetCacheKey(pos)
	return math.floor(pos.x / 20) .. "_" .. math.floor(pos.y / 20) .. "_" .. math.floor(pos.z / 20)
end

local function GetMaximumPoolSize(pos, normal, limit)
	local limit = limit or 50
	
	local cacheKey = GetCacheKey(pos)
	if poolSizeCache[cacheKey] and poolSizeCache[cacheKey].time > CurTime() then
		return math.min(poolSizeCache[cacheKey].size, limit)
	end
	
	local fraction = 3
	local dn_dist = 4
	for size=1,limit,fraction do
		local dir = size
		local spots = {
			pos + Vector(0, dir, 0),
			pos + Vector(dir, 0, 0),
			pos + Vector(0, -dir, 0),
			pos + Vector(-dir, 0, 0),
		}
		for i=1,#spots do
			local spos = spots[i] + Vector(0,0,1)
			local epos = spots[i] + Vector(0,0,-dn_dist)
			if not IsSolid(spos) then
				local tr = util.TraceLine({start=spos, endpos=epos, mask=MASK_DEADSOLID})
				if not tr.Hit then
					local result = math.max(size - fraction, 1)
					poolSizeCache[cacheKey] = {size = result, time = CurTime() + CACHE_LIFETIME}
					return result
				end
			end
		end
	end
	
	poolSizeCache[cacheKey] = {size = limit, time = CurTime() + CACHE_LIFETIME}
	return limit
end

local function EaseOut(p)
	return p^(0.6)
end

local function EaseInOut(p)
	if p < 0.5 then
		return 2 * p * p
	else
		return 1 - math.pow(-2 * p + 2, 2) / 2
	end
end

local function ModColor(c, mult, a)
	if type(c) ~= "table" or c.r == nil then
		c = Color(120,0,0)
	end
	return Color(math.Clamp(c.r*mult,0,255), math.Clamp(c.g*mult,0,255), math.Clamp(c.b*mult,0,255), a or c.a)
end

local function NormalizeColor(col)
	if type(col) == "table" and col.r then
		return Color(col.r,col.g,col.b,col.a or 255)
	end
	if type(col) == "number" then
		local v = math.Clamp(col,0,255)
		return Color(120,0,0,v)
	end
	return Color(120,0,0)
end

local SPRITE_MAT_CACHE = {}
local function GetSpriteMaterial(path)
	if not path then return nil end
	if SPRITE_MAT_CACHE[path] and SPRITE_MAT_CACHE[path].IsValid and SPRITE_MAT_CACHE[path]:IsError() == false then
		return SPRITE_MAT_CACHE[path]
	end
	local name = string.Replace("bloodshed_sprite_"..path, "/", "_")
	local mat = CreateMaterial(name, "UnlitGeneric", {
		["$basetexture"] = path,
		["$translucent"] = "1",
		["$vertexcolor"] = "1",
		["$vertexalpha"] = "1",
		["$ignorez"] = "0",
		["$nocull"] = "1"
	})
	SPRITE_MAT_CACHE[path] = mat
	return mat
end

local function RandomBloodMaterial(tbl)
	if type(tbl) ~= "table" or #tbl == 0 then return nil,nil end
	for _=1,6 do
		local v = tbl[math.random(1,#tbl)]
		if type(v) == "string" then
			return GetSpriteMaterial(v), v
		end
	end
	return nil,nil
end

function EFFECT:Init(data)
	-- Жидкая кровь из модуля gmcl_bsblood, если он стоит у игрока (client/cl_bsblood.lua).
	if MuR and MuR.BSBlood and MuR.BSBlood:Effect("bloodshed_blood_pool", data) then return end
    if not ENABLED then return end
    self.Profile = MuR and MuR.GetGoreQualityProfile and MuR:GetGoreQualityProfile()
    if not self.Profile then return end
    self.Detail = GetProfileDetail(self.Profile)

    local ent = data:GetEntity()
    self.Entity = ent
    self.Origin = data:GetOrigin()
    if not isvector(self.Origin) or self.Origin == vector_origin then
        self.Origin = IsValid(ent) and ent:GetPos() or vector_origin
    end
    if self.SetPos then self:SetPos(self.Origin) end
    self.BoneID = data:GetAttachment() or 0
    self.Flags = data:GetFlags() or 0
    self.BloodColor = NormalizeColor(data:GetColor())
    -- 1 drops, 2 huge and slow, 3 medium, 10 a gush, 11 small, anything else large.
    -- 10 and 11 sit up here out of the way because 4 is already passed in as a flag by
    -- sv_deathragdoll and falls through to the default on purpose.
    if self.Flags == 1 then
        self.MinSize, self.MaxSize = 6, 8
        self.BloodType = blooddrops
        self.RndPos = VectorRand(-8,8) 
		self.RndPos.z = 0
    elseif self.Flags == 2 then
        self.MinSize, self.MaxSize = 46, 52
        self.BloodType = bloodpools
        self.RndPos = vector_origin
    elseif self.Flags == 3 then
        self.MinSize, self.MaxSize = 16, 24
        self.BloodType = bloodpools
        self.RndPos = vector_origin
    elseif self.Flags == 10 then
        -- A body opened at the waist does not seep, it empties. Bigger than anything
        -- else and it arrives in about a second.
        self.MinSize, self.MaxSize = 58, 70
        self.BloodType = bloodpools
        self.RndPos = vector_origin
    elseif self.Flags == 11 then
        self.MinSize, self.MaxSize = 10, 15
        self.BloodType = bloodpools
        self.RndPos = vector_origin
    else
        self.MinSize, self.MaxSize = 30, 36
        self.BloodType = bloodpools
        self.RndPos = vector_origin
    end
    self.LifeTimeHard = CurTime() + 360 * self.Profile.lifetimeScale
    self.TracePos = nil
    self.TraceNormal = nil
    self.NextTrace = 0
    self.State = "forming"
    self.Layers = {}
    self.DropLayers = {}
    self.CreatedMain = false
    self.TargetRadius = 0
    self.FormStart = 0
    self.FormTime = 0
    self.StableStart = 0
    self.DryStart = 0
    self.Done = false
    self.CenterPos = nil
    self.RandomColorMul = 0.9 + math.Rand(0,0.15)
    self.Initialized = true
    self:UpdateTrace(true)
    if self.SetRenderBounds then
		local bound = Vector(1024,1024,1024)
        self:SetRenderBounds(bound,-bound)
    end
end

function EFFECT:CreatePredrip()
	if self.Flags == 1 or self.Flags == 3 then return end
	local requested = self.Flags == 2 and 5 or 3
	local count = math.max(1, math.floor(requested * self.Profile.particleScale + 0.5))

	for i = 1, count do
		if not SpendRender(1, 0) then break end

		local ang = self.TraceNormal:Angle()
		ang.roll = math.random(0, 360)
		local r = math.Rand(2, 5)
		local off = VectorRand()
		off.z = 0
		off:Normalize()
		off = off * math.Rand(0, 6)
		local m, raw = RandomBloodMaterial(self.BloodType)
		m = m or GetSpriteMaterial("decals/bloodpool/bloodpool1")
		local lay = {
			mat = m,
			raw = raw or "decals/bloodpool/bloodpool1",
			angle = ang,
			startSize = 0,
			endSize = r,
			born = CurTime(),
			life = 0.6 * self.Profile.lifetimeScale,
			pos = self.TracePos + self.RndPos + off,
			alpha = 255,
			kind = "drop"
		}
		table.insert(self.DropLayers, lay)
	end
end

function EFFECT:CreateMainLayers()
	if self.CreatedMain then return end

	local detail = self.Detail or GetProfileDetail(self.Profile)
	local baseCount = detail == 0 and 1 or (detail == 1 and 2 or 3)
	local edge = detail >= 1
	local gloss = detail == 2
	local mats = {}
	for i = 1, 8 do
		local m, raw = RandomBloodMaterial(self.BloodType)
		mats[i] = {
			mat = m or GetSpriteMaterial("decals/bloodpool/bloodpool1"),
			raw = raw or "decals/bloodpool/bloodpool1"
		}
	end

	local baseAngle = self.TraceNormal:Angle()
	local layerCount = 0
	local function rotatedAngle()
		return Angle(baseAngle.p, baseAngle.y, math.random(0, 360))
	end
	local function addLayer(layer)
		if not SpendRender(1, 0) then return false end
		table.insert(self.Layers, layer)
		layerCount = layerCount + 1
		return true
	end

	for i = 1, baseCount do
		if not addLayer({
			mat = mats[i].mat,
			raw = mats[i].raw,
			angle = rotatedAngle(),
			startSize = 0,
			endSize = self.TargetRadius * (0.65 + (i - 1) * 0.15),
			born = CurTime(),
			life = self.FormTime,
			alpha = 240,
			kind = "core",
			offset = self.RndPos
		}) then break end
	end

	if layerCount == 0 then
		self.CreatedMain = true
		self.State = "done"
		return
	end

	if edge then
		addLayer({
			mat = mats[5].mat,
			raw = mats[5].raw,
			angle = rotatedAngle(),
			startSize = 0,
			endSize = self.TargetRadius * 1.05,
			born = CurTime(),
			life = self.FormTime * 0.9,
			alpha = 200,
			kind = "edge",
			offset = self.RndPos
		})
	end

	if gloss then
		addLayer({
			mat = mats[6].mat,
			raw = mats[6].raw,
			angle = rotatedAngle(),
			startSize = 0,
			endSize = self.TargetRadius * 0.5,
			born = CurTime(),
			life = self.FormTime * 0.8,
			alpha = 160,
			kind = "gloss",
			offset = self.RndPos
		})
	end

	if detail >= 1 and self.TargetRadius > 15 then
		local requested = math.random(3, 6)
		local edgeDropCount = math.max(1, math.floor(requested * self.Profile.particleScale + 0.5))
		for i = 1, edgeDropCount do
			local angle = math.Rand(0, math.pi * 2)
			local dist = self.TargetRadius * math.Rand(0.85, 1.1)
			local dropOff = Vector(math.cos(angle) * dist, math.sin(angle) * dist, 0)
			local matData = mats[math.random(1, 4)]
			if not addLayer({
				mat = matData.mat,
				raw = matData.raw,
				angle = rotatedAngle(),
				startSize = 0,
				endSize = math.Rand(2, 5),
				born = CurTime() + math.Rand(0, self.FormTime * 0.5),
				life = self.FormTime * math.Rand(0.3, 0.6),
				alpha = math.random(180, 230),
				kind = "edgedrop",
				offset = self.RndPos + dropOff
			}) then break end
		end
	end

	self.CreatedMain = true
end

function EFFECT:AdvanceState()
    if self.State == "predrip" then
        if CurTime() >= self.PredripStart + self.PredripTime then
            self.State = "forming"
            if not self.FormPrepared then self:PrepareForm() end
        end
    elseif self.State == "forming" then
        local p = (CurTime()-self.FormStart)/self.FormTime
        if p >= 1 then
            self.State = "stable"
            self.StableStart = CurTime()
            if CONVERT_TO_DECAL_ON_STABLE and not self.DecalSpawned then self:SpawnDecals() end
        end
    elseif self.State == "stable" then
        local stableDur
        if self.Flags == 1 then stableDur = 8 elseif self.Flags == 2 then stableDur = 40 elseif self.Flags == 3 then stableDur = 20 else stableDur = 25 end
        stableDur = stableDur * self.Profile.lifetimeScale
        if CurTime() >= self.StableStart + stableDur then
            if DECAY then
                self.State = "drying"
                self.DryStart = CurTime()
                if self.Flags == 2 then self.DryTime = 120 elseif self.Flags == 1 then self.DryTime = 40 elseif self.Flags == 3 then self.DryTime = 60 else self.DryTime = 90 end
                self.DryTime = self.DryTime * self.Profile.lifetimeScale
            else
                self.State = "done"
            end
        end
    elseif self.State == "drying" then
        if CurTime() >= self.DryStart + self.DryTime then
            self.State = "done"
        end
    end
end

function EFFECT:UpdateTrace(force)
	if CurTime() < self.NextTrace and not force then return end

	local bonePos = self.Origin
	if IsValid(self.Entity) then
		local entBonePos = self.Entity:GetBonePosition(self.BoneID)
		if isvector(entBonePos) and (entBonePos ~= vector_origin or bonePos == vector_origin) then
			bonePos = entBonePos
		else
			bonePos = self.Entity:WorldSpaceCenter()
		end
	end

	if not isvector(bonePos) then return end
	local moved = true
	if self.LastTraceBonePos then
		moved = (bonePos - self.LastTraceBonePos):Length() > 2
	end
	if not moved and not force then return end
	self.LastTraceBonePos = bonePos
	self.NextTrace = CurTime() + 0.25
	local tr = util.TraceLine({start=bonePos + Vector(0,0,32), endpos=bonePos + Vector(0,0,-160), mask=MASK_DEADSOLID})
	if tr.Hit then
		self.TracePos = tr.HitPos + tr.HitNormal*0.01
		self.TraceNormal = tr.HitNormal
		if not self.CenterPos then self.CenterPos = self.TracePos end
	end
end

function EFFECT:PrepareForm()
	if self.FormPrepared then return end
	if not self.TracePos then return end
	local minsize = self.MinSize
	local maxsize = self.MaxSize
	if minsize > maxsize then minsize = maxsize end
	local base = math.random(minsize,maxsize)
	base = base * MAXSIZE_MULT
	local size = GetMaximumPoolSize(self.TracePos, self.TraceNormal, base)
	if size < 3 then self.State = "done" return end
	self.TargetRadius = size
	if self.Flags == 1 then
		self.FormTime = 0.2
	elseif self.Flags == 2 then
		self.FormTime = math.Rand(8,11)
	elseif self.Flags == 3 then
		self.FormTime = math.Rand(2,3)
	elseif self.Flags == 10 then
		self.FormTime = math.Rand(1,1.6)
	elseif self.Flags == 11 then
		self.FormTime = math.Rand(0.8,1.2)
	else
		self.FormTime = math.Rand(5,8)
	end
	self.FormTime = self.FormTime * self.Profile.lifetimeScale
	self.FormStart = CurTime()
	self:CreateMainLayers()
	self.FormPrepared = true
end

function EFFECT:ApplySlope(dt)
	if not self.TraceNormal then return end
	local nz = self.TraceNormal.z
	if nz >= 0.97 then return end
	local gravity = Vector(0, 0, -1)
	local slide = gravity - self.TraceNormal * gravity:Dot(self.TraceNormal)
	if slide:Length() < 0.001 then return end
	slide:Normalize()
	local spd = (1-nz)*20
	self.CenterPos = self.CenterPos + slide * spd * dt
end

function EFFECT:UpdateLayers()
	local now = CurTime()
	if self.State == "predrip" then
		local prog = (now - self.PredripStart)/self.PredripTime
		for _,l in ipairs(self.DropLayers) do
			local lp = (now - l.born)/l.life
			if lp >= 1 then l.alpha = 0 else
				local sz = Lerp(EaseOut(math.Clamp(lp,0,1)), l.startSize, l.endSize)
				l.curSize = sz
				l.alpha = 255 * (1 - lp)
			end
		end
	end
	if self.State == "forming" then
		local p = math.Clamp((now - self.FormStart)/self.FormTime,0,1)
		local ep = EaseOut(p)
		for _,l in ipairs(self.Layers) do
			local lp = math.Clamp((now - l.born)/l.life,0,1)
			local sp = EaseOut(lp)
			l.curSize = Lerp(sp, l.startSize, l.endSize)
		end
	elseif self.State == "stable" then
		for _,l in ipairs(self.Layers) do
			if not l.curSize then l.curSize = l.endSize end
		end
	elseif self.State == "drying" then
		local dp = math.Clamp((now - self.DryStart)/self.DryTime,0,1)
		for _,l in ipairs(self.Layers) do
			local baseAlpha = l.kind == "edge" and 180 or (l.kind=="gloss" and 120 or 235)
			local fade = 1 - dp
			if l.kind == "gloss" then fade = fade^1.5 end
			if l.kind == "edge" then fade = math.max(fade,0.15) end
			l.alpha = baseAlpha * fade
			if not l.curSize then l.curSize = l.endSize end
			if l.kind == "gloss" then
				local pulse = 0.5 + math.sin(CurTime()*3)*0.5
				l.alpha = l.alpha * pulse * (1-dp)
			end
		end
	end
end

function EFFECT:Think()
	if not self.Initialized or self.Done then return false end
	if not ENABLED then return false end
	if not IsValid(self.Entity) and not isvector(self.Origin) and not self.TracePos then return false end
	if CurTime() > self.LifeTimeHard then return false end
	self:UpdateTrace()
	if not self.TracePos then return true end
	if self.State == "forming" and not self.FormPrepared then self:PrepareForm() end
	self:AdvanceState()
	if self.State == "done" then self.Done = true return false end
	self:UpdateLayers()
	if self.CenterPos then self:ApplySlope(FrameTime()) else self.CenterPos = self.TracePos end
	if self.UpdateRenderBounds then self:UpdateRenderBounds() end
	return true
end

function EFFECT:SpawnDecals()
	if self.DecalSpawned or not self.TracePos or not self.TraceNormal then return end

	-- Mark the one-shot conversion as handled even when the shared budget rejects it.
	self.DecalSpawned = true
	local pos = self.CenterPos or self.TracePos
	local decalLimit = math.max(1, math.floor(#self.Layers * self.Profile.decalScale + 0.5))
	local considered = 0

	for _, l in ipairs(self.Layers) do
		if l.curSize and l.curSize > 2 and l.raw then
			considered = considered + 1
			if considered > decalLimit then break end

			local decalPos = pos + (l.offset or vector_origin)
			local mat = GetSpriteMaterial(l.raw)
			if mat and SpendRender(0, 1) and TryDecal(decalPos, 0.18) then
				util.DecalEx(
					mat,
					Entity(0),
					decalPos,
					self.TraceNormal,
					Color(self.BloodColor.r, self.BloodColor.g, self.BloodColor.b, 200),
					l.curSize * 0.5,
					l.curSize * 0.5
				)
			end
		end
	end
end

function EFFECT:Render()
	if not self.TracePos or not self.TraceNormal then return end
	if CONVERT_TO_DECAL_ON_STABLE and self.DecalSpawned then return end
	self.BloodColor = NormalizeColor(self.BloodColor)
	local baseColor = ModColor(self.BloodColor, self.RandomColorMul)
	local center = self.CenterPos or self.TracePos
	render.SetColorModulation(1,1,1)
	render.CullMode(MATERIAL_CULLMODE_NONE)
	if DEPTH_OVERRIDE then render.OverrideDepthEnable(true,false) end
	local n = self.TraceNormal
	local offsetN = n * 0.05
	for _,l in ipairs(self.DropLayers) do
		if l.alpha > 0 and l.curSize and l.kind == "drop" and l.mat then
			local c = Color(baseColor.r, baseColor.g, baseColor.b, math.Clamp(l.alpha,0,255))
			render.SetMaterial(l.mat)
			local p = l.pos + offsetN
			render.DrawQuadEasy(p, n, l.curSize, l.curSize, c, l.angle.roll)
		end
	end
	local layerLimit = self.Detail or 0
	local shown = 0
	for _,l in ipairs(self.Layers) do
		if l.curSize and l.alpha>1 and l.mat then
			shown = shown + 1
			if shown > (layerLimit==0 and 1 or (layerLimit==1 and 2 or 5)) then break end
			local mult = 1
			if l.kind == "edge" then mult = 0.75 end
			if self.State == "drying" and l.kind == "core" then mult = mult * 0.85 end
			local c = ModColor(baseColor,mult, math.Clamp(l.alpha,0,255))
			render.SetMaterial(l.mat)
			local p = center + (l.offset or vector_origin) + offsetN
			render.DrawQuadEasy(p, n, l.curSize, l.curSize, c, l.angle.roll)
		end
	end
	if DEPTH_OVERRIDE then render.OverrideDepthEnable(false,false) end
	render.CullMode(MATERIAL_CULLMODE_CCW)
end
