AddCSLuaFile()

ENT.Base = "base_anim"
ENT.PrintName = "IED"

if SERVER then
    util.AddNetworkString("IEDMotionAlert")

    --
    -- Куда сдвигать точку взрыва, если заряд утоплен в геометрии.
    -- Порядок от «чуть вверх» к «вбок»: заряд чаще всего лежит на полу.
    --
    local UNSTICK = {
        Vector(0, 0, 6), Vector(0, 0, 12), Vector(0, 0, 20),
        Vector(10, 0, 6), Vector(-10, 0, 6), Vector(0, 10, 6), Vector(0, -10, 6),
    }

    --
    -- Точка, ОТ которой считается взрыв.
    --
    -- Не позиция заряда: он прилипает вплотную к поверхности (PhysicsCollide
    -- гасит физику и цепляет его к тому, во что попал), и его начало координат
    -- оказывается в толще браша. Движковый RadiusDamage на каждую цель делает
    -- трассу из точки взрыва и, если она не дошла, урон по этой цели просто не
    -- начисляет — из точки внутри стены не доходит НИ ОДНА. Взрыв при этом
    -- гремит, трясёт экран и оставляет копоть, а урона нет вовсе.
    --
    local function BlastOrigin(ent)
        local pos = ent:GetPos()

        if bit.band(util.PointContents(pos), CONTENTS_SOLID) == 0 then
            return pos + Vector(0, 0, 2)
        end

        for _, off in ipairs(UNSTICK) do
            local p = pos + off
            if bit.band(util.PointContents(p), CONTENTS_SOLID) == 0 then return p end
        end

        return pos + Vector(0, 0, 20)
    end

    -- На каких высотах над зарядом брать точку отсчёта взрыва.
    local BLAST_LIFTS = {2, 18, 36}

    --
    -- Свой радиусный урон вместо util.BlastDamage.
    --
    -- Движковый RadiusDamage решает «достаёт или нет» ОДНОЙ трассой: из одной
    -- точки взрыва в центр цели. Одна помеха на этой линии — порог, ступенька,
    -- ящик, карниз — и цель не получает НИЧЕГО, независимо от расстояния.
    --
    -- Замерено на ttt_warsaw_city_school, заряд на ровном полу, мишени в
    -- створе: на 0 юнитов урон 464, на 20 урон 458, на 45 РОВНО НОЛЬ, на 90
    -- снова 392. Ноль посередине — это край ступеньки, за который зацепилась
    -- единственная трасса. Со стороны это и есть «взорвалось под ногами, а я
    -- целый».
    --
    -- Поэтому перебираем СЕТКУ: три высоты источника (у пола, по колено, по
    -- пояс) на три точки цели (ноги, центр, макушка). Хватает одной свободной
    -- пары. Сплошную стену это не пробивает — там перекрыты все девять, — а
    -- пороги и ступеньки перестают выключать взрыв.
    --
    local function RadiusDamage(inflictor, attacker, src, radius, damage)
        if radius <= 0 then return end

        attacker = IsValid(attacker) and attacker or inflictor

        -- Источники, которые сами не в стене.
        local origins = {}
        for i = 1, #BLAST_LIFTS do
            local p = src + Vector(0, 0, BLAST_LIFTS[i] - 2)
            if bit.band(util.PointContents(p), CONTENTS_SOLID) == 0 then
                origins[#origins + 1] = p
            end
        end
        if #origins == 0 then origins[1] = src end

        for _, ent in ipairs(ents.FindInSphere(src, radius)) do
            if ent == inflictor or ent:IsWorld() then continue end

            local maxs = ent:OBBMaxs()
            local spots = {
                ent:WorldSpaceCenter(),
                ent:GetPos() + Vector(0, 0, math.max(8, maxs.z - 6)),
                ent:GetPos() + Vector(0, 0, 6),
            }

            local spot, from

            for o = 1, #origins do
                for i = 1, #spots do
                    local tr = util.TraceLine({
                        start = origins[o],
                        endpos = spots[i],
                        mask = MASK_SHOT,
                        filter = {inflictor, ent},
                    })

                    if not tr.Hit then spot, from = spots[i], origins[o] break end
                end

                if spot then break end
            end

            if not spot then continue end

            -- Спад линейный, как у движка: у самого заряда полный урон, на
            -- границе радиуса нулевой.
            local amount = damage * (1 - math.Clamp(src:Distance(spot) / radius, 0, 1))
            if amount < 1 then continue end

            local dir = (spot - from):GetNormalized()

            local dmg = DamageInfo()
            dmg:SetDamage(amount)
            dmg:SetDamageType(DMG_BLAST)
            dmg:SetAttacker(attacker)
            dmg:SetInflictor(inflictor)
            dmg:SetDamagePosition(src)
            dmg:SetDamageForce(dir * amount * 40)

            ent:TakeDamageInfo(dmg)
        end
    end

    function ENT:Initialize()
        self:SetModel("models/murdered/weapons/insurgency/w_ied.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(true)
        end
        self:SetCollisionGroup(1)
        self.ExplosionDamageMult = 1
        self.IsZBaseGrenade = true
    end

    function ENT:PhysicsCollide(data, col)
        if self.Connected then return end
        self.Connected = true

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Sleep()
            phys:EnableMotion(false)
        end

        if game.GetWorld() != data.HitEntity then
            self:SetParent(data.HitEntity)
        end
        self:SetAngles(data.HitNormal:Angle()+Angle(0,270,0))
    end

    function ENT:OnTakeDamage(dmg)
        if self.Activated then return end
        if dmg:GetDamage() > 5 then
            self:Explode()
        end
    end

    function ENT:Think()
        local par = self:GetParent()
        if IsValid(par) and (IsValid(par:GetPhysicsObject()) and par:GetPhysicsObject():IsMotionEnabled() or istable(par.Inventory)) then
            self:SetNoDraw(true)
        end

        local ply = self.PlayerOwner
        if IsValid(ply) then
            local targetFound = false
            for _, ent in pairs(ents.FindInSphere(self:GetPos(), 400)) do
                if (ent:IsPlayer() and ent:Alive() or MuR.IsAI(ent)) and ent:IsLineOfSightClear(self:GetPos()) and ent != ply then
                    targetFound = true
                    break
                end
            end

            if targetFound then
                net.Start("IEDMotionAlert")
                net.Send(ply)
            end
        end

        self:NextThink(CurTime()+0.2)
        return true
    end

    function ENT:Explode()
        self:SetParent(nil)
        timer.Simple(0.01, function()
            if !IsValid(self) then return end
            self.Activated = true
            self.Connected = true
            self:EmitSound(")murdered/weapons/other/ied_detonate_dist_0"..math.random(1,3)..".wav", 120, math.random(75,85))
            util.ScreenShake(self:GetPos(), 50, 25, 4, 2500)

            ParticleEffect("AC_rpg_explosion", self:GetPos(), Angle(0,0,0))
            ParticleEffect("AC_rpg_explosion_air", self:GetPos(), Angle(0,0,0))

            local att = self
            if IsValid(self.PlayerOwner) then
                att = self.PlayerOwner
            end

            local src = BlastOrigin(self)

            util.Decal("Scorch", self:GetPos(), self:GetPos()-Vector(0,0,8), self)

            --
            -- Инфликтор — САМ заряд, а не тот, кто его поставил.
            --
            -- Раньше в оба поля шёл игрок: у потребителей урона (sv_functions,
            -- ранения, список смертей) GetInflictor тогда возвращал человека, а
            -- не взрывчатку, и разбор «чем убило» врал. Атакующим он остаётся —
            -- за подрыв отвечает именно он.
            --
            RadiusDamage(self, att, src, 250*(self.ExplosionDamageMult*2), 500*self.ExplosionDamageMult)
            MuR:ApplyConcussion(src, "ied", att)
            MakeExplosionReverb(self:GetPos())
            self:Remove()
        end)
    end
else
    net.Receive("IEDMotionAlert", function()
        surface.PlaySound("buttons/button15.wav")

        local startTime = CurTime()
        local displayTime = 0.02
        local fadeTime = 0.4

        hook.Add("HUDPaint", "IEDMotionAlert", function()
            local elapsed = CurTime() - startTime
            local alpha = 255

            if elapsed > displayTime then
                local fadeProgress = (elapsed - displayTime) / fadeTime
                if fadeProgress >= 1 then
                    hook.Remove("HUDPaint", "IEDMotionAlert")
                    return
                end
                alpha = 255 * (1 - fadeProgress)
            end

            local text = "Motion Detected [IED]"
            local font = "MuR_Font2"

            surface.SetFont(font)
            local textW, textH = surface.GetTextSize(text)

            local boxW = textW + We(20)
            local boxH = textH + He(10)
            local x = ScrW() / 2 - boxW / 2
            local y = ScrH() /2 + He(200)

            surface.SetDrawColor(0, 0, 0, alpha * 0.78)
            surface.DrawRect(x, y, boxW, boxH)

            surface.SetDrawColor(255, 0, 0, alpha)
            surface.DrawOutlinedRect(x, y, boxW, boxH)

            surface.SetTextColor(255, 255, 255, alpha)
            surface.SetTextPos(x + We(10), y + He(5))
            surface.DrawText(text)
        end)
    end)
end
