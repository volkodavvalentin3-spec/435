local meta = FindMetaTable("Player")
util.AddNetworkString("MuR.UseShop")
util.AddNetworkString("MuR.SyncShopCounts")

net.Receive("MuR.UseShop", function(len, ply)
	if not IsValid(ply) or not ply:Alive() then return end
	local str = net.ReadString()
	local id = net.ReadFloat()
	if string.len(str) > 256 then return end
	ply:BuyItem(str, id)
end)

hook.Add("MuR.GameState", "MuR.ShopReset", function(state)
	if state then
		for _, ply in player.Iterator() do
			ply.ShopPurchases = {}
			net.Start("MuR.SyncShopCounts")
			net.WriteTable({})
			net.Send(ply)
		end
	end
end)

function meta:BuyItem(cat, id)
	if self:GetNW2Float("Guilt") >= 50 and MuR.Gamemode != 18 then
		MuR:GiveAnnounce("money_cancel", self)
		return
	end

	local tab = MuR.Shop[cat]
	if not istable(tab) or not tab[id] then return end

    local class = self:GetNW2String("Class")
    if cat == "Killer" and (class == "Attacker" or class == "Terrorist2") then return end

	local soldierCategoryBlocked = cat == "Soldier" and class != "Soldier" and not (MuR.Gamemode == 24 and class == "PMCCommander")
	local killerCategoryBlocked = cat == "Killer" and not self:IsKiller() and class != "Criminal"
	if soldierCategoryBlocked or killerCategoryBlocked then return end
	if class == "Maniac" then return end
	if (!self:IsKiller() or class == "Criminal") and tab[id].traitor then return end
	if MuR.Gamemode == 19 then return end
	if MuR.Gamemode == 23 then return end
	if tab[id].modes and not table.HasValue(tab[id].modes, MuR.Gamemode) then return end

	local item = tab[id]

	self.ShopPurchases = self.ShopPurchases or {}
	self.ShopPurchases[cat] = self.ShopPurchases[cat] or {}

	local limit = item.limit or 1
	local current = self.ShopPurchases[cat][id] or 0

	if MuR.Gamemode != 24 and limit > 0 and current >= limit then return end

	local price = item.price
	if MuR.Gamemode == 18 then
		price = item.zombieprice or price
		if MuR.Mode18 and MuR.Mode18.FireSaleEnd and CurTime() < MuR.Mode18.FireSaleEnd then
			price = math.floor(price * 0.5)
		end
		if self:GetNWInt("MuR_ZombiesPoints", 0) < price then return end
	elseif MuR.Gamemode == 24 then
		price = item.zombieprice or price
		if self:GetNWInt("MuR_Mode24Points", 0) < price then return end
	else
		if self:GetNW2Float("Money") < price then return end
	end

	if self.ItemBuyDelay and self.ItemBuyDelay > CurTime() then return end

	self.ItemBuyDelay = CurTime()+1

	if MuR.Gamemode == 18 then
		self:SetNWInt("MuR_ZombiesPoints", self:GetNWInt("MuR_ZombiesPoints", 0) - price)
	elseif MuR.Gamemode == 24 then
		self:SetNWInt("MuR_Mode24Points", self:GetNWInt("MuR_Mode24Points", 0) - price)
	else
		self:SetNW2Float("Money", self:GetNW2Float("Money") - price)
	end

	self.ShopPurchases[cat][id] = current + 1

	net.Start("MuR.SyncShopCounts")
	net.WriteTable(self.ShopPurchases)
	net.Send(self)

	item.func(self)
end
