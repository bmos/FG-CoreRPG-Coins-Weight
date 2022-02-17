--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

-- Used for item name init and also finding the item, constant will never get out of sync.
COINS_INVENTORY_ITEM_NAME = 'Coins'

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
		DB.setValue(nodeCoinsItem, 'name', 'string', COINS_INVENTORY_ITEM_NAME)
		DB.setValue(nodeCoinsItem, 'count', 'number', 1)
		DB.setValue(nodeCoinsItem, 'type', 'string', 'Wealth and Money')
		DB.setValue(nodeCoinsItem, 'description', 'formattedtext', Interface.getString("item_description_coins"))
	end

	return nodeCoinsItem
end

---	This function looks for the "Coins" inventory item if it already exists.
--	It also matches "Coins (Coins Weight Extension)" for more context in name.
local function findCoinsItem(nodeChar)
	local nodeCoinsItemBookmark = nodeChar.getChild('coinsitembookmark')
	if nodeCoinsItemBookmark then return DB.findNode(DB.getText(nodeCoinsItemBookmark)) end
	for _,nodeItem in pairs(DB.getChildren(nodeChar, 'inventorylist')) do
		local sItemName = DB.getValue(nodeItem, 'name', '')
		if sItemName == COINS_INVENTORY_ITEM_NAME
		   or string.match(sItemName:lower(), '^%W*coins%W+coins%W+weight%W+extension%W*$') then
			return nodeItem
		end
	end
end

---	This function writes the coin data to the database.
local function writeCoinData(nodeChar, nTotalCoinsWeight, nTotalCoinsWealth)
	local sCoinItemNode = DB.getValue(nodeChar, 'coinsitembookmark')
	local nodeCoinsItem
	if sCoinItemNode then nodeCoinsItem = DB.findNode(sCoinItemNode) end

	-- search by name for backwards compatibility
	if not nodeCoinsItem then nodeCoinsItem = findCoinsItem(nodeChar) end

	if (nTotalCoinsWeight > 0 or nTotalCoinsWealth ~= 0) and not nodeCoinsItem then
		nodeCoinsItem = createCoinsItem(nodeChar)
	end
	if (nTotalCoinsWeight <= 0 and nTotalCoinsWealth == 0) and nodeCoinsItem then
		nodeCoinsItem.delete()
		local nodeCoinsItemBookmark = nodeChar.getChild('coinsitembookmark')
		if nodeCoinsItemBookmark then nodeCoinsItemBookmark.delete() end
	elseif nTotalCoinsWeight < 0 and nodeCoinsItem then
		DB.setValue(nodeCoinsItem, 'cost', 'string', nTotalCoinsWealth .. ' gp')
		DB.setValue(nodeCoinsItem, 'weight', 'number', 0) -- coins can't be negative weight
		DB.setValue(nodeCoinsItem, 'count', 'number', 1)
		DB.setValue(nodeChar, 'coinsitembookmark', 'string', nodeCoinsItem.getNodeName())
	elseif nodeCoinsItem then
		DB.setValue(nodeCoinsItem, 'cost', 'string', nTotalCoinsWealth .. ' gp')
		DB.setValue(nodeCoinsItem, 'weight', 'number', round(nTotalCoinsWeight, determineRounding(nTotalCoinsWeight)))
		DB.setValue(nodeCoinsItem, 'count', 'number', 1)
		DB.setValue(nodeChar, 'coinsitembookmark', 'string', nodeCoinsItem.getNodeName())
	end
end

---	This function calculates the weight of all coins and their total value (in gp).
--	It looks at each coins database subnode and checks them for the data of other extensions.
--	Then, it checks their denominations agains those defined in aDenominations.
--	If it doesn't find a match, it assumes a coin weight of .02.
local function computeCoins(nodeChar)
	local nTotalCoinsWeight, nTotalCoinsWealth = 0, 0
	for _,nodeCoinSlot in pairs(DB.getChildren(nodeChar, 'coins')) do
		local nCoinAmount = DB.getValue(nodeCoinSlot, 'amount', 0)
		local sDenomination = string.lower(DB.getValue(nodeCoinSlot, 'name', ''))
		local tCurrency = CurrencyManager.getCurrencyRecord(sDenomination)
		if tCurrency then
			nTotalCoinsWealth = nTotalCoinsWealth + (nCoinAmount * tCurrency['nValue'])
			nTotalCoinsWeight = nTotalCoinsWeight + (nCoinAmount * tCurrency['nWeight'])
		else
			nTotalCoinsWeight = nTotalCoinsWeight + (nCoinAmount * .02)
		end
	end
	writeCoinData(nodeChar, nTotalCoinsWeight, nTotalCoinsWealth)
end

--	This function is called when a denomination field is changed
local function onDenominationsChanged(nodeCurrency)
	for _,nodeChar in pairs(DB.getChildren(DB.findNode('charsheet'))) do
		computeCoins(nodeChar)
	end
end

--	This function is called when a coin field is changed
local function onCoinsValueChanged(nodeCoinData)
	local nodeChar = nodeCoinData.getChild('...')
	if nodeChar.getParent().getName() == 'charsheet' then
		computeCoins(nodeChar)
	end
end

local function calcDefaultCurrencyEncumbrance_new(nodeChar)
	return 0
end

function onInit()
	CharEncumbranceManager.calcDefaultCurrencyEncumbrance = calcDefaultCurrencyEncumbrance_new
	if Session.IsHost then
		DB.addHandler("charsheet.*.coins.*", "onChildUpdate", onCoinsValueChanged)
		DB.addHandler("charsheet.*.coins", "onChildDeleted", onCoinsValueChanged)
		DB.addHandler(CurrencyManager.CAMPAIGN_CURRENCY_LIST .. ".*.", "onChildUpdate", onDenominationsChanged)
		DB.addHandler(CurrencyManager.CAMPAIGN_CURRENCY_LIST, "onChildDeleted", onDenominationsChanged)
	end
end