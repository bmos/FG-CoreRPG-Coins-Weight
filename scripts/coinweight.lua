--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

---	This function imports the data from the second column of coins used in damned's coins weight extension.
--	bmos also used this data structure in an early version of Total Encumbrance.
--	Once imported, the original database nodes are deleted.
local function upgradeDamnedCoinWeight(nodeCoinSlot)
	local nCoinAmount = DB.getValue(nodeCoinSlot, 'amount', 0)
	local nCoinAmount2 = DB.getValue(nodeCoinSlot, 'amountA', 0)
	if nCoinAmount2 ~= 0 then
		local nCoinAmount = nCoinAmount + nCoinAmount2
		DB.setValue(nodeCoinSlot, 'amount', 'number', nCoinAmount)
		if DB.getValue(nodeCoinSlot, 'amountA') then nodeCoinSlot.getChild('amountA').delete() end
	end
end

---	This function rounds to the specified number of decimals
local function round(number, decimals)
    local n = 10^(decimals or 0)
    number = number * n
    if number >= 0 then number = math.floor(number + 0.5) else number = math.ceil(number - 0.5) end
    return number / n
end

--- This function figures out how many decimal places to round to.
--	If the total weight is greater than or equal to 100, it recommends 0 (whole numbers).
--	If it's greater than or equal to 10, it recommends 1.
--	If it's greater than or equal to 1, it recommends 2.
--	Otherwise, it recommends 3.
--	This maximizes difficulty at low levels when it has the most impact.
--	The intent is to keep the number visible on the inventory list without clipping.
local function determineRounding(nTotalCoinsWeight)
	if nTotalCoinsWeight >= 100 then
		return 0
	elseif nTotalCoinsWeight >= 10 then
		return 1
	elseif nTotalCoinsWeight >= 1 then
		return 2
	else
		return 3
	end 
end

--	This function creates the "Coins" item in a PC's inventory.
--	It populates the name, type, and description and then returns the database node.
local function createCoinsItem(nodeChar)
	local nodeCoinsItem
	if nodeChar.getParent().getName() == 'charsheet' then
		nodeCoinsItem = DB.createChild(nodeChar.createChild('inventorylist'))
		DB.setValue(nodeCoinsItem, 'name', 'string', 'Coins')
		DB.setValue(nodeCoinsItem, 'type', 'string', 'Wealth and Money')
		DB.setValue(nodeCoinsItem, 'description', 'formattedtext', Interface.getString("item_description_coins"))
	end

	return nodeCoinsItem
end

---	This function looks for the "Coins" inventory item if it already exists.
local function findCoinsItem(nodeChar)
	for _,nodeItem in pairs(DB.getChildren(nodeChar, 'inventorylist')) do
		local sItemName = DB.getValue(nodeItem, 'name', '')
		if sItemName == 'Coins' then
			return nodeItem
		end
	end
end

---	This function writes the coin data to the database.
local function writeCoinData(nodeChar, nTotalCoinsWeight, nTotalCoinsWealth)
	local nodeCoinsItem = findCoinsItem(nodeChar)
	if (nTotalCoinsWeight > 0 or nTotalCoinsWealth ~= 0) and not nodeCoinsItem then
		nodeCoinsItem = createCoinsItem(nodeChar)
	end
	if (nTotalCoinsWeight <= 0 and nTotalCoinsWealth == 0) and nodeCoinsItem then
		nodeCoinsItem.delete()
	elseif nTotalCoinsWeight < 0 and nodeCoinsItem then
		DB.setValue(nodeCoinsItem, 'cost', 'string', nTotalCoinsWealth .. ' gp')
		DB.setValue(nodeCoinsItem, 'weight', 'number', 0) -- coins can't be negative weight
	elseif nodeCoinsItem then
		DB.setValue(nodeCoinsItem, 'cost', 'string', nTotalCoinsWealth .. ' gp')
		DB.setValue(nodeCoinsItem, 'weight', 'number', round(nTotalCoinsWeight, determineRounding(nTotalCoinsWeight)))
	end
end

---	This function calculates the weight of all coins and their total value (in gp).
--	It looks at each coins database subnode and checks them for the data of other extensions.
--	Then, it checks their denominations agains those defined in aDenominations.
--	If it doesn't find a match, it assumes a coin weight of .02.
local function computeCoins(nodeChar)
	local nTotalCoinsWeight, nTotalCoinsWealth = 0, 0
	for _,nodeCoinSlot in pairs(DB.getChildren(nodeChar, 'coins')) do
		-- import data from other extensions
		upgradeDamnedCoinWeight(nodeCoinSlot)

		local nCoinAmount = DB.getValue(nodeCoinSlot, 'amount', 0)
		local sDenomination = string.lower(DB.getValue(nodeCoinSlot, 'name', ''))
		if sDenomination ~= '' then
			for sDenominationName,tDenominationData in pairs(aDenominations) do
				if string.match(sDenomination, string.lower(sDenominationName)) then
					nTotalCoinsWealth = nTotalCoinsWealth + (nCoinAmount * tDenominationData['nValue'])
					nTotalCoinsWeight = nTotalCoinsWeight + (nCoinAmount * tDenominationData['nWeight'])
				end
			end
		else
			nTotalCoinsWeight = nTotalCoinsWeight + (nCoinAmount * nDefaultCoinWeight)
		end
	end
	writeCoinData(nodeChar, nTotalCoinsWeight, nTotalCoinsWealth)
end

--	This function is called when a coin field is changed
local function onCoinsValueChanged(nodeCoinData)
	local nodeChar = nodeCoinData.getChild('...')
	if nodeChar.getParent().getName() == 'charsheet' then
		computeCoins(nodeChar)
	end
end

---	On initializing, the script checks what the current ruleset is.
--	It then loads the correct denominations into the aDenominations table.
--	Then it configures a database node handler to watch for changes to coin data.
nDefaultCoinWeight = .02
aDenominations = {}
function onInit()
	local sRuleset = User.getRulesetName()
	-- Set multipliers for different currency denominations.
	-- nValue = per-coin value multiplier. nWeight = per-coin weight multiplier (in pounds)
	if sRuleset == "3.5E" or sRuleset == "PFRPG" or sRuleset == "PFRPG2" then
		-- aDenominations['mp'] = { ['nValue'] = 500, ['nWeight'] = .3 } -- Asgurgolas' Mithral Pieces (homebrew)
		aDenominations['pp'] = { ['nValue'] = 10, ['nWeight'] = .02 }
		aDenominations['gp'] = { ['nValue'] = 1, ['nWeight'] = .02 }
		aDenominations['sp'] = { ['nValue'] = .1, ['nWeight'] = .02 }
		aDenominations['cp'] = { ['nValue'] = .01, ['nWeight'] = .02 }
		-- aDenominations['op'] = { ['nValue'] = 0, ['nWeight'] = .02 } -- Zygmunt Molotch (homebrew)
		-- aDenominations['jp'] = { ['nValue'] = 0, ['nWeight'] = .02 } -- Zygmunt Molotch (homebrew)
	elseif sRuleset == "5E" then
		aDenominations['pp'] = { ['nValue'] = 10, ['nWeight'] = .02 }
		aDenominations['gp'] = { ['nValue'] = 1, ['nWeight'] = .02 }
		aDenominations['ep'] = { ['nValue'] = .5, ['nWeight'] = .02 }
		aDenominations['sp'] = { ['nValue'] = .1, ['nWeight'] = .02 }
		aDenominations['cp'] = { ['nValue'] = .01, ['nWeight'] = .02 }
	elseif sRuleset == "4E" then
		aDenominations['ad'] = { ['nValue'] = 10000, ['nWeight'] = .002 }
		aDenominations['pp'] = { ['nValue'] = 100, ['nWeight'] = .02 }
		aDenominations['gp'] = { ['nValue'] = 1, ['nWeight'] = .02 }
		aDenominations['sp'] = { ['nValue'] = .1, ['nWeight'] = .02 }
		aDenominations['cp'] = { ['nValue'] = .01, ['nWeight'] = .02 }
	end
	
	if Session.IsHost then
		DB.addHandler("charsheet.*.coins.*", "onChildUpdate", onCoinsValueChanged)
	end
end