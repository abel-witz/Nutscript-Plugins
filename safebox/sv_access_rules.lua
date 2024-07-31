local PLUGIN = SafeboxPlugin

local PROHIBITED_ACTIONS = {
	["Equip"] = true,
	["EquipUn"] = true,
}

function PLUGIN:CanPlayerInteractItem(client, action, itemObject, data)
	if ( not nut.version ) then return end
	
	local inventory = nut.item.inventories[itemObject.invID]

	if (inventory and inventory.isSafebox == true) then
		if (PROHIBITED_ACTIONS[action]) then
			return false, "forbiddenActionStorage"
		end
	end
end

local MAX_ACTION_DISTANCE = 128
local RULES = {
	AccessIfStorageReceiver = function(inventory, action, context)
		local client = context.client
		if (not IsValid(client)) then return end

		local char = client:getChar()
		if (not char) then return end

		local safeboxData = PLUGIN.charInventoryIDs[char:getID()]
		if (not safeboxData) then return end
		local safeboxInvID = safeboxData[1]

		local storageInv = nut.item.inventories[safeboxInvID]

		local storage = context.safebox or client.nutSafeboxEntity
		if (not IsValid(storage)) then return end
		if (storageInv ~= inventory) then return end

		-- If the player is too far away from storage, then ignore
		local distance = storage:GetPos():Distance(client:GetPos())
		if (distance > MAX_ACTION_DISTANCE) then return false end

		if (storage.receivers[client]) then
			return true
		end
	end
}

function PLUGIN:SafeboxInventorySet(inventory)
	inventory:addAccessRule(RULES.AccessIfStorageReceiver)
end

return RULES
