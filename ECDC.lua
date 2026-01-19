local ADDON_NAME, addon = ...
local L

-- -----------------------------------------------------------------------------
-- TBC Anniversary 2.5.5 (and other Classic branches) API compatibility layer
-- -----------------------------------------------------------------------------
-- Spell API differences:
-- * Classic/TBC: GetSpellInfo(spellID) returns multiple values (name is 1st return)
-- * Retail: C_Spell.GetSpellName/GetSpellInfo may exist (often returning a table)
--
-- This addon only needs a reliable spell name + optional description for tooltips.
local function ECDC_GetSpellName(spellID)
    if C_Spell and type(C_Spell.GetSpellName) == "function" then
        return C_Spell.GetSpellName(spellID)
    end

    if type(GetSpellInfo) == "function" then
        local name = GetSpellInfo(spellID)
        if type(name) == "table" then
            return name.name
        end
        return name
    end

    return nil
end

local function ECDC_GetSpellDescription(spellID)
    -- Prefer global API if available (Classic)
    if type(GetSpellDescription) == "function" then
        local ok, desc = pcall(GetSpellDescription, spellID)
        if ok and desc and desc ~= "" then
            return desc
        end
    end

    -- Retail fallback
    if C_Spell and type(C_Spell.GetSpellDescription) == "function" then
        local ok, desc = pcall(C_Spell.GetSpellDescription, spellID)
        if ok and desc and desc ~= "" then
            return desc
        end
    end

    return nil
end

-- Chat/AddOn message API differences
local ECDC_RegisterAddonMessagePrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
local ECDC_SendAddonMessage = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage

local function ECDC_GetPlayerFullName()
    local name, realm = UnitName("player")
    if not name then return nil end

    -- Modern classic: UnitName may already include realm
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end

    -- Fallback: append current realm name without spaces
    local rn = (GetRealmName and GetRealmName()) or ""
    rn = rn and rn:gsub("%s", "") or ""
    if rn ~= "" then
        return name .. "-" .. rn
    end

    return name
end

-- Robust comm sender (INSTANCE_CHAT is not always available on older Classic branches)
local function ECDC_CommSend(guid, spellId, timestamp)
    if not ECDC_SendAddonMessage then return end
    local payload = format("%s+%s+%s", guid, spellId, timestamp)

    local function try(dist)
        if not dist then return false end
        local ok = pcall(ECDC_SendAddonMessage, "ECDC_Comm", payload, dist)
        return ok
    end

    if IsInInstance() then
        if try("INSTANCE_CHAT") then return end
        if IsInRaid() then
            try("RAID")
        else
            try("PARTY")
        end
        return
    end

    if IsInRaid() then
        if try("RAID") then return end
    end

    if IsInGroup() then
        try("PARTY")
    end
end

function ECDC_OnLoad(self)
	L = addon.L	

	ECDC_ToolTips = {};
	ECDC_ToolTipDetails = {};
	ECDC_ErrCountdown = 0;
	ECDC_UsedSkills = {};
	ECDC_UpdateInterval = 0.1;
	ECDC_TimeSinceLastUpdate = 0;
	ECDC_UnitIDs = {
		["player"] = 0,
		["party1"] = 0,
		["party2"] = 0,
		["party3"] = 0,
		["party4"] = 0,
		["arena1"] = 0,
		["arena2"] = 0,
		["arena3"] = 0,
		["arena4"] = 0,
		["arena5"] = 0};

	ECDC_LoadSkills();
	ECDC_Activate(self);	
end

function ECDC_ToggleStack(setPos)
	if (not ECDC_Pos or ECDC_Pos == nil) then
		ECDC_Pos = "Hori"
	end
	
	if (not ECDC_Padding or ECDC_Padding == nil) then
		ECDC_Padding = 0;
	end
	local pa = ECDC_Padding;
	
	if (setPos == "Verti") and (ECDC_Row == 1 or nil) then
		ECDC_Pos = "Verti";
		ECDC_Tex1:ClearAllPoints(); ECDC_Tex1:SetPoint("TOP", "ECDC", "BOTTOM", 0, 3);
		ECDC_Tex2:ClearAllPoints(); ECDC_Tex2:SetPoint("TOP", "ECDC_Tex1", "BOTTOM", 0, -pa);
		ECDC_Tex3:ClearAllPoints(); ECDC_Tex3:SetPoint("TOP", "ECDC_Tex2", "BOTTOM", 0, -pa);
		ECDC_Tex4:ClearAllPoints(); ECDC_Tex4:SetPoint("TOP", "ECDC_Tex3", "BOTTOM", 0, -pa);
		ECDC_Tex5:ClearAllPoints(); ECDC_Tex5:SetPoint("TOP", "ECDC_Tex4", "BOTTOM", 0, -pa);
		ECDC_Tex6:ClearAllPoints(); ECDC_Tex6:SetPoint("TOP", "ECDC_Tex5", "BOTTOM", 0, -pa);
		ECDC_Tex7:ClearAllPoints(); ECDC_Tex7:SetPoint("TOP", "ECDC_Tex6", "BOTTOM", 0, -pa);
		ECDC_Tex8:ClearAllPoints(); ECDC_Tex8:SetPoint("TOP", "ECDC_Tex7", "BOTTOM", 0, -pa);
		ECDC_Tex9:ClearAllPoints(); ECDC_Tex9:SetPoint("TOP", "ECDC_Tex8", "BOTTOM", 0, -pa);
		ECDC_Tex10:ClearAllPoints(); ECDC_Tex10:SetPoint("TOP", "ECDC_Tex9", "BOTTOM", 0, -pa);
	elseif (setPos == "Verti") and (ECDC_Row == 2) then
		ECDC_Pos = "Verti";
		ECDC_Tex1:ClearAllPoints(); ECDC_Tex1:SetPoint("TOP", "ECDC", "BOTTOM", 0, 3);
		ECDC_Tex2:ClearAllPoints(); ECDC_Tex2:SetPoint("TOP", "ECDC_Tex1", "BOTTOM", 0, -pa);
		ECDC_Tex3:ClearAllPoints(); ECDC_Tex3:SetPoint("TOP", "ECDC_Tex2", "BOTTOM", 0, -pa);
		ECDC_Tex4:ClearAllPoints(); ECDC_Tex4:SetPoint("TOP", "ECDC_Tex3", "BOTTOM", 0, -pa);
		ECDC_Tex5:ClearAllPoints(); ECDC_Tex5:SetPoint("TOP", "ECDC_Tex4", "BOTTOM", 0, -pa);
		
		ECDC_Tex6:ClearAllPoints(); ECDC_Tex6:SetPoint("LEFT", "ECDC_Tex1", "RIGHT", pa, 0); -- new row
		ECDC_Tex7:ClearAllPoints(); ECDC_Tex7:SetPoint("TOP", "ECDC_Tex6", "BOTTOM", 0, -pa);
		ECDC_Tex8:ClearAllPoints(); ECDC_Tex8:SetPoint("TOP", "ECDC_Tex7", "BOTTOM", 0, -pa);
		ECDC_Tex9:ClearAllPoints(); ECDC_Tex9:SetPoint("TOP", "ECDC_Tex8", "BOTTOM", 0, -pa);
		ECDC_Tex10:ClearAllPoints(); ECDC_Tex10:SetPoint("TOP", "ECDC_Tex9", "BOTTOM", 0, -pa);
	elseif (setPos == "Hori") and (ECDC_Row == 1 or nil) then
		ECDC_Pos = "Hori";
		ECDC_Tex1:ClearAllPoints(); ECDC_Tex1:SetPoint("LEFT", "ECDC", "RIGHT", 0, 0);
		ECDC_Tex2:ClearAllPoints(); ECDC_Tex2:SetPoint("LEFT", "ECDC_Tex1", "RIGHT", pa, 0);
		ECDC_Tex3:ClearAllPoints(); ECDC_Tex3:SetPoint("LEFT", "ECDC_Tex2", "RIGHT", pa, 0);
		ECDC_Tex4:ClearAllPoints(); ECDC_Tex4:SetPoint("LEFT", "ECDC_Tex3", "RIGHT", pa, 0);
		ECDC_Tex5:ClearAllPoints(); ECDC_Tex5:SetPoint("LEFT", "ECDC_Tex4", "RIGHT", pa, 0);
		ECDC_Tex6:ClearAllPoints(); ECDC_Tex6:SetPoint("LEFT", "ECDC_Tex5", "RIGHT", pa, 0);
		ECDC_Tex7:ClearAllPoints(); ECDC_Tex7:SetPoint("LEFT", "ECDC_Tex6", "RIGHT", pa, 0);
		ECDC_Tex8:ClearAllPoints(); ECDC_Tex8:SetPoint("LEFT", "ECDC_Tex7", "RIGHT", pa, 0);
		ECDC_Tex9:ClearAllPoints(); ECDC_Tex9:SetPoint("LEFT", "ECDC_Tex8", "RIGHT", pa, 0);
		ECDC_Tex10:ClearAllPoints(); ECDC_Tex10:SetPoint("LEFT", "ECDC_Tex9", "RIGHT", pa, 0);
	elseif (setPos == "Hori") and (ECDC_Row == 2) then
		ECDC_Pos = "Hori";
		ECDC_Tex1:ClearAllPoints(); ECDC_Tex1:SetPoint("LEFT", "ECDC", "RIGHT", 0, 0);
		ECDC_Tex2:ClearAllPoints(); ECDC_Tex2:SetPoint("LEFT", "ECDC_Tex1", "RIGHT", pa, 0);
		ECDC_Tex3:ClearAllPoints(); ECDC_Tex3:SetPoint("LEFT", "ECDC_Tex2", "RIGHT", pa, 0);
		ECDC_Tex4:ClearAllPoints(); ECDC_Tex4:SetPoint("LEFT", "ECDC_Tex3", "RIGHT", pa, 0);
		ECDC_Tex5:ClearAllPoints(); ECDC_Tex5:SetPoint("LEFT", "ECDC_Tex4", "RIGHT", pa, 0);
		
		ECDC_Tex6:ClearAllPoints(); ECDC_Tex6:SetPoint("TOP", "ECDC_Tex1", "BOTTOM", 0, -pa); -- new row
		ECDC_Tex7:ClearAllPoints(); ECDC_Tex7:SetPoint("LEFT", "ECDC_Tex6", "RIGHT", pa, 0);
		ECDC_Tex8:ClearAllPoints(); ECDC_Tex8:SetPoint("LEFT", "ECDC_Tex7", "RIGHT", pa, 0);
		ECDC_Tex9:ClearAllPoints(); ECDC_Tex9:SetPoint("LEFT", "ECDC_Tex8", "RIGHT", pa, 0);
		ECDC_Tex10:ClearAllPoints(); ECDC_Tex10:SetPoint("LEFT", "ECDC_Tex9", "RIGHT", pa, 0);
	end
end
addon.ECDC_ToggleStack = ECDC_ToggleStack;

function ECDC_Rows(amount)
	if (amount == 1) then
		ECDC_Row = 1;
		ECDC_ToggleStack(ECDC_Pos)
	elseif (amount == 2) then
		ECDC_Row = 2;
		ECDC_ToggleStack(ECDC_Pos)
	else
		ECDC_Row = 1;
		ECDC_ToggleStack(ECDC_Pos)
	end
end
addon.ECDC_Rows = ECDC_Rows;

function ECDC_ToggleVisi(setVisi)
	local button = _G[("ECDC_Button")];
	local frame = _G[("ECDC")];
	if (setVisi == "show") then
		ECDC_Visi = "show";
		frame:EnableMouse(true)
		button:Show();
	elseif (setVisi == "hide") then
		ECDC_Visi = "hide";
		frame:EnableMouse(false)
		button:Hide();
	else
		frame:EnableMouse(true)
		button:Show();
	end
end
addon.ECDC_ToggleVisi = ECDC_ToggleVisi;

function ECDC_SetSize(size)
	if size == nil then
		size = 1
	end
	ECDC_Size = size
	for i=1,10 do
		_G[("ECDC_Frame"..i)]:SetScale(ECDC_Size);
		_G[("ECDC_CD"..i)]:SetScale(ECDC_Size);
		_G[("ECDC_Tex"..i)]:SetScale(ECDC_Size);
	end
end
addon.ECDC_SetSize = ECDC_SetSize;

function ECDC_Activate(self)
	ECDC_Button:SetNormalTexture("Interface\\Buttons\\UI-MicroButton-Abilities-Up.blp");

	self:RegisterEvent("CHAT_MSG_ADDON");
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("PLAYER_LOGIN");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("PLAYER_TARGET_CHANGED");
 end

function ECDC_ToolTip(self, tooltipnum)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:AddLine(ECDC_ToolTips[tooltipnum]);
	GameTooltip:AddLine(ECDC_ToolTipDetails[tooltipnum], .8, .8, .8, 1);
	GameTooltip:Show();
end

function ECDC_ClickIcon(self, button, frameid)
	if button=='RightButton' and IsShiftKeyDown() then
		for k, v in pairs(ECDC_UsedSkills) do
				if (UnitGUID("target") == v.player and ECDC_ToolTips[frameid] == ECDC_GetLocalizedSpellName(v.skill)) then
				v.countdown = 0
			end
		end
	end
end

function ECDC_TableContains(guid, spell, spelltime)
	local index = 1;
	while ECDC_UsedSkills[index] do
		if (guid == ECDC_UsedSkills[index].player and spell == ECDC_UsedSkills[index].skill and spelltime >= ECDC_UsedSkills[index].started and spelltime <= (ECDC_UsedSkills[index].started + 4)) then
			return true;
		end
		index = index + 1;
	end
	return false;
end

function ECDC_OnEvent(self, event, arg1, message, channel, sender, ...)
	local _, subevent, _, sourceGUID, sourceName, _, _, destGUID, _, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()
	
	if (event == "ADDON_LOADED" and arg1 == ADDON_NAME) then
		ECDC_ToggleStack(ECDC_Pos);
		ECDC_ToggleVisi(ECDC_Visi);
		ECDC_SetSize(ECDC_Size);
		ECDC_Rows(ECDC_Row);
		ECDC_CreateOptionsMenu();
		
		self:UnregisterEvent("ADDON_LOADED")
	end

	if (event == "PLAYER_LOGIN") then
		if ECDC_RegisterAddonMessagePrefix then ECDC_RegisterAddonMessagePrefix("ECDC_Comm") end
	end
	
	if (event == "PLAYER_ENTERING_WORLD") or (event == "PLAYER_TARGET_CHANGED" and not UnitExists("target")) then
		for k, v in pairs(ECDC_UsedSkills) do
			local timeleft = (v.countdown - (GetServerTime() - v.started));
			if (timeleft <= 0) then
				table.remove(ECDC_UsedSkills, k) -- delete old unused data. We use table.remove to keep the order.
			end
		end
	end
	
	if (event == "PLAYER_ENTERING_WORLD") then
        -- TBC Classic cleanup
		if (select(2, IsInInstance()) == "arena") then
			-- TBC Classic does not support C_PvP arena cooldown info.
            -- We rely solely on CombatLog for tracking.
			for k, v in pairs(ECDC_UsedSkills) do
				ECDC_UsedSkills[k] = nil -- reset all cds upon entering arena
			end
			
			for k, v in pairs(ECDC_UnitIDs) do
				ECDC_UnitIDs[k] = 0
			end
		end
	end
	
	if (event == "PLAYER_TARGET_CHANGED") then
		for k, v in ipairs(ECDC_ToolTips) do
			ECDC_ToolTips[k] = nil -- clean up the tooltips
		end
		
		for k, v in ipairs(ECDC_ToolTipDetails) do
			ECDC_ToolTipDetails[k] = nil
		end
	end
	
	if (event == "CHAT_MSG_ADDON") then
		if (arg1 == "ECDC_Comm") then
			local pName = UnitName("player")
			local pFull = ECDC_GetPlayerFullName()
			if sender == pName or (pFull and sender == pFull) then
				return
			end
			local getGUID, getSpellStr, getTimeStr = strsplit("+", message)
			local getTime = tonumber(getTimeStr)
			local getSpell = tonumber(getSpellStr)
			
			if getSpell ~= nil then
				if (ECDC_GetSkillCooldown(getSpell) > 10) then
					if (ECDC_TableContains(getGUID, getSpell, getTime) ~= true) then
					table.insert(ECDC_UsedSkills, {player = getGUID, skill = getSpell, info = ECDC_GetInfo(getSpell), texture = ECDC_GetTexture(getSpell), countdown = ECDC_GetSkillCooldown(getSpell), started = getTime});
						if (getSpell == 14185 or getSpell == 11958 or getSpell == 24531 or getSpell == 23989) then
							ECDC_FinishCd(getGUID, getTime)
						end
					end
				end
			end
		end
	end
	
	if (subevent == "SPELL_CAST_SUCCESS") then
		if ((ECDC_GetSkillCooldown(spellId) ~= ECDC_ErrCountdown) and not ECDC_DelayedCd(spellId)) then
			table.insert(ECDC_UsedSkills, {player = sourceGUID, skill = spellId, info = ECDC_GetInfo(spellId), texture = ECDC_GetTexture(spellId), countdown = ECDC_GetSkillCooldown(spellId), started = GetServerTime()});
			
			if (select(2, IsInInstance()) == "arena") then
				for i=1,5 do
					local unitID = "arenapet"..i
					if (UnitExists(unitID) and UnitGUID(unitID) == sourceGUID) then
						local petOwnerGUID = UnitGUID("arena"..i)
						table.insert(ECDC_UsedSkills, {player = petOwnerGUID, skill = spellId, info = ECDC_GetInfo(spellId), texture = ECDC_GetTexture(spellId), countdown = ECDC_GetSkillCooldown(spellId), started = GetServerTime()});
						ECDC_CommSend(petOwnerGUID, spellId, GetServerTime());
					end
				end
			end
			
			if not IsResting() then ECDC_CommSend(sourceGUID, spellId, GetServerTime()); end
		end
		
		if (spellId == 14185 or spellId == 11958 or spellId == 24531 or spellId == 23989) then
			ECDC_FinishCd(sourceGUID, GetServerTime())
		end
	end
	
	if (subevent == "SPELL_AURA_REMOVED" or subevent == "SPELL_AURA_BROKEN" or subevent == "SPELL_AURA_BROKEN_SPELL") then
		if ((ECDC_GetSkillCooldown(spellId) ~= ECDC_ErrCountdown) and ECDC_DelayedCd(spellId)) then
			if (ECDC_TableContains(destGUID, spellId, GetServerTime()) ~= true) then
				table.insert(ECDC_UsedSkills, {player = destGUID, skill = spellId, info = ECDC_GetInfo(spellId), texture = ECDC_GetTexture(spellId), countdown = ECDC_GetSkillCooldown(spellId), started = GetServerTime()});
				if not IsResting() then ECDC_CommSend(destGUID, spellId, GetServerTime()); end
			end
		end
	end
	
	if (subevent == "SPELL_AURA_APPLIED") then
		if ((ECDC_GetSkillCooldown(spellId) ~= ECDC_ErrCountdown) and (spellId == 11196 or spellId == 25771 or spellId == 45182 or spellId == 34936)) then
			table.insert(ECDC_UsedSkills, {player = destGUID, skill = spellId, info = ECDC_GetInfo(spellId), texture = ECDC_GetTexture(spellId), countdown = ECDC_GetSkillCooldown(spellId), started = GetServerTime()});
			if (IsInInstance()) then
				if not IsResting() then ECDC_CommSend(destGUID, spellId, GetServerTime()); end
			elseif (not IsInInstance() and not IsResting()) then
				if not IsResting() then ECDC_CommSend(destGUID, spellId, GetServerTime()); end
			end
		end
	end
    
    -- REMOVED: ARENA_COOLDOWNS_UPDATE logic (C_PvP is not available in TBC Classic)
end

function ECDC_OnUpdate(elapsed)
	ECDC_TimeSinceLastUpdate = ECDC_TimeSinceLastUpdate + elapsed;
	if (ECDC_TimeSinceLastUpdate > ECDC_UpdateInterval) then
		ECDC_TimeSinceLastUpdate = 0;
		-- Spit out the infoz
		local i = 1;
		for k, v in pairs(ECDC_UsedSkills) do
			--print(k,v)
			local timeleft = (v.countdown - (GetServerTime() - v.started));
			local className, _, classID = UnitClass("target")
			local skillName = ECDC_GetLocalizedSpellName(v.skill)
			if (ECDC_isSpellEnabled(skillName)) then
				--	  Only show CD for our target if there is time left on the CD      Loop through Stuff           Warrior enrage isnt a CD, Druid Enrage is!
				if ((v.player == UnitGUID("target")) and (UnitPlayerControlled("target") or UnitIsPlayer("target")) and (timeleft > 0) and (timeleft ~= nil) and (i < 11) and not(classID ~= 2 and v.skill == 25771) and (ECDC_ToolTips[(i-1)] ~= skillName) and (ECDC_ToolTips[(i-2)] ~= skillName) and (ECDC_ToolTips[(i-3)] ~= skillName)) then
					ECDC_ToolTips[i] = skillName;
					ECDC_ToolTipDetails[i] = v.info;
					if (timeleft > 60) then
						--timeleft = floor((timeleft/60)*10)/10;
						_G[("ECDC_CD"..i)]:SetTextColor(1, 1, 1);
					elseif (timeleft < 6) then
						_G[("ECDC_CD"..i)]:SetTextColor(1, 0, 0);
					else
						_G[("ECDC_CD"..i)]:SetTextColor(1, 1, 0);
					end
					_G[("ECDC_CD"..i)]:SetText((timeleft < 60 and math.floor(timeleft)) or (timeleft < 3600 and math.ceil(timeleft / 60).."m") or math.ceil(timeleft / 3600).."h");
					_G[("ECDC_Tex"..i)]:SetTexture("Interface\\Icons\\"..v.texture);
					if (ECDC_Border == true) then
						_G[("ECDC_Tex"..i)]:SetTexCoord(0.07, 0.93, 0.07, 0.93)
					else
						_G[("ECDC_Tex"..i)]:SetTexCoord(0, 1, 0, 1)
					end
					_G[("ECDC_Frame"..i)]:Show();
					_G[("ECDC_CD"..i)]:Show();
					_G[("ECDC_Tex"..i)]:Show();
					if UnitAffectingCombat("player") and not IsShiftKeyDown() then
						_G[("ECDC_Frame"..i)]:EnableMouse(false)
					else
						_G[("ECDC_Frame"..i)]:EnableMouse(true)
					end
					i = i + 1;
				end
				
				--if ((v.player == UnitGUID("focus")) and (UnitPlayerControlled("focus") or UnitIsPlayer("focus")) and (timeleft > 0) and (timeleft ~= nil) and (i < 11) and not(classID ~= 2 and v.skill == 25771) and (ECDC_ToolTips[(i-1)] ~= v.skill) and (ECDC_ToolTips[(i-2)] ~= v.skill) and (ECDC_ToolTips[(i-3)] ~= v.skill)) then
					-- TODO: focus stuff go here
				--end
			end
		end
		
		if (ECDC_ShowTestIcons and InCombatLockdown()) then
			ECDC_ShowTestIcons = false
			_G["ECDC_p1_checkbox2"]:SetChecked(false)
		end
		
		while (i < 11 and not ECDC_ShowTestIcons) do
			_G[("ECDC_Frame"..i)]:Hide();
			_G[("ECDC_CD"..i)]:Hide();
			_G[("ECDC_Tex"..i)]:Hide();
			i = i + 1;
		end
	end
end

function ECDC_GetLocalizedSpellName(skill)
	local name = ECDC_GetSpellName(skill)
	
	if name == nil then -- use non-localized name as a fallback
		for k, v in pairs(ECDC_Skills) do 
			if (tContains(v.id, skill)) then
				name = v.name;
			end
		end
	end
	return name;
end
addon.ECDC_GetLocalizedSpellName = ECDC_GetLocalizedSpellName;

function ECDC_GetSpellId(skill)
	for k, v in pairs(ECDC_Skills) do
		if v.name == skill then
			SkillId = v.id[1];
		end
	end
	return SkillId;
end

function ECDC_GetTexture(skill)
	for k, v in pairs(ECDC_Skills) do 
		if (tContains(v.id, skill)) then
			SkillTexture = v.icon;
		end
	end;
	return SkillTexture;	
end

function ECDC_GetInfo(skill)
    -- TBC Classic compatible method
	local SkillInfo = ECDC_GetSpellDescription(skill)
	
	if SkillInfo == nil or SkillInfo == "" then -- use non-localized desc as a fallback
		for k, v in pairs(ECDC_Skills) do 
			if (tContains(v.id, skill)) then
				SkillInfo = v.desc;
			end
		end
	end
	return SkillInfo;	
end
addon.ECDC_GetInfo = ECDC_GetInfo;

function ECDC_GetSkillCooldown(skill)
	for k, v in pairs(ECDC_Skills) do 
		if (tContains(v.id, skill)) then
			SkillCountdown = v.cooldown;
			break;
		else
			SkillCountdown = ECDC_ErrCountdown;
		end
	end;
	return SkillCountdown;
end

function ECDC_DelayedCd(skill)
	for _, spell in ipairs(ECDC_DelayedCds) do
		if (skill == spell) then
			return true;
		end
	end
	return false;
end

function ECDC_FinishCd(sourceGUID, getTime)
	for k, v in pairs(ECDC_UsedSkills) do
		for _, spell in ipairs(ECDC_FinishCds) do
			if (sourceGUID == v.player and spell == v.skill and getTime >= v.started) then
				v.countdown = 0
			end
		end
	end
end

function ECDC_isSpellEnabled(spellName)
	-- savedOptions is loaded via SavedVariablesPerCharacter; on a fresh character it
	-- can be nil until the options file initializes defaults.
	if not savedOptions then
		return true
	end

	local function enabledIn(class)
		return savedOptions[class] and savedOptions[class][spellName]
	end

	return enabledIn("Warrior") or enabledIn("Warlock") or enabledIn("Shaman")
		or enabledIn("Rogue") or enabledIn("Priest") or enabledIn("Paladin")
		or enabledIn("Mage") or enabledIn("Hunter") or enabledIn("Druid")
		or enabledIn("Miscellaneous") or enabledIn("Racials") or enabledIn("Trinkets")
end

function ECDC_OnDragStart()
	ECDC:StartMoving()
end

function ECDC_OnDragStop()
	ECDC:StopMovingOrSizing()
end

function ECDC_LoadSkills()
	ECDC_Skills = {
		-- Exclusively Talent Cooldowns
		{id = {13877}, name = L["Blade Flurry"], cooldown = 120, desc = "Increases your attack speed by 20%.  In addition, attacks strike an additional nearby opponent.  Lasts 15 sec.", icon = "Ability_Warrior_PunishingBlow"},
		{id = {13750}, name = L["Adrenaline Rush"], cooldown = (5*60), desc = "Increases your Energy regeneration rate by 100% for 15 sec.", icon = "Spell_Shadow_ShadowWordDominate"},
		{id = {14185}, name = L["Preparation"], cooldown = 600, desc = "Finishes cooldown of all other Rogue abilities", icon = "spell_shadow_antishadow"},
		{id = {14278}, name = L["Ghostly Strike"], cooldown = 20, desc = "A strike that deals 125% weapon damage and increases your chance to dodge by 15% for 7 sec.  Awards 1 combo point.", icon = "Spell_Shadow_Curse"},
		{id = {14183}, name = L["Premeditation"], cooldown = 120, desc = "Adds 2 combo points to your target", icon = "Spell_Shadow_Possession"},
		{id = {14177}, name = L["Cold Blood"], cooldown = 180, desc = "Increases the critical strike chance of your next Sinister Strike, Backstab, Ambush, or Eviscerate by 100%.", icon = "Spell_Ice_Lament"},
		{id = {14251}, name = L["Riposte"], cooldown = 6, desc = "A strike that becomes active after parrying an opponent's attack.  This attack deals 150% weapon damage and disarms the target for 6 sec.", icon = "ability_warrior_challange"},
		{id = {36554}, name = L["Shadowstep"], cooldown = 30, desc = "Attempts to step through the shadows and reappear behind your enemy and increases movement speed by 70% for 3 sec.  The damage of your next ability is increased by 20% and the threat caused is reduced by 50%.  Lasts 10 sec.", icon = "ability_rogue_shadowstep"},
		{id = {45182}, name = L["Cheating Death"], cooldown = 60, desc = "All damage taken reduced by 90%.", icon = "ability_rogue_cheatdeath"},

		{id = {19574}, name = L["Bestial Wrath"], cooldown = 120, desc = "Send your pet into a rage causing 50% additional damage for 18 sec.  While enraged, the beast does not feel pity or remorse or fear and it cannot be stopped unless killed.", icon = "Ability_Druid_FerociousBite"},
		{id = {19577}, name = L["Intimidation"], cooldown = 60, desc = "Command your pet to intimidate the target on the next successful melee attack, causing a high amount of threat and stunning the target for 3 sec.", icon = "Ability_Devour"},
		{id = {19263}, name = L["Deterrence"], cooldown = (5*60), desc = "When activated, increases your Dodge and Parry chance by 25% for 10 sec.", icon = "Ability_whirlwind"},
		{id = {19503}, name = L["Scatter Shot"], cooldown = 30, desc = "A short-range shot that deals 50% weapon damage and disorients the target for 4 sec.  Any damage caused will remove the effect.  Turns off your attack when used.", icon = "Ability_golemstormbolt"},
		{id = {19434, 20900, 20901, 20902, 20903, 20904, 27065}, name = L["Aimed Shot"], cooldown = 6, desc = "An aimed shot that increases ranged damage by 870 and reduces healing done to that target by 50%.  Lasts 10 sec.", icon = "inv_spear_07"},
		{id = {34490}, name = L["Silencing Shot"], cooldown = 20, desc = "A shot that deals 50% weapon damage and Silences the target for 3 sec.", icon = "ability_theblackarrow"},
		{id = {19306, 20909, 20910}, name = L["Counterattack"], cooldown = 5, desc = "A strike that becomes active after parrying an opponent's attack. This attack deals 110 damage and immobilizes the target for 5 sec. Counterattack cannot be blocked, dodged, or parried.", icon = "Ability_Warrior_Challange"},
		{id = {19386, 24132, 24133, 27068}, name = L["Wyvern Sting"], cooldown = 120, desc = "A stinging shot that puts the target to sleep for 12 sec. Any damage will cancel the effect. When the target wakes up, the Sting causes 600 Nature damage over 12 sec. Only usable out of combat. Only one Sting per Hunter can be active on the target at a time.", icon = "INV_Spear_02"},
		{id = {23989}, name = L["Readiness"], cooldown = 300, desc = "When activated, this ability immediately finishes the cooldown on your other Hunter abilities.", icon = "ability_hunter_readiness"},
		
		{id = {12975}, name = L["Last Stand"], cooldown = 480, desc = "This ability temporarily grants you 30% of your maximum hit points for 20 seconds.  After the effect expires, the hit points are lost.", icon = "Spell_Holy_AshesToAshes"},
		{id = {12328}, name = L["Sweeping Strikes"], cooldown = 30, desc = "Your next 5 melee attacks strike an additional nearby opponent.", icon = "ability_rogue_slicedice"},
		{id = {12292}, name = L["Death Wish"], cooldown = 180, desc = "When activated, increases your physical damage by 20% and makes you immune to Fear effects, but lowers your armor and all resistances by 20%.  Lasts 30 sec.", icon = "spell_shadow_deathpact"},
		{id = {12809}, name = L["Concussion Blow"], cooldown = 45, desc = "Stuns the opponent for 5 sec.", icon = "ability_thunderbolt"},

		{id = {14751}, name = L["Inner Focus"], cooldown = 180, desc = "Reduces the Mana cost of your next spell by 100% and increases its critical effect chance by 25% if it is capable of a critical effect.", icon = "Spell_Frost_WindWalkOn"},
		{id = {10060}, name = L["Power Infusion"], cooldown = 180, desc = "Infuses the target with power, increasing their spell damage and healing by 20%.  Lasts 15 sec.", icon = "Spell_Holy_PowerInfusion"},
		{id = {15487}, name = L["Silence"], cooldown = 45, desc = "Silences the target, preventing them from casting spells for 5 sec.", icon = "spell_shadow_impphaseshift"},
		{id = {33206}, name = L["Pain Suppression"], cooldown = 120, desc = "Instantly reduces a friendly target's threat by 5%, reduces all damage taken by 40% and increases resistance to Dispel mechanics by 65% for 8 sec.", icon = "spell_holy_painsupression"},
		{id = {724, 27870, 27871, 28275}, name = L["Lightwell"], cooldown = 360, desc = "Creates a Holy Lightwell.  Members of your raid or party can click the Lightwell to restore 2361 health over 6 sec.  Any damage taken will cancel the effect.  Lightwell lasts for 3 min or 5 charges.", icon = "spell_holy_summonlightwell"},

		{id = {16166}, name = L["Elemental Mastery"], cooldown = 180, desc = "This spell gives your next Fire, Frost, or Nature damage spell a 100% critical strike chance and reduces the mana cost by 100%.", icon = "Spell_Nature_WispHeal"},
		{id = {17364}, name = L["Stormstrike"], cooldown = 9, desc = "Gives you an extra attack.  In addition, the next 2 sources of Nature damage dealt to the target are increased by 20%.  Lasts 12 sec.", icon = "ability_shaman_stormstrike"},
		{id = {16188}, name = L["Nature's Swiftness"], cooldown = 180, desc = "Next NATURE spell is instant cast", icon = "Spell_Nature_RavenForm"},
		{id = {30823}, name = L["Shamanistic Rage"], cooldown = 120, desc = "Reduces all damage taken by 30% and gives your successful melee attacks a chance to regenerate mana equal to 30% of your attack power.  Lasts 15 sec.", icon = "spell_nature_shamanrage"},
		{id = {16190}, name = L["Mana Tide Totem"], cooldown = (5*60), desc = "Summons a Mana Tide Totem with 5 health at the feet of the caster for 12 sec that restores 290 mana every 3 seconds to group members within 20 yards.", icon = "Spell_Frost_SummonWaterElemental"},

		{id = {18708}, name = L["Fel Domination"], cooldown = (15*60), desc = "Your next Imp, Voidwalker, Succubus, or Felhunter Summon spell has its casting time reduced by 5.5 sec and its Mana cost reduced by 50%.", icon = "Spell_Nature_RemoveCurse"},
		{id = {18288}, name = L["Amplify Curse"], cooldown = 180, desc = "Increases the effect of your next Curse of Weakness or Curse of Agony by 50%, or your next Curse of Exhaustion by 20%.  Lasts 30 sec.", icon = "spell_shadow_contagion"},
		{id = {17877, 18867, 18868, 18869, 18870, 18871, 27263, 30546}, name = L["Shadowburn"], cooldown = 15, desc = "Instantly blasts the target for 450 to 502 Shadow damage. If the target dies within 5 sec of Shadowburn, and yields experience or honor, the caster gains a Soul Shard.", icon = "Spell_Shadow_ScourgeBuild"},
		{id = {17962, 18930, 18931, 18932, 27266, 30912}, name = L["Conflagrate"], cooldown = 10, desc = "Ignites a target that is already afflicted by Immolate, dealing 447 to 557 Fire damage and consuming the Immolate spell.", icon = "Spell_Fire_Fireball"},
		{id = {30283, 30413, 30414}, name = L["Shadowfury"], cooldown = 20, desc = "Shadowfury is unleashed, causing 612 to 728 Shadow damage and stunning all enemies within 8 yds for 2 sec.", icon = "spell_shadow_shadowfury"},
		{id = {34936}, name = L["Backlash"], cooldown = 8, desc = "Your next Shadow Bolt or Incinerate spell has its cast time reduced by 100%.", icon = "spell_fire_playingwithfire"},

		{id = {20216}, name = L["Divine Favor"], cooldown = 120, desc = "Gives your next Flash of Light, Holy Light, or Holy Shock spell a 100% critical effect chance.", icon = "Spell_Holy_Heal"},
		{id = {20473, 20929, 20930, 27174, 33072}, name = L["Holy Shock"], cooldown = 15, desc = "Blasts the target with Holy energy, causing 365 to 395 Holy damage to an enemy, or 365 to 395 healing to an ally.", icon = "Spell_Holy_SearingLight"},
		{id = {20925, 20927, 20928, 27179}, name = L["Holy Shield"], cooldown = 10, desc = "Increases chance to block by 30% for 10 sec, and deals 130 Holy damage for each attack blocked while active.  Damage caused by Holy Shield causes 20% additional threat.  Each block expends a charge.  4 charges.", icon = "Spell_Holy_BlessingOfProtection"},
		{id = {20066}, name = L["Repentance"], cooldown = 60, desc = "Puts the enemy target in a state of meditation, incapacitating them for up to 6 sec.  Any damage caused will awaken the target.  Only works against Humanoids.", icon = "Spell_Holy_PrayerOfHealing"},
		{id = {31842}, name = L["Divine Illumination"], cooldown = 180, desc = "Reduces the mana cost of all spells by 50% for 15 sec.", icon = "spell_holy_divineillumination"},
		{id = {31935, 32699, 32700}, name = L["Avenger's Shield"], cooldown = 30, desc = "Hurls a holy shield at the enemy, dealing 494 to 602 Holy damage, Dazing them and then jumping to additional nearby enemies.  Affects 3 total targets.  Lasts 6 sec.", icon = "spell_holy_avengersshield"},
		{id = {35395}, name = L["Crusader Strike"], cooldown = 6, desc = "An instant strike that causes 110% weapon damage and refreshes all Judgements on the target.", icon = "spell_holy_crusaderstrike"},

		{id = {29166}, name = L["Innervate"], cooldown = (6*60), desc = "Increases the target's Mana regeneration by 400% and allows 100% of the target's Mana regeneration to continue while casting.  Lasts 20 sec.", icon = "Spell_Nature_Lightning"},
		{id = {16857, 17390, 17391, 17392, 27011}, name = L["Faerie Fire (Feral)"], cooldown = 6, desc = "Decrease the armor of the target by 505 for 40 sec.  While affected, the target cannot stealth or turn invisible.", icon = "Spell_Nature_FaerieFire"},
		{id = {16979}, name = L["Feral Charge"], cooldown = 15, desc = "Causes you to charge an enemy, immobilizing and interrupting any spell being cast for 4 sec.", icon = "Ability_Hunter_Pet_Bear"},
		{id = {18562}, name = L["Swiftmend"], cooldown = 15, desc = "Consumes a Rejuvenation or Regrowth effect on a friendly target to instantly heal them an amount equal to 12 sec. of Rejuvenation or 18 sec. of Regrowth.", icon = "Inv_Relics_IdolOfRejuvenation"},
		{id = {17116}, name = L["Nature's Swiftness"], cooldown = 180, desc = "Next NATURE spell is instant cast", icon = "Spell_Nature_RavenForm"},
		{id = {16689, 16810, 16811, 16812, 16813, 17329, 27009}, name = L["Nature's Grasp"], cooldown = 60, desc = "While active, any time an enemy strikes the caster they have a 35% chance to become afflicted by Entangling Roots (Rank 6). Only useable outdoors. 1 charge. Lasts 45 sec.", icon = "Spell_Nature_NaturesWrath"},
		{id = {33831}, name = L["Force of Nature"], cooldown = 180, desc = "Summons 3 treants to attack enemy targets for 30 sec.", icon = "ability_druid_forceofnature"},

		{id = {12043}, name = L["Presence of Mind"], cooldown = 180, desc = "Your next Mage spell with a casting time less than 10 sec becomes an instant cast spell.", icon = "Spell_Nature_EnchantArmor"},
		{id = {12042}, name = L["Arcane Power"], cooldown = 180, desc = "Your spells deal 30% more damage while costing 30% more mana to cast.  This effect lasts 15 sec.", icon = "Spell_Nature_Lightning"},
		{id = {11129}, name = L["Combustion"], cooldown = 180, desc = "This spell causes each of your Fire damage spell hits to increase your critical strike chance with Fire damage spells by 10%.  This effect lasts until you have caused 3 critical strikes with Fire spells.", icon = "Spell_Fire_SealOfFire"},
		{id = {11958}, name = L["Cold Snap"], cooldown = 384, desc = "This spell finishes the cooldown on all of your Frost spells.", icon = "Spell_Frost_WizardMark"},
		{id = {45438}, name = L["Ice Block"], cooldown = 240, desc = "You become encased in a block of ice, protecting you from all physical attacks and spells for 10 sec, but during that time you cannot attack, move or cast spells.", icon = "Spell_Frost_Frost"},
		{id = {11113, 13018, 13019, 13020, 13021, 27133, 33933}, name = L["Blast Wave"], cooldown = 30, desc = "A wave of flame radiates outward from the caster, damaging all enemies caught within the blast for 462 to 544 Fire damage, and dazing them for 6 sec.", icon = "Spell_Holy_Excorcism_02"},
		{id = {31661, 33041, 33042, 33043}, name = L["Dragon's Breath"], cooldown = 20, desc = "Targets in a cone in front of the caster take 680 to 790 Fire damage and are Disoriented for 3 sec.  Any direct damaging attack will revive targets.  Turns off your attack when used.", icon = "inv_misc_head_dragon_01"},
		{id = {12472}, name = L["Icy Veins"], cooldown = 180, desc = "Hastens your spellcasting, increasing spell casting speed by 20% and gives you 100% chance to avoid interruption caused by damage while casting.  Lasts 20 sec.", icon = "spell_frost_coldhearted"},
		{id = {11426, 13031, 13032, 13033, 27134, 33405}, name = L["Ice Barrier"], cooldown = 24, desc = "Instantly shields you, absorbing 818 damage. Lasts 1 min. While the shield holds, spells will not be interrupted.", icon = "Spell_Ice_Lament"},
		{id = {31687}, name = L["Summon Water Elemental"], cooldown = 180, desc = "Summon a Water Elemental to fight for the caster for 45 sec.", icon = "spell_frost_summonwaterelemental_2"},
		{id = {33395}, name = L["Freeze"], cooldown = 25, desc = "Blasts enemies in a 8 yard radius for 74 to 86 Frost damage and freezes them in place for up to 8 sec.  Damage caused may interrupt the effect.", icon = "spell_frost_frostnova"},
		
		-- Trinkets & Racials
		{id = {7744}, name = L["Will of the Forsaken"], cooldown = 120, desc = "Provides immunity to Charm, Fear and Sleep while active.  May also be used while already afflicted by Charm, Fear or Sleep.  Lasts 5 sec.", icon = "Spell_Shadow_RaiseDead"},
		{id = {20600}, name = L["Perception"], cooldown = 180, desc = "Dramatically increases stealth detection for 20 sec.", icon = "Spell_Nature_Sleep"},
		{id = {20549}, name = L["War Stomp"], cooldown = 120, desc = "Stuns up to 5 enemies within 8 yds for 2 sec.", icon = "Ability_WarStomp"},
		{id = {20594}, name = L["Stoneform"], cooldown = 180, desc = "While active, grants immunity to Bleed, Poison, and Disease effects.  In addition, Armor increased by 10%.  Lasts 8 sec.", icon = "Spell_Shadow_UnholyStrength"},
		{id = {20577}, name = L["Cannibalize"], cooldown = 120, desc = "When activated, regenerates 7% of total health every 2 sec for 10 sec.  Only works on Humanoid or Undead corpses within 5 yds.  Any movement, action, or damage taken while Cannibalizing will cancel the effect.", icon = "ability_racial_cannibalize"},
		{id = {20572}, name = L["Blood Fury"], cooldown = 120, desc = "Increases base melee attack power by 25% for 15 sec and reduces healing effects on you by 50% for 25 sec.", icon = "racial_orc_berserkerstrength"},
		{id = {26297, 20554, 26296}, name = L["Berserking"], cooldown = 180, desc = "Increases your attack/casting speed by 10% to 30%.  At full health the speed increase is 10% with a greater effect up to 30% if you are badly hurt when you activate Berserking.  Lasts 10 sec.", icon = "racial_troll_berserk"},
		{id = {20580}, name = L["Shadowmeld"], cooldown = 10, desc = "Activate to slip into the shadows, reducing the chance for enemies to detect your presence. Lasts until cancelled or upon moving.", icon = "ability_ambush"},
		{id = {20589}, name = L["Escape Artist"], cooldown = 105, desc = "Escape the effects of any immobilization or movement speed reduction effect.", icon = "ability_rogue_trip"},
		{id = {28730, 25046}, name = L["Arcane Torrent"], cooldown = 120, desc = "Silence all enemies within 8 yards for 2 sec.  In addition, you gain 10 Energy/Mana for each Mana Tap charge currently affecting you.", icon = "spell_shadow_teleport"},
		{id = {28734}, name = L["Mana Tap"], cooldown = 30, desc = "Reduces target's mana by 50 and charges you with Arcane energy for 10 min.  This effect stacks up to 3 times.", icon = "spell_arcane_manatap"},
		{id = {28880}, name = L["Gift of the Naaru"], cooldown = 180, desc = "Heals the target of 50 damage over 15 sec.", icon = "spell_holy_holyprotection"},

		{id = {24532}, name = L["Burst of Energy"], cooldown = 180, desc = "Instantly increases your energy by 60.", icon = "inv_jewelry_necklace_19"},
		{id = {24531}, name = L["Refocus"], cooldown = 180, desc = "Instantly clears the cooldowns of Aimed Shot, Multishot, Volley, and Arcane Shot.", icon = "inv_jewelry_necklace_19"},
		{id = {23723}, name = L["Mind Quickening"], cooldown = 300, desc = "Quickens the mind, increasing the Mage's casting speed by 33% for 20 sec.", icon = "spell_nature_wispheal"},
		{id = {23725}, name = L["Gift of Life"], cooldown = 300, desc = "Heals yourself for 15% of your maximum health, and increases your maximum health by 15% for 20 sec.", icon = "INV_Misc_Gem_Pearl_05"},
		{id = {23733}, name = L["Blinding Light"], cooldown = 300, desc = "Energizes a Paladin with light, increasing haste rating by 250 and spell haste rating by 330 for 20 sec.", icon = "inv_scroll_08"},
		{id = {26480}, name = L["Badge of the Swarmguard"], cooldown = 180, desc = "Gives a chance on melee or ranged attack to apply an armor penetration effect on you for 30 sec, lowering the target's physical armor by 200 to your own attacks. The armor penetration effect can be applied up to 6 times.", icon = "inv_misc_ahnqirajtrinket_04"},
		{id = {14530}, name = L["Speed"], cooldown = 1800, desc = "Increases run speed by 40% for 10 sec.", icon = "inv_misc_pocketwatch_01"}, -- TODO: Fix tracking of nifty/swiftness pot (both auras are called "Speed")
		{id = {42292}, name = L["PvP Trinket"], cooldown = 120, desc = "Removes all movement impairing effects and all effects which cause loss of control of your character.", icon = "inv_jewelry_trinketpvp_02"},
		{id = {44055}, name = L["Tremendous Fortitude"], cooldown = 180, desc = "Increases maximum health by 1750 for 15 sec. Shares cooldown with other Battlemaster's trinkets.", icon = "ability_warrior_endlessrage"},
		{id = {32140}, name = L["Talisman of the Horde"], cooldown = 120, desc = "Heal self for 877 to 969 damage.", icon = "inv_jewelry_talisman_09"},
		{id = {33828}, name = L["Talisman of the Alliance"], cooldown = 120, desc = "Heal self for 877 to 969 damage.", icon = "inv_jewelry_talisman_10"},
		
		{id = {17534, 28495}, name = L["Healing Potion"], cooldown = 120, desc = "Restores 1050 to 1750 health.", icon = "inv_potion_54"},
		{id = {17531, 28499}, name = L["Restore Mana"], cooldown = 120, desc = "Restores 1350 to 2250 mana.", icon = "inv_potion_76"},
		{id = {6615}, name = L["Free Action"], cooldown = 120, desc = "Makes you immune to Stun and Movement Impairing effects for the next 30 sec.   Does not remove effects already on the imbiber.", icon = "inv_potion_04"},
		{id = {24364}, name = L["Living Free Action"], cooldown = 120, desc = "Makes you immune to Stun and Movement Impairing effects for the next 5 sec.  Also removes existing Stun and Movement Impairing effects.", icon = "inv_potion_07"},
		{id = {11359}, name = L["Restoration"], cooldown = 120, desc = "Removes 1 magic, curse, poison or disease effect on you every 5 seconds for 30 seconds.", icon = "inv_potion_01"},
		{id = {9512}, name = L["Restore Energy"], cooldown = 300, desc = "Instantly restores 100 energy.", icon = "inv_drink_milk_05"},
		
		{id = {11196}, name = L["Recently Bandaged"], cooldown = 60, desc = "Cannot be bandaged again.", icon = "inv_misc_bandage_08"},
		{id = {4068}, name = L["Iron Grenade"], cooldown = 60, desc = "Inflicts 132 to 218 Fire damage and stuns targets for 3 sec in a 3 yard radius.  Any damage will break the effect.", icon = "inv_misc_bomb_08"},
		{id = {19769}, name = L["Thorium Grenade"], cooldown = 60, desc = "Inflicts 300 to 500 Fire damage and stuns targets for 3 sec in a 3 yard radius.  Any damage will break the effect.", icon = "inv_misc_bomb_08"},
		{id = {13241}, name = L["Goblin Sapper Charge"], cooldown = 300, desc = "Explodes when triggered dealing 450 to 750 Fire damage to all enemies nearby and 375 to 625 damage to you.", icon = "spell_fire_selfdestruct"},
		{id = {19821}, name = L["Arcane Bomb"], cooldown = 60, desc = "Drains 675 to 1125 mana from those in the blast radius and does 50% of the mana drained in damage to the target.  Also Silences targets in the blast for 5 sec.", icon = "spell_shadow_mindbomb"},
		{id = {30217}, name = L["Adamantite Grenade"], cooldown = 60, desc = "Inflicts 450 to 750 Fire damage and incapacitates targets for 3 sec in a 3 yard radius.  Any damage will break the effect.  Unreliable against targets higher than level 80.", icon = "inv_misc_bomb_08"},
		{id = {30486}, name = L["Super Sapper Charge"], cooldown = 300, desc = "Explodes when triggered, dealing 900 to 1500 Fire damage to all enemies nearby and 675 to 1125 damage to you.", icon = "inv_gizmo_supersappercharge"},
		
		{id = {5024}, name = L["Flee"], cooldown = 300, desc = "Increase your run speed by 60% for 10 sec, but deals 100 to 500 damage and drains 100 to 500 mana every 2 seconds.", icon = "inv_misc_bone_elfskull_01"},
		{id = {13141}, name = L["Gnomish Rocket Boots"], cooldown = 1800, desc = "These boots significantly increase your run speed for 20 sec.", icon = "inv_boots_02"},
		{id = {8892}, name = L["Goblin Rocket Boots"], cooldown = 300, desc = "These dangerous looking boots significantly increase your run speed for 20 sec.", icon = "inv_gizmo_rocketboot_01"},
		{id = {9175}, name = L["Running Speed"], cooldown = 3600, desc = "Increases run speed by 40% for 15 sec.", icon = "inv_boots_08"},
		{id = {13180}, name = L["Gnomish Mind Control Cap"], cooldown = 1800, desc = "Engage in mental combat with a humanoid target to try and control their mind.  If all works well, you will control the mind of the target for 20 sec.", icon = "inv_helmet_49"},
		{id = {22641}, name = L["Reckless Charge"], cooldown = 1200, desc = "Charge an enemy, knocking it silly for 30 seconds. Also knocks you down, stunning you for a short period of time. Any damage caused will revive the target.", icon = "inv_helmet_49"},
		{id = {51582}, name = L["Rocket Boots Engaged"], cooldown = 300, desc = "Engage the rocket boots to greatly increase your speed... most of the time.", icon = "inv_gizmo_rocketboot_01"},

		-- Warrior
		{id = {100, 6178, 11578}, name = L["Charge"], cooldown = 15, desc = "Charge an enemy, generate 15 rage, and stun it for 1 sec. Cannot be used in combat.", icon = "Ability_Warrior_Charge"},
		{id = {694, 7400, 7402, 20559, 20560, 25266}, name = L["Mocking Blow"], cooldown = 120, desc = "A mocking attack that causes 93 damage, a moderate amount of threat and forces the target to focus attacks on you for 6 sec.", icon = "Ability_Warrior_PunishingBlow"},
		{id = {12294, 21551, 21552, 21553, 25248, 30330}, name = L["Mortal Strike"], cooldown = 5, desc = "A vicious strike that deals weapon damage plus 160 and wounds the target, reducing the effectiveness of any healing by 50% for 10 sec.", icon = "Ability_Warrior_SavageBlow"},
		{id = {7384, 7887, 11584, 11585}, name = L["Overpower"], cooldown = 5, desc = "Instantly overpower the enemy, causing weapon damage plus 35. Only useable after the target dodges. The Overpower cannot be blocked, dodged or parried.", icon = "Ability_MeleeDamage"},
		{id = {20230}, name = L["Retaliation"], cooldown = (20*60), desc = "Instantly counterattack any enemy that strikes you in melee for 15 sec. Melee attacks made from behind cannot be counterattacked. A maximum of 30 attacks will cause retaliation.", icon = "Ability_Warrior_Challange"},
		{id = {6343, 8198, 8204, 8205, 11580, 11581, 25264}, name = L["Thunder Clap"], cooldown = 4, desc = "Blasts nearby enemies with thunder slowing their attack speed by 10% for 30 sec and doing 103 damage to them. Will affect up to 4 targets.", icon = "Spell_Nature_ThunderClap"},
		{id = {18499}, name = L["Berserker Rage"], cooldown = 30, desc = "The warrior enters a berserker rage, becoming immune to Fear and Incapacitate effects and generating extra rage when taking damage. Lasts 10 sec.", icon = "Spell_Nature_AncestralGuardian"},
		{id = {23881, 23892, 23893, 23894, 25251, 30335}, name = L["Bloodthirst"], cooldown = 6, desc = "Instantly attack the target causing damage equal to 45% of your attack power. In addition, the next 5 successful melee attacks will restore 20 health. This effect lasts 8 sec.", icon = "Spell_Nature_BloodLust"},
		{id = {1161}, name = L["Challenging Shout"], cooldown = 600, desc = "Forces all nearby enemies to focus attacks on you for 6 sec.", icon = "Ability_BullRush"},
		{id = {20252, 20616, 20617, 25272, 25275}, name = L["Intercept"], cooldown = 15, desc = "Charge an enemy, causing 65 damage and stunning it for 3 sec.", icon = "Ability_Rogue_Sprint"},
		{id = {5246}, name = L["Intimidating Shout"], cooldown = 180, desc = "The warrior shouts, causing the targeted enemy to cower in fear. Up to 5 total nearby enemies will flee in fear. Lasts 8 sec.", icon = "Ability_GolemThunderClap"},
		{id = {6552, 6554}, name = L["Pummel"], cooldown = 10, desc = "Pummel the target for 50 damage. It also interrupts spellcasting and prevents any spell in that school from being cast for 4 sec.", icon = "INV_Gauntlets_04"},
		{id = {1719}, name = L["Recklessness"], cooldown = (20*60), desc = "The warrior will cause critical hits with most attacks and will be immune to Fear effects for the next 15 sec, but all damage taken is increased by 20%.", icon = "Ability_CriticalStrike"},
		{id = {1680}, name = L["Whirlwind"], cooldown = 8, desc = "In a whirlwind of steel you attack up to 4 enemies within 8 yards, causing weapon damage to each enemy.", icon = "Ability_Whirlwind"},
		{id = {2687}, name = L["Bloodrage"], cooldown = 60, desc = "Generates 10 rage at the cost of health, and then generates an additional 10 rage over 10 sec. The warrior is considered in combat for the duration.", icon = "Ability_Racial_BloodRage"},
		{id = {676}, name = L["Disarm"], cooldown = 60, desc = "Disarm the enemy's weapon for 10 sec.", icon = "Ability_Warrior_Disarm"},
		{id = {6572, 6574, 7379, 11600, 11601, 25288, 25269, 30357}, name = L["Revenge"], cooldown = 5, desc = "Instantly counterattack an enemy for 81 to 99 damage and a high amount of threat. Revenge must follow a block, dodge or parry.", icon = "Ability_Warrior_Revenge"},
		{id = {72, 1671, 1672, 29704}, name = L["Shield Bash"], cooldown = 12, desc = "Bashes the target with your shield for 45 damage. It also interrupts spellcasting and prevents any spell in that school from being cast for 6 sec.", icon = "Ability_Warrior_ShieldBash"},
		{id = {2565}, name = L["Shield Block"], cooldown = 5, desc = "Increases chance to block by 75% for 5 sec, but will only block 1 attack.", icon = "Ability_Defend"},
		{id = {23922, 23923, 23924, 23925, 25258, 30356}, name = L["Shield Slam"], cooldown = 6, desc = "Slam the target with your shield, causing 342 to 358 damage, modified by your shield block value, and has a 50% chance of dispelling 1 magic effect on the target. Also causes a high amount of threat.", icon = "INV_Shield_05"},
		{id = {871}, name = L["Shield Wall"], cooldown = (20*60), desc = "Reduces the damage taken from melee attacks, ranged attacks and spells by 75% for 10 sec.", icon = "Ability_Warrior_ShieldWall"},
		{id = {23920}, name = L["Spell Reflect"], cooldown = 10, desc = "Raise your shield, reflecting the next spell cast on you.  Lasts 5 sec.", icon = "ability_warrior_shieldreflection"},
		{id = {3411}, name = L["Intervene"], cooldown = 30, desc = "Run at high speed towards a party member, intercepting the next melee or ranged attack made against them.", icon = "ability_warrior_victoryrush"},
		
		-- Paladin
		{id = {26573, 20116, 20922, 20923, 20924, 27173}, name = L["Consecration"], cooldown = 8, desc = "Consecrates the land beneath Paladin, doing 384 Holy damage over 8 sec to enemies who enter the area.", icon = "Spell_Holy_InnerFire"},
		{id = {879, 5614, 5615, 10312, 10313, 10314, 27138}, name = L["Exorcism"], cooldown = 15, desc = "Causes 505 to 563 Holy damage to an Undead or Demon target.", icon = "Spell_Holy_Excorcism_02"},
		{id = {24275, 24274, 24239, 27180}, name = L["Hammer of Wrath"], cooldown = 6, desc = "Hurls a hammer that strikes an enemy for 304 to 336 Holy damage. Only usable on enemies that have 20% or less health.", icon = "Ability_ThunderClap"},
		{id = {2812, 10318, 27139}, name = L["Holy Wrath"], cooldown = 60, desc = "Sends bolts of holy power in all directions, causing 490 to 576 Holy damage to all Undead and Demon targets within 20 yds.", icon = "Spell_Holy_Excorcism"},
		{id = {633, 2800, 10310, 27154}, name = L["Lay on Hands"], cooldown = (40*60), desc = "Heals a friendly target for an amount equal to the Paladin's maximum health and restores 550 of their mana. Drains all of the Paladin's remaining mana when used.", icon = "Spell_Holy_LayOnHands"},
		{id = {2878, 5627}, name = L["Turn Undead"], cooldown = 30, desc = "The targeted undead enemy will be compelled to flee for up to 20 sec. Damage caused may interrupt the effect. Only one target can be turned at a time.", icon = "Spell_Holy_TurnUndead"},
		{id = {1044}, name = L["Blessing of Freedom"], cooldown = 25, desc = "Places a Blessing on the friendly target, granting immunity to movement impairing effects for 10 sec. Players may only have one Blessing on them per Paladin at any one time.", icon = "Spell_Holy_SealOfValor"},
		{id = {1022, 5599, 10278}, name = L["Blessing of Protection"], cooldown = (3*60), desc = "A targeted party member is protected from all physical attacks for 10 sec, but during that time they cannot attack or use physical abilities. Players may only have one Blessing on them per Paladin at any one time. Once protected, the target cannot be made invulnerable by Divine Shield, Divine Protection or Blessing of Protection again for 1 min.", icon = "Spell_Holy_SealOfProtection"},
		{id = {19752}, name = L["Divine Intervention"], cooldown = (60*60), desc = "The paladin sacrifices himself to remove the targeted party member from harms way. Enemies will stop attacking the protected party member, who will be immune to all harmful attacks but cannot take any action for 3 min.", icon = "Spell_Nature_TimeStop"},
		{id = {498, 5573}, name = L["Divine Protection"], cooldown = (5*60), desc = "You are protected from all physical attacks and spells for 8 sec, but during that time you cannot attack or use physical abilities yourself. Once protected, the target cannot be made invulnerable by Divine Shield, Divine Protection or Blessing of Protection again for 1 min.", icon = "Spell_Holy_Restoration"},
		{id = {642, 1020}, name = L["Divine Shield"], cooldown = (4*60), desc = "Protects the paladin from all damage and spells for 12 sec, but reduces attack speed by 50%. Once protected, the target cannot be made invulnerable by Divine Shield, Divine Protection or Blessing of Protection again for 1 min.", icon = "Spell_Holy_DivineIntervention"},
		{id = {853, 5588, 5589, 10308}, name = L["Hammer of Justice"], cooldown = 35, desc = "Stuns the target for 6 sec.", icon = "Spell_Holy_SealOfMight"},
		{id = {20271}, name = L["Judgement"], cooldown = 8, desc = "Unleashes the energy of a Seal spell upon an enemy. Refer to individual Seals for Judgement effect.", icon = "Spell_Holy_RighteousFury"}, -- set to 8 sec becuase of 2/2 imp. judgement talent
		{id = {25771}, name = L["Forbearance"], cooldown = 60, desc = "Cannot be made invulnerable by Divine Shield, Divine Protection or Blessing of Protection.", icon = "spell_holy_removecurse"},
		{id = {31789}, name = L["Righteous Defense"], cooldown = 15, desc = "Come to the defense of a friendly target, commanding up to 3 enemies attacking the target to attack the Paladin instead.", icon = "inv_shoulder_37"}, 
		{id = {31884}, name = L["Avenging Wrath"], cooldown = 180, desc = "Increases all damage caused by 30% for 20 sec.  Causes Forebearance, preventing the use of Divine Shield, Divine Protection, Blessing of Protection again for 1 min.", icon = "spell_holy_avenginewrath"},

		-- Mage
		{id = {1953}, name = L["Blink"], cooldown = 15, desc = "Teleports the caster 20 yards forward, unless something is in the way. Also frees the caster from stuns and bonds.", icon = "Spell_Arcane_Blink"},
		{id = {2136, 2137, 2138, 8412, 8413, 10197, 10199, 27078, 27079}, name = L["Fire Blast"], cooldown = 7, desc = "Blasts the enemy for 431 to 509 Fire damage.", icon = "Spell_Fire_Fireball"},
		{id = {543, 8457, 8458, 10223, 10225, 27128}, name = L["Fire Ward"], cooldown = 30, desc = "Absorbs 920 Fire damage. Lasts 30 sec.", icon = "Spell_Fire_FireArmor"},
		{id = {120, 8492, 10159, 10160, 10161, 27087}, name = L["Cone of Cold"], cooldown = 8, desc = "Targets in a cone in front of the caster take 335 to 365 Frost damage and are slowed by 50% for 8 sec.", icon = "Spell_Frost_Glacier"},
		{id = {122, 865, 6131, 10230, 27088}, name = L["Frost Nova"], cooldown = 21, desc = "Blasts enemies near the caster for 71 to 79 Frost damage and freezes them in place for up to 8 sec. Damage caused may interrupt the effect.", icon = "Spell_Frost_FrostNova"}, -- setting cd to 21 because almost every mage run imp frost nova in pvp.
		{id = {6143, 8461, 8462, 10177, 28609, 32796}, name = L["Frost Ward"], cooldown = 30, desc = "Absorbs 920 Frost damage. Lasts 30 sec.", icon = "Spell_Frost_FrostWard"},
		{id = {2139}, name = L["Counterspell"], cooldown = 24, desc = "Counters the enemy's spellcast, preventing any spell from that school of magic from being cast for 10 sec.  Generates a high amount of threat.", icon = "spell_frost_iceshock"},
		{id = {12051}, name = L["Evocation"], cooldown = 480, desc = "While channeling this spell, your mana regeneration is active and increased by 1500%.  Lasts 8 sec.", icon = "spell_nature_purge"},
		{id = {66}, name = L["Invisibility"], cooldown = 300, desc = "Fades the caster to invisibility over 5 sec, reducing threat each second.  The effect is cancelled if you perform or receive any actions.  While invisible, you can only see other invisible targets and those whom can see invisible.  Lasts 20 sec.", icon = "ability_mage_invisibility"},
		{id = {43987}, name = L["Ritual of Refreshment"], cooldown = 300, desc = "Begins a ritual that creates a refreshment table.  Raid members can click the table to acquire Conjured Manna Biscuits.  The tables lasts for 3 min or 50 charges.  Requires the caster and 2 additional party members to complete the ritual.  In order to participate, all players must right-click the refreshment portal and not move until the ritual is complete.", icon = "spell_arcane_massdispel"},

		-- Rogues
		{id = {408, 8643}, name = L["Kidney Shot"], cooldown = 20, desc = "Finishing move that stuns the target. Lasts longer per combo point.", icon = "Ability_Rogue_KidneyShot"},
		{id = {5277, 26669}, name = L["Evasion"], cooldown = 210, desc = "The rogue's dodge chance will increase by 50% for 15 sec.", icon = "Spell_Shadow_ShadowWard"},
		{id = {1966, 6768, 8637, 11303, 25302, 27448}, name = L["Feint"], cooldown = 10, desc = "Performs a feint, causing no damage but lowering your threat by a large amount, making the enemy less likely to attack you.", icon = "Ability_Rogue_Feint"},
		{id = {1776, 1777, 8629, 11285, 11286, 38764}, name = L["Gouge"], cooldown = 10, desc = "Causes 75 damage, incapacitating the opponent for 4 sec, and turns off your attack. Target must be facing you. Any damage caused will revive the target. Awards 1 combo point.", icon = "Ability_Gouge"},
		{id = {1766, 1767, 1768, 1769, 38768}, name = L["Kick"], cooldown = 10, desc = "A quick kick that injures a single foe for 80 damage. It also interrupts spellcasting and prevents any spell in that school from being cast for 5 sec.", icon = "Ability_Kick"},
		{id = {2983, 8696, 11305}, name = L["Sprint"], cooldown = 210, desc = "Increases the rogue's movement speed by 70% for 15 sec. Does not break stealth.", icon = "Ability_Rogue_Sprint"},
		{id = {2094}, name = L["Blind"], cooldown = 90, desc = "Blinds the target, causing it to wander disoriented for up to 10 sec. Any damage caused will remove the effect.", icon = "Spell_Shadow_MindSteal"},
		{id = {1725}, name = L["Distract"], cooldown = 30, desc = "Throws a distraction, attracting the attention of all nearby monsters for 10 seconds. Does not break stealth.", icon = "Ability_Rogue_Distract"},
		{id = {1784, 1785, 1786, 1787}, name = L["Stealth"], cooldown = 6, desc = "Allows the rogue to sneak around, but reduces your speed by 30%. Lasts until cancelled.", icon = "Ability_Stealth"}, -- Setting this to 6 sec cd because of 4/5 Camouflage in pvp
		{id = {1856, 1857, 26889}, name = L["Vanish"], cooldown = 210, desc = "Allows the rogue to vanish from sight, entering an improved stealth mode for 10 sec. Also breaks movement impairing effects. More effective than Vanish (Rank 1).", icon = "Ability_Vanish"},
		{id = {31224}, name = L["Cloak of Shadows"], cooldown = 60, desc = "Instantly removes all existing harmful spell effects and increases your chance to resist all spells by 90% for 5 sec.  Does not remove effects that prevent you from using Cloak of Shadows.", icon = "spell_shadow_nethercloak"},

		-- Shaman
		{id = {20608}, name = L["Reincarnation"], cooldown = (40*60), desc = "Allows you to resurrect yourself upon death with 20% health and mana.", icon = "spell_nature_reincarnation"},
		{id = {421, 930, 2860, 10605, 25439, 25442}, name = L["Chain Lightning"], cooldown = 6, desc = "Hurls a lightning bolt at the enemy, dealing 493 to 551 Nature damage and then jumping to additional nearby enemies. Each jump reduces the damage by 30%. Affects 3 total targets.", icon = "Spell_Nature_ChainLightning"},
		{id = {8042, 8044, 8045, 8046, 10412, 10413, 10414, 25454}, name = L["Earth Shock"], cooldown = 5, desc = "Instantly shocks the target with concussive force, causing 517 to 545 Nature damage. It also interrupts spellcasting and prevents any spell in that school from being cast for 2 sec. Causes a high amount of threat.", icon = "Spell_Nature_EarthShock"},
		{id = {2484}, name = L["Earthbind Totem"], cooldown = 15, desc = "Summons an Earthbind Totem with 5 health at the feet of the caster for 45 sec that slows the movement speed of enemies within 10 yards.", icon = "Spell_Nature_StrengthOfEarthTotem02"},
		{id = {1535, 8498, 8499, 11314, 11315, 25546, 25547}, name = L["Fire Nova Totem"], cooldown = 15, desc = "Summons a Fire Nova Totem that has 5 health and lasts 5 sec. Unless it is destroyed within 4 sec., the totem inflicts 396 to 442 fire damage to enemies within 10 yd.", icon = "Spell_Fire_SealOfFire"},
		{id = {8050, 8052, 8053, 10447, 10448, 29228, 25457}, name = L["Flame Shock"], cooldown = 5, desc = "Instantly sears the target with fire, causing 292 Fire damage immediately and 320 Fire damage over 12 sec.", icon = "Spell_Fire_FlameShock"},
		{id = {8056, 8058, 10472, 10473, 25464}, name = L["Frost Shock"], cooldown = 5, desc = "Instantly shocks the target with frost, causing 486 to 514 Frost damage and slowing movement speed by 50%. Lasts 8 sec.", icon = "Spell_Frost_FrostShock"},
		{id = {5730, 6390, 6391, 6392, 10427, 10428, 25525}, name = L["Stoneclaw Totem"], cooldown = 30, desc = "Summons a Stoneclaw Totem with 480 health at the feet of the caster for 15 sec that taunts creatures within 8 yards to attack it.", icon = "Spell_Nature_StoneClawTotem"},
		{id = {556}, name = L["Astral Recall"], cooldown = (15*60), desc = "Yanks the caster through the twisting nether back to [home]. Speak to an Innkeeper in a different place to change your home location.", icon = "Spell_Nature_AstralRecal"},
		{id = {8177}, name = L["Grounding Totem"], cooldown = 11.5, desc = "Summons a Grounding Totem with 5 health at the feet of the caster that will redirect one harmful spell cast on a nearby party member to itself every 10 seconds. Will not redirect area of effect spells. Lasts 45 sec.", icon = "Spell_Nature_GroundingTotem"},
		{id = {2825}, name = L["Bloodlust"], cooldown = (10*60), desc = "Increases melee, ranged, and spell casting speed by 30% for all party members.  Lasts 40 sec.", icon = "spell_nature_bloodlust"},
		{id = {32182}, name = L["Heroism"], cooldown = (10*60), desc = "Increases melee, ranged, and spell casting speed by 30% for all party members.  Lasts 40 sec.", icon = "ability_shaman_heroism"},
		{id = {2894}, name = L["Fire Elemental Totem"], cooldown = (20*60), desc = "Summons an elemental totem that calls forth a greater fire elemental to rain destruction on the caster's enemies.  Lasts 2 min.", icon = "spell_fire_elemental_totem"},
		{id = {2062}, name = L["Earth Elemental Totem"], cooldown = (20*60), desc = "Summon an elemental totem that calls forth a greater earth elemental to protect the caster and his allies.  Lasts 2 min.", icon = "spell_nature_earthelemental_totem"},

		-- Hunters
		{id = {1513, 14326, 14327}, name = L["Scare Beast"], cooldown = 30, desc = "Scares a beast, causing it to run in fear for up to 20 sec. Damage caused may interrupt the effect. Only one beast can be feared at a time.", icon = "Ability_Druid_Cower"},
		{id = {19801}, name = L["Tranquilizing Shot"], cooldown = 20, desc = "Attempts to remove 1 Frenzy effect from an enemy creature.", icon = "Spell_Nature_Drowsy"},
		{id = {3044, 14281, 14282, 14283, 14284, 14285, 14286, 14287, 27019}, name = L["Arcane Shot"], cooldown = 5, desc = "An instant shot that causes 183 Arcane damage.", icon = "Ability_ImpalingBolt"},
		{id = {5116}, name = L["Concussive Shot"], cooldown = 12, desc = "Dazes the target, slowing movement speed by 50% for 4 sec.", icon = "Spell_Frost_Stun"},
		{id = {20736, 14274, 15629, 15630, 15631, 15632, 27020}, name = L["Distracting Shot"], cooldown = 8, desc = "Distract the target, causing threat.", icon = "Spell_Arcane_Blink"},
		{id = {1543}, name = L["Flare"], cooldown = 20, desc = "Exposes all hidden and invisible enemies within 10 yards of the targeted area for 30 sec.", icon = "Spell_Fire_Flare"},
		{id = {2643, 14288, 14289, 14290, 25294, 27021}, name = L["Multi-Shot"], cooldown = 9, desc = "Fires several missiles, hitting 3 targets for an additional 150 damage.", icon = "Ability_UpgradeMoonGlaive"},
		{id = {3045}, name = L["Rapid Fire"], cooldown = (3*60), desc = "Increases ranged attack speed by 40% for 15 sec.", icon = "Ability_Hunter_RunningShot"},
		{id = {1510, 14294, 14295}, name = L["Volley"], cooldown = 60, desc = "Continuously fires a volley of ammo at the target area, causing 80 Arcane damage to enemy targets within 8 yards every second for 6 sec.", icon = "Ability_Marksmanship"},
		{id = {781, 14272, 14273, 27015}, name = L["Disengage"], cooldown = 5, desc = "Attempts to disengage from the target, reducing threat. More effective than Disengage (Rank 2). Character exits combat mode.", icon = "Ability_Rogue_Feint"},
		{id = {13813, 14316, 14317, 27025}, name = L["Explosive Trap"], cooldown = 24, desc = "Place a fire trap that explodes when an enemy approaches, causing 201 to 257 Fire damage and 330 additional Fire damage over 20 sec to all within 10 yards. Trap will exist for 1 min. Traps can only be placed when out of combat. Only one trap can be active at a time.", icon = "Spell_Fire_SelfDestruct"},
		{id = {5384}, name = L["Feign Death"], cooldown = 30, desc = "Feign death which may trick enemies into ignoring you. Lasts up to 6 min.", icon = "Ability_Rogue_FeignDeath"},
		{id = {1499, 14310, 14311}, name = L["Freezing Trap"], cooldown = 24, desc = "Place a frost trap that freezes the first enemy that approaches, preventing all action for up to 20 sec. Any damage caused will break the ice. Trap will exist for 1 min. Traps can only be placed when out of combat. Only one trap can be active at a time.", icon = "Spell_Frost_ChainsOfIce"},
		{id = {13809}, name = L["Frost Trap"], cooldown = 24, desc = "Place a frost trap that creates an ice slick around itself for 30 sec when the first enemy approaches it. All enemies within 10 yards will be slowed by 60% while in the area of effect. Trap will exist for 1 min. Traps can only be placed when out of combat. Only one trap can be active at a time.", icon = "Spell_Frost_FreezingBreath"},
		{id = {13795, 14302, 14303, 14304, 14305, 27023}, name = L["Immolation Trap"], cooldown = 24, desc = "Place a fire trap that will burn the first enemy to approach for 690 Fire damage over 15 sec. Trap will exist for 1 min. Traps can only be placed when out of combat. Only one trap can be active at a time.", icon = "Spell_Fire_FlameShock"},
		{id = {1495, 14269, 14270, 14271, 36916}, name = L["Mongoose Bite"], cooldown = 5, desc = "Counterattack the enemy for 115 damage. Can only be performed after you dodge.", icon = "Ability_Hunter_SwiftStrike"},
		{id = {2973, 14260, 14261, 14262, 14263, 14264, 14265, 14266, 27014}, name = L["Raptor Strike"], cooldown = 6, desc = "A strong attack that increases melee damage by 140.", icon = "Ability_MeleeDamage"},
		{id = {34477}, name = L["Misdirection"], cooldown = 120, desc = "Threat caused by your next 3 attacks is redirected to the target raid member.  Caster and target can only be affected by one Misdirection spell at a time.  Effect lasts 30 sec.", icon = "ability_hunter_misdirection"},
		{id = {34026}, name = L["Kill Command"], cooldown = 5, desc = "Give the command to kill, causing your pet to instantly attack for an additional 127 damage.  Can only be used after the Hunter lands a critical strike on the target.", icon = "ability_hunter_killcommand"},
		{id = {34600}, name = L["Snake Trap"], cooldown = 24, desc = "Place a trap that will release several venomous snakes to attack the first enemy to approach.  The snakes will die after 15 sec.  Trap will exist for 1 min.  Only one trap can be active at a time.", icon = "ability_hunter_snaketrap"},
		{id = {26090, 26187, 26188, 27063}, name = L["Thunderstomp"], cooldown = 60, desc = "Shakes the ground with thundering force, doing 161 to 185 Nature damage to all enemies within 8 yards.  This ability causes a moderate amount of additional threat.", icon = "ability_hunter_pet_gorilla"},
		{id = {7371, 26177, 26178, 26179, 26201, 27685}, name = L["Charge"], cooldown = 25, desc = "Charges an enemy, immobilizes it for 1 sec, and adds 580 melee attack power to the boar's next attack.", icon = "ability_hunter_pet_boar"},
		{id = {35346}, name = L["Warp"], cooldown = 15, desc = "Teleports to an enemy up to 30 yards away and gives the pet a 50% chance to avoid the next melee attack.  Lasts 4 sec.", icon = "spell_arcane_arcane04"},
		{id = {23099, 23109, 23110}, name = L["Dash"], cooldown = 30, desc = "Increases movement speed by 80% for 15 sec.", icon = "ability_druid_dash"},
		{id = {23145, 23147, 23148}, name = L["Dive"], cooldown = 30, desc = "Increases movement speed by 80% for 15 sec.", icon = "spell_shadow_burningspirit"},

		-- Warlocks
		{id = {20707, 20762, 20763, 20764, 20765, 27239}, name = L["Soulstone Resurrection"], cooldown = (30*60), desc = "Stores the friendly target's soul.  If the target dies while his soul is stored, he will be able to resurrect with 2900 health and 3300 mana.", icon = "spell_shadow_soulgem"},
		{id = {603, 30910}, name = L["Curse of Doom"], cooldown = 60, desc = "Curses the target with impending doom, causing 3200 Shadow damage after 1 min. If the target dies from this damage, there is a chance that a Doomguard will be summoned. Cannot be cast on players.", icon = "Spell_Shadow_AuraOfDarkness"},
		{id = {6789, 17925, 17926, 27223}, name = L["Death Coil"], cooldown = 120, desc = "Causes the enemy target to run in horror for 3 sec and causes 470 Shadow damage. The caster gains 100% of the damage caused in health.", icon = "Spell_Shadow_DeathCoil"},
		{id = {5484, 17928}, name = L["Howl of Terror"], cooldown = 40, desc = "Howl, causing 5 enemies within 10 yds to flee in terror for 15 sec. Damage caused may interrupt the effect.", icon = "Spell_Shadow_DeathScream"},
		{id = {1122}, name = L["Inferno"], cooldown = (60*60), desc = "Summons a meteor from the Twisting Nether, causing 200 Fire damage and stunning all enemy targets in the area for 2 sec. An Infernal rises from the crater, under the command of the caster for 5 min. Once control is lost, the Infernal must be Enslaved to maintain control. Can only be used outdoors.", icon = "Spell_Shadow_SummonInfernal"},
		{id = {18540}, name = L["Ritual of Doom"], cooldown = (60*60), desc = "Begins a ritual that sacrifices a random participant to summon a doomguard. The doomguard must be immediately enslaved or it will attack the ritual participants. Requires the caster and 4 additional party members to complete the ritual. In order to participate, all players must right-click the portal and not move until the ritual is complete.", icon = "Spell_Shadow_AntiMagicShell"},
		{id = {6229, 11739, 11740, 28610}, name = L["Shadow Ward"], cooldown = 30, desc = "Absorbs 920 shadow damage. Lasts 30 sec.", icon = "Spell_Shadow_AntiShadow"},
		{id = {6353, 17924, 27211, 30545}, name = L["Soul Fire"], cooldown = 60, desc = "Burn the enemy's soul, causing 703 to 881 Fire damage.", icon = "Spell_Fire_Fireball02"},
		{id = {19505, 19731, 19734, 19736, 27276, 27277}, name = L["Devour Magic"], cooldown = 8, desc = "Purges 1 harmful magic effect from a friend or 1 beneficial magic effect from an enemy. If an effect is devoured, the Felhunter will be healed for 579.", icon = "Spell_Nature_Purge"},
		{id = {19244, 19647}, name = L["Spell Lock"], cooldown = 24, desc = "Silences the enemy for 3 sec. If used on a casting target, it will counter the enemy's spellcast, preventing any spell from that school of magic from being cast for 8 sec.", icon = "Spell_Shadow_MindRot"},
		{id = {7814, 7815, 7816, 11778, 11779, 11780, 27274}, name = L["Lash of Pain"], cooldown = 12, desc = "An instant attack that lashes the target, causing 99 Shadow damage.", icon = "Spell_Shadow_Curse"},
		{id = {6360, 7813, 11784, 11785, 27275}, name = L["Soothing Kiss"], cooldown = 4, desc = "Soothes the target, increasing the chance that it will attack something else. More effective than Soothing Kiss (Rank 3).", icon = "Spell_Shadow_SoothingKiss"},
		{id = {29858}, name = L["Soulshatter"], cooldown = 300, desc = "Reduces threat by 50% for all enemies within 50 yards.", icon = "spell_arcane_arcane01"},
		{id = {30151, 30194, 30198}, name = L["Intercept"], cooldown = 30, desc = "Charge an enemy, causing 105 damage and stunning it for 3 sec.", icon = "ability_rogue_sprint"},
		{id = {30213, 30219, 30223}, name = L["Cleave"], cooldown = 6, desc = "A sweeping attack that does your weapon damage plus 78 to the target and his nearest ally.", icon = "ability_warrior_cleave"},

		-- Priest
		{id = {2651}, name = L["Elune's Grace"], cooldown = 180, desc = "Reduces ranged damage taken by 95 and increases chance to dodge by 10% for 15 sec.", icon = "Spell_Holy_ElunesGrace"},
		{id = {13896, 19271, 19273, 19274, 19275, 25441}, name = L["Feedback"], cooldown = (3*60), desc = "The priest becomes surrounded with anti-magic energy. Any successful spell cast against the priest will burn 105 of the attacker's Mana, causing 1 Shadow damage for each point of Mana burned. Lasts 15 sec.", icon = "Spell_Shadow_RitualOfSacrifice"},
		{id = {17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901, 25217, 25218}, name = L["Power Word: Shield"], cooldown = 4, desc = "Draws on the soul of the party member to shield them, absorbing 942 damage. Lasts 30 sec. While the shield holds, spellcasting will not be interrupted by damage. Once shielded, the target cannot be shielded again for 15 sec.", icon = "Spell_Holy_PowerWordShield"},
		{id = {13908, 19236, 19238, 19240, 19241, 19242, 19243, 25437}, name = L["Desperate Prayer"], cooldown = 600, desc = "Instantly heals the caster for 1324 to 1562.", icon = "Spell_Holy_Restoration"},
		{id = {6346}, name = L["Fear Ward"], cooldown = 180, desc = "Wards the friendly target against Fear. The next Fear effect used against the target will fail, using up the ward. Lasts 10 min.", icon = "Spell_Holy_Excorcism"},
		{id = {2944, 19276, 19277, 19278, 19279, 19280, 25467}, name = L["Devouring Plague"], cooldown = 180, desc = "Afflicts the target with a disease that causes 904 Shadow damage over 24 sec. Damage caused by the Devouring Plague heals the caster.", icon = "Spell_Shadow_BlackPlague"},
		{id = {586, 9578, 9579, 9592, 10941, 10942, 25429}, name = L["Fade"], cooldown = 24, desc = "Fade out, discouraging enemies from attacking you for 10 sec. More effective than Fade (rank 5).", icon = "Spell_Magic_LesserInvisibilty"},
		{id = {8092, 8102, 8103, 8104, 8105, 8106, 10945, 10946, 10947, 25372, 25375}, name = L["Mind Blast"], cooldown = 6, desc = "Blasts the target for 503 to 531 Shadow damage, but causes a high amount of threat.", icon = "Spell_Shadow_UnholyFrenzy"},
		{id = {8122, 8124, 10888, 10890}, name = L["Psychic Scream"], cooldown = 26, desc = "The caster lets out a psychic scream, causing 5 enemies within 8 yards to flee for 8 sec. Damage caused may interrupt the effect.", icon = "Spell_Shadow_PsychicScream"},
		{id = {32548}, name = L["Symbol of Hope"], cooldown = 300, desc = "Greatly increases the morale of party members, giving them 33 mana every 5 sec.  Effect lasts 15 sec.", icon = "spell_holy_symbolofhope"},
		{id = {44041, 44043, 44044, 44045, 44046, 44047}, name = L["Chastise"], cooldown = 30, desc = "Chastise the target, causing 370 to 430 Holy damage and Immobilizing them for up to 2 sec. Only works against Humanoids.  This spell causes very low threat.", icon = "spell_holy_chastise"},
		{id = {33076}, name = L["Prayer of Mending"], cooldown = 10, desc = "Places a spell on the target that heals them for 800 the next time they take damage.  When the heal occurs, Prayer of Mending jumps to a raid member within 20 yards.  Jumps up to 5 times and lasts 30 sec after each jump.  This spell can only be placed on one target at a time.", icon = "spell_holy_prayerofmendingtga"},
		{id = {34433}, name = L["Shadowfiend"], cooldown = 300, desc = "Creates a shadowy fiend to attack the target.  Caster receives mana when the Shadowfiend deals damage.  Lasts 15 sec.", icon = "spell_shadow_shadowfiend"},
		{id = {32379, 32996}, name = L["Shadow Word: Death"], cooldown = 12, desc = "A word of dark binding that inflicts 572 to 664 Shadow damage to the target.  If the target is not killed by Shadow Word: Death, the caster takes damage equal to the damage inflicted upon the target.", icon = "spell_shadow_demonicfortitude"},
		{id = {10797, 19296, 19299, 19302, 19303, 19304, 19305, 25446}, name = L["Starshards"], cooldown = 30, desc = "Rains starshards down on the enemy target's head, causing 785 Arcane damage over 15 sec.", icon = "spell_arcane_starfire"},
		{id = {32676}, name = L["Consume Magic"], cooldown = 120, desc = "Dispels one beneficial Magic effect from the caster and gives them 120 to 154 mana.  The dispelled effect must be a priest spell.", icon = "spell_arcane_studentofmagic"},
		
		-- Druid
		{id = {22812}, name = L["Barkskin"], cooldown = 60, desc = "The druid's skin becomes as tough as bark. Physical damage taken is reduced by 20%. While protected, damaging attacks will not cause spellcasting delays but non-instant spells take 1 sec longer to cast and melee combat is slowed by 20%. Lasts 15 sec.", icon = "Spell_Nature_StoneClawTotem"},
		{id = {16914, 17401, 17402, 27012}, name = L["Hurricane"], cooldown = 60, desc = "Creates a violent storm in the target area causing 134 Nature damage to enemies every 1 sec, and reducing the attack speed of enemies by 20%. Lasts 10 sec. Druid must channel to maintain the spell.", icon = "Spell_Nature_Cyclone"},
		{id = {5211, 6798, 8983}, name = L["Bash"], cooldown = 60, desc = "Stuns the target for 4 sec.", icon = "Ability_Druid_Bash"},
		{id = {5209}, name = L["Challenging Roar"], cooldown = 600, desc = "Forces all nearby enemies to focus attacks on you for 6 sec.", icon = "Ability_Druid_ChallangingRoar"},
		{id = {8998, 9000, 9892, 31709, 27004}, name = L["Cower"], cooldown = 10, desc = "Cower, causing no damage but lowering your threat a large amount, making the enemy less likely to attack you.", icon = "Ability_Druid_Cower"},
		{id = {1850, 9821, 33357}, name = L["Dash"], cooldown = 300, desc = "Increases movement speed by 60% for 15 sec. Does not break prowling.", icon = "Ability_Druid_Dash"},
		{id = {5229}, name = L["Enrage"], cooldown = 60, desc = "Generates 20 rage over 10 sec, but reduces base armor by 27% in Bear Form and 16% in Dire Bear Form. The druid is considered in combat for the duration.", icon = "Ability_Druid_Enrage"},
		{id = {22842, 22895, 22896, 26999}, name = L["Frenzied Regeneration"], cooldown = 180, desc = "Converts up to 10 rage per second into health for 10 sec. Each point of rage is converted into 20 health.", icon = "Ability_BullRush"},
		{id = {5215, 6783, 9913}, name = L["Prowl"], cooldown = 10, desc = "Allows the Druid to prowl around, but reduces your movement speed by 30%. Lasts until cancelled.", icon = "Ability_Ambush"},
		{id = {5217, 6793, 9845, 9846}, name = L["Tiger's Fury"], cooldown = 1, desc = "Increases damage done by 40 for 6 sec.", icon = "Ability_Mount_JungleTiger"},
		{id = {20484, 20739, 20742, 20747, 20748, 26994}, name = L["Rebirth"], cooldown = (20*60), desc = "Returns the spirit to the body, restoring a dead target to life with 2200 health and 2800 mana.", icon = "Spell_Nature_Reincarnation"},
		{id = {740, 8918, 9862, 9863, 26983}, name = L["Tranquility"], cooldown = (10*60), desc = "Regenerates all nearby group members for 294 every 2 seconds for 10 sec. Druid must channel to maintain the spell.", icon = "Spell_Nature_Tranquility"}
	};
	
	-- cd start when buff fades..
	ECDC_DelayedCds = {
		1784, 1785, 1786, 1787, --"Stealth",
		5215, 6783, 9913, --"Prowl",
		20580, --"Shadowmeld",
		12043, --"Presence of Mind",
		16166, --"Elemental Mastery",
		16188, 17116, --"Nature's Swiftness",
		11129, --"Combustion",
		14751, --"Inner Focus",
		20216 --"Divine Favor"
	};
	
	ECDC_FinishCds = {
		-- Rogue
		--408, 8643, --"Kidney Shot",
		5277, 26669, --"Evasion",
		--1966, 6768, 8637, 11303, 25302, 27448, --"Feint",
		--1776, 1777, 8629, 11285, 11286, 38764, --"Gouge",
		--1766, 1767, 1768, 1769, 38768, --"Kick",
		2983, 8696, 11305, --"Sprint",
		--2094, --"Blind",
		--1725, --"Distract",
		1856, 1857, 26889, --"Vanish",
		--13877, --"Blade Flurry",
		14177, --"Cold Blood",
		14183, --"Premeditation",
		--14278, --"Ghostly Strike",
		36554, --"Shadowstep",
		
		-- Mage
		120, 8492, 10159, 10160, 10161, 27087, --"Cone of Cold",
		122, 865, 6131, 10230, 27088, --"Frost Nova",
		6143, 8461, 8462, 10177, 28609, 32796, --"Frost Ward",
		11426, 13031, 13032, 13033, 27134, 33405, --"Ice Barrier",
		45438, --"Ice Block",
		12472, --"Icy Veins",
		31687, --"Summon Water Elemental",
		
		-- Hunter
		19434, 20900, 20901, 20902, 20903, 20904, 27065, --"Aimed Shot",
		2643, 14288, 14289, 14290, 25294, 27021, --"Multi-Shot",
		1510, 14294, 14295, 27022, --"Volley",
		
	};
	
end
addon.ECDC_LoadSkills = ECDC_LoadSkills

SLASH_ECDC1 = '/ecdc';
function SlashCmdList.ECDC(param)
	param = (param and string.lower(param)) or ""

	-- /ecdc -> open settings
	if param == "" then
		-- New Settings UI
		if Settings and Settings.OpenToCategory and addon and addon.optionsCategoryID then
			-- Some client builds prefer categoryID, others accept the category name.
			pcall(Settings.OpenToCategory, addon.optionsCategoryID)
			pcall(Settings.OpenToCategory, ADDON_NAME)
			return
		end

		-- Legacy Interface Options
		if InterfaceOptionsFrame_OpenToCategory then
			InterfaceOptionsFrame_OpenToCategory("ECDC")
			InterfaceOptionsFrame_OpenToCategory("ECDC") -- workaround for Blizzard bug
			return
		end
	end

	-- Quick toggles (useful if the settings panel can't be opened)
	-- /ecdc hide  -> hide fist icon
	-- /ecdc show  -> show fist icon
	if param == "hide" then
		addon.ECDC_ToggleVisi("hide")
		print("|cff1a9fc0ECDC|r: fist icon hidden.")
		return
	elseif param == "show" then
		addon.ECDC_ToggleVisi("show")
		print("|cff1a9fc0ECDC|r: fist icon shown.")
		return
	end
end

-- Message on login
local ECDC_LoginMsg = CreateFrame("FRAME");
ECDC_LoginMsg:SetScript("OnEvent", function()
    C_Timer.After(3, function() 
	print("|cff1a9fc0Enemy Cooldown Count|r loaded!")
	print("Type |cff1a9fc0/ecdc|r to open settings.")
	end);
    ECDC_LoginMsg:UnregisterEvent("PLAYER_ENTERING_WORLD");
end);
ECDC_LoginMsg:RegisterEvent("PLAYER_ENTERING_WORLD");