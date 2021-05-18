--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

local aDenominations = {}
---	On initializing, the script checks what the current ruleset is.
--	It then loads the correct denominations into the aDenominations table.
function onInit()
	local sRuleset = User.getRulesetName()
	-- Set multipliers for different currency denominations.
	-- nValue = value multiplier. nWeight = per-coin weight (in pounds)
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
end

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

--	This function creates the "Coins" item in a PC's inventory.
--	It populates the name, type, and description and then returns the database node.
local function createCoinsItem(nodeChar)
	local nodeCoinsItem = DB.createChild(nodeChar.getChild('inventorylist'))
	DB.setValue(nodeCoinsItem, 'name', 'string', 'Coins')
	DB.setValue(nodeCoinsItem, 'type', 'string', 'Wealth and Money')
	DB.setValue(nodeCoinsItem, 'description', 'formattedtext', Interface.getString("item_description_coins"))
	
	return nodeCoinsItem
end

---	This function rounds to the specified number of decimals
local function round(number, decimals)
    local n = 10^(decimals or 0)
    number = number * n
    if number >= 0 then number = math.floor(number + 0.5) else number = math.ceil(number - 0.5) end
    return number / n
end
	
---	This function calculates the weight of all coins and their total value (in gp).
--	It looks at each coins database subnode and checks them for the data of other extensions.
--	Then, it checks their denominations agains those defined in aDenominations.
--	If it doesn't find a match, it assumes a coin weight of .02.
--	It then looks for an item in the inventory called "Coins"
--	If it doesn't find it, and the weight or value total is not zero, it creates it.
--	
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
					Debug.chat(nTotalCoinsWeight, nCoinAmount, tDenominationData['nWeight'])
				end
			end
		else
			nTotalCoinsWeight = nTotalCoinsWeight + (nCoinAmount * .02)
		end
	end

	-- this looks for the "Coins" inventory if it already exists
	local nodeCoinsItem
	for _,nodeItem in pairs(DB.getChildren(nodeChar, 'inventorylist')) do
		local sItemName = DB.getValue(nodeItem, 'name', '')
		if sItemName == 'Coins' then
			nodeCoinsItem = nodeItem
		end
	end
	
	local nRoundTo = 2
	if nTotalCoinsWeight >= 100 then
		nRoundTo = 0
	elseif nTotalCoinsWeight >= 10 then
		nRoundTo = 1
	end

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
		DB.setValue(nodeCoinsItem, 'weight', 'number', round(nTotalCoinsWeight, nRoundTo))
	end
end

--	This function is called when a coin field is changed
function onCoinsValueChanged(nodeChar)
	computeCoins(nodeChar)
end