--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--
-- Used for item name init and also finding the item, constant will never get out of sync.
-- luacheck: globals COINS_INVENTORY_ITEM_NAME
COINS_INVENTORY_ITEM_NAME = 'Coins'

---	This function calculates the weight of all coins and their total value (in gp).
--	It looks at each coins database subnode and checks them for the data of other extensions.
--	Then, it checks their denominations agains those defined in aDenominations.
--	If it doesn't find a match, it assumes a coin weight of .02.
local function computeCoins(nodeChar)

	---	This function writes the coin data to the database.
	local function writeCoinData(nTotalCoinsWeight, nTotalCoinsWealth)

		--- This function figures out how many decimal places to round to.
		--	If the total weight is greater than or equal to 100, it recommends 0 (whole numbers).
		--	If it's greater than or equal to 10, it recommends 1.
		--	If it's greater than or equal to 1, it recommends 2.
		--	Otherwise, it recommends 3.
		--	This maximizes difficulty at low levels when it has the most impact.
		--	The intent is to keep the number visible on the inventory list without clipping.
		local function determineRounding()
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
		local function createCoinsItem()
			if nodeChar.getParent().getName() == 'charsheet' then
				local nodeFirstInventory
				local tItemLists = ItemManager.getInventoryPaths('charsheet');
				for _, sItemList in pairs(tItemLists) do
					nodeFirstInventory = nodeChar.getChild(sItemList)
					if nodeFirstInventory then break end
				end
				if nodeFirstInventory then
					local nodeCoinsItem = DB.createChild(nodeFirstInventory)
					DB.setValue(nodeCoinsItem, 'name', 'string', COINS_INVENTORY_ITEM_NAME)
					DB.setValue(nodeCoinsItem, 'count', 'number', 1)
					DB.setValue(nodeCoinsItem, 'type', 'string', 'Wealth and Money')
					DB.setValue(nodeCoinsItem, 'description', 'formattedtext', '<p>' .. Interface.getString('item_description_coins') .. '</p>')
					return nodeCoinsItem
				end
			end
		end

		---	This function looks for the "Coins" inventory item if it already exists.
		--	It also matches "Coins (Coins Weight Extension)" for more context in name.
		local function findCoinsItem()
			local _, sCoinsItemNode = DB.getValue(nodeChar, 'coinitemshortcut')

			-- temporary until backwards compatibility no longer necessary
			if not sCoinsItemNode then sCoinsItemNode = DB.getValue(nodeChar, 'coinsitembookmark') end

			if sCoinsItemNode then return DB.findNode(sCoinsItemNode) end

			-- If path to coin item is not found in coinitemshortcut, search for the item by name (much slower)
			local function searchInventoriesForCoinsItem()
				local tItemLists = ItemManager.getInventoryPaths('charsheet');
				for _, sItemList in pairs(tItemLists) do
					for _, nodeItem in pairs(DB.getChildren(nodeChar, sItemList)) do
						local sItemName = DB.getValue(nodeItem, 'name', '')
						if sItemName == COINS_INVENTORY_ITEM_NAME or string.match(sItemName:lower(), '^%W*coins%W+coins%W+weight%W+extension%W*$') then
							return nodeItem
						end
					end
				end
			end

			searchInventoriesForCoinsItem()
		end

		local nodeCoinsItem = findCoinsItem()

		if not nodeCoinsItem and (nTotalCoinsWeight > 0 or nTotalCoinsWealth ~= 0) then nodeCoinsItem = createCoinsItem() end
		if nodeCoinsItem then

			-- temporary until backwards compatibility no longer necessary
			local nodeCoinsItemBookmark = nodeChar.getChild('coinsitembookmark')
			if nodeCoinsItemBookmark then nodeCoinsItemBookmark.delete() end

			if nTotalCoinsWeight <= 0 and nTotalCoinsWealth == 0 then
				nodeCoinsItem.delete()
				local nodeCoinsItemShortcut = nodeChar.getChild('coinitemshortcut')
				if nodeCoinsItemShortcut then nodeCoinsItemShortcut.delete() end
			elseif nTotalCoinsWeight < 0 then
				DB.setValue(nodeCoinsItem, 'cost', 'string', nTotalCoinsWealth .. ' gp')
				DB.setValue(nodeCoinsItem, 'weight', 'number', 0) -- coins can't be negative weight
				DB.setValue(nodeCoinsItem, 'count', 'number', 1)
				DB.setValue(nodeChar, 'coinitemshortcut', 'windowreference', 'item', nodeCoinsItem.getNodeName());
			else
				DB.setValue(nodeCoinsItem, 'cost', 'string', nTotalCoinsWealth .. ' gp')
				DB.setValue(nodeCoinsItem, 'weight', 'number', round(nTotalCoinsWeight, determineRounding()))
				DB.setValue(nodeCoinsItem, 'count', 'number', 1)
				DB.setValue(nodeChar, 'coinitemshortcut', 'windowreference', 'item', nodeCoinsItem.getNodeName());
			end
		end
	end

	local nTotalCoinsWeight, nTotalCoinsWealth = 0, 0
	local tCurrencyPaths = CurrencyManager.getCurrencyPaths('charsheet');
	for _, sCurrencyPath in pairs(tCurrencyPaths) do
		for _, nodeCoinSlot in pairs(DB.getChildren(nodeChar, sCurrencyPath)) do
			local nCoinAmount = DB.getValue(nodeCoinSlot, 'amount', 0)
			local sDenomination = string.lower(DB.getValue(nodeCoinSlot, 'name', ''))
			local tCurrency = CurrencyManager.getCurrencyRecord(sDenomination)
			if tCurrency then
				nTotalCoinsWealth = nTotalCoinsWealth + (nCoinAmount * (tCurrency['nValue'] or 0))
				nTotalCoinsWeight = nTotalCoinsWeight + (nCoinAmount * (tCurrency['nWeight'] or .02))
			else
				nTotalCoinsWeight = nTotalCoinsWeight + (nCoinAmount * .02)
			end
		end
	end
	writeCoinData(nTotalCoinsWeight, nTotalCoinsWealth)
end

--	This function is called when a denomination field is changed
local function onDenominationsChanged() for _, nodeChar in pairs(DB.getChildren(DB.findNode('charsheet'))) do computeCoins(nodeChar) end end

--	This function is called when a currency is removed from the character sheet
local function onCoinsDeleted(nodeCoins)
	local nodeChar = nodeCoins.getParent()
	if nodeChar.getParent().getName() == 'charsheet' then computeCoins(nodeChar) end
end

--	This function is called when a coin name or quantity is changed ont he character sheet
local function onCoinsValueChanged(nodeCoinData)
	local nodeChar = nodeCoinData.getChild('...')
	if nodeChar.getParent().getName() == 'charsheet' then computeCoins(nodeChar) end
end

local function calcDefaultCurrencyEncumbrance_new() return 0 end

function onInit()
	CharEncumbranceManager.calcDefaultCurrencyEncumbrance = calcDefaultCurrencyEncumbrance_new
	if Session.IsHost then
		local tCurrencyPaths = CurrencyManager.getCurrencyPaths('charsheet');
		for _, sCurrencyPath in pairs(tCurrencyPaths) do
			DB.addHandler('charsheet.*.' .. sCurrencyPath .. '.*', 'onChildUpdate', onCoinsValueChanged)
			DB.addHandler('charsheet.*.' .. sCurrencyPath, 'onChildDeleted', onCoinsDeleted)
		end
		DB.addHandler(CurrencyManager.CAMPAIGN_CURRENCY_LIST .. '.*.', 'onChildUpdate', onDenominationsChanged)
		DB.addHandler(CurrencyManager.CAMPAIGN_CURRENCY_LIST, 'onChildDeleted', onDenominationsChanged)
	end
end
