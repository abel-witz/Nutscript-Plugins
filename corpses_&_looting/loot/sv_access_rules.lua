local PROHIBITED_ACTIONS = {
	["Equip"] = true,
	["EquipUn"] = true,
}

function PLUGIN:CanPlayerInteractItem(client, action, itemObject, data)
	if (not nut.version) then return end

	local inventory = nut.inventory.instances[itemObject.invID]

	if (inventory and inventory.isCorpse == true) then
		if (PROHIBITED_ACTIONS[action]) then
			return false, "forbiddenActionStorage"
		end
	end
end

local MAX_ACTION_DISTANCE = 128
local RULES = {
	AccessIfStorageReceiver = function(inventory, action, context)
		-- Make sure that the storage and the player are valid
		local client = context.client
		if (not IsValid(client)) then return end
		local storage = context.storage or client.nutCorpseEntity
		if (not IsValid(storage)) then return end
		if (storage:GetVar("LootInv") ~= inventory) then return end

		-- If the player is too far away from storage, then ignore
		local distance = storage:GetPos():Distance(client:GetPos())
		if (distance > MAX_ACTION_DISTANCE) then return false end

		if (storage.Searchers[client]) then
			return true
		end
	end
}

function PLUGIN:CorpseInventorySet(corpse, inventory)
	inventory:addAccessRule(RULES.AccessIfStorageReceiver)
end

return RULES