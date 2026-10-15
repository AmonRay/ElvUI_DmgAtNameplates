---@diagnostic disable-next-line: deprecated
local E, L, V, P, G, _ = unpack(ElvUI);
local NP = E:GetModule('NamePlates');
local EP = E.Libs.EP
local DAN = E:GetModule('DmgAtNameplates')
local LibEasing = LibStub("LibEasing-1.0")
local LSM = E.Libs.LSM

local CreateFrame = CreateFrame
local mtfl, mtpw, mtrn = math.floor, math.pow, math.random
local tostring, tonumber = tostring, tonumber
local format, find = string.format, string.find
local next, select, pairs, ipairs = next, select, pairs, ipairs
local tinsert, tremove = table.insert, table.remove
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local band = bit.band

local SMALL_HIT_EXPIRY_WINDOW = 30
local SMALL_HIT_MULTIPIER = 0.5

local ANIMATION_VERTICAL_DISTANCE = 75

local ANIMATION_ARC_X_MIN = 50
local ANIMATION_ARC_X_MAX = 150
local ANIMATION_ARC_Y_TOP_MIN = 10
local ANIMATION_ARC_Y_TOP_MAX = 50
local ANIMATION_ARC_Y_BOTTOM_MIN = 10
local ANIMATION_ARC_Y_BOTTOM_MAX = 50

local ANIMATION_RAINFALL_X_MAX = 75
local ANIMATION_RAINFALL_Y_MIN = 50
local ANIMATION_RAINFALL_Y_MAX = 100
local ANIMATION_RAINFALL_Y_START_MIN = 5
local ANIMATION_RAINFALL_Y_START_MAX = 15

local AutoAttack = select(1, GetSpellInfo(6603))
local AutoAttackPet = select(1, GetSpellInfo(315235))

local AutoShot = select(1, GetSpellInfo(75))
local targetUnitType
DAN.DmgTextFrame = CreateFrame("Frame", nil, UIParent)
DAN.DmgTextFrame:SetFrameStrata("MEDIUM")

DAN.ElvUI_ToPlayerFrame = CreateFrame("Frame","ElvUI_ToPlayerFrame", UIParent)
DAN.ElvUI_ToPlayerFrame:SetPoint("CENTER",UIParent,"CENTER",300,0)
DAN.ElvUI_ToPlayerFrame:SetSize(300,32)
DAN.ElvUI_ToPlayerFrame:Show()

DAN.ElvUI_ToTargetFrame = CreateFrame("Frame","ElvUI_ToTargetFrame", UIParent)
DAN.ElvUI_ToTargetFrame:SetPoint("CENTER",UIParent,"CENTER",-300,0)
DAN.ElvUI_ToTargetFrame:SetSize(300,32)
DAN.ElvUI_ToTargetFrame:Show()

local inversePositions = {
	["BOTTOM"] = "TOP",
	["LEFT"] = "RIGHT",
	["TOP"] = "BOTTOM",
	["RIGHT"] = "LEFT",
	["TOPLEFT"] = "BOTTOMRIGHT",
	["TOPRIGHT"] = "BOTTOMLEFT",
	["BOTTOMLEFT"] = "TOPRIGHT",
	["BOTTOMRIGHT"] = "TOPLEFT",
	["CENTER"] = "CENTER"
}

local animating = {}

local DAMAGE_TYPE_COLORS = {
	[SCHOOL_MASK_PHYSICAL] = "FFFF00",
	[SCHOOL_MASK_HOLY] = "FFE680",
	[SCHOOL_MASK_FIRE] = "FF8000",
	[SCHOOL_MASK_NATURE] = "4DFF4D",
	[SCHOOL_MASK_FROST] = "80FFFF",
	[SCHOOL_MASK_FROST + SCHOOL_MASK_FIRE] = "FF80FF",
	[SCHOOL_MASK_SHADOW] = "8080FF",
	[SCHOOL_MASK_ARCANE] = "FF80FF",
	[AutoAttack] = "FFFFFF",
	[AutoShot] = "FFFFFF",
	["pet"] = "CC8400"
}
local MISS_EVENT_STRINGS = {
	["ABSORB"] = L["Absorb"],
	["BLOCK"] = L["Block"],
	["DEFLECT"] = L["Deflect"],
	["DODGE"] = L["Dodge"],
	["EVADE"] = L["Evade"],
	["IMMUNE"] = L["Immune"],
	["MISS"] = L["Miss"],
	["PARRY"] = L["Parry"],
	["REFLECT"] = L["Reflected"],
	["RESIST"] = L["Resisted"]
}

function DAN:GetUnitTypeByFlag(flag)
	local sReturn = ""
	flag = flag or 0
	if band(flag, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 then
		sReturn = "Player"
	elseif band (flag, COMBATLOG_OBJECT_TYPE_NPC) > 0 then
		sReturn = "NPC"
	end
	if band(flag, COMBATLOG_OBJECT_REACTION_FRIENDLY) > 0 then
		sReturn = sReturn.."Friend"
	elseif (band(flag, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0) or (band(flag, COMBATLOG_OBJECT_REACTION_NEUTRAL) > 0) then
		sReturn = sReturn.."Enemy"
	end
	return sReturn
end

function DAN:rgbToHex(r, g, b)
	return format("%02x%02x%02x", mtfl(255 * r), mtfl(255 * g), mtfl(255 * b))
end

function DAN:hexToRGB(hex)
	return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, 1
end
function DAN:CSEP(number)
	-- https://stackoverflow.com/questions/10989788/lua-format-integer
	local _, _, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)');
	int = int:reverse():gsub("(%d%d%d)", "%1,");
	return minus..int:reverse():gsub("^,", "")..fraction;
end

-- damage spell events
local dse = {
	DAMAGE_SHIELD = true,
	SPELL_DAMAGE = true,
	SPELL_PERIODIC_DAMAGE = true,
	SPELL_BUILDING_DAMAGE = true,
	RANGE_DAMAGE = true
}
--miss spell events
local mse = {
	SPELL_MISSED = true,
	SPELL_PERIODIC_MISSED = true,
	RANGE_MISSED = true,
	SPELL_BUILDING_MISSED = true,
}
-- heal spell events
local hse = {
	SPELL_HEAL = true,
	SPELL_PERIODIC_HEAL = true

}
--spell interrupt
local csi = {
	SPELL_INTERRUPT = true
}

local pguid

function DAN:GetFontPath(fontName)
	local fontPath = LSM:Fetch("font", fontName) or "Fonts\\FRIZQT__.TTF"
	return fontPath
end
-- A GUID index avoids scanning all visible plates for every combat-log hit.
-- The tables belong to this addon; no fields or scripts of client plates change.
local platesByGUID, guidByPlate = {}, {}
-- Short, bounded negative cache: unknown GUIDs must not trigger a full scan
-- for every hit. Plate lifecycle hooks invalidate it immediately; expiry also
-- recovers changes made by older ElvUI/other addons without those hooks.
local missingPlates, missingCount, missingUntil = {}, 0, 0
local MISSING_PLATE_TTL, MISSING_PLATE_LIMIT = 0.1, 128
local function ClearMissingPlates()
	for guid in pairs(missingPlates) do missingPlates[guid] = nil end
	missingCount, missingUntil = 0, 0
end
local function PlateFrame(plate)
	return plate and (plate.ElvUIFrame or plate)
end

local function ForgetPlate(plate)
	ClearMissingPlates()
	local frame = PlateFrame(plate)
	local guid = frame and guidByPlate[frame]
	if guid and platesByGUID[guid] == frame then platesByGUID[guid] = nil end
	if frame then guidByPlate[frame] = nil end
end

local function IndexPlate(plate)
	local frame = PlateFrame(plate)
	ForgetPlate(plate)
	if frame and frame.guid and frame:IsShown() then
		platesByGUID[frame.guid] = frame
		guidByPlate[frame] = frame.guid
	end
end

local function ValidPlate(frame, guid)
	return frame and frame:IsShown() and frame.guid == guid
		and (not frame.unit or UnitGUID(frame.unit) == guid)
end

function DAN:InitializePlateIndex()
	if self.plateIndexInitialized then return end
	self.plateIndexInitialized = true
	if NP.OnShow then hooksecurefunc(NP, "OnShow", IndexPlate) end
	if NP.OnHide then hooksecurefunc(NP, "OnHide", ForgetPlate) end
	for frame in pairs(NP.VisiblePlates or {}) do IndexPlate(frame) end
end

function DAN:GetNameplateFrame(guid)
	if not guid then return end
	local frame = platesByGUID[guid]
	if ValidPlate(frame, guid) then return frame end
	if frame then ForgetPlate(frame) end

	-- Compatibility with old ElvUI, plus recovery when the plugin starts after
	-- plates are shown or another plugin changes their visibility.
	frame = PlateFrame(NP.PlateGUID and NP.PlateGUID[guid])
	if ValidPlate(frame, guid) then IndexPlate(frame) return frame end
	local now = GetTime()
	if now >= missingUntil then
		ClearMissingPlates()
		missingUntil = now + MISSING_PLATE_TTL
	end
	if missingPlates[guid] then return end
	for visible in pairs(NP.VisiblePlates or {}) do
		if ValidPlate(visible, guid) then IndexPlate(visible) return visible end
	end
	if missingCount < MISSING_PLATE_LIMIT then
		missingPlates[guid] = true
		missingCount = missingCount + 1
	end
end
function DAN:GetFrame(whoguid, whoname, whoflag, tguid, tname, tflag)
	if not pguid or not tguid then return end
	if tguid == pguid then return self.ElvUI_ToPlayerFrame end
	if whoguid == pguid or self:IsSourceMyPet(whoguid, whoflag) then
		local frame = self:GetNameplateFrame(tguid)
		if frame then return frame end
		if UnitGUID("target") == tguid then return self.ElvUI_ToTargetFrame end
	end
end
local useRandomCoords = true

local fontStringCache = {}
function DAN:GetFontString(frame)
	local fontString, fontStringFrame

	if next(fontStringCache) then
		fontString = tremove(fontStringCache)
	else
		fontStringFrame = CreateFrame("Frame", nil, DAN.DmgTextFrame)
		fontStringFrame:SetFrameLevel(DAN.DmgTextFrame:GetFrameLevel() + 1)
		fontString = fontStringFrame:CreateFontString()
		fontString:SetParent(fontStringFrame)
		fontString:SetShadowOffset(0, 0)
		end

	fontString:SetAlpha(1)
	fontString:SetDrawLayer("OVERLAY")
	fontString:Show()

	if not fontString.icon then
		fontString.icon = DAN.DmgTextFrame:CreateTexture(nil, "OVERLAY")
		fontString.icon:SetTexCoord(0.062, 0.938, 0.062, 0.938)
	end
	fontString.icon:SetAlpha(1)
	fontString.icon:Hide()
	local x,y = frame:GetSize()
	x = mtrn(-mtfl(x / 2), mtfl(x / 2))
	y = mtrn(-mtfl(y / 2), mtfl(y / 2))
	fontString.startX = useRandomCoords and x or 0
	fontString.startY = useRandomCoords and y or 0

		--

	return fontString
end

function DAN:DeleteFontString(fontString)
	fontString:SetAlpha(0)
	fontString:Hide()

	animating[fontString] = nil

	fontString.distance = nil
	fontString.arcTop = nil
	fontString.arcBottom = nil
	fontString.arcXDist = nil
	fontString.deflection = nil
	fontString.numShakes = nil
	fontString.animation = nil
	fontString.animatingDuration = nil
	fontString.animatingStartTime = nil
	fontString.anchorFrame = nil
	fontString.nameplateFrame = nil
	fontString.anchorGUID = nil
	fontString.startX = nil
	fontString.startY = nil

	fontString.pow = nil
	fontString.startHeight = nil
	fontString.DANFontSize = nil
	fontString.DANText = nil
	fontString.fontPath, fontString.fontOutline, fontString.startAlpha = nil, nil, nil
	fontString.rainfallX, fontString.rainfallStartY = nil, nil

	if fontString.icon then
		fontString.icon:ClearAllPoints()
		fontString.icon:SetAlpha(0)
		fontString.icon:Hide()
		if fontString.icon.button then
			fontString.icon.button:Hide()
			fontString.icon.button:ClearAllPoints()
		end

		fontString.icon.anchorFrame = nil

	end

	fontString:ClearAllPoints()

	tinsert(fontStringCache, fontString)
end

local function verticalPath(elapsed, duration, distance)
	return 0, LibEasing.InQuad(elapsed, 0, distance, duration)
end

local function arcPath(elapsed, duration, xDist, yStart, yTop, yBottom)
	local x, y
	local progress = elapsed / duration

	x = progress * xDist

	local a = -2 * yStart + 4 * yTop - 2 * yBottom
	local b = -3 * yStart + 4 * yTop - yBottom

	y = -a * mtpw(progress, 2) + b * progress + yStart

	return x, y
end

local function powSizing(elapsed, duration, start, middle, finish)
	local size = finish
	if elapsed < duration then
		if elapsed / duration < 0.5 then
			size = LibEasing.OutQuint(elapsed, start, middle - start, duration / 2)
		else
			size = LibEasing.InQuint(elapsed - elapsed / 2, middle, finish - middle, duration / 2)
		end
	end
	return size
end

local function AnimationOnUpdate()
	local now = GetTime()
	if next(animating) then
		for fontString, _ in pairs(animating) do
			local elapsed = now - fontString.animatingStartTime
			local plate = fontString.nameplateFrame
			if elapsed > fontString.animatingDuration or (plate and
				(not plate:IsShown() or plate.guid ~= fontString.anchorGUID
				or (plate.unit and UnitGUID(plate.unit) ~= fontString.anchorGUID))) then
				DAN:DeleteFontString(fontString)
			else
				local startAlpha = fontString.startAlpha or 1
				local alpha = LibEasing.InExpo(elapsed, startAlpha, -startAlpha, fontString.animatingDuration)
				fontString:SetAlpha(alpha)
				if fontString.icon and fontString.icon:IsShown() then fontString.icon:SetAlpha(alpha) end

				if fontString.pow then
					local height = fontString.startHeight
					if elapsed < fontString.animatingDuration / 6 then
						fontString:SetText(fontString.DANText)
						local size =
							powSizing(elapsed, fontString.animatingDuration / 6, height / 2, height * 2, height)
						fontString:SetTextHeight(size)
					else
						fontString.pow = nil
						fontString:SetTextHeight(height)
						fontString:SetFont(fontString.fontPath, fontString.DANFontSize, fontString.fontOutline)
											fontString:SetText(fontString.DANText)
					end
				end

				local xOffset, yOffset = 0, 0
				if fontString.animation == "verticalUp" then
					xOffset, yOffset = verticalPath(elapsed, fontString.animatingDuration, fontString.distance)
				elseif fontString.animation == "verticalDown" then
					xOffset, yOffset = verticalPath(elapsed, fontString.animatingDuration, -fontString.distance)
				elseif fontString.animation == "fountain" then
					xOffset, yOffset = arcPath(elapsed, fontString.animatingDuration, fontString.arcXDist, 0, fontString.arcTop, fontString.arcBottom)
				elseif fontString.animation == "rainfall" then
					_, yOffset = verticalPath(elapsed, fontString.animatingDuration, -fontString.distance)
					xOffset = fontString.rainfallX
					yOffset = yOffset + fontString.rainfallStartY
				end

				if fontString.anchorFrame and fontString.anchorFrame:IsShown() then
					fontString:SetPoint("CENTER", fontString.anchorFrame, "CENTER", fontString.startX + xOffset, fontString.startY + yOffset)
				else
					DAN:DeleteFontString(fontString)
				end
			end
		end
	else
		DAN.DmgTextFrame:SetScript("OnUpdate", nil)
	end
end

local arcDirection = 1
function DAN:Animate(fontString, anchorFrame, duration, animation)
	animation = animation or "verticalUp"

	fontString.animation = animation
	fontString.animatingDuration = duration
	fontString.animatingStartTime = GetTime()
	fontString.anchorFrame = anchorFrame

	if animation == "verticalUp" then
		fontString.distance = ANIMATION_VERTICAL_DISTANCE
	elseif animation == "verticalDown" then
		fontString.distance = ANIMATION_VERTICAL_DISTANCE
	elseif animation == "fountain" then
		fontString.arcTop = mtrn(ANIMATION_ARC_Y_TOP_MIN, ANIMATION_ARC_Y_TOP_MAX)
		fontString.arcBottom = -mtrn(ANIMATION_ARC_Y_BOTTOM_MIN, ANIMATION_ARC_Y_BOTTOM_MAX)
		fontString.arcXDist = arcDirection * mtrn(ANIMATION_ARC_X_MIN, ANIMATION_ARC_X_MAX)

		arcDirection = arcDirection * -1
	elseif animation == "rainfall" then
		fontString.distance = mtrn(ANIMATION_RAINFALL_Y_MIN, ANIMATION_RAINFALL_Y_MAX)
		fontString.rainfallX = mtrn(-ANIMATION_RAINFALL_X_MAX, ANIMATION_RAINFALL_X_MAX)
		fontString.rainfallStartY = -mtrn(ANIMATION_RAINFALL_Y_START_MIN, ANIMATION_RAINFALL_Y_START_MAX)
	end

	animating[fontString] = true

	-- start onupdate if it's not already running
	if DAN.DmgTextFrame:GetScript("OnUpdate") == nil then
		DAN.DmgTextFrame:SetScript("OnUpdate", AnimationOnUpdate)
	end
end

function DAN:DisplayText(f, text, size, alpha, animation, spellId, pow, spellName,etype)
	if not f or animation == "disabled" then return end
	local fontString
	local icon

	fontString = self:GetFontString(f)

	fontString.DANText = text

	fontString.DANFontSize = size
	fontString.fontPath = self:GetFontPath(etype and self.db[etype].font or self.db.font)
	fontString.fontOutline = etype and self.db[etype].fontOutline or self.db.fontOutline
	fontString.startAlpha = alpha or 1
	fontString:SetAlpha(fontString.startAlpha)
	fontString:SetFont(fontString.fontPath, size, fontString.fontOutline)
	fontString:SetText(fontString.DANText)

	fontString.startHeight = fontString:GetStringHeight()
	fontString.pow = pow

	if (fontString.startHeight <= 0) then
		fontString.startHeight = 5
	end

	local texture = select(3, GetSpellInfo(spellId or spellName))
	if not texture and spellName then
		texture = select(3, GetSpellInfo(spellName))
	end

	if texture and self.db.showIcon then
		icon = fontString.icon
		icon:Show()
		icon:SetTexture(texture)
		icon:SetSize(size * 1, size * 1)
		icon:SetPoint(inversePositions["RIGHT"], fontString, "RIGHT", 0, 0)
		icon:SetAlpha(alpha)
		fontString.icon = icon
	else
		if fontString.icon then
			fontString.icon:Hide()
		end
	end
	-- Use the visible ElvUI health bar, not the hidden Blizzard UnitFrame.
	local anchor = f.Health and f.Health:IsShown() and f.Health or f
	fontString.nameplateFrame = f.guid and f or nil
	fontString.anchorGUID = f.guid
	self:Animate(fontString, anchor, self.db.duration, animation)
end

local numDamageEvents = 0
local lastDamageEventTime
local runningAverageDamageEvents = 0
local text, animation, pow, size, alpha, color
function DAN:DamageEvent(f, spellName, amount, school, crit, spellId, whog, whoName)
	if not f then return end

	if targetUnitType == "PlayerEnemy" or targetUnitType == "NPCEnemy" then
		if not self.db.showDmgToEnemy then return end
	elseif targetUnitType == "PlayerFriend" or targetUnitType == "NPCFriend" then
		if not self.db.showDmgToFriend then return end
	end
	local autoattack = spellName == AutoAttack or spellName == AutoShot or spellName == "pet"
	if (autoattack and crit) then
		animation = self.db.autoAttackPlusCritAnimation or "verticalUp"
		pow = true
	elseif (autoattack) then
		animation =  self.db.autoAttack or "fountain"
		pow = false
	elseif (crit) then
		animation = self.db.critAnimation or "fountain"
		pow = true
	elseif (not autoattack and not crit) then
		animation = self.db.commonDMGAnimation or "fountain"
		pow = false
	end

	if self.db.textFormat == "kkk" then
		text = format("%.1fk", amount / 1000)
	elseif self.db.textFormat == "csep" then
		text = self:CSEP(amount)
	elseif self.db.textFormat == "none" then
		text = amount
	end

	if	(spellName == AutoAttack or spellName == AutoShot) and DAMAGE_TYPE_COLORS[spellName] then
		text = "|cff" .. DAMAGE_TYPE_COLORS[spellName] .. text .. "|r"
	elseif school and DAMAGE_TYPE_COLORS[school] then
		text = "|cff" .. DAMAGE_TYPE_COLORS[school] .. text .. "|r"
	else
		text = "|cff" .. "ffff00" .. text .. "|r"
	end
	if whog ~= pguid and self.db.showFromAnotherPlayer and whoName then
		text = whoName .."  ".. text
	end

	local isTarget = (UnitGUID("target") == f.guid)

	if (self.db.showOffTargetText and not isTarget and pguid ~= f.guid) then
		size = self.db.showOffTargetTextSize or 20
		alpha = self.db.showOffTargetTextAlpha or 1

	else
		size = self.db.fontSize or 20
		alpha = self.db.fontAlpha or 1
	end

	if (self.db.smallHits or self.db.smallHitsHide) then
		if (not lastDamageEventTime or (lastDamageEventTime + SMALL_HIT_EXPIRY_WINDOW < GetTime())) then
			numDamageEvents = 0
			runningAverageDamageEvents = 0
		end
		runningAverageDamageEvents = ((runningAverageDamageEvents * numDamageEvents) + amount) / (numDamageEvents + 1)
		numDamageEvents = numDamageEvents + 1
		lastDamageEventTime = GetTime()
		if ((not crit and amount < SMALL_HIT_MULTIPIER * runningAverageDamageEvents) or (crit and amount / 2 < SMALL_HIT_MULTIPIER * runningAverageDamageEvents)) then
			if (self.db.smallHitsHide) then
				return
			else
				size = size * (self.db.smallHitsScale or 1)
			end
		end
	end

	if (size < 5) then
		size = 5
	end

	self:DisplayText(f, text, size, alpha, animation, spellId, pow, spellName)
end

function DAN:HealEvent(f, spllname, slldmg, healcrt, splld, vrhll)
	if not f then return end

	----------------------- animation
	if healcrt then
		animation = self.db.healCrit or "verticalUp"
	else
		animation =  self.db.noHealCrit or "fountain"
	end
	------------color
	color = self.db.healColor or "ffff00"
	----------------- size
	size = self.db.fontSize or 20
	---------------- alpha
	alpha = 1
	pow = false
	------------- text
	if self.db.showOverHeal and slldmg == vrhll then
		if self.db.textFormat == "kkk" then
			text = format("Перелечено: %.1fk", vrhll / 1000)
		elseif self.db.textFormat == "csep" then
			text = "Перелечено: "..self:CSEP(vrhll)
		elseif self.db.textFormat == "none" then
			text = "Перелечено: "..vrhll
		end
	elseif not self.db.showOverHeal and slldmg == vrhll then
		return
	elseif self.db.showOverHeal and slldmg ~= vrhll then
		if self.db.textFormat == "kkk" then
			text = format("%.1fk", ((slldmg) / 1000))
		elseif self.db.textFormat == "csep" then
			text = self:CSEP((slldmg))
		elseif self.db.textFormat == "none" then
			text = slldmg
		end
	else
		text = slldmg ---debug
	end
	text = "|cff" .. color .. text .. "|r"
	self:DisplayText(f, text, size, alpha, animation, splld, pow, spllname)
end

function DAN:MissEvent(f, spellName, missType, spellId)
	if not f then return end
	animation = self.db.miss.animation or "verticalDown"
	color = self.db.miss.color or "ffff00"
	size = self.db.miss.fontSize or 20
	alpha = self.db.miss.fontAlpha or 1
	pow = true
	if missType == "ABSORB" then
		return
	end
	text = MISS_EVENT_STRINGS[missType] or ACTION_SPELL_MISSED_MISS
	text = "|cff" .. color .. text .. "|r"

	self:DisplayText(f, text, size, alpha, animation, spellId, pow, spellName, "miss")
end

function DAN:MissEventPet(f, spellName, missType, spellId)
	if not f then return end
	animation = self.db.miss.animation or "verticalDown"
	color = self.db.miss.color or "ffff00"
	size = self.db.miss.fontSize or 20
	alpha = self.db.miss.fontAlpha or 1
	pow = true
	if missType == "ABSORB" then
		return
	end
	text = MISS_EVENT_STRINGS[missType] or ACTION_SPELL_MISSED_MISS
	text = "|cff" .. color .."Питомец ".. text .. "|r"
	self:DisplayText(f, text, size, alpha, animation, spellId, pow, spellName,"miss")
end

function DAN:DispelEvent(f, spellName, infodis, spellId)
	if not f then return end
	animation = self.db.dispel.animation or "verticalDown"
	color = self.db.dispel.color or "ffff00"
	size = self.db.dispel.fontSize or 20
	alpha = self.db.dispel.fontAlpha or 1
	pow = false
	text = "|cff" .. color .. infodis .. "|r"
	self:DisplayText(f, text, size, alpha, animation, spellId, pow, spellName,"dispel")
end

function DAN:SpellInterruptEvent(f,  spllname, splld, intrspll)
	if not f then return end
	animation = self.db.interrupt.animation or "verticalDown"
	color = self.db.interrupt.color or "ffff00"
	size = self.db.interrupt.fontSize or 20
	alpha = self.db.interrupt.fontAlpha or 1
	pow = true
	text = "Прервано ".."{"..intrspll.."}"
	text = "|cff" .. color .. text .. "|r"
	self:DisplayText(f, text, size, alpha, animation, splld, pow, spllname,"interrupt")
end

local relevantEvents = { SWING_DAMAGE = true, SWING_MISSED = true, SPELL_DISPEL = true }
for _, events in ipairs({ dse, mse, hse, csi }) do
	for event in pairs(events) do relevantEvents[event] = true end
end

local BITMASK_PETS = COMBATLOG_OBJECT_TYPE_PET + COMBATLOG_OBJECT_TYPE_GUARDIAN

function DAN:IsSourceMyPet(whoguid, whoflag)
	whoflag = whoflag or 0
	if (band(whoflag, BITMASK_PETS) > 0) and (band(whoflag, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0) then
		return true
	end
	if pguid and whoguid == pguid then
		return false
	end
	if band(whoflag, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0 and UnitExists('pet') then
		local petGuid = UnitGUID('pet')
		if petGuid and whoguid == petGuid then
			return true
		end
	end
	return false
end

function DAN:FilterEvent(args1,args2,subevent,whoguid,whoname,whoflag,tguid,tname,tflag,spellid,spellname,spellschool,amount,overHeal_Kill,args15,args16,args17,args18,dmgCrit)
	local db = E.db.DmgAtNameplates
	self.db = db
	if not db or not db.enable or not relevantEvents[subevent] then return end
	-- local args = {...}
	-- end
	local isPlayerEvent = pguid == whoguid;
	local isPetEvent = self:IsSourceMyPet(whoguid, whoflag)
	local playerToUnitEvent = isPlayerEvent and (tguid ~= pguid);
	local unitToPlayerEvent = not isPlayerEvent and (tguid == pguid);
	targetUnitType = self:GetUnitTypeByFlag(tflag);

	-- The Sirus/3.3.5 combat log has a different payload for melee attacks:
	-- SWING_DAMAGE: amount, overkill, school, resisted, blocked, absorbed, crit.
	-- SWING_MISSED: missType, offHand. Normalize without allocating a table.
	local swingDamage, swingMiss = subevent == "SWING_DAMAGE", subevent == "SWING_MISSED"
	if swingDamage or swingMiss then
		amount = spellid
		spellname = isPetEvent and AutoAttackPet or AutoAttack
		spellschool = 1
		spellid = isPetEvent and 315235 or 6603
		if swingDamage then dmgCrit = args16 end
	end
	local damageEvent = dse[subevent] or swingDamage
	local missEvent = mse[subevent] or swingMiss

	if isPetEvent then
		if damageEvent and db.petToTargetDamageText then
			self:DamageEvent(self:GetFrame(whoguid,whoname,whoflag,tguid,tname,tflag), spellname, amount, "pet", dmgCrit, spellid, whoguid, whoname)
		elseif missEvent and db.petToTargetDamageText then
			self:MissEventPet(self:GetFrame(whoguid,whoname,whoflag,tguid,tname,tflag), spellname, amount, spellid)
		elseif hse[subevent] and db.petToTargetHealText then
			self:HealEvent(self:GetFrame(whoguid,whoname,whoflag,tguid,tname,tflag), spellname, amount, args16, spellid,overHeal_Kill)
		end
	elseif playerToUnitEvent then
		if damageEvent and db.playerToTargetDamageText then
			self:DamageEvent(self:GetFrame(whoguid,whoname,whoflag,tguid,tname,tflag), spellname, amount, spellschool, dmgCrit, spellid, whoguid, whoname)
		elseif missEvent and db.playerToTargetDamageText then
			self:MissEvent(self:GetFrame(whoguid,whoname,whoflag,tguid,tname,tflag), spellname, amount, spellid)
		elseif subevent == "SPELL_DISPEL" and db.playerToTargetDamageText then
			self:DispelEvent(self:GetFrame(whoguid,whoname,whoflag,tguid,tname,tflag), spellname, overHeal_Kill, amount)
		elseif hse[subevent] and db.playerToTargetHealText then
			self:HealEvent(self:GetFrame(whoguid,whoname,whoflag,tguid,tname,tflag), spellname, amount, args16, spellid,overHeal_Kill)
		elseif csi[subevent] and db.playerToTargetDamageText then
			self:SpellInterruptEvent(self:GetFrame(whoguid,whoname,whoflag,tguid,tname,tflag), spellname,spellid,overHeal_Kill)
		end
	elseif unitToPlayerEvent or isPlayerEvent then
		if damageEvent and db.targetToPlayerDamageText then
			self:DamageEvent(self:GetFrame(whoguid,whoname,whoflag,tguid,tname,tflag), spellname, amount, spellschool, dmgCrit, spellid, whoguid, whoname)
		elseif missEvent and db.targetToPlayerDamageText then
			self:MissEvent(self:GetFrame(whoguid,whoname,whoflag,tguid,tname,tflag), spellname, amount, spellid)
		elseif subevent == "SPELL_DISPEL" and db.targetToPlayerDamageText then
			self:DispelEvent(self:GetFrame(whoguid,whoname,whoflag,tguid,tname,tflag), spellname, overHeal_Kill, amount)
		elseif hse[subevent] and db.targetToPlayerHealText then
			self:HealEvent(self:GetFrame(whoguid,whoname,whoflag,tguid,tname,tflag), spellname, amount, args16, spellid,overHeal_Kill)
		elseif csi[subevent] and db.targetToPlayerDamageText then
			self:SpellInterruptEvent(self:GetFrame(whoguid,whoname,whoflag,tguid,tname,tflag), spellname,spellid,overHeal_Kill)
		end
	end
end

function DAN:PLAYER_ENTERING_WORLD(...)
	ClearMissingPlates()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")

	pguid = UnitGUID("player")
	self.DmgTextFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self.DmgTextFrame:SetScript("OnEvent", function(_, event, ...)
		self:FilterEvent(event, ...)
	end)
	self.db = E.db.DmgAtNameplates
	E:CreateMover(self.ElvUI_ToPlayerFrame, "PlayerDMGFrame", L["PlayerDMGFrame"], nil, nil, nil, "ALL", nil, "DmgAtNameplates");
	E:CreateMover(self.ElvUI_ToTargetFrame, "TargetDMGFrame", L["TargetDMGFrame"], nil, nil, nil, "ALL", nil, "DmgAtNameplates");
end

function DAN:PLAYER_TALENT_UPDATE(event)
	local cache = C_Talent and C_Talent.GetSpecInfoCache and C_Talent.GetSpecInfoCache()
	if cache and self.activeSpec ~= cache.activeTalentGroup then
		self.db = E.db.DmgAtNameplates
		self.activeSpec = cache.activeTalentGroup
	end
end

function DAN:OnDisable()
	ClearMissingPlates()
	-- if not E.db.DmgAtNameplates.onorof then
	self.DmgTextFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	for fontString in pairs(animating) do self:DeleteFontString(fontString) end
	self.DmgTextFrame:SetScript("OnUpdate", nil)
end
function DAN:OnEnable()
	ClearMissingPlates()
	-- if E.db.DmgAtNameplates.onorof then
	self.DmgTextFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self.DmgTextFrame:SetScript("OnEvent", function(_, event, ...)
		self:FilterEvent(event, ...)
	end)
end

function DAN:Initialize()
	self:InitializePlateIndex()
	EP:RegisterPlugin(DAN.AddOnName, self.DmgAtNameplatesOptions)
	local cache = C_Talent and C_Talent.GetSpecInfoCache and C_Talent.GetSpecInfoCache()
	self.activeSpec = cache and cache.activeTalentGroup or 1
	self.db = E.db.DmgAtNameplates
	-- self.db = E.db
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_TALENT_UPDATE")
end

local function InitializeCallback()
	DAN:Initialize()
end

E:RegisterModule(DAN:GetName(), InitializeCallback)
