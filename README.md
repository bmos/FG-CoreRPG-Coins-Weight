[![Build FG-Usable File](https://github.com/bmos/FG-CoreRPG-Coins-Weight/actions/workflows/create-ext.yml/badge.svg)](https://github.com/bmos/FG-CoreRPG-Coins-Weight/actions/workflows/create-ext.yml) [![Luacheck](https://github.com/bmos/FG-CoreRPG-Coins-Weight/actions/workflows/luacheck.yml/badge.svg)](https://github.com/bmos/FG-CoreRPG-Coins-Weight/actions/workflows/luacheck.yml)

# Coins Weight
This extension calculates coin weight and total monetary wealth via the inventory by creating an item whose weight and value are equivalent to all carried coins.

# Compatibility and Instructions
This extension has been tested with [FantasyGrounds Unity](https://www.fantasygrounds.com/home/FantasyGroundsUnity.php) 4.3.0 (2022-10-20).

It has been tested with the CoreRPG, Pathfinder 1e, D&D 3.5E, and 5E rulesets. I likely works with many/most other rulesets as well.

Currencies must have weight and value defined in the options menu for these calculations to work and the currency weight option needs to be enabled.

# Features
Coin weight is tracked via a new "Coins" inventory item of the appropriate weight and value for the total of all coins.
This "Coins" inventory entry can be marked not carried or put into a bag of holding (if using my [extraplanar containers](https://www.fantasygrounds.com/forums/showthread.php?67126-PFRPG-Extraplanar-Containers) extension) to negate the weight.

If you are using a ruleset that has multiple inventories like Savage Worlds, you can delete the coins item and create one called Coins in your preferred inventory. The next time coin weight is recalculated the link will be re-established. Once this has occurred, you can rename the item to whatever you want. 

# Video Demonstration (click for video)
[<img src="https://i.ytimg.com/vi_webp/7X2PlfZ2bgE/hqdefault.webp">](https://www.youtube.com/watch?v=7X2PlfZ2bgE)
