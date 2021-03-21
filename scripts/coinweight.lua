--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

--	Set multipliers for different currency denominations. nValue = value multiplier. nWeight = per-coin weight (in pounds -- conversion is automatic)
local aDenominations =
	{
	-- ['mp'] = {['nValue'] = 500, ['nWeight'] = .3}, -- Asgurgolas' mithral pieces (homebrew)
	['pp'] = {['nValue'] = 10, ['nWeight'] = .02},
	['gp'] = {['nValue'] = 1, ['nWeight'] = .02},
	-- ['ep'] = {['nValue'] = .5, ['nWeight'] = .02}, -- electrum pieces (for Forgotten Realms homebrews)
	['sp'] = {['nValue'] = .1, ['nWeight'] = .02},
	['cp'] = {['nValue'] = .01, ['nWeight'] = .02},
	-- ['op'] = {['nValue'] = 0, ['nWeight'] = .02}, -- Zygmunt Molotch (homebrew)
	-- ['jp'] = {['nValue'] = 0, ['nWeight'] = .02}, -- Zygmunt Molotch (homebrew)
	}
	
---	Calculate weight of all coins and total value (in gp).
--	@param nodeChar databasenode of PC within charsheet
local function computeCoins(nodeChar)
	local nTotalCoinsWeight = 0
	local nWealth = 0

	for _,nodeCoinSlot in pairs(DB.getChildren(nodeChar, 'coins')) do
		local sDenomination = string.lower(DB.getValue(nodeCoinSlot, 'name', ''))
		local nCoinAmount = DB.getValue(nodeCoinSlot, 'amount', 0)

		-- upgrade method to support removing second coins column
		if DB.getValue(nodeCoinSlot, 'amountA') and DB.getValue(nodeCoinSlot, 'amountA', 0) ~= 0 then
			nCoinAmount = nCoinAmount + DB.getValue(nodeCoinSlot, 'amountA', 0)
			DB.setValue(nodeCoinSlot, 'amount', 'number', nCoinAmount)
			if DB.getValue(nodeCoinSlot, 'amountA') then nodeCoinSlot.getChild('amountA').delete() end
		end

		if sDenomination ~= '' then
			for sDenominationName,tDenominationData in pairs(aDenominations) do
				if string.match(sDenomination, sDenominationName) then
					nWealth = nWealth + (nCoinAmount * tDenominationData['nValue'])
					nTotalCoinsWeight = nTotalCoinsWeight + (nCoinAmount * tDenominationData['nWeight'])
				end
			end
		end
	end

	local nTotalCoinWeightToSet = math.floor(nTotalCoinsWeight)
	if nTotalCoinWeightToSet then
		local nodeOtherCoins
		for _,nodeItem in pairs(DB.getChildren(nodeChar, 'inventorylist')) do
			local sItemName = DB.getValue(nodeItem, 'name', '')
			if sItemName == 'Coins' then
				nodeOtherCoins = nodeItem
			end
		end
		if nTotalCoinWeightToSet > 0 and not nodeOtherCoins then
			nodeOtherCoins = DB.createChild(nodeChar.getChild('inventorylist'))
		end
		if nTotalCoinWeightToSet == 0 and nodeOtherCoins then
			nodeOtherCoins.delete()
		elseif nodeOtherCoins then
			DB.setValue(nodeOtherCoins, 'name', 'string', 'Coins')
			DB.setValue(nodeOtherCoins, 'type', 'string', 'Wealth and Money')
			DB.setValue(nodeOtherCoins, 'cost', 'string', nWealth .. ' gp')
			DB.setValue(nodeOtherCoins, 'description', 'formattedtext', Interface.getString("item_description_coins"))
			DB.setValue(nodeOtherCoins, 'weight', 'number', nTotalCoinWeightToSet)
		end
	end
end

--	This function is called when a coin field is changed
function onCoinsValueChanged(nodeChar)
	computeCoins(nodeChar)
end
