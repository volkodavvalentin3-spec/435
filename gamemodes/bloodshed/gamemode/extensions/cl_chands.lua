CreateClientConVar("blsd_chands", 1)
CreateClientConVar("blsd_chands_shoulder",1)
CreateClientConVar("blsd_chands_infscl", 0)
TRANSCARMTOPMWN_CMdl = TRANSCARMTOPMWN_CMdl
local function Check(ch, n, nn)
    local i = GetConVar("blsd_chands_shoulder"):GetInt()
    return ((not ch:LookupBone(n) and not ch:LookupBone(nn)) or string.find(n, "Spine") or string.find(nn, "Spine") or ((i == 1 and string.find(n, "Trapezius")) or (string.find(n, "Shoulder") or string.find(n, "Trapezius"))) or string.find(n, "Thigh") or string.find(n, "Calf") or string.find(n, "Foot") or string.find(n, "Toe0") or string.find(nn, "Thigh") or string.find(nn, "Calf") or string.find(nn, "Foot") or string.find(nn, "Toe0")) and not string.find(n, "Wrist") and not string.find(n, "Elbow") and not string.find(n, "Bicep") and (i == 0 or (i == 1 and not string.find(n, "Shoulder")) or (not string.find(n, "Shoulder") and not string.find(n, "Trapezius")))
end

local Meta = table.Copy(FindMetaTable("Entity"))
local OldGetModel = Meta.GetModel
local Old__index = Meta.__index
function Meta:__index(key)
    local val = Meta[key]
    if val then
        return val
    end
    return Old__index(self, key)
end

function Meta:GetModel()
    local on = GetConVar("blsd_chands"):GetInt() == 1
    local p = LocalPlayer()
    if on and IsValid(p) and self == p:GetHands() and IsValid(p:GetActiveWeapon()) and (not weapons.IsBasedOn(p:GetActiveWeapon():GetClass(), "mg_base") or p:GetActiveWeapon():GetViewModel().m_CHands.transcarmtopmwms2) then
        return OldGetModel(self)
    else
        return OldGetModel(self)
    end
end

local OldGetBodygroup = Meta.GetBodygroup
function Meta:GetBodygroup(i)
    local on = GetConVar("blsd_chands"):GetInt() == 1
    local p = LocalPlayer()
    if on and IsValid(p) then
        return p:GetBodygroup(i)
    else
        return OldGetBodygroup(self, i)
    end
end

local OldGetBodyGroups = Meta.GetBodyGroups
function Meta:GetBodyGroups(i)
    local on = GetConVar("blsd_chands"):GetInt() == 1
    local p = LocalPlayer()
    if on and IsValid(p) then
        return p:GetBodyGroups()
    else
        return OldGetBodyGroups(self, i)
    end
end

local myfunkinhugeval = math.huge
local Run
local function PaintFunc(vm, hand, tfa)
    local p = LocalPlayer()
    if not IsValid(p) then return end
    local w = p:GetActiveWeapon()
    if not IsValid(hand) then
        return
    end

    if not IsValid(vm) then vm = hand end
    local on = GetConVar("blsd_chands"):GetInt() == 1
    if on and (not hand.savee_transcarmtopmwm_hide) then
        p:SetupBones()
        hand.savee_transcarmtopmwm_hide = true
        hand.savee_transcarmtopmwm_befmat = hand:GetMaterial()
        debug.setmetatable(hand, Meta)
        local mod = {}
        if IsValid(TRANSCARMTOPMWN_CMdl) then
            TRANSCARMTOPMWN_CMdl:Remove()
        end

        for i = 0, p:GetBoneCount() - 1 do
            local n = p:GetBoneName(i)
            local nn = p:GetBoneName(p:GetBoneParent(i))
            if Check(hand, n, nn) then
                mod[i] = true
                if IsValid(p.vrnvghand) then
                    if GetConVar("blsd_chands_infscl"):GetInt() == 1 then
                        p.vrnvghand:ManipulateBoneScale(i, Vector(myfunkinhugeval, myfunkinhugeval, myfunkinhugeval))
                    else
                        p.vrnvghand:ManipulateBoneScale(i, Vector(0, 0, 0))
                    end

                    p.vrnvghand:ManipulateBonePosition(i, Vector(-myfunkinhugeval, 0, -myfunkinhugeval))
                end
            end
        end

        hand.savee_transarmtopmwm_mod = mod
        TRANSCARMTOPMWN_CMdl = ClientsideModel(p:GetModel())
        function TRANSCARMTOPMWN_CMdl:GetPlayerColor()
            return p:GetPlayerColor()
        end

        TRANSCARMTOPMWN_CMdl:SetNoDraw(true)
        TRANSCARMTOPMWN_CMdl:SetParent(vm)
        TRANSCARMTOPMWN_CMdl:AddEffects(EF_BONEMERGE)
        TRANSCARMTOPMWN_CMdl:AddEffects(EF_PARENT_ANIMATES)
        TRANSCARMTOPMWN_CMdl:AddCallback("BuildBonePositions", function(ent, nb)
            for i = 0, nb - 1 do
                local mat = ent:GetBoneMatrix(i)
                if not mat or not mod[i] then continue end
                local scale = mat:GetScale()
                mat:Scale(GetConVar("blsd_chands_infscl"):GetInt() == 1 and Vector(myfunkinhugeval, myfunkinhugeval, myfunkinhugeval) or Vector(0, 0, 0))
                mat:SetTranslation(mat:GetTranslation() - p:GetAimVector() * 114514)
                ent:SetBoneMatrix(i, mat)
            end
        end)
    elseif on then
        if tfa then
        if IsValid(hand) then
                hand:SetMaterial(hand.savee_transcarmtopmwm_befmat)
                if not isnumber(hand.savee_transcarmtopmwm_callback) then
                    hand.savee_transcarmtopmwm_callback = hand:AddCallback("BuildBonePositions", function(ent, nb)
                        for i = 0, nb - 1 do
                            local mat = ent:GetBoneMatrix(i)
                            if not mat or not ent.savee_transarmtopmwm_mod[i] then continue end
                            local scale = mat:GetScale()
                            mat:Scale(GetConVar("blsd_chands_infscl"):GetInt() == 1 and Vector(myfunkinhugeval, myfunkinhugeval, myfunkinhugeval) or Vector(0, 0, 0))
                            mat:SetTranslation(mat:GetTranslation() - p:GetAimVector() * 114514)
                            ent:SetBoneMatrix(i, mat)
                        end
                    end)
                end

                hand:SetModel(p:GetModel())
                for i = 0, p:GetNumBodyGroups() do
                    hand:SetBodygroup(i, p:GetBodygroup(i))
                end
            end
        else
            if IsValid(hand) then
                hand:SetMaterial("savee/transchand/invisiblemat/invisiblemat")
                if isnumber(hand.savee_transcarmtopmwm_callback) then
                    hand:RemoveCallback("BuildBonePositions", hand.savee_transcarmtopmwm_callback)
                    local playermodel = player_manager.TranslateToPlayerModelName(p:GetModel())
                    hand:SetModel(player_manager.TranslatePlayerHands(playermodel).model)
                    hand.savee_transcarmtopmwm_callback = nil
                end
            end

            if not IsValid(TRANSCARMTOPMWN_CMdl) then
                TRANSCARMTOPMWN_CMdl = ClientsideModel(p:GetModel())
                function TRANSCARMTOPMWN_CMdl:GetPlayerColor()
                    return p:GetPlayerColor()
                end

                TRANSCARMTOPMWN_CMdl:SetNoDraw(true)
                TRANSCARMTOPMWN_CMdl:SetParent(vm)
                TRANSCARMTOPMWN_CMdl:AddEffects(EF_BONEMERGE)
                TRANSCARMTOPMWN_CMdl:AddEffects(EF_PARENT_ANIMATES)
                TRANSCARMTOPMWN_CMdl:AddCallback("BuildBonePositions", function(ent, nb)
                    for i = 0, nb - 1 do
                        local mat = ent:GetBoneMatrix(i)
                        if not mat or not hand.savee_transarmtopmwm_mod[i] then continue end
                        local scale = mat:GetScale()
                        mat:Scale(GetConVar("blsd_chands_infscl"):GetInt() == 1 and Vector(myfunkinhugeval, myfunkinhugeval, myfunkinhugeval) or Vector(0, 0, 0))
                        mat:SetTranslation(mat:GetTranslation() - p:GetAimVector() * 114514)
                        ent:SetBoneMatrix(i, mat)
                    end
                end)
            end

            TRANSCARMTOPMWN_CMdl:SetMaterial(hand.savee_transcarmtopmwm_befmat)
            TRANSCARMTOPMWN_CMdl:SetParent(vm)
            TRANSCARMTOPMWN_CMdl:SetRenderOrigin(vm:GetPos())
            TRANSCARMTOPMWN_CMdl:SetRenderAngles(vm:GetAngles())
            for i = 0, p:GetNumBodyGroups() do
                TRANSCARMTOPMWN_CMdl:SetBodygroup(i, p:GetBodygroup(i))
            end

            TRANSCARMTOPMWN_CMdl:SetSkin(p:GetSkin())
            TRANSCARMTOPMWN_CMdl:DrawModel()
        end

        if IsValid(p.vrnvghand) then
            for i = 0, p:GetBoneCount() - 1 do
                local n = p:GetBoneName(i)
                local nn = p:GetBoneName(p:GetBoneParent(i))
                if Check(hand, n, nn) then
                    if GetConVar("blsd_chands_infscl"):GetInt() == 1 then
                        p.vrnvghand:ManipulateBoneScale(i, Vector(myfunkinhugeval, myfunkinhugeval, myfunkinhugeval))
                    else
                        p.vrnvghand:ManipulateBoneScale(i, Vector(0, 0, 0))
                    end

                    p.vrnvghand:ManipulateBonePosition(i, Vector(-myfunkinhugeval, 0, -myfunkinhugeval))
                end
            end

            for i = 0, p:GetNumBodyGroups() do
                p.vrnvghand:SetBodygroup(i, p:GetBodygroup(i))
            end
        end
    elseif not on and hand.savee_transcarmtopmwm_hide then
        hand.savee_transcarmtopmwm_hide = false
        debug.setmetatable(hand, FindMetaTable("Entity"))
        hand:SetMaterial(hand.savee_transcarmtopmwm_befmat)
        if isnumber(hand.savee_transcarmtopmwm_callback) then
            hand:RemoveCallback("BuildBonePositions", hand.savee_transcarmtopmwm_callback)
            hand.savee_transcarmtopmwm_callback = nil
        end

        local playermodel = player_manager.TranslateToPlayerModelName(p:GetModel())
        hand:SetModel(player_manager.TranslatePlayerHands(playermodel).model)
        if IsValid(TRANSCARMTOPMWN_CMdl) then TRANSCARMTOPMWN_CMdl:Remove() end
    end
end

hook.Add("PreDrawPlayerHands", "savee_transcarmtopmwm", function(hand, vm)
    local p = LocalPlayer()
    local w = p:GetActiveWeapon()
    if IsValid(w) and weapons.IsBasedOn(w:GetClass(), "mg_base") then
        local hand = p:GetHands()
        TRANSCARMTOPMWN_CMdl:Remove()
        local on = GetConVar("blsd_chands"):GetInt() == 1
        if on and not w:GetViewModel().m_CHands.transcarmtopmwm then
            local playermodel = player_manager.TranslateToPlayerModelName(LocalPlayer():GetModel())
            hand:SetModel(player_manager.TranslatePlayerHands(playermodel).model)
        end
        return
    end

    PaintFunc(vm, hand, w.IsTFAWeapon)
end)

hook.Add("HUDPaint", "savee_transcarmtopmwm", function(vm)
    local p = LocalPlayer()
    if not IsValid(p) then return end
    local hand = p:GetHands()
    local w = p:GetActiveWeapon()
    if not IsValid(w) or not IsValid(hand) then return end
    local on = GetConVar("blsd_chands"):GetInt() == 1
    if on and IsValid(w) and weapons.IsBasedOn(w:GetClass(), "mg_base") and not w:GetViewModel().m_CHands.transcarmtopmwm then
        if IsValid(TRANSCARMTOPMWN_CMdl) then TRANSCARMTOPMWN_CMdl:Remove() end
        local wvm = w:GetViewModel()
        local ch = wvm.m_CHands
        local old = ch.RenderOverride
        local mod = {}
        if on and not ch.savee_transcarmtopmwm_bonesdata then
            ch.savee_transcarmtopmwm_bonesdata = {}
            for i = 0, p:GetBoneCount() - 1 do
                local n = p:GetBoneName(i)
                local nn = p:GetBoneName(p:GetBoneParent(i))
                if Check(ch, n, nn) then mod[i] = true end
            end
        end

        ch:AddCallback("BuildBonePositions", function(ent, numbones)
            local on = GetConVar("blsd_chands"):GetInt() == 1
            if not on then return end
            for i = 0, numbones - 1 do
                if not mod[i] then continue end
                local mat = ent:GetBoneMatrix(i)
                if not mat then continue end
                local scale = mat:GetScale()
                mat:Scale(Vector(myfunkinhugeval, myfunkinhugeval, myfunkinhugeval))
                ent:SetBoneMatrix(i, mat)
            end
        end)

        function ch:RenderOverride(flags)
            if not self:CanDraw() then return end
            local on = GetConVar("blsd_chands"):GetInt() == 1
            local tar = on and p or p:GetHands()
            self:SetModel(tar:GetModel())
            self:SetSkin(tar:GetSkin())
            for b = 0, tar:GetNumBodyGroups() do
                self:SetBodygroup(b, tar:GetBodygroup(b))
            end

            if VManip ~= nil then
                p:GetHands():SetParent(self:GetParent())
                p:GetHands():DrawModel(flags)
                self:DrawModel(flags)
            else
                self:DrawModel(flags)
            end
        end

        ch.transcarmtopmwm = true
    elseif w.IsTFAWeapon then
        if IsValid(TRANSCARMTOPMWN_CMdl) then TRANSCARMTOPMWN_CMdl:Remove() end
    end
end)
