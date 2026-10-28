AddCSLuaFile()

SWEP.Base = "mur_other_base"
SWEP.PrintName = "Surveillance Probe"

SWEP.VElements = {
	["main"] = { type = "Model", model = "models/props_canal/mattpipe.mdl", bone = "Base", rel = "", pos = Vector(-0.519, -2.597, 7.791), angle = Angle(3.506, -94.676, 0), size = Vector(0.5, 0.5, 0.5), color = Color(255, 255, 255, 255), surpresslightning = false, material = "mechanics/metal2", skin = 0, bodygroup = {} },
	["monitor"] = { type = "Model", model = "models/props_lab/monitor01b.mdl", bone = "Base", rel = "", pos = Vector(1.2, -2.401, 2.25), angle = Angle(-85.325, 8.182, -85.325), size = Vector(0.2, 0.2, 0.2), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} }
}
SWEP.WElements = {
	["main"] = { type = "Model", model = "models/props_canal/mattpipe.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "", pos = Vector(18, 1, -7), angle = Angle(75, 0, 180), size = Vector(0.95, 0.95, 0.95), color = Color(255, 255, 255, 255), surpresslightning = false, material = "mechanics/metal2", skin = 0, bodygroup = {} },
	["monitor"] = { type = "Model", model = "models/props_lab/monitor01b.mdl", bone = "ValveBiped.Bip01_R_Hand", rel = "", pos = Vector(8, 3.635, -2.597), angle = Angle(0, 180, 180), size = Vector(0.4, 0.4, 0.4), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bodygroup = {} }
}

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Slot = 3
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.HoldType = "ar2"
SWEP.ViewModelFOV = 60
SWEP.ViewModelFlip = false
SWEP.UseHands = false
SWEP.ViewModel = "models/weapons/v_irifle.mdl"
SWEP.WorldModel = "models/weapons/w_irifle.mdl"
SWEP.ShowViewModel = false
SWEP.ShowWorldModel = false
SWEP.ViewModelBoneMods = {
	["Base"] = { scale = Vector(0.009, 0.009, 0.009), pos = Vector(-2.037, 3.888, 0), angle = Angle(5.556, -7.778, 5.556) }
}

SWEP.ProbeActive = false
SWEP.ProbeEntity = nil
SWEP.MaxProbeDistance = 120
SWEP.ProbePos = Vector(0, 0, 0)
SWEP.ProbeAng = Angle(0, 0, 0)

function SWEP:CustomInit()
    self.ProbeActive = false
    self.ProbePlayerAng = Angle(0,0,0)
    self:SetHoldType("ar2")

    if CLIENT then
        self.ScanlineTexture = surface.GetTextureID("effects/tvscreen_noise002a")
        self.StaticTexture = surface.GetTextureID("effects/combine_binocoverlay")
        self.NoiseOffset = 0
        self.GlitchTime = 0
        self.ProbeLight = nil
    end
end

function SWEP:GetValidProbeTarget()
    local owner = self:GetOwner()
    if not IsValid(owner) then return nil, nil, nil end

    local trace = {}
    trace.start = owner:EyePos()
    trace.endpos = trace.start + owner:GetAimVector() * self.MaxProbeDistance
    trace.filter = owner

    local tr = util.TraceLine(trace)

    if not tr.Hit then return nil, nil, nil end
    if tr.HitPos:Distance(owner:GetPos()) > self.MaxProbeDistance then return nil, nil, nil end

    local isDoor = IsValid(tr.Entity) and string.find(tr.Entity:GetClass(), "_door")
    local isWall = tr.HitWorld and math.abs(tr.HitNormal.z) < 0.3

    if isDoor then
        return "door", tr, tr.Entity
    elseif isWall then
        local hitPoint = tr.HitPos
        local normal = tr.HitNormal
        local right = owner:GetAimVector():Cross(Vector(0, 0, 1)):GetNormalized()

        local checkDist = 25

        local trLeft = util.TraceLine({
            start = hitPoint + normal * 5,
            endpos = hitPoint + normal * 5 + right * checkDist,
            filter = owner
        })

        local trRight = util.TraceLine({
            start = hitPoint + normal * 5,
            endpos = hitPoint + normal * 5 - right * checkDist,
            filter = owner
        })

        local leftDist = trLeft.Fraction * checkDist
        local rightDist = trRight.Fraction * checkDist

        if leftDist > 15 or rightDist > 15 then
            return "corner", tr, nil
        end
    end

    return nil, nil, nil
end

function SWEP:PrimaryAttack()
    if SERVER and not self.ProbeActive then
        local targetType, tr, ent = self:GetValidProbeTarget()
        local owner = self:GetOwner()

        if targetType == "door" then
            local pos = ent:WorldSpaceCenter()
            pos.z = owner:GetPos().z + 8
            self:DeployProbe(pos, owner:GetAimVector(), "door")

            net.Start("ProbeActivated")
            net.WriteBool(true)
            net.WriteString("door")
            net.Send(owner)
            self:SetHoldType("passive")
            owner:ScreenFade(SCREENFADE.IN, Color(0,0,0,255), 0.5, 0)
        elseif targetType == "corner" then
            local forward = owner:GetAimVector()
            local right = forward:Cross(Vector(0, 0, 1)):GetNormalized()

            local leftTrace = util.TraceLine({
                start = tr.HitPos,
                endpos = tr.HitPos - right * 30,
                mask = MASK_SOLID_BRUSHONLY
            })

            local rightTrace = util.TraceLine({
                start = tr.HitPos,
                endpos = tr.HitPos + right * 30,
                mask = MASK_SOLID_BRUSHONLY
            })

            local peekDir = leftTrace.Fraction > rightTrace.Fraction and -right or right
            local cornerPos = tr.HitPos - tr.HitNormal * -2

            self:DeployProbe(cornerPos, peekDir, "corner")

            net.Start("ProbeActivated")
            net.WriteBool(true)
            net.WriteString("corner")
            net.Send(owner)
            self:SetHoldType("passive")
            owner:ScreenFade(SCREENFADE.IN, Color(0,0,0,255), 0.5, 0)
        end
    elseif SERVER and self.ProbeActive then
        self:RetrieveProbe()

        net.Start("ProbeActivated")
        net.WriteBool(false)
        net.WriteString("")
        net.Send(self:GetOwner())
        self:SetHoldType("ar2")
        self:GetOwner():ScreenFade(SCREENFADE.IN, Color(0,0,0,255), 0.5, 0)
        self:GetOwner():SetEyeAngles(self.ProbePlayerAng)
    end

    self:SetNextPrimaryFire(CurTime() + 0.5)
end

function SWEP:SecondaryAttack()
end

function SWEP:DeployProbe(pos, normal, probeType)
    local probe = ents.Create("prop_physics")
    probe:SetModel("models/props_lab/huladoll.mdl")

    local ang = normal:Angle()
    ang:RotateAroundAxis(ang:Right(), 90)

    probe:SetPos(pos + normal * 8)
    probe:SetAngles(ang)
    probe:SetModelScale(0.5, 0)
    probe:Spawn()

    local phys = probe:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    probe.Owner = self:GetOwner()
    probe:SetNoDraw(true)
    probe.ProbeType = probeType

    self.ProbeEntity = probe
    self.ProbeActive = true
    self.ProbePos = probe:GetPos() + probe:GetForward() * 3
    self.ProbeAng = probe:GetAngles()
    self.ProbePlayerAng = self:GetOwner():EyeAngles()
end

function SWEP:RetrieveProbe()
    if IsValid(self.ProbeEntity) then
        self.ProbeEntity:Remove()
    end

    self.ProbeEntity = nil
    self.ProbeActive = false
end

function SWEP:CustomHolster()
    if SERVER and self.ProbeActive then
        self:RetrieveProbe()

        net.Start("ProbeActivated")
        net.WriteBool(false)
        net.WriteString("")
        net.Send(self:GetOwner())
    end
    return true
end

function SWEP:OnRemove()
    if SERVER and self.ProbeActive then
        self:RetrieveProbe()

        if IsValid(self:GetOwner()) then
            net.Start("ProbeActivated")
            net.WriteBool(false)
            net.WriteString("")
            net.Send(self:GetOwner())
        end
    end

    if CLIENT and IsValid(self.ProbeLight) then
        self.ProbeLight:Remove()
    end
end

function SWEP:OnDrop()
    if SERVER and self.ProbeActive then
        self:RetrieveProbe()

        if IsValid(self:GetOwner()) then
            net.Start("ProbeActivated")
            net.WriteBool(false)
            net.WriteString("")
            net.Send(self:GetOwner())
        end
    end
end

function SWEP:Think()
    if SERVER and self.ProbeActive then
        if not IsValid(self.ProbeEntity) or self:GetOwner():GetPos():Distance(self.ProbeEntity:GetPos()) > self.MaxProbeDistance or self:GetNoDraw() then
            self:RetrieveProbe()

            net.Start("ProbeActivated")
            net.WriteBool(false)
            net.WriteString("")
            net.Send(self:GetOwner())
            return
        end

        self.ProbePos = self.ProbeEntity:GetPos() + self.ProbeEntity:GetForward() * 8
        self.ProbeAng = self.ProbeEntity:GetAngles()

        net.Start("ProbePosition")
        net.WriteVector(self.ProbePos)
        net.WriteAngle(self.ProbeAng)
        net.Send(self:GetOwner())
    end
end

if SERVER then
    util.AddNetworkString("ProbeActivated")
    util.AddNetworkString("ProbePosition")
end

if CLIENT then
    local probeActive = false
    local probePos = Vector(0, 0, 0)
    local probeAng = Angle(0, 0, 0)
    local probeType = ""

    net.Receive("ProbeActivated", function()
        probeActive = net.ReadBool()
        probeType = net.ReadString()
        if probeActive then
            surface.PlaySound("items/nvg_on.wav")
        else
            surface.PlaySound("items/nvg_off.wav")
        end
    end)

    net.Receive("ProbePosition", function()
        probePos = net.ReadVector()
        probeAng = Angle(-10, net.ReadAngle().y, 0)
    end)

    hook.Add("CalcView", "SurveillanceProbeView", function(ply, origin, angles, fov)
        local activeWeapon = ply:GetActiveWeapon()
        if not IsValid(activeWeapon) or activeWeapon:GetClass() ~= "mur_doorlooker" then
            return
        end

        if probeActive then
            local view = {}
            view.origin = probePos
            view.angles = Angle(angles.x/4, angles.y, 0)
            view.fov = 50
            view.drawviewer = true
            view.znear = 1

            return view
        end
    end)

    hook.Add("PreDrawHalos", "ProbeLight", function()
        local ply = LocalPlayer()
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "mur_doorlooker" then return end

        if probeActive then
            local dlight = DynamicLight(ply:EntIndex())
            if dlight then
                dlight.pos = probePos
                dlight.r = 180
                dlight.g = 200
                dlight.b = 220
                dlight.brightness = 1
                dlight.decay = 1024
                dlight.size = 256
                dlight.dietime = CurTime() + 0.1
            end
        end
    end)

    hook.Add("RenderScreenspaceEffects", "ProbeGrayscale", function()
        local ply = LocalPlayer()
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "mur_doorlooker" or not probeActive then return end

        local tab = {}
        tab["$pp_colour_addr_to_screen"] = 0
        tab["$pp_colour_brightness"] = 0.2
        tab["$pp_colour_contrast"] = 1
        tab["$pp_colour_colour"] = 0
        tab["$pp_colour_mulr"] = 0
        tab["$pp_colour_mulg"] = 0
        tab["$pp_colour_mulb"] = 0

        DrawColorModify(tab)
    end)

    function SWEP:DrawHUD()
        local w, h = ScrW(), ScrH()

        if not probeActive then
            local targetType, tr, ent = self:GetValidProbeTarget()

            if targetType then
                local screenPos = tr.HitPos:ToScreen()
                local pulse = math.sin(CurTime() * 4) * 0.3 + 0.7
                local col = Color(100, 255, 100, 200 * pulse)

                surface.SetDrawColor(col)
                local size = 20
                surface.DrawLine(screenPos.x - size, screenPos.y, screenPos.x - size/2, screenPos.y)
                surface.DrawLine(screenPos.x + size/2, screenPos.y, screenPos.x + size, screenPos.y)
                surface.DrawLine(screenPos.x, screenPos.y - size, screenPos.x, screenPos.y - size/2)
                surface.DrawLine(screenPos.x, screenPos.y + size/2, screenPos.x, screenPos.y + size)

                local text = targetType == "door" and "UNDER DOOR" or "CORNER PEEK"
                draw.SimpleText(text, "DermaDefault", screenPos.x, screenPos.y + He(50), col, TEXT_ALIGN_CENTER)
                draw.SimpleText("[LMB] DEPLOY", "DermaDefault", screenPos.x, screenPos.y + He(65), Color(200, 200, 200, 200 * pulse), TEXT_ALIGN_CENTER)
            end
            return
        end

        self.NoiseOffset = self.NoiseOffset + FrameTime() * 100
        self.ScanOffset = (self.ScanOffset or 0) + FrameTime() * 200

        draw.RoundedBox(0, 0, 0, w, h, Color(5, 8, 5, 20))

        local vignette = 100
        for i = 0, vignette do
            local alpha = (1 - i / vignette) * 180
            surface.SetDrawColor(0, 0, 0, alpha)
            surface.DrawRect(0, i, w, 1)
            surface.DrawRect(0, h - i, w, 1)
            surface.DrawRect(i, 0, 1, h)
            surface.DrawRect(w - i, 0, 1, h)
        end

        surface.SetDrawColor(15, 20, 15, 60)
        for y = 0, h, 2 do
            surface.DrawRect(0, y, w, 1)
        end

        local scanY = (self.ScanOffset % (h + 50)) - 25
        for i = 0, 20 do
            local lineY = scanY + i
            local alpha = 80 - math.abs(i - 10) * 8
            if alpha > 0 and lineY > 0 and lineY < h then
                surface.SetDrawColor(100, 120, 100, alpha)
                surface.DrawRect(0, lineY, w, 1)
            end
        end

        if math.random(1, 150) == 1 then
            self.GlitchTime = CurTime() + math.Rand(0.02, 0.08)
            self.GlitchIntensity = math.random(1, 3)
        end

        if CurTime() < self.GlitchTime then
            for i = 1, self.GlitchIntensity do
                local glitchY = math.random(0, h)
                local glitchH = math.random(1, 4)
                local offset = math.random(-15, 15)

                surface.SetDrawColor(120, 140, 120, 150)
                surface.DrawRect(offset, glitchY, w, glitchH)

                surface.SetDrawColor(80, 100, 80, 80)
                surface.DrawRect(-offset, glitchY + math.random(-30, 30), w, 1)
            end
        end

        local borderSize = 25
        surface.SetDrawColor(10, 12, 10, 220)
        surface.DrawRect(0, 0, w, borderSize)
        surface.DrawRect(0, h - borderSize, w, borderSize)
        surface.DrawRect(0, 0, borderSize, h)
        surface.DrawRect(w - borderSize, 0, borderSize, h)

        surface.SetDrawColor(60, 70, 60, 255)
        surface.DrawOutlinedRect(borderSize, borderSize, w - borderSize * 2, h - borderSize * 2, 2)

        local textCol = Color(180, 190, 180, 230)
        local dimCol = Color(120, 130, 120, 180)

        draw.SimpleText("◉ REC", "DermaDefaultBold", borderSize + 15, borderSize + 8, math.floor(CurTime() * 2) % 2 == 0 and Color(200, 80, 80, 255) or Color(100, 40, 40, 255))

        local time = os.date("%H:%M:%S")
        draw.SimpleText(time, "DermaDefault", w - borderSize - 15, borderSize + 8, dimCol, TEXT_ALIGN_RIGHT)

        draw.SimpleText("SURVEILLANCE PROBE", "DermaDefaultBold", w / 2, borderSize + 8, textCol, TEXT_ALIGN_CENTER)

        local dist = math.Round(LocalPlayer():GetPos():Distance(probePos))
        local modeText = probeType == "door" and "MODE: UNDER-DOOR" or "MODE: CORNER-PEEK"
        draw.SimpleText(modeText, "DermaDefault", borderSize + 15, h - borderSize - 22, dimCol)
        draw.SimpleText("DIST: " .. dist .. "u", "DermaDefault", w - borderSize - 15, h - borderSize - 22, dimCol, TEXT_ALIGN_RIGHT)
        draw.SimpleText("[LMB] RETRIEVE", "DermaDefault", w / 2, h - borderSize - 22, dimCol, TEXT_ALIGN_CENTER)

        local cx, cy = w / 2, h / 2
        local crossSize = 15
        local crossGap = 5
        surface.SetDrawColor(180, 190, 180, 150)
        surface.DrawRect(cx - crossSize, cy, crossSize - crossGap, 1)
        surface.DrawRect(cx + crossGap, cy, crossSize - crossGap, 1)
        surface.DrawRect(cx, cy - crossSize, 1, crossSize - crossGap)
        surface.DrawRect(cx, cy + crossGap, 1, crossSize - crossGap)

        surface.SetDrawColor(80, 90, 80, 100)
        surface.DrawOutlinedRect(cx - 80, cy - 80, 160, 160, 1)

        local cornerLen = 15
        surface.SetDrawColor(150, 160, 150, 200)
        surface.DrawRect(cx - 80, cy - 80, cornerLen, 2)
        surface.DrawRect(cx - 80, cy - 80, 2, cornerLen)
        surface.DrawRect(cx + 80 - cornerLen, cy - 80, cornerLen, 2)
        surface.DrawRect(cx + 78, cy - 80, 2, cornerLen)
        surface.DrawRect(cx - 80, cy + 78, cornerLen, 2)
        surface.DrawRect(cx - 80, cy + 80 - cornerLen, 2, cornerLen)
        surface.DrawRect(cx + 80 - cornerLen, cy + 78, cornerLen, 2)
        surface.DrawRect(cx + 78, cy + 80 - cornerLen, 2, cornerLen)
    end

    function SWEP:CalcViewModelView(vm, oldPos, oldAng, pos, ang)
        if probeActive then
            return Vector(0, 0, -10000), ang
        end
    end
end

SWEP.Category = "Bloodshed - Police"
