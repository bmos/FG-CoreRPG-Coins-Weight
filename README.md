# CoreRPG Coins Weight
This extension calculates coin weight and total monetary wealth.

# Compatibility and Instructions
This extension has been tested with [FantasyGrounds Unity](https://www.fantasygrounds.com/home/FantasyGroundsUnity.php) 4.0.10 (2021-02-04).
It has been tested with the CoreRPG, Pathfinder 1e, D&D 3.5E, and 5E rulesets.

Users of [damned](https://www.fantasygrounds.com/forums/member.php?19192-damned)'s [5eCoinWeight extension](https://www.fantasygrounds.com/forums/showthread.php?41109-The-weight-of-the-coins&p=387476&viewfull=1#post387476) will have carried and uncarried coins (from both columns) brought over seamlessly. 

# Features
It does this by adding a "Coins" inventory item of the appropriate weight and setting the cost of this item to the total value of all coins.
This "Coins" inventory entry can be marked uncarried or put into a bag of holding (if using my [extraplanar containers](https://www.fantasygrounds.com/forums/showthread.php?67126-PFRPG-Extraplanar-Containers) extension) to negate the weight.
Editing the coinweight.lua file allows setting different weights for different denominations.

# Included ruleset definitions:
*Pathfinder/3.5E*: pp, gp, sp, cp

*4E*: ad, pp, gp, sp, cp

*5E*: pp, gp, ep, sp, cp

To get more rulesets added, post in [the forum thread](https://www.fantasygrounds.com/forums/showthread.php?67228-CoreRPG-Coins-Weight) or create [a GitHub issue](https://github.com/bmos/FG-CoreRPG-Coins-Weight/issues/new).
Provide the name of your ruleset, a list of the official currencies, and their weight and value (as available).
