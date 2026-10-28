if !SERVER then return end

local ENT = FindMetaTable("Entity")

local FLEX_INTENSITY = 4

local FLEX_PAIN = {
    "inner_raiser",
    "outer_raiser", 
    "nose_wrinkler",
    "upper_lip_raiser",
    "lip_corner_puller",
    "chin_raiser",
    "brow_lowerer",
}

local FLEX_FEAR = {
    "inner_raiser",
    "outer_raiser",
    "upper_lid_raiser",
    "jaw_drop",
    "lip_stretcher",
}

local FLEX_DEATH = {
    "jaw_drop",
    "left_lid_droop",
    "right_lid_droop", 
}

local FLEX_AGONY = {
    "inner_raiser",
    "nose_wrinkler",
    "upper_lip_raiser",
    "lip_corner_depressor",
    "chin_raiser",
    "mouth_stretch",
    "brow_lowerer",
}

function ENT:ZGM3_InitFacialFlex()
    if self.ZGM3_FlexInit then return end
    self.ZGM3_FlexInit = true
    self.ZGM3_FlexMap = {}

    local flexCount = self:GetFlexNum() or 0
    if flexCount == 0 then return end

    for i = 0, flexCount - 1 do
        local name = self:GetFlexName(i)
        if not isstring(name) then continue end
        local lname = string.lower(name)
        self.ZGM3_FlexMap[lname] = i
    end
end

function ENT:ZGM3_SetFlexByName(name, value)
    if not self.ZGM3_FlexMap then return false end

    local lname = string.lower(name)
    for flexName, flexID in pairs(self.ZGM3_FlexMap) do
        if string.find(flexName, lname) then
            self:SetFlexWeight(flexID, math.Clamp(value, 0, FLEX_INTENSITY))
            return true
        end
    end
    return false
end

function ENT:ZGM3_ApplyFlexSet(flexSet, intensity, randomize)
    if not self.ZGM3_FlexMap then return end

    intensity = intensity or 1
    intensity = intensity * FLEX_INTENSITY

    for _, flexName in ipairs(flexSet) do
        local value = intensity
        if randomize then
            value = intensity * math.Rand(0.6, 1.0)
        end
        self:ZGM3_SetFlexByName(flexName, value)
    end
end

function ENT:ZGM3_SetPainExpression(intensity)
    self:ZGM3_InitFacialFlex()
    intensity = math.Clamp(intensity or 0.7, 0, 1)
    self:ZGM3_ApplyFlexSet(FLEX_PAIN, intensity, true)
end

function ENT:ZGM3_SetFearExpression(intensity)
    self:ZGM3_InitFacialFlex()
    intensity = math.Clamp(intensity or 0.6, 0, 1)
    self:ZGM3_ApplyFlexSet(FLEX_FEAR, intensity, true)
end

function ENT:ZGM3_SetDeathExpression(instant)
    self:ZGM3_InitFacialFlex()

    if instant then
        self:ZGM3_ApplyFlexSet(FLEX_DEATH, 1, false)
        self:ZGM3_SetFlexByName("jaw_drop", math.Rand(0.2, 0.6) * FLEX_INTENSITY)
        return
    end

    self:ZGM3_ApplyFlexSet(FLEX_AGONY, 0.9, true)

    local timerName = "ZGM3_DeathFlex_" .. self:EntIndex()
    local stage = 0

    timer.Create(timerName, 0.5, 6, function()
        if not IsValid(self) then
            timer.Remove(timerName)
            return
        end

        stage = stage + 1
        local relaxFactor = stage / 6

        for _, flexName in ipairs(FLEX_AGONY) do
            local current = 0.9 * (1 - relaxFactor * 0.5)
            self:ZGM3_SetFlexByName(flexName, current * math.Rand(0.7, 1.0) * FLEX_INTENSITY)
        end

        self:ZGM3_SetFlexByName("lid_closer", relaxFactor * 0.3 * FLEX_INTENSITY)
        self:ZGM3_SetFlexByName("left_lid_closer", relaxFactor * 0.3 * FLEX_INTENSITY)
        self:ZGM3_SetFlexByName("right_lid_closer", relaxFactor * 0.3 * FLEX_INTENSITY)
        self:ZGM3_SetFlexByName("jaw_drop", (0.3 + relaxFactor * 0.3) * FLEX_INTENSITY)

        if stage >= 6 then
            timer.Remove(timerName)
        end
    end)

    self:CallOnRemove("ZGM3_StopDeathFlex", function()
        timer.Remove(timerName)
    end)
end

function ENT:ZGM3_SetAgonyExpression()
    self:ZGM3_InitFacialFlex()
    self:ZGM3_ApplyFlexSet(FLEX_AGONY, 1.0, true)

    local timerName = "ZGM3_AgonyFlex_" .. self:EntIndex()
    local phase = math.Rand(0, math.pi * 2)

    timer.Create(timerName, 0.1, 30, function()
        if not IsValid(self) then
            timer.Remove(timerName)
            return
        end

        local wave = 0.7 + 0.3 * math.sin(CurTime() * 8 + phase)

        for _, flexName in ipairs(FLEX_AGONY) do
            self:ZGM3_SetFlexByName(flexName, wave * math.Rand(0.8, 1.0) * FLEX_INTENSITY)
        end

        if math.random(1, 10) == 1 then
            self:ZGM3_SetFlexByName("jaw_drop", math.Rand(0.4, 0.8) * FLEX_INTENSITY)
        end
    end)

    self:CallOnRemove("ZGM3_StopAgonyFlex", function()
        timer.Remove(timerName)
    end)
end

function ENT:ZGM3_SetDismemberExpression(boneName)
    self:ZGM3_InitFacialFlex()

    self:ZGM3_ApplyFlexSet(FLEX_AGONY, 1.0, false)
    self:ZGM3_SetFlexByName("jaw_drop", 0.9 * FLEX_INTENSITY)
    self:ZGM3_SetFlexByName("mouth_stretch", 1.0 * FLEX_INTENSITY)

    if boneName and string.find(boneName, "Head") then
        return
    end

    timer.Simple(0.5, function()
        if IsValid(self) then
            self:ZGM3_SetAgonyExpression()
        end
    end)
end

function ENT:ZGM3_ResetFlex()
    if not self.ZGM3_FlexMap then return end

    for _, flexID in pairs(self.ZGM3_FlexMap) do
        self:SetFlexWeight(flexID, 0)
    end
end
