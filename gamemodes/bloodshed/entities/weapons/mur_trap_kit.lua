AddCSLuaFile()

SWEP.Base = "mur_loot_base"

SWEP.PrintName = "Trap Constructor"
SWEP.Author = "Hari"
SWEP.Category = "Bloodshed - Illegal"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Slot = 4
SWEP.SlotPos = 3
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.DrawWeaponInfoBox = false

SWEP.ViewModel = "models/murdered/v_item_pda.mdl"
SWEP.WorldModel = "models/props_lab/clipboard.mdl"
SWEP.ViewModelFOV = 100
SWEP.ViewModelPos = Vector(0, 0, -2)
SWEP.ViewModelAng = Angle(0, 0, 0)
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.2

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 0.6

SWEP.HoldType = "slam"
SWEP.TPIKForce = true

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

--[[ ------------------------------------------------------------------
	Раскладной планшет: та же схема анимаций, что у химического планшета —
	корпус раскрывается вместе с появлением интерфейса.
------------------------------------------------------------------ ]]--

if SERVER then
	util.AddNetworkString("mur_trap_anim")

	net.Receive("mur_trap_anim", function(_, ply)
		local isOpen = net.ReadBool()
		local wep = ply:GetActiveWeapon()

		if not IsValid(wep) or wep:GetClass() ~= "mur_trap_kit" then return end

		if isOpen then
			if wep.OpenAnim then wep:OpenAnim() end
		else
			if wep.CloseAnim then wep:CloseAnim() end
		end
	end)
end

function SWEP:Deploy()
	self.OpenedAnim = true
	self:CloseAnim()
	self:SetHoldType(self.HoldType)

	return true
end

function SWEP:CloseAnim()
	if not self.OpenedAnim then return end

	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	local vm = ply:GetViewModel()
	if IsValid(vm) then
		vm:SendViewModelMatchingSequence(vm:SelectWeightedSequence(ACT_VM_HOLSTER))
	end

	self.OpenedAnim = false

	if CLIENT then
		net.Start("mur_trap_anim")
		net.WriteBool(false)
		net.SendToServer()
		surface.PlaySound("murdered/radio/off.mp3")
	end
end

function SWEP:OpenAnim()
	if self.OpenedAnim then return end

	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	local vm = ply:GetViewModel()
	if IsValid(vm) then
		vm:SendViewModelMatchingSequence(vm:SelectWeightedSequence(ACT_VM_DRAW))
	end

	self.OpenedAnim = true

	if CLIENT then
		net.Start("mur_trap_anim")
		net.WriteBool(true)
		net.SendToServer()
		surface.PlaySound("murdered/radio/start.mp3")
	end
end

function SWEP:Holster()
	if CLIENT and IsValid(MuR.TrapMenu) then
		MuR.TrapMenu:Close()
	end

	self:CloseAnim()

	return true
end

--[[ ------------------------------------------------------------------
	ЛКМ удерживается — установка идёт с прогрессом на сервере.
------------------------------------------------------------------ ]]--

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	-- Само действие ведёт Think: здесь только предупреждение о пустых руках,
	-- с паузой, иначе автоогонь зальёт экран уведомлениями.
	if SERVER and not ply.MuR_TrapBlueprint and (self.NextWarn or 0) < CurTime() then
		self.NextWarn = CurTime() + 2.5
		MuR.Traps:Notify(ply, "trap_err_nodevice")
	end
end

-- ПКМ открывает конструктор, а во время изготовления — отменяет его.
function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

	if not CLIENT then return end

	if LocalPlayer():GetNW2Float("MuR_TrapAssembleEnd", 0) > CurTime() then
		net.Start("MuR.TrapCancel")
		net.SendToServer()
		return
	end

	RunConsoleCommand("mur_open_traps")
end

-- R: радиодетонация всех ловушек с радиовзрывателем.
function SWEP:Reload()
	if not IsFirstTimePredicted() then return end

	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	if (self.NextRemote or 0) > CurTime() then return end
	self.NextRemote = CurTime() + 1

	if SERVER then
		MuR.Traps:DetonateRemote(ply)
	end
end

function SWEP:Think()
	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	if SERVER then
		-- Think крутится каждый тик: без этой проверки не догруженная серверная
		-- часть залила бы консоль ошибками вместо одной.
		if not MuR.Traps or not MuR.Traps.PlantThink then return end

		MuR.Traps:PlantThink(ply, ply:KeyDown(IN_ATTACK))
		return
	end

	if ply ~= LocalPlayer() then return end

	-- Планшет раскрыт ровно столько, сколько открыт интерфейс.
	if IsValid(MuR.TrapMenu) then
		self:OpenAnim()
	else
		self:CloseAnim()
	end
end

--[[ ------------------------------------------------------------------
	Клиент: раскрытие вьюмодели и HUD трёх стадий
------------------------------------------------------------------ ]]--

if not CLIENT then return end

local lastAngles = Angle(0, 0, 0)
local lastPos = Vector(0, 0, 0)

function SWEP:CalcViewModelView(vm, oldEyePos, oldEyeAng, eyePos, eyeAng)
	if not IsValid(vm) then return end

	local pos, viewAngles, fov = oldEyePos, oldEyeAng, self.ViewModelFOV
	local seqAct = vm:GetSequenceActivity(vm:GetSequence())

	if seqAct == ACT_VM_DRAW then
		lastAngles = LerpAngle(FrameTime() * 5, lastAngles, Angle(-20, 0, 0))
		viewAngles:Add(lastAngles)

		lastPos = LerpVector(FrameTime() * 5, lastPos, Vector(-3, 0, 1))
	elseif seqAct == ACT_VM_HOLSTER then
		lastAngles = LerpAngle(FrameTime() * 5, lastAngles, Angle(0, 0, 0))
		viewAngles:Add(lastAngles)

		lastPos = LerpVector(FrameTime() * 5, lastPos, Vector(0, 0, 0))
	else
		return pos, viewAngles, fov
	end

	pos = pos + viewAngles:Forward() * lastPos.x + viewAngles:Right() * lastPos.y + viewAngles:Up() * lastPos.z

	return pos, viewAngles, fov
end

local function He(x) return x * (ScrH() / 1080) end

local function bar(x, y, w, h, frac, col)
	surface.SetDrawColor(0, 0, 0, 190)
	surface.DrawRect(x, y, w, h)

	surface.SetDrawColor(col)
	surface.DrawRect(x, y, w * math.Clamp(frac, 0, 1), h)

	surface.SetDrawColor(col.r, col.g, col.b, 90)
	surface.DrawOutlinedRect(x, y, w, h)
end

function SWEP:DrawHUD()
	if MuR:GetClient("blsd_nohud") then return end

	local ply = LocalPlayer()
	local lang = MuR.Language or {}
	local cx, cy = ScrW() / 2, ScrH() / 2

	-- Стадия 2: изготовление.
	local aEnd = ply:GetNW2Float("MuR_TrapAssembleEnd", 0)

	if aEnd > CurTime() then
		local aStart = ply:GetNW2Float("MuR_TrapAssembleStart", 0)
		local frac = (CurTime() - aStart) / math.max(aEnd - aStart, 0.01)

		draw.SimpleText(lang["trap_hud_assembling"] or "ASSEMBLING", "MuR_Font1",
			cx, cy + He(70), Color(0, 255, 136), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		bar(cx - He(120), cy + He(84), He(240), He(10), frac, Color(0, 255, 136))

		draw.SimpleText(math.ceil(aEnd - CurTime()) .. (lang["trap_hud_seconds"] or "s"), "MuR_Font1",
			cx, cy + He(106), Color(136, 255, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText(lang["trap_hud_cancel"] or "RMB - cancel", "MuR_Font1",
			cx, cy + He(126), Color(255, 170, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		return
	end

	-- Стадия 3.5: растяжка поставлена, но второй конец ещё висит.
	if ply:GetNW2Bool("MuR_TrapAnchoring", false) then
		draw.SimpleText(lang["trap_hud_anchor"] or "ANCHOR THE WIRE", "MuR_Font1",
			cx, cy + He(40), Color(255, 170, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText(lang["trap_hud_anchor_hint"] or "Aim at a surface and press LMB", "MuR_Font1",
			cx, cy + He(58), Color(136, 255, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		return
	end

	-- Стадия 3: установка удержанием.
	local pEnd = ply:GetNW2Float("MuR_TrapPlantEnd", 0)

	if pEnd > CurTime() then
		local pStart = ply:GetNW2Float("MuR_TrapPlantStart", 0)
		local frac = (CurTime() - pStart) / math.max(pEnd - pStart, 0.01)

		draw.SimpleText(lang["trap_hud_planting"] or "PLANTING", "MuR_Font1",
			cx, cy + He(40), Color(255, 170, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		bar(cx - He(90), cy + He(54), He(180), He(8), frac, Color(255, 170, 0))

		return
	end

	local lines = {
		lang["trap_kit_hint_1"] or "Hold LMB - Plant device",
		lang["trap_kit_hint_2"] or "RMB - Open constructor",
		lang["trap_kit_hint_3"] or "R - Remote detonation",
	}

	local y = ScrH() - He(130)

	for i, text in ipairs(lines) do
		draw.SimpleText(text, "MuR_Font1", cx, y + (i - 1) * He(15),
			color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local ready = ply:GetNW2Bool("MuR_TrapReady", false)
	local status = ready and (lang["trap_kit_ready"] or "DEVICE ASSEMBLED")
		or (lang["trap_kit_empty"] or "NO DEVICE")

	draw.SimpleText(status, "MuR_Font1", cx, y - He(20),
		ready and Color(0, 255, 136) or Color(255, 120, 120),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
