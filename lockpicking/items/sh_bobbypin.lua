ITEM.name = "Bobby pin box"
ITEM.desc = ""
ITEM.model = "models/props_lab/box01a.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.price = 90
ITEM.isStackable = false
ITEM.pinAmount = 5
ITEM.startingPinHealth = 20

----------------
-- [[ Data ]] --
----------------
local conditions = {
	[0.85] = {"lockpickingExcellent", {0, 179, 0}},
	[0.55] = {"lockpickingWell", {255, 255, 0}},
	[0.35] = {"lockpickingWeak", {255, 140, 26}},
	[0.25] = {"lockpickingBad", {255, 51, 0}},
	[0] = {"lockpickingVeryBad", {102, 0, 0}}
}

function ITEM:GetCondition()
	local pinHealth = self:getData("health", self.startingPinHealth)

	for k, v in SortedPairs(conditions, true) do
		if ( pinHealth >= self.startingPinHealth * k ) then
			return v[1], v[2]
		end
	end
end

function ITEM:GetQuantity()
	return self:getData("quantity", self.pinAmount)
end

------------------
-- [[ Action ]] --
------------------
local function isDoorLocked(ent)
	return ent:GetSaveTable().m_bLocked or ent.locked or false
end

local function getDoorLockpicker(door)
	local session = door.LockpickingSession

	if (session) then
		return ssession.Player
	end
end

ITEM.functions.use = {
	name = "lockpickingPick",
	tip = "useTip",
	icon = "icon16/wrench.png",
	onRun = function(item)
		local client = item.player
		local ent = LockpickingPlugin:GetEntityLookedAt(client, LockpickingPlugin.Config.MaxLookDistance)

		if ( isDoorLocked(ent) and not getDoorLockpicker(ent) ) then
			local session = LockpickingPlugin:StartServerSession(ent, client, item)

			if ( type(session) == "string" ) then
				client:notify(session)
			end
		end
		
		return false
	end,
	onCanRun = function(item)
		local client
		if ( SERVER ) then 
			client = item.player 
		else 
			client = LocalPlayer() 
		end
		
		local ent = LockpickingPlugin:GetEntityLookedAt(client, LockpickingPlugin.Config.MaxLookDistance)

		if ( IsValid(ent) and ent:isDoor() ) then
			if ( SERVER ) then
				if ( not isDoorLocked(ent) ) then
					client:notifyLocalized("lockpickingNotLocked")
				elseif ( getDoorLockpicker(ent) ) then
					client:notifyLocalized("lockpickingAlreadyLocked")
				end
			end

			return true
		else
			return false
		end
	end
}

function ITEM:PinBreak()
	local oldQuantity = self:GetQuantity()

	if ( oldQuantity == 1 ) then
		self:remove()
		return false
	else
		self:setData("health", self.startingPinHealth)
		self:setData("quantity", oldQuantity - 1)
		return true
	end
end

function ITEM:onRemoved()
    local session = self.LockpickingSession

	if ( session ) then
		session:Stop()
	end
end

------------------------------
-- [[ In NutScript menus ]] --
------------------------------
function ITEM:IsInBusinnessMenu()
	return (self:getID() == 0)
end

function ITEM:getDesc()
	local desc = self.desc

	if ( self:IsInBusinnessMenu() ) then
		return desc
	else
		local newDesc = ""

		if ( desc and desc ~= "" and desc ~= "noDesc" ) then
			newDesc = desc.."\n"
		end

		local state, color = self:GetCondition()
		local localizedText = L("lockpickingCondition", L(state))

		newDesc = newDesc.."<color="..color[1]..", "..color[2]..", "..color[3]..">"..localizedText.."</color>"
		return newDesc
	end
end

function ITEM:paintOver(item, w, h)
	local quantity = item:GetQuantity()
	draw.SimpleText(quantity, "DermaDefault", 5, h-5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 1, color_black)
end