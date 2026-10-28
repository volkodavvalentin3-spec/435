AddCSLuaFile()

SWEP.Base = "mur_loot_base"
SWEP.PrintName = "Medical Base"
SWEP.Slot = 5
SWEP.Spawnable = false

SWEP.TPIKForce = true
SWEP.UsableWhileProne = true

SWEP.HealTimeSelf = 2
SWEP.HealTimeTarget = 2

SWEP.AnimTable = {
    idle = ACT_VM_IDLE,
    use_self = ACT_VM_PRIMARYATTACK,
    use_mate = ACT_VM_SECONDARYATTACK,
    holster = ACT_VM_HOLSTER,
    draw = ACT_VM_DRAW
}

SWEP.AnimFallback = {
    idle = ACT_VM_IDLE,
    draw = ACT_VM_DRAW,
    holster = ACT_VM_HOLSTER,
    bandage = ACT_VM_PRIMARYATTACK,
    medkit = ACT_VM_PRIMARYATTACK,
    genetherapy = ACT_VM_PRIMARYATTACK,
    give = ACT_VM_SECONDARYATTACK
}

SWEP.SoundTable = {}

SWEP.HealDist = 72

SWEP.PhraseSelf = "loot_medic_left"
SWEP.PhraseTarget = "loot_medic_right"

function SWEP:SetupDataTables()
    self:NetworkVar("Int", 0, "HealState")
    self:NetworkVar("Float", 0, "HealStart")
end

function SWEP:CustomInit()
    self:SetHealState(0)
    self:SetHealStart(0)
    self.PlayedSounds = {}
end

function SWEP:FindHealTarget()
    local owner = self:GetOwner()
    if not IsValid(owner) then return NULL end

    local tr = util.TraceLine({
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * self.HealDist,
        filter = owner,
        mask = MASK_SHOT_HULL
    })

    local tar = tr.Entity
    if IsValid(tar) and tar.isRDRag and IsValid(tar.Owner) then tar = tar.Owner end
    if IsValid(tar) and tar:IsPlayer() then return tar end

    local origin = IsValid(owner:GetRD()) and owner:GetRD():WorldSpaceCenter() or owner:GetShootPos()
    local best, bestDist = NULL, self.HealDist * self.HealDist

    for _, ply in player.Iterator() do
        if ply == owner or not ply:Alive() then continue end

        local ref = IsValid(ply:GetRD()) and ply:GetRD():WorldSpaceCenter() or ply:WorldSpaceCenter()
        local dist = origin:DistToSqr(ref)
        if dist < bestDist then
            best, bestDist = ply, dist
        end
    end

    return best
end

function SWEP:PlayAnimation(anim, targetDuration, noRetry)
    if not IsValid(self) or not anim then return end
    if isnumber(anim) then
        self:SendWeaponAnim(anim)
    elseif isstring(anim) then
        if SERVER then return end

        local ow = self:GetOwner()
        if not IsValid(ow) or not ow:IsPlayer() then return end

        local vm = ow:GetViewModel()
        if not IsValid(vm) then return end

        if vm:GetModel() != self.ViewModel then
            if noRetry then return end
            timer.Simple(0, function()
                if IsValid(self) and IsValid(ow) and ow:Alive() and ow:GetActiveWeapon() == self then
                    self:PlayAnimation(anim, targetDuration, true)
                end
            end)
            return
        end

        local seq = vm:LookupSequence(anim)
        if seq == -1 then
            local fallback = self.AnimFallback and self.AnimFallback[anim]
            if fallback then self:SendWeaponAnim(fallback) end
            return
        end

        vm:ResetSequence(seq)
        vm:SetCycle(0)

        local rate = 1
        if targetDuration and targetDuration > 0 then
            local seqDur = vm:SequenceDuration(seq)
            if seqDur and seqDur > 0 then
                rate = math.Clamp(seqDur / targetDuration, 0.05, 8)
            end
        end
        vm:SetPlaybackRate(rate)

        self.LastVMSequence = seq
        self.LastVMRate = rate
    end
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType or "slam")
    self:PlayAnimation(self.AnimTable.draw or ACT_VM_DRAW)
    self:StopHeal()
    return true
end

function SWEP:Holster()
    self:StopHeal()
    return true
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.1)
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.1)
end

function SWEP:StopHeal()
    if self:GetHealState() != 0 then
        self:SetHealState(0)
        self:SetHealStart(0)
        self:PlayAnimation(self.AnimTable.idle or ACT_VM_IDLE)
        self.PlayedSounds = {}
    end

    local last = self.LastHealTarget
    if IsValid(last) then
        last:SetNW2Float("MuR.HealEnd", 0)
        last:SetNW2Entity("MuR.Healer", NULL)
    end
    self.LastHealTarget = nil
end

function SWEP:StartHeal(state)
    local owner = self:GetOwner()

    if self:GetHealState() == state then return end

    if state == 2 then
        local tar = self:FindHealTarget()

        if not IsValid(tar) or not tar:IsPlayer() then return end
        if self.CanHeal and not self:CanHeal(tar) then return end
    else
        if self.CanHeal and not self:CanHeal(owner) then return end
    end

    self:SetHealState(state)
    self:SetHealStart(CurTime())
    self.PlayedSounds = {}

    local anim = (state == 1) and self.AnimTable.use_self or self.AnimTable.use_mate
    self:PlayAnimation(anim, (state == 1) and self.HealTimeSelf or self.HealTimeTarget)

    self:CheckSounds(0)
end

function SWEP:CheckSounds(elapsed)
    if not self.SoundTable then return end
    if CLIENT then return end

    for time, snd in pairs(self.SoundTable) do
        local t = tonumber(time)
        if t and elapsed >= t and not self.PlayedSounds[time] then
            self:GetOwner():EmitSound("<"..snd, 60, math.random(90,110))
            self.PlayedSounds[time] = true
        end
    end
end

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local state = self:GetHealState()
    local startTime = self:GetHealStart()
    local curTime = CurTime()

    if state == 0 then
        if owner:KeyDown(IN_ATTACK) then
            self:StartHeal(1)
        elseif owner:KeyDown(IN_ATTACK2) then
            self:StartHeal(2)
        end
    else
        local isSelf = (state == 1)
        local key = isSelf and IN_ATTACK or IN_ATTACK2
        local duration = isSelf and self.HealTimeSelf or self.HealTimeTarget

        if not isSelf then
            local tar = self:FindHealTarget()
            if not IsValid(tar) or not tar:IsPlayer() then
                self:StopHeal()
                return
            end
            self.CurrentTarget = tar
        else
            self.CurrentTarget = owner
        end

        if not owner:KeyDown(key) then
            self:StopHeal()
            return
        end

        local elapsed = curTime - startTime
        self:CheckSounds(elapsed)

        local tgt = self.CurrentTarget
        if IsValid(tgt) then
            tgt:SetNW2Float("MuR.HealStart", startTime)
            tgt:SetNW2Float("MuR.HealEnd", curTime + math.max(duration - elapsed, 0))
            tgt:SetNW2Entity("MuR.Healer", owner)
            self.LastHealTarget = tgt
        end

        if elapsed >= duration then
            if SERVER then
                local tgt = self.CurrentTarget
                local wasDying = IsValid(tgt) and tgt.IsDying and tgt:IsDying()
                self:FinishHeal(tgt, isSelf)

                if wasDying and self.CanRevive and IsValid(tgt) and tgt:IsDying() then
                    tgt:StabilizeDying(owner)
                end
            end
            self:StopHeal()
        end
    end
end

function SWEP:FinishHeal(target, isSelf)
end

if CLIENT then
    function SWEP:DrawHealProgress(state)
        local start = self:GetHealStart()
        if not start or start <= 0 then return end

        local isSelf = state == 1
        local duration = isSelf and self.HealTimeSelf or self.HealTimeTarget
        if not duration or duration <= 0 then return end

        local frac = math.Clamp((CurTime() - start) / duration, 0, 1)

        local w = He(280)
        local h = He(6)
        local x = ScrW() / 2 - w / 2
        local y = ScrH() - He(140)

        draw.RoundedBox(4, x - He(3), y - He(3), w + He(6), h + He(6), Color(0, 0, 0, 170))
        draw.RoundedBox(2, x, y, w * frac, h, isSelf and Color(120, 190, 255) or Color(120, 230, 130))

        local label = isSelf and MuR.Language["med_healing_self"] or MuR.Language["med_healing_target"]
        local left = math.max(duration * (1 - frac), 0)
        draw.SimpleText(string.format("%s %d%% (%.1fs)", label or "", math.floor(frac * 100), left), "MuR_FontDef", ScrW() / 2, y - He(18), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    function SWEP:DrawHUD()
        local state = self:GetHealState()

        if state != 0 then
            self:DrawHealProgress(state)
        end

        local a = self.HintAlpha or 0
        local want = state == 0 and 255 or 0

        a = math.Approach(a, want, RealFrameTime() * 700)
        self.HintAlpha = a

        if a <= 0 then return end

        local col = ColorAlpha(color_white, a)

        draw.SimpleText(MuR.Language[self.PhraseSelf] or self.PhraseSelf, "MuR_Font1", ScrW()/2, ScrH()-He(100), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(MuR.Language[self.PhraseTarget] or self.PhraseTarget, "MuR_Font1", ScrW()/2, ScrH()-He(85), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    hook.Add("HUDPaint", "MuR_BeingHealed", function()
        local lp = LocalPlayer()
        if not IsValid(lp) or not lp:Alive() then return end

        local endTime = lp:GetNW2Float("MuR.HealEnd", 0)
        if endTime <= CurTime() then return end

        local healer = lp:GetNW2Entity("MuR.Healer")
        if healer == lp then return end

        local startTime = lp:GetNW2Float("MuR.HealStart", 0)
        local total = endTime - startTime
        local frac = total > 0 and math.Clamp((CurTime() - startTime) / total, 0, 1) or 0

        local w = He(240)
        local h = He(5)
        local x = ScrW() / 2 - w / 2
        local y = ScrH() / 2 + He(60)

        draw.RoundedBox(4, x - He(3), y - He(3), w + He(6), h + He(6), Color(0, 0, 0, 170))
        draw.RoundedBox(2, x, y, w * frac, h, Color(120, 230, 130))

        draw.SimpleText(MuR.Language["med_being_healed"] or "", "MuR_FontDef", ScrW() / 2, y - He(16), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
end
