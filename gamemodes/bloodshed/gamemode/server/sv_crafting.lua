util.AddNetworkString("MuR_OpenCrafting")
util.AddNetworkString("MuR_StartCraft")
util.AddNetworkString("MuR_CancelCraft")
util.AddNetworkString("MuR_CraftComplete")
util.AddNetworkString("MuR_CraftCancelled")
util.AddNetworkString("MuR_CraftingUpdate")
util.AddNetworkString("MuR_PickupIngredient")
util.AddNetworkString("MuR_DropItem")
util.AddNetworkString("MuR_DestroyItem")
util.AddNetworkString("MuR_BuyReagents")

hook.Add("PlayerInitialSpawn", "MuR_InitCraftingInventory", function(ply)
	ply.CraftingInventory = {}
	ply.IsCrafting = false
	ply.CraftStartTime = 0
	ply.CurrentRecipe = nil
	ply.CraftTimer = nil
end)

hook.Add("PlayerSpawn", "MuR_ClearCraftingOnSpawn", function(ply)
	ply.CraftingInventory = {}
	ply.IsCrafting = false
	ply.CraftStartTime = 0
	ply.CurrentRecipe = nil
	if ply.CraftTimer and timer.Exists(ply.CraftTimer) then
		timer.Remove(ply.CraftTimer)
	end
	ply.CraftTimer = nil
	net.Start("MuR_CraftingUpdate")
	net.WriteTable({})
	net.Send(ply)
end)

local function GetInventoryLimit(ply)
	if !IsValid(ply) then return 16 end

	if ply:IsRolePolice() then
		return 8
	end

	if ply:IsKiller() then
		return 24
	end

	return 16
end

local function GetInventoryCount(ply)
	local count = 0
	for _, amount in pairs(ply.CraftingInventory or {}) do
		count = count + amount
	end
	return count
end

function MuR.Crafting:GiveIngredient(ply, ingredient, amount)
	amount = amount or 1

	local currentCount = GetInventoryCount(ply)
	local limit = GetInventoryLimit(ply)

	if currentCount + amount > limit then
		local canGive = limit - currentCount
		if canGive <= 0 then
			net.Start("MuR.CraftingMessage")
			net.WriteString("craft_msg_inventory_full")
			net.WriteInt(limit, 8)
			net.Send(ply)
			return false
		end
		amount = canGive
		net.Start("MuR.CraftingMessage")
		net.WriteString("craft_msg_inventory_partial")
		net.WriteInt(amount, 8)
		net.Send(ply)
	end

	ply.CraftingInventory[ingredient] = (ply.CraftingInventory[ingredient] or 0) + amount
	net.Start("MuR_CraftingUpdate")
	net.WriteTable(ply.CraftingInventory)
	net.Send(ply)
	return true
end

function MuR.Crafting:RemoveIngredient(ply, ingredient, amount)
	amount = amount or 1
	ply.CraftingInventory[ingredient] = math.max(0, (ply.CraftingInventory[ingredient] or 0) - amount)
	net.Start("MuR_CraftingUpdate")
	net.WriteTable(ply.CraftingInventory)
	net.Send(ply)
end

local function SpawnIngredientEntity(pos, ingredient)
	local ent = ents.Create("prop_physics")
	if !IsValid(ent) then return end

	local ingredientData = MuR.Crafting:GetIngredient(ingredient)
	if !ingredientData then return end

	ent:SetModel(ingredientData.model)
	ent:SetPos(pos + Vector(0, 0, 10))
	ent:Spawn()
	ent:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	ent.IsCraftingIngredient = true
	ent.IngredientID = ingredient

	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
	end

	return ent
end

function MuR.Crafting:PickupIngredient(ply, ent)
	if !IsValid(ent) or !ent.IsCraftingIngredient then return end
	if !ply:Alive() then return end

	local ingredient = ent.IngredientID
	if !ingredient then return end

	local currentCount = GetInventoryCount(ply)
	local limit = GetInventoryLimit(ply)

	if currentCount >= limit then
		net.Start("MuR.CraftingMessage")
		net.WriteString("craft_msg_inventory_full")
		net.WriteInt(limit, 8)
		net.Send(ply)
		return false
	end

	MuR.Crafting:GiveIngredient(ply, ingredient, 1)
	ent:Remove()

	ply:EmitSound("items/ammo_pickup.wav", 50, 100)

	return true
end

hook.Add("PlayerUse", "MuR_PickupIngredient", function(ply, ent)
	if MuR.Crafting:PickupIngredient(ply, ent) then
		return false
	end
end)

local function SpawnRandomIngredients()
	local allEnts = ents.GetAll()
	local lootableProps = {}

	for _, ent in ipairs(allEnts) do
		if ent:GetClass() == "prop_physics" then
			local model = ent:GetModel()
			if model then
				for _, lootModel in ipairs(MuR.LootableProps or {}) do
					if model == lootModel then
						table.insert(lootableProps, ent)
						break
					end
				end
			end
		end
	end

	if #lootableProps == 0 then return end

	for ingredientID, data in pairs(MuR.Crafting.Ingredients) do
		local spawnCount = math.random(2, 5)

		for i = 1, spawnCount do
			if math.random(100) <= data.lootChance then
				local prop = table.Random(lootableProps)
				if IsValid(prop) then
					local offset = VectorRand() * 50
					offset.z = math.abs(offset.z)
					SpawnIngredientEntity(prop:GetPos() + offset, ingredientID)
				end
			end
		end
	end
end

net.Receive("MuR_StartCraft", function(len, ply)
	if !IsValid(ply) or !ply:Alive() then return end
	if ply.IsCrafting then return end

	if IsValid(ply:GetRD()) then
		net.Start("MuR.CraftingMessage")
		net.WriteString("craft_msg_in_ragdoll")
		net.Send(ply)
		return
	end

	local wep = ply:GetActiveWeapon()
	if !IsValid(wep) or (wep:GetClass() != "mur_chemistry_illegal" and wep:GetClass() != "mur_chemistry_basic") then
		net.Start("MuR.CraftingMessage")
		net.WriteString("craft_msg_no_tablet")
		net.Send(ply)
		return
	end

	local recipeID = net.ReadString()
	if string.len(recipeID) > 64 then return end

	local recipe = MuR.Crafting:GetRecipe(recipeID)

	if !recipe then return end
	if !MuR.Crafting:CanCraft(ply, recipeID) then
		net.Start("MuR.CraftingMessage")
		net.WriteString("craft_msg_no_ingredients")
		net.Send(ply)
		return
	end

	if wep:GetClass() == "mur_chemistry_basic" then
		local dangerousCategories = {
			["toxins"] = true,
			["chemical_weapons"] = true,
			["stimulants"] = true,
		}

		if dangerousCategories[recipe.category] then
			net.Start("MuR.CraftingMessage")
			net.WriteString("craft_msg_basic_restricted")
			net.Send(ply)
			return
		end
	end

	for ingredient, amount in pairs(recipe.ingredients) do
		MuR.Crafting:RemoveIngredient(ply, ingredient, amount)
	end

	ply.IsCrafting = true
	ply.CraftStartTime = CurTime()
	ply.CurrentRecipe = recipeID

	local craftTime = math.Clamp(5 + (recipe.difficulty * 25), 5, 30)

	net.Start("MuR.CraftingMessage")
	net.WriteString("craft_msg_started")
	net.WriteString(recipe.name)
	net.Send(ply)

	local timerID = "MuR_Craft_" .. ply:SteamID64()
	ply.CraftTimer = timerID

	timer.Create(timerID, craftTime, 1, function()
		if !IsValid(ply) or !ply:Alive() or !ply.IsCrafting then return end

		local success = math.Rand(0, 1) > (recipe.difficulty or 0) * 0.42

		if success then
			ply:GiveWeapon(recipe.result)
		end

		net.Start("MuR_CraftComplete")
		net.WriteBool(success)
		net.WriteString(recipe.name)
		net.Send(ply)

		ply.IsCrafting = false
		ply.CurrentRecipe = nil
		ply.CraftTimer = nil
	end)
end)

net.Receive("MuR_CancelCraft", function(len, ply)
	if !IsValid(ply) or !ply.IsCrafting then return end

	local wep = ply:GetActiveWeapon()
	if !IsValid(wep) or (wep:GetClass() != "mur_chemistry_illegal" and wep:GetClass() != "mur_chemistry_basic") then
		return
	end

	if ply.CraftTimer and timer.Exists(ply.CraftTimer) then
		timer.Remove(ply.CraftTimer)
	end

	ply.IsCrafting = false
	ply.CurrentRecipe = nil
	ply.CraftTimer = nil

	net.Start("MuR.CraftingMessage")
	net.WriteString("craft_msg_cancelled")
	net.Send(ply)

	net.Start("MuR_CraftCancelled")
	net.Send(ply)
end)

hook.Add("PlayerDeath", "MuR_CancelCraftOnDeath", function(ply)
	if ply.IsCrafting and ply.CraftTimer and timer.Exists(ply.CraftTimer) then
		timer.Remove(ply.CraftTimer)

		net.Start("MuR_CraftCancelled")
		net.Send(ply)

		ply.IsCrafting = false
		ply.CurrentRecipe = nil
		ply.CraftTimer = nil
	end
end)

hook.Add("OnPlayerRagdoll", "MuR_CancelCraftOnRagdoll", function(ply)
	if ply.IsCrafting and ply.CraftTimer and timer.Exists(ply.CraftTimer) then
		timer.Remove(ply.CraftTimer)

		net.Start("MuR_CraftCancelled")
		net.Send(ply)

		ply.IsCrafting = false
		ply.CurrentRecipe = nil
		ply.CraftTimer = nil
	end
end)

concommand.Add("mur_give_ingredient", function(ply, cmd, args)
	if !ply:IsAdmin() then return end

	local ingredient = args[1]
	local amount = tonumber(args[2]) or 1

	if !ingredient or !MuR.Crafting:GetIngredient(ingredient) then
		net.Start("MuR.CraftingMessage")
		net.WriteString("craft_msg_admin_invalid")
		net.Send(ply)
		return
	end

	ply.CraftingInventory[ingredient] = (ply.CraftingInventory[ingredient] or 0) + amount
	net.Start("MuR_CraftingUpdate")
	net.WriteTable(ply.CraftingInventory)
	net.Send(ply)

	net.Start("MuR.CraftingMessage")
	net.WriteString("craft_msg_admin_gave")
	net.WriteInt(amount, 16)
	net.WriteString(ingredient)
	net.Send(ply)

	print(string.format("[CRAFTING] Admin %s (%s) gave themselves %dx %s", ply:Nick(), ply:SteamID(), amount, ingredient))
end)

concommand.Add("mur_spawn_ingredients", function(ply, cmd, args)
	if !ply:IsAdmin() then return end

	SpawnRandomIngredients()
	net.Start("MuR.CraftingMessage")
	net.WriteString("craft_msg_admin_spawned")
	net.Send(ply)
end)

local dangerousCategories = {
	["toxins"] = true,
	["chemical_weapons"] = true,
	["stimulants"] = true,
}

local craftingMenuCooldown = {}

concommand.Add("mur_open_crafting", function(ply, cmd, args)
	if !IsValid(ply) or !ply:Alive() then return end

	local steamID = ply:SteamID()
	if craftingMenuCooldown[steamID] and craftingMenuCooldown[steamID] > CurTime() then
		return
	end
	craftingMenuCooldown[steamID] = CurTime() + 0.5

	local craftingType = args[1] or "illegal"
	local isBasic = (craftingType == "basic")

	local wep = ply:GetActiveWeapon()
	if !IsValid(wep) then return end

	local requiredWeapon = isBasic and "mur_chemistry_basic" or "mur_chemistry_illegal"
	if wep:GetClass() != requiredWeapon then
		return
	end

	net.Start("MuR_OpenCrafting")

	local recipesArray = {}
	for id, recipe in pairs(MuR.Crafting.Recipes or {}) do

		if isBasic and dangerousCategories[recipe.category] then
			continue
		end

		local reqsArray = {}
		for ingredientID, amount in pairs(recipe.ingredients or {}) do
			local ingredient = MuR.Crafting:GetIngredient(ingredientID)
			table.insert(reqsArray, {
				item = ingredientID,
				name = ingredient and ingredient.name or ingredientID,
				amount = amount
			})
		end

		local craftTime = math.Clamp(5 + (recipe.difficulty * 25), 5, 30)

		table.insert(recipesArray, {
			id = id,
			name = recipe.name,
			desc = recipe.description or "",
			category = recipe.category,
			result = recipe.result,
			difficulty = recipe.difficulty or 0,
			craftTime = craftTime,
			reqs = reqsArray
		})
	end

	net.WriteBool(isBasic)
	net.WriteTable(recipesArray)
	net.WriteTable(ply.CraftingInventory or {})
	net.WriteInt(GetInventoryLimit(ply), 8)
	net.Send(ply)
end)

net.Receive("MuR_DropItem", function(len, ply)
	if !IsValid(ply) or !ply:Alive() then return end

	local wep = ply:GetActiveWeapon()
	if !IsValid(wep) or (wep:GetClass() != "mur_chemistry_illegal" and wep:GetClass() != "mur_chemistry_basic") then
		return
	end

	local itemID = net.ReadString()
	if string.len(itemID) > 64 then return end

	if !itemID or !ply.CraftingInventory[itemID] or ply.CraftingInventory[itemID] <= 0 then return end

	MuR.Crafting:RemoveIngredient(ply, itemID, 1)

	local trace = ply:GetEyeTrace()
	local randomOffset = VectorRand() * 20
	randomOffset.z = math.abs(randomOffset.z)
	local spawnPos = ply:GetPos() + ply:GetForward() * 50 + Vector(0, 0, 50) + randomOffset

	SpawnIngredientEntity(spawnPos, itemID)

	ply:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 7) .. ".wav", 60, 100)

	net.Start("MuR.CraftingMessage")
	net.WriteString("craft_msg_item_dropped")
	net.WriteString(MuR.Crafting:GetIngredient(itemID).name or itemID)
	net.Send(ply)
end)

net.Receive("MuR_DestroyItem", function(len, ply)
	if !IsValid(ply) or !ply:Alive() then return end

	local wep = ply:GetActiveWeapon()
	if !IsValid(wep) or (wep:GetClass() != "mur_chemistry_illegal" and wep:GetClass() != "mur_chemistry_basic") then
		return
	end

	local itemID = net.ReadString()
	if string.len(itemID) > 64 then return end

	if !itemID or !ply.CraftingInventory[itemID] or ply.CraftingInventory[itemID] <= 0 then return end

	MuR.Crafting:RemoveIngredient(ply, itemID, 1)

	ply:EmitSound("physics/metal/metal_box_break" .. math.random(1, 2) .. ".wav", 60, 100)

	net.Start("MuR.CraftingMessage")
	net.WriteString("craft_msg_item_destroyed")
	net.WriteString(MuR.Crafting:GetIngredient(itemID).name or itemID)
	net.Send(ply)
end)

net.Receive("MuR_BuyReagents", function(len, ply)
	local recipeID = net.ReadString()
	if not isstring(recipeID) or recipeID == "" then return end

	local recipe = MuR.Crafting.Recipes[recipeID]
	if not recipe then return end

	local missingCount = 0
	local totalCount = 0
	local missingItems = {}

	if recipe.ingredients then
		for ingredientID, amount in pairs(recipe.ingredients) do
			totalCount = totalCount + amount
			local has = ply.CraftingInventory[ingredientID] or 0
			if has < amount then
				local needed = amount - has
				missingCount = missingCount + needed
				missingItems[ingredientID] = needed
			end
		end
	end

	if missingCount == 0 then return end

	local price = math.ceil(200 * (missingCount / totalCount))

	if ply:GetNW2Float("Money") >= price then
		ply:SetNW2Float("Money", ply:GetNW2Float("Money") - price)

		for item, amount in pairs(missingItems) do
			MuR.Crafting:GiveIngredient(ply, item, amount)
		end

		net.Start("MuR.PlaySoundOnClient")
		net.WriteString("murdered/vgui/buy.wav")
		net.Send(ply)
	end
end)
