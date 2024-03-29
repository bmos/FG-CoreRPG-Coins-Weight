--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--
-- Used for item name init and also finding the item, constant will never get out of sync.
-- luacheck: globals COINS_INVENTORY_ITEM_NAME
COINS_INVENTORY_ITEM_NAME = 'Coins'

--- This function figures out how many decimal places to round to.
--	If the total weight is greater than or equal to 100, it recommends 0 (whole numbers).
--	If it's greater than or equal to 10, it recommends 1.
--	Otherwise, it recommends 2.
--	This maximizes difficulty at low levels when it has the most impact.
--	The intent is to keep the number visible on the inventory list without clipping.
local function determineRounding(nTotalCoinsWeight)
	if nTotalCoinsWeight >= 100 then
		return 0
	elseif nTotalCoinsWeight >= 10 then
		return 1
	else
		return 2
	end
end

---	This function rounds to the specified number of decimals
local function round(number, decimals)
	local n = 10 ^ (decimals or 0)
	number = number * n
	if number >= 0 then
		number = math.floor(number + 0.5)
	else
		number = math.ceil(number - 0.5)
	end
	return number / n
end

--	This function creates the "Coins" item in a PC's inventory.
--	It populates the name, type, and description and then returns the database node.
local function createCoinsItem(nodeChar)
	if DB.getName(nodeChar, '..') == 'charsheet' then
		local nodeFirstInventory
		local tItemLists = ItemManager.getInventoryPaths('charsheet')
		for _, sItemList in pairs(tItemLists) do
			nodeFirstInventory = DB.getChild(nodeChar, sItemList)
			if nodeFirstInventory then
				break
			end
		end
		if nodeFirstInventory then
			local sCoinDesc = string.format('<p>%s</p>', Interface.getString('item_description_coins'))
			local nodeCoinsItem = DB.createChild(nodeFirstInventory)
			DB.setValue(nodeCoinsItem, 'name', 'string', COINS_INVENTORY_ITEM_NAME)
			DB.setValue(nodeCoinsItem, 'count', 'number', 1)
			DB.setValue(nodeCoinsItem, 'type', 'string', 'Wealth and Money')
			DB.setValue(nodeCoinsItem, 'description', 'formattedtext', sCoinDesc)
			return nodeCoinsItem
		end
	end
end

-- If path to coin item is not found in coinitemshortcut, search for the item by name (much slower)
local function searchInventoriesForCoinsItem(nodeChar)
	local tItemLists = ItemManager.getInventoryPaths('charsheet')
	for _, sItemList in pairs(tItemLists) do
		for _, nodeItem in ipairs(DB.getChildList(nodeChar, sItemList)) do
			local sItemName = DB.getValue(nodeItem, 'name', '')
			local sCoinsNameRegex = '^%W*coins%W+coins%W+weight%W+extension%W*$'
			if sItemName == COINS_INVENTORY_ITEM_NAME or string.match(sItemName:lower(), sCoinsNameRegex) then
				return nodeItem
			end
		end
	end
end

---	This function calculates the weight of all coins and their total value (in gp).
--	It looks at each coins database subnode and checks them for the data of other extensions.
--	Then, it checks their denominations agains those defined in aDenominations.
--	If it doesn't find a match, it assumes a coin weight of .02.
local function computeCoins(nodeChar)
	---	This function writes the coin data to the database.
	local function writeCoinData(nTotalCoinsWeight, nTotalCoinsWealth)
		---	This function looks for the "Coins" inventory item if it already exists.
		--	It also matches "Coins (Coins Weight Extension)" for more context in name.
		local function findCoinsItem()
			local _, sCoinsItemNode = DB.getValue(nodeChar, 'coinitemshortcut')
			if sCoinsItemNode then
				return DB.findNode(sCoinsItemNode)
			end
			searchInventoriesForCoinsItem(nodeChar)
		end

		local nodeCoinsItem = findCoinsItem()
		if not nodeCoinsItem and (nTotalCoinsWeight > 0 or nTotalCoinsWealth ~= 0) then
			nodeCoinsItem = createCoinsItem(nodeChar)
		end
		if not nodeCoinsItem then
			return
		end

		if nTotalCoinsWeight <= 0 and nTotalCoinsWealth == 0 then
			DB.deleteNode(nodeCoinsItem)
			local nodeCoinsItemShortcut = DB.getChild(nodeChar, 'coinitemshortcut')
			if nodeCoinsItemShortcut then
				DB.deleteNode(nodeCoinsItemShortcut)
			end
		elseif nTotalCoinsWeight < 0 then
			DB.setValue(nodeCoinsItem, 'cost', 'string', nTotalCoinsWealth .. ' gp')
			DB.setValue(nodeCoinsItem, 'weight', 'number', 0) -- coins can't be negative weight
			DB.setValue(nodeCoinsItem, 'count', 'number', 1)
			DB.setValue(nodeChar, 'coinitemshortcut', 'windowreference', 'item', DB.getPath(nodeCoinsItem))
		else
			local nCostRound = 3
			if User.getRulesetName() == 'PFRPG2' or User.getRulesetName() == 'PFRPG2-Legacy' then
				nCostRound = 0
			end

			DB.setValue(nodeCoinsItem, 'cost', 'string', round(nTotalCoinsWealth, nCostRound) .. ' gp')
			DB.setValue(nodeCoinsItem, 'weight', 'number', round(nTotalCoinsWeight, determineRounding(nTotalCoinsWeight)))
			DB.setValue(nodeCoinsItem, 'count', 'number', 1)
			DB.setValue(nodeChar, 'coinitemshortcut', 'windowreference', 'item', DB.getPath(nodeCoinsItem))
		end
	end

	local nTotalCoinsWeight, nTotalCoinsWealth = 0, 0
	local tCurrencyPaths = CurrencyManager.getCurrencyPaths('charsheet')
	for _, sCurrencyPath in pairs(tCurrencyPaths) do
		for _, nodeCoinSlot in ipairs(DB.getChildList(nodeChar, sCurrencyPath)) do
			local nCoinAmount = DB.getValue(nodeCoinSlot, 'amount', 0)
			local sDenomination = string.lower(DB.getValue(nodeCoinSlot, 'name', ''))
			local tCurrency = CurrencyManager.getCurrencyRecord(sDenomination)
			if tCurrency then
				nTotalCoinsWealth = nTotalCoinsWealth + (nCoinAmount * (tCurrency['nValue'] or 0))
				nTotalCoinsWeight = nTotalCoinsWeight + (nCoinAmount * (tCurrency['nWeight'] or 0.02))
			else
				nTotalCoinsWeight = nTotalCoinsWeight + (nCoinAmount * 0.02)
			end
		end
	end
	writeCoinData(nTotalCoinsWeight, nTotalCoinsWealth)
end

--	This function is called when a denomination field is changed
local function onDenominationsChanged()
	for _, nodeChar in ipairs(DB.getChildList('charsheet')) do
		computeCoins(nodeChar)
	end
end

--	This function is called when a currency is removed from the character sheet
local function onCoinsDeleted(nodeCoins)
	local nodeChar = DB.getParent(nodeCoins)
	if DB.getName(nodeChar, '..') == 'charsheet' then
		computeCoins(nodeChar)
	end
end

--	This function is called when a coin name or quantity is changed on the character sheet
local function onCoinsValueChanged(nodeCoinData)
	local nodeChar = DB.getChild(nodeCoinData, '...')
	if DB.getName(nodeChar, '..') == 'charsheet' then
		computeCoins(nodeChar)
	end
end

local function calcDefaultCurrencyEncumbrance_new()
	return 0
end

function onInit()
	CharEncumbranceManager.calcDefaultCurrencyEncumbrance = calcDefaultCurrencyEncumbrance_new
	if not Session.IsHost then
		return
	end
	for _, sCurrencyPath in pairs(CurrencyManager.getCurrencyPaths('charsheet')) do
		DB.addHandler(string.format('charsheet.*.%s.*', sCurrencyPath), 'onChildUpdate', onCoinsValueChanged)
		DB.addHandler(string.format('charsheet.*.%s', sCurrencyPath), 'onChildDeleted', onCoinsDeleted)
	end
	DB.addHandler(CurrencyManager.CAMPAIGN_CURRENCY_LIST .. '.*.', 'onChildUpdate', onDenominationsChanged)
	DB.addHandler(CurrencyManager.CAMPAIGN_CURRENCY_LIST, 'onChildDeleted', onDenominationsChanged)
end
