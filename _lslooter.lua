LSLooter = LibStub("AceAddon-3.0"):NewAddon("LSLooter", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
local L

local texture_unlock = "Interface\\AddOns\\lslooter\\Textures\\icons\\lock"
local texture_lock = "Interface\\AddOns\\lslooter\\Textures\\icons\\un_lock"

local inRaid, Rolling, Rolls_count, inFight, isML, SelectedLoot, Winner_index

local defaults = {
	profile = {
		posx = nil,
		posy = nil,
		lock = nil,
		width = 200,
		height = 300,
		count = 10,
		lootframe = {
			posx = nil,
			posy = nil,
			lock = nil,
			width = 200,
			height = 300,
		}
	}
}

local LSMainFrame = nil
local LSLootFrame = nil

local function _color(r, g, b, msg)
	if type(r) == "table" then
		if r.r then r, g, b = r.r, r.g, r.b else r, g, b = unpack(r) end
	end
	t_color = string.format("|cff%02x%02x%02x", r*255, g*255, b*255)
	if msg ~= '' then
		return t_color..msg..'|r'
	else
		return t_color
	end
end

local function _message(msg, label)
	local output = ""
	output = _color(0,1,1, 'LSL: ')
	if label then
		output = output.._color(0,0.7,0.7, label..': ')
	end
	output = output..msg
	print(output)
end

-- Display LSMainFrame --------------------------------------------------------

local function onDragStart(self) self:StartMoving() end
local function onLSMainFrameDragStop(self)
	self:StopMovingOrSizing()
	LSLooter.db.profile.posx = self:GetLeft()
	LSLooter.db.profile.posy = self:GetTop()
end
local function OnDragHandleMouseDown(self) self.frame:StartSizing("BOTTOMRIGHT") end
local function OnDragHandleMouseUp(self) self.frame:StopMovingOrSizing() end
local function onLSMainFrameResize(self, width, height)
	LSLooter.db.profile.width = width
	LSLooter.db.profile.height = height
end

local locked = nil
local function lockLSMainFrame()
	if locked then return end
	LSMainFrame:EnableMouse(false)
	LSMainFrame:SetMovable(false)
	LSMainFrame:SetResizable(false)
	LSMainFrame:RegisterForDrag()
	LSMainFrame:SetScript("OnSizeChanged", nil)
	LSMainFrame:SetScript("OnDragStart", nil)
	LSMainFrame:SetScript("OnDragStop", nil)
	LSMainFrame.drag:Hide()
	locked = true
end

local function unlockLSMainFrame()
	if not locked then return end
	LSMainFrame:EnableMouse(true)
	LSMainFrame:SetMovable(true)
	LSMainFrame:SetResizable(true)
	LSMainFrame:RegisterForDrag("LeftButton")
	LSMainFrame:SetScript("OnSizeChanged", onLSMainFrameResize)
	LSMainFrame:SetScript("OnDragStart", onDragStart)
	LSMainFrame:SetScript("OnDragStop", onLSMainFrameDragStop)
	LSMainFrame.drag:Show()
	locked = nil
end

local function updateLSMainFrameLockButton()
	if not LSMainFrame then return end
	LSMainFrame.lock:SetNormalTexture(LSLooter.db.profile.lock and texture_unlock or texture_lock)
end

local function toggleLSMainFrameLock()
	if LSLooter.db.profile.lock then
		unlockLSMainFrame()
	else
		lockLSMainFrame()
	end
	LSLooter.db.profile.lock = not LSLooter.db.profile.lock
	updateLSMainFrameLockButton()
end

local function closeLSMainFrame() LSMainFrame:Hide() end

function LSLooter:displayMain()
	if LSMainFrame then return end

	local LSMainFrameDisplay = CreateFrame("Frame", "LSMainFrameAnchor", UIParent)
	LSMainFrameDisplay:SetWidth(LSLooter.db.profile.width)
	LSMainFrameDisplay:SetHeight(LSLooter.db.profile.height)
	LSMainFrameDisplay:SetMinResize(200, 180)
	LSMainFrameDisplay:SetClampedToScreen(true)
	local bg = LSMainFrameDisplay:CreateTexture(nil, "PARENT")
	bg:SetAllPoints(LSMainFrameDisplay)
	bg:SetBlendMode("BLEND")
	bg:SetTexture(0, 0, 0, 0.3)

	local LSMainFrameClose = CreateFrame("Button", nil, LSMainFrameDisplay)
	LSMainFrameClose:SetPoint("BOTTOMRIGHT", LSMainFrameDisplay, "TOPRIGHT", -2, 2)
	LSMainFrameClose:SetHeight(16)
	LSMainFrameClose:SetWidth(16)
	LSMainFrameClose:SetNormalTexture("Interface\\AddOns\\lslooter\\Textures\\icons\\close")
	LSMainFrameClose:SetScript("OnClick", closeLSMainFrame)

	local LSMainFrameLock = CreateFrame("Button", nil, LSMainFrameDisplay)
	LSMainFrameLock:SetPoint("BOTTOMLEFT", LSMainFrameDisplay, "TOPLEFT", 2, 2)
	LSMainFrameLock:SetHeight(16)
	LSMainFrameLock:SetWidth(16)
	LSMainFrameLock:SetScript("OnClick", toggleLSMainFrameLock)
	LSMainFrameDisplay.lock = LSMainFrameLock

	local LSMainFrameHeader = LSMainFrameDisplay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	LSMainFrameHeader:SetText("LSLooter:Roster")
	LSMainFrameHeader:SetPoint("BOTTOM", LSMainFrameDisplay, "TOP", 0, 4)

	local LSMainFrameReset = CreateFrame("Button", nil, LSMainFrameDisplay, "UIPanelButtonTemplate")
	LSMainFrameReset:SetHeight(18)
	LSMainFrameReset:SetWidth(65)
	LSMainFrameReset:SetText(L["Reset"])
	LSMainFrameReset:SetPoint("BOTTOMLEFT",LSMainFrameDisplay,"BOTTOMLEFT", 4,  4)
	LSMainFrameReset:SetScript("OnClick", function()
		if inRaid then
			for index, value in pairs(self.db.profile.roster) do
				value._plus = 0
			end
			LSLooter:refreshPlus()
			SendChatMessage(L["Penalities reset"], "RAID", nil, nil)
		end
	end)
	
	local LSMainFrameTextNames = {}
	LSMainFrameDisplay._names = {}
	local LSMainFrameTextStatus = {}
	LSMainFrameDisplay._status = {}
	local LSMainFrameButtonTwo = {}
	local LSMainFrameButtonFive = {}
	
	for i = 1, 10 do
		LSMainFrameTextNames[i] = LSMainFrameDisplay:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
		LSMainFrameTextNames[i]:SetFont("Fonts\\FRIZQT__.TTF", 12)
		LSMainFrameTextNames[i]:SetJustifyH("LEFT")
		LSMainFrameTextNames[i]:SetText("...")
		LSMainFrameTextNames[i]:SetWidth(115)
		LSMainFrameTextNames[i]:SetPoint("TOPLEFT",LSMainFrameDisplay,"TOPLEFT", 5, 2 - i * 14)
		LSMainFrameDisplay._names[i] = LSMainFrameTextNames[i]
		
		LSMainFrameTextStatus[i] = LSMainFrameDisplay:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
		LSMainFrameTextStatus[i]:SetFont("Fonts\\FRIZQT__.TTF", 12)
		LSMainFrameTextStatus[i]:SetJustifyH("CENTER")
		LSMainFrameTextStatus[i]:SetText("...")
		LSMainFrameTextStatus[i]:SetWidth(30)
		LSMainFrameTextStatus[i]:SetPoint("TOPLEFT",LSMainFrameTextNames[i],"TOPRIGHT", 0,  0)
		LSMainFrameDisplay._status[i] = LSMainFrameTextStatus[i]
		
		LSMainFrameButtonTwo[i] = CreateFrame("Button", nil, LSMainFrameDisplay, "UIPanelButtonTemplate")
		LSMainFrameButtonTwo[i]:SetHeight(16)
		LSMainFrameButtonTwo[i]:SetWidth(20)
		LSMainFrameButtonTwo[i]:SetText("-2")
		LSMainFrameButtonTwo[i]:SetPoint("TOPLEFT",LSMainFrameTextStatus[i],"TOPRIGHT", 0,  0)
		LSMainFrameButtonTwo[i]:SetScript("OnClick", function()
			if inRaid then
				self.db.profile.roster[LSMainFrameTextNames[i]:GetText()]._plus = self.db.profile.roster[LSMainFrameTextNames[i]:GetText()]._plus - 2
				LSLooter:refreshPlus()
				SendChatMessage(LSMainFrameTextNames[i]:GetText()..L["takes -2 pen"]..self.db.profile.roster[LSMainFrameTextNames[i]:GetText()]._plus..")", "RAID", nil, nil)
			end
		end)
		
		
		LSMainFrameButtonFive[i] = CreateFrame("Button", nil, LSMainFrameDisplay, "UIPanelButtonTemplate")
		LSMainFrameButtonFive[i]:SetHeight(16)
		LSMainFrameButtonFive[i]:SetWidth(20)
		LSMainFrameButtonFive[i]:SetText("-5")
		LSMainFrameButtonFive[i]:SetPoint("TOPLEFT",LSMainFrameButtonTwo[i],"TOPRIGHT", 3,  0)
		LSMainFrameButtonFive[i]:SetScript("OnClick", function()
			if inRaid then
				self.db.profile.roster[LSMainFrameTextNames[i]:GetText()]._plus = self.db.profile.roster[LSMainFrameTextNames[i]:GetText()]._plus - 5
				LSLooter:refreshPlus()
				SendChatMessage(LSMainFrameTextNames[i]:GetText()..L["takes -5 pen"]..self.db.profile.roster[LSMainFrameTextNames[i]:GetText()]._plus..")", "RAID", nil, nil)
			end
		end)
	end

	local LSMainFrameDrag = CreateFrame("Frame", nil, LSMainFrameDisplay)
	LSMainFrameDrag.frame = LSMainFrameDisplay
	LSMainFrameDrag:SetFrameLevel(LSMainFrameDisplay:GetFrameLevel() + 10) -- place this above everything
	LSMainFrameDrag:SetWidth(16)
	LSMainFrameDrag:SetHeight(16)
	LSMainFrameDrag:SetPoint("BOTTOMRIGHT", LSMainFrameDisplay, -1, 1)
	LSMainFrameDrag:EnableMouse(true)
	LSMainFrameDrag:SetScript("OnMouseDown", OnDragHandleMouseDown)
	LSMainFrameDrag:SetScript("OnMouseUp", OnDragHandleMouseUp)
	LSMainFrameDrag:SetAlpha(0.5)
	LSMainFrameDisplay.drag = LSMainFrameDrag

	local LSMainFrameTex = LSMainFrameDrag:CreateTexture(nil, "BACKGROUND")
	LSMainFrameTex:SetTexture("Interface\\AddOns\\lslooter\\Textures\\draghandle")
	LSMainFrameTex:SetWidth(16)
	LSMainFrameTex:SetHeight(16)
	LSMainFrameTex:SetBlendMode("ADD")
	LSMainFrameTex:SetPoint("CENTER", LSMainFrameDrag)

	LSMainFrame = LSMainFrameDisplay

	local x = LSLooter.db.profile.posx
	local y = LSLooter.db.profile.posy
	if x and y then
		LSMainFrameDisplay:ClearAllPoints()
		LSMainFrameDisplay:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	else
		LSMainFrameDisplay:ClearAllPoints()
		LSMainFrameDisplay:SetPoint("CENTER", UIParent)
	end

	updateLSMainFrameLockButton()
	if LSLooter.db.profile.lock then
		locked = nil
		lockLSMainFrame()
	else
		locked = true
		unlockLSMainFrame()
	end
end

local function resetMainWindow()
	LSMainFrame:ClearAllPoints()
	LSMainFrame:SetPoint("CENTER", UIParent)
	LSMainFrame:SetWidth(defaults.profile.width)
	LSMainFrame:SetHeight(defaults.profile.height)
	LSLooter.db.profile.posx = nil
	LSLooter.db.profile.posy = nil
	LSLooter.db.profile.width = nil
	LSLooter.db.profile.height = nil
end

-- Display LSLootFrame --------------------------------------------------------

local function onLSLootFrameDragStop(self)
	self:StopMovingOrSizing()
	LSLooter.db.profile.lootframe.posx = self:GetLeft()
	LSLooter.db.profile.lootframe.posy = self:GetTop()
end

local function onLSLootFrameResize(self, width, height)
	LSLooter.db.profile.lootframe.width = width
	LSLooter.db.profile.lootframe.height = height
end

local locked = nil
local function lockLSLootFrame()
	if locked then return end
	LSLootFrame:EnableMouse(false)
	LSLootFrame:SetMovable(false)
	LSLootFrame:SetResizable(false)
	LSLootFrame:RegisterForDrag()
	LSLootFrame:SetScript("OnSizeChanged", nil)
	LSLootFrame:SetScript("OnDragStart", nil)
	LSLootFrame:SetScript("OnDragStop", nil)
	LSLootFrame.drag:Hide()
	locked = true
end

local function unlockLSLootFrame()
	if not locked then return end
	LSLootFrame:EnableMouse(true)
	LSLootFrame:SetMovable(true)
	LSLootFrame:SetResizable(true)
	LSLootFrame:RegisterForDrag("LeftButton")
	LSLootFrame:SetScript("OnSizeChanged", onLSLootFrameResize)
	LSLootFrame:SetScript("OnDragStart", onDragStart)
	LSLootFrame:SetScript("OnDragStop", onLSLootFrameDragStop)
	LSLootFrame.drag:Show()
	locked = nil
end

local function updateLSLootFrameLockButton()
	if not LSLootFrame then return end
	LSLootFrame.lock:SetNormalTexture(LSLooter.db.profile.lootframe.lock and texture_unlock or texture_lock)
end

local function toggleLSLootFrameLock()
	if LSLooter.db.profile.lootframe.lock then
		unlockLSLootFrame()
	else
		lockLSLootFrame()
	end
	LSLooter.db.profile.lootframe.lock = not LSLooter.db.profile.lootframe.lock
	updateLSLootFrameLockButton()
end

local function closeLSLootFrame() LSLootFrame:Hide() end


function LSLooter:LootDropDownMenu_SelectLoot(self, arg1, arg2, checked)
	local ndb = self:GetID()
	
	for i = 1, #LSLooter.db.profile.loot, 1 do
		if LSLooter.db.profile.loot[i]._id == self:GetText() then
			SelectedLoot = i
			break
		end
	end
	
	UIDropDownMenu_SetSelectedID(LSLooter.LootDropDownMenu, ndb)
end

function LSLooter:LootDropDownMenu_Initialize()
	if LSLooter.db.profile.loot then
		if #LSLooter.db.profile.loot > 0 then
			_message ("init "..#LSLooter.db.profile.loot)
			for i = 1, #LSLooter.db.profile.loot do
				if LSLooter.db.profile.loot[i]._pickedup == false then
					_message ("init loot "..i)
					local info_loot = UIDropDownMenu_CreateInfo()
					info_loot.fontObject = "GameFontNormal"
					info_loot.text =  LSLooter.db.profile.loot[i]._id
					info_loot.checked = i == 1
					info_loot.func = function(self, arg1, arg2, checked) LSLooter:LootDropDownMenu_SelectLoot(self, arg1, arg2, checked) end
					UIDropDownMenu_AddButton(info_loot)
				end
			end
			for i = 1, #LSLooter.db.profile.loot do
				if LSLooter.db.profile.loot[i]._pickedup == false then
					UIDropDownMenu_SetText(LSLooter.LootDropDownMenu, LSLooter.db.profile.loot[i]._id)
					break
				end
			end
		else
			local info = UIDropDownMenu_CreateInfo()
			info.text = "Нет предметов"
			UIDropDownMenu_AddButton(info)
			if LSLootFrame then LSLootFrame:Hide() end
		end
	else 
		local info = UIDropDownMenu_CreateInfo()
		info.text = L["noitems"]
		UIDropDownMenu_AddButton(info)
			if LSLootFrame then LSLootFrame:Hide() end
	end
end

function LSLooter:displayLoot()
	if LSLootFrame then return end

	local LSLootFrameDisplay = CreateFrame("Frame", "LSLootFrameAnchor", UIParent)
	LSLootFrameDisplay:SetWidth(LSLooter.db.profile.lootframe.width)
	LSLootFrameDisplay:SetHeight(LSLooter.db.profile.lootframe.height)
	LSLootFrameDisplay:SetMinResize(200, 180)
	LSLootFrameDisplay:SetClampedToScreen(true)
	local bg = LSLootFrameDisplay:CreateTexture(nil, "PARENT")
	bg:SetAllPoints(LSLootFrameDisplay)
	bg:SetBlendMode("BLEND")
	bg:SetTexture(0, 0, 0, 0.3)

	local LSLootFrameClose = CreateFrame("Button", nil, LSLootFrameDisplay)
	LSLootFrameClose:SetPoint("BOTTOMRIGHT", LSLootFrameDisplay, "TOPRIGHT", -2, 2)
	LSLootFrameClose:SetHeight(16)
	LSLootFrameClose:SetWidth(16)
	LSLootFrameClose:SetNormalTexture("Interface\\AddOns\\lslooter\\Textures\\icons\\close")
	LSLootFrameClose:SetScript("OnClick", closeLSLootFrame)

	local LSLootFrameLock = CreateFrame("Button", nil, LSLootFrameDisplay)
	LSLootFrameLock:SetPoint("BOTTOMLEFT", LSLootFrameDisplay, "TOPLEFT", 2, 2)
	LSLootFrameLock:SetHeight(16)
	LSLootFrameLock:SetWidth(16)
	LSLootFrameLock:SetScript("OnClick", toggleLSLootFrameLock)
	LSLootFrameDisplay.lock = LSLootFrameLock

	local LSLootFrameHeader = LSLootFrameDisplay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	LSLootFrameHeader:SetText("LSLooter:Loot")
	LSLootFrameHeader:SetPoint("BOTTOM", LSLootFrameDisplay, "TOP", 0, 4)
	
	self.LootDropDownMenu = CreateFrame("Button","LootDropDownMenu",LSLootFrameDisplay,"UIDropDownMenuTemplate")
	self.LootDropDownMenu:SetPoint("TOPLEFT",LSLootFrameDisplay,"TOPLEFT", -14,  -2)
	self.LootDropDownMenu:SetScript("OnClick", function()
		
	end)
	UIDropDownMenu_Initialize(self.LootDropDownMenu, self.LootDropDownMenu_Initialize)
	UIDropDownMenu_SetSelectedID(self.LootDropDownMenu, 1)
	UIDropDownMenu_SetWidth(self.LootDropDownMenu, 230)
  
	local LSLootFrameStartRoll = CreateFrame("Button", nil, LSLootFrameDisplay, "UIPanelButtonTemplate")
	LSLootFrameStartRoll:SetHeight(18)
	LSLootFrameStartRoll:SetWidth(100)
	LSLootFrameStartRoll:SetText(L["Start roll"])
	LSLootFrameStartRoll:SetPoint("TOPLEFT",LSLootFrameDisplay,"TOPLEFT", 65,  -34)
	LSLootFrameStartRoll:SetScript("OnClick", function()
		if inRaid and isML then
			Rolls_count = 0
			Rolling = true
			for i=1,10,1 do
				LSLootFrame._names[i]:Hide()
				LSLootFrame._status[i]:Hide()
				LSLootFrame._roll[i]:Hide()
				LSLootFrame._cancel[i]:Hide()
			end
			SendChatMessage(L["Roll"]..UIDropDownMenu_GetText(self.LootDropDownMenu), "RAID", nil, nil)
		end
	end)
	
	local LSLootFrameEndRoll = CreateFrame("Button", nil, LSLootFrameDisplay, "UIPanelButtonTemplate")
	LSLootFrameEndRoll:SetHeight(18)
	LSLootFrameEndRoll:SetWidth(135)
	LSLootFrameEndRoll:SetText(L["End roll"])
	LSLootFrameEndRoll:SetPoint("BOTTOMLEFT",LSLootFrameDisplay,"BOTTOMLEFT", 4,  4)
	LSLootFrameEndRoll:SetScript("OnClick", function()
		if inRaid and Rolling and isML then
			if LSLooter.db.profile.rolls == nil then
				SendChatMessage(UIDropDownMenu_GetText(self.LootDropDownMenu).." - "..L["no contenders"], "RAID", nil, nil)
			else
			
				local winner = ""
				local maxroll = 0
				for index, value in pairs(LSLooter.db.profile.rolls) do
					if value._total > maxroll and value._allow then
						maxroll = value._total
						winner = value._name
					end
				end
				
				Winner_index = winner
				if maxroll == 0 then -- happens when all rolls canceled by ML
					SendChatMessage(UIDropDownMenu_GetText(self.LootDropDownMenu).." - "..L["no contenders"], "RAID", nil, nil)
				else
					LSLooter.db.profile.loot[SelectedLoot]._winner = winner
					SendChatMessage(LSLooter.db.profile.loot[SelectedLoot]._id..L["winner"]..winner..":", "RAID", nil, nil)
					for index, value in pairs(LSLooter.db.profile.rolls) do
						if value._allow then
							local plus
							if LSLooter.db.profile.roster[value._name]._plus == 0 then
								plus = "-"..LSLooter.db.profile.roster[value._name]._plus
							else 
								plus = LSLooter.db.profile.roster[value._name]._plus
							end
							SendChatMessage(value._name..": "..value._roll..plus.." = "..value._total, "RAID", nil, nil)
						end
					end
					for index, value in pairs(LSLooter.db.profile.rolls) do
						if value._allow then
							LSLooter.db.profile.roster[value._name]._plus = 0
						end
					end
					LSLooter:refreshPlus()
				end
			end
			
			Rolling = false
			if LSLooter.db.profile.rolls then
				wipe(LSLooter.db.profile.rolls)
				LSLooter.db.profile.rolls = nil
			end
		end
	end)
	
	local LSLootFrameGive = CreateFrame("Button", nil, LSLootFrameDisplay, "UIPanelButtonTemplate")
	LSLootFrameGive:SetHeight(18)
	LSLootFrameGive:SetWidth(100)
	LSLootFrameGive:SetText(L["Give"])
	LSLootFrameGive:SetPoint("TOPLEFT",LSLootFrameEndRoll,"TOPRIGHT", 6,  0)
	LSLootFrameGive:SetScript("OnClick", function()
		if inRaid and isML then
			_message("give selected loot "..SelectedLoot)
			local _item = UIDropDownMenu_GetText(self.LootDropDownMenu)
			local lucky_guy = LSLooter.db.profile.loot[SelectedLoot]._winner
			
			if lucky_guy == "" then
				_message(L["nowinner"])
				return
			end
			
			for i = 1, GetNumRaidMembers() do
				if (GetMasterLootCandidate(i) == lucky_guy) then
					for e = 1, GetNumLootItems() do
						if LootSlotIsItem(e) then
							if GetLootSlotLink(e) == _item then
								_message("trying to give "..e.." to "..i)
								GiveMasterLoot(e, i)
								return
							end
						end
					end
				end
			end
			_message(L["cant give"].._item..L["to"]..lucky_guy)
		end
	end)
	
	local LSLootFrameTextNames = {}
	LSLootFrameDisplay._names = {}
	local LSLootFrameTextRoll = {}
	LSLootFrameDisplay._roll = {}
	local LSLootFrameTextStatus = {}
	LSLootFrameDisplay._status = {}
	local LSLootFrameButtonCancel = {}
	LSLootFrameDisplay._cancel = {}
	
	for i = 1, 10 do
		LSLootFrameTextNames[i] = LSLootFrameDisplay:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
		LSLootFrameTextNames[i]:SetFont("Fonts\\FRIZQT__.TTF", 12)
		LSLootFrameTextNames[i]:SetJustifyH("LEFT")
		LSLootFrameTextNames[i]:SetText("...")
		LSLootFrameTextNames[i]:SetWidth(115)
		LSLootFrameTextNames[i]:SetPoint("TOPLEFT",LSLootFrameDisplay,"TOPLEFT", 5, -38 - i * 14)
		LSLootFrameDisplay._names[i] = LSLootFrameTextNames[i]
		LSLootFrameDisplay._names[i]:Hide()
		
		LSLootFrameTextStatus[i] = LSLootFrameDisplay:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
		LSLootFrameTextStatus[i]:SetFont("Fonts\\FRIZQT__.TTF", 12)
		LSLootFrameTextStatus[i]:SetJustifyH("CENTER")
		LSLootFrameTextStatus[i]:SetText("...")
		LSLootFrameTextStatus[i]:SetWidth(30)
		LSLootFrameTextStatus[i]:SetPoint("TOPLEFT",LSLootFrameTextNames[i],"TOPRIGHT", 0,  0)
		LSLootFrameDisplay._status[i] = LSLootFrameTextStatus[i]
		LSLootFrameDisplay._status[i]:Hide()
		
		LSLootFrameTextRoll[i] = LSLootFrameDisplay:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
		LSLootFrameTextRoll[i]:SetFont("Fonts\\FRIZQT__.TTF", 12)
		LSLootFrameTextRoll[i]:SetJustifyH("CENTER")
		LSLootFrameTextRoll[i]:SetText("...")
		LSLootFrameTextRoll[i]:SetWidth(30)
		LSLootFrameTextRoll[i]:SetPoint("TOPLEFT",LSLootFrameTextStatus[i],"TOPRIGHT", 0,  0)
		LSLootFrameDisplay._roll[i] = LSLootFrameTextRoll[i]
		LSLootFrameDisplay._roll[i]:Hide()
		
		LSLootFrameButtonCancel[i] = CreateFrame("Button", nil, LSLootFrameDisplay, "UIPanelButtonTemplate")
		LSLootFrameButtonCancel[i]:SetHeight(16)
		LSLootFrameButtonCancel[i]:SetWidth(65)
		LSLootFrameButtonCancel[i]:SetText(L["cancel"])
		LSLootFrameButtonCancel[i]:SetPoint("TOPLEFT",LSLootFrameTextRoll[i],"TOPRIGHT", 0,  0)
		LSLootFrameButtonCancel[i]:SetScript("OnClick", function()
			if inRaid and Rolling and isML then
				LSLooter.db.profile.rolls[LSLootFrameDisplay._names[i]:GetText()]._allow = false
				SendChatMessage(LSLootFrameDisplay._names[i]:GetText()..L["not allow"], "RAID", nil, nil)
				LSLootFrameDisplay._names[i]:Hide()
				LSLootFrameDisplay._status[i]:Hide()
				LSLootFrameDisplay._roll[i]:Hide()
				LSLootFrameDisplay._cancel[i]:Hide()
			end
		end)
		LSLootFrameDisplay._cancel[i] = LSLootFrameButtonCancel[i]
		LSLootFrameDisplay._cancel[i]:Hide()
	end

	local LSLootFrameDrag = CreateFrame("Frame", nil, LSLootFrameDisplay)
	LSLootFrameDrag.frame = LSLootFrameDisplay
	LSLootFrameDrag:SetFrameLevel(LSLootFrameDisplay:GetFrameLevel() + 10) -- place this above everything
	LSLootFrameDrag:SetWidth(16)
	LSLootFrameDrag:SetHeight(16)
	LSLootFrameDrag:SetPoint("BOTTOMRIGHT", LSLootFrameDisplay, -1, 1)
	LSLootFrameDrag:EnableMouse(true)
	LSLootFrameDrag:SetScript("OnMouseDown", OnDragHandleMouseDown)
	LSLootFrameDrag:SetScript("OnMouseUp", OnDragHandleMouseUp)
	LSLootFrameDrag:SetAlpha(0.5)
	LSLootFrameDisplay.drag = LSLootFrameDrag

	local LSLootFrameTex = LSLootFrameDrag:CreateTexture(nil, "BACKGROUND")
	LSLootFrameTex:SetTexture("Interface\\AddOns\\lslooter\\Textures\\draghandle")
	LSLootFrameTex:SetWidth(16)
	LSLootFrameTex:SetHeight(16)
	LSLootFrameTex:SetBlendMode("ADD")
	LSLootFrameTex:SetPoint("CENTER", LSLootFrameDrag)

	LSLootFrame = LSLootFrameDisplay

	local x = LSLooter.db.profile.lootframe.posx
	local y = LSLooter.db.profile.lootframe.posy
	if x and y then
		LSLootFrameDisplay:ClearAllPoints()
		LSLootFrameDisplay:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	else
		LSLootFrameDisplay:ClearAllPoints()
		LSLootFrameDisplay:SetPoint("CENTER", UIParent)
	end

	updateLSLootFrameLockButton()
	if LSLooter.db.profile.lootframe.lock then
		locked = nil
		lockLSLootFrame()
	else
		locked = true
		unlockLSLootFrame()
	end
end

local function resetLootWindow()
	LSLootFrame:ClearAllPoints()
	LSLootFrame:SetPoint("CENTER", UIParent)
	LSLootFrame:SetWidth(defaults.profile.width)
	LSLootFrame:SetHeight(defaults.profile.height)
	LSLooter.db.profile.lootframe.posx = nil
	LSLooter.db.profile.lootframe.posy = nil
	LSLooter.db.profile.lootframe.width = nil
	LSLooter.db.profile.lootframe.height = nil
end

-------------------------------------------------------------------------------

function _getItemLink(id)
	local itemName, _, itemRarity, _, _, _, _, _, _, _, _ = GetItemInfo(id)
	if itemRarity then -- seems that sometimes itemRarities not loaded
		local _, _, _, hex = GetItemQualityColor(itemRarity)
		return "|c"..hex.."|Hitem:"..id..":0:0:0:0:0:0:0:0:0|h["..itemName.."]|h|r"
	else 
		return "|cffffff|Hitem:"..id..":0:0:0:0:0:0:0:0:0|h["..itemName.."]|h|r"
	end
end

function LSLooter:refreshPlus()
	local y = 1
	for index, value in pairs(self.db.profile.roster) do
		if value._inRaid then
			LSMainFrame._names[y]:SetText(value._name)
			LSMainFrame._status[y]:SetText(value._plus)
			y = y + 1
			if y == 11 then break end
		end
	end
	for i=y,10,1 do
		LSMainFrame._names[i]:SetText("...")
		LSMainFrame._status[i]:SetText("...")
	end
end

function LSLooter:OnInitialize()
	L = LibStub("AceLocale-3.0"):GetLocale("LSLooter", true)
	
	self.db = LibStub("AceDB-3.0"):New("LSLooterDB", defaults, true)
	if self.db.profile.roster == nil then
		self.db.profile.roster = {{}}
	end
	if self.db.profile.rolls ~= nil then
		wipe(self.db.profile.rolls)
		self.db.profile.rolls = nil
	end
	if self.db.profile.loot then wipe(self.db.profile.loot) end
	self.db.profile.loot = nil
	
	LSLooter:RegisterChatCommand("lsl", "LSLooterSlashProcessorFunc")
	LSLooter:RegisterEvent("RAID_ROSTER_UPDATE")
	LSLooter:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	LSLooter:RegisterEvent("CHAT_MSG_SYSTEM")
	LSLooter:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	LSLooter:RegisterEvent("LOOT_OPENED")
	LSLooter:RegisterEvent("LOOT_CLOSED")
	LSLooter:RegisterEvent("LOOT_SLOT_CLEARED")
	LSLooter:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	LSLooter:RegisterEvent("PLAYER_REGEN_DISABLED")
	LSLooter:RegisterEvent("PLAYER_REGEN_ENABLED")
	
	self:displayMain()
	self:displayLoot()
	LSMainFrame:Hide()
	LSLootFrame:Hide()
	
	
	if GetNumRaidMembers() > 0 then
		inRaid = true
	else 
		inRaid = false
	end
	
	SelectedLoot = 0
	inFight = false
	Rolling = false
	Rolls_count = 0
	
	_message(L["init"]);
end

function LSLooter:LSLooterSlashProcessorFunc(input)
	if input == "show" then
		LSMainFrame:Show()
	elseif input == "resetpos" then
		resetMainWindow()
		resetLootWindow()
	elseif input == "reset" then
		for index, value in pairs(self.db.profile.roster) do
			value._plus = 0
		end
		self:refreshPlus()
	else
		_message(L["LSLooter commands:"])
		_message(L["Reset penalties"]..": /lsl reset")
		_message(L["Show roster"]..": /lsl show")
		_message(L["Reset position"]..": /lsl resetpos")
	end
end

local function detectInstanceChange()
	local zone = GetRealZoneText()
	if zone == nil or zone == "" then
		LSLooter:ScheduleTimer(detectInstanceChange, 5)
		return
	else
		-- LSMainFrame:Hide() -- TODO: make option for this
		-- _message("Zone: "..GetCurrentMapAreaID())
		-- TODO: enable addon only in raid-zones
	end
end

function LSLooter:RAID_ROSTER_UPDATE ()
	if GetNumRaidMembers() > 0 then
		inRaid = true
		isML = false
	else 
		LSMainFrame:Hide()
		inRaid = false
		return
	end
	for index, value in pairs(self.db.profile.roster) do
		value._inRaid = false
	end
	for i = 1, GetNumRaidMembers(), 1 do
		local name, _, _, _, _, _, _, _, _, _, _isML = GetRaidRosterInfo(i)
		if (name == UnitName("player") and _isML) then
			isML = true
		end
		if self.db.profile.roster[name] == nil then
			self.db.profile.roster[name] = {
				_name = name,
				_plus = 0,
				_inRaid = true
			}
		else
			self.db.profile.roster[name]._inRaid = true
		end
	end
	LSLooter:refreshPlus()
end

function LSLooter:COMBAT_LOG_EVENT_UNFILTERED ()
	return
end

function LSLooter:CHAT_MSG_SYSTEM(self, event, arg1, ...)
	if SelectedLoot == 0 then return end -- nothing to roll for
	if Rolling then
		if string.find(event, L["rolls"]) and string.find(event, "%(1%-100%)") then
			local _, _, name, roll = string.find(event, "(.+) "..L["rolls"].." (%d+)") -- TODO: check this at enUS client
			Rolls_count = Rolls_count + 1
			
			if LSLooter.db.profile.rolls == nil then LSLooter.db.profile.rolls = {} end
				
			if LSLooter.db.profile.rolls[name] == nil then
				if Rolls_count == 11 then return end -- TODO: some improvements here
				LSLooter.db.profile.rolls[name] = {
					_name = name,
					_plus = 0,
					_roll = roll,
					_total = roll + LSLooter.db.profile.roster[name]._plus,
					_i = Rolls_count,
					_allow = true
				}
				LSLootFrame._names[Rolls_count]:SetText(name)
				LSLootFrame._status[Rolls_count]:SetText(roll)
				LSLootFrame._roll[Rolls_count]:SetText(roll + LSLooter.db.profile.roster[name]._plus)
				
				LSLootFrame._names[Rolls_count]:Show()
				LSLootFrame._status[Rolls_count]:Show()
				LSLootFrame._roll[Rolls_count]:Show()
				LSLootFrame._cancel[Rolls_count]:Show()
			else
				-- _message (name.." rerolling...") -- any penalities for rerolling?
			end
		end
	end
end

function LSLooter:LOOT_SLOT_CLEARED (self, arg1)
	_message("loot_cleared arg1 "..tostring(arg1))
	_message("loot_cleared selected "..SelectedLoot)
	if isML and inRaid then -- and LootSlotIsItem(arg1)
		_message("_pickedup = false")
		LSLooter.db.profile.loot[arg1]._pickedup = true
		for i = 1, #LSLooter.db.profile.loot, 1 do
			if LSLooter.db.profile.loot[i]._pickedup == false then
				SelectedLoot = i
				_message("new SelectedLoot = "..SelectedLoot)
				break
			end
		end
		_message("loot_cleared selected after "..SelectedLoot)
		LSLooter.LootDropDownMenu_Initialize()
	end
end

function LSLooter:LOOT_CLOSED () -- TODO: save current rolls if loot-window accidently closed
	
	if self.db.profile.loot then wipe(self.db.profile.loot) end
	self.db.profile.loot = nil
	SelectedLoot = 0
	self:LootDropDownMenu_Initialize()
	UIDropDownMenu_SetText(LSLooter.LootDropDownMenu, L["noitems"])
end

function LSLooter:LOOT_OPENED ()
	SelectedLoot = 1
	local y = 1
	if self.db.profile.loot then wipe(self.db.profile.loot) end
	self.db.profile.loot = {{}}
	if isML and inRaid then
		LSLootFrame:Show()
		for i = 1, GetNumLootItems() do
			if LootSlotIsItem(i) then
				itemName, _, itemRarity, _, _, _, _, _, _, _ = GetItemInfo(GetLootSlotLink(i))
				
				self.db.profile.loot[y] = {
					_i = i,
					_id = GetLootSlotLink(i), -- should be "_link"
					_pickedup = false,
					_winner = ""
				}
				
				y = y + 1
				
				if itemRarity == 2 then -- looting green-items -- TODO: add this in options
					for ci = 1, GetNumRaidMembers() do
						if (GetMasterLootCandidate(ci) == UnitName("player")) then
							GiveMasterLoot(i, ci)
						end
					end
				end
			end
		end
		UIDropDownMenu_SetSelectedID(LSLooter.LootDropDownMenu, 1)
		self.LootDropDownMenu_Initialize()
	end
end

function LSLooter:INSTANCE_ENCOUNTER_ENGAGE_UNIT ()
	local mob = nil
	if UnitExists("boss1") then mob = "boss1" end
	
	if mob and inRaid then
		inFight = true
	end
	return
end

function LSLooter:PLAYER_REGEN_DISABLED ()
	LSMainFrame:Hide()
end

function LSLooter:PLAYER_REGEN_ENABLED ()
	if inFight then
		LSMainFrame:Show()
		inFight = false
	end
end

function LSLooter:ZONE_CHANGED_NEW_AREA ()
	detectInstanceChange()
end
