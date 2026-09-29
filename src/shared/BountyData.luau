-- Bounty Board: three open bounties at a time. A bounty counts something the player does after
-- taking it (`counter` = a profile counter, see server/AchievementLogic). Claiming pays coins
-- equal to `minutes` of the player's own income (Progression.incomeCoins) plus Pass XP, then the
-- board offers a new bounty. Nothing expires and nothing is lost by waiting. `effort` is roughly
-- how many minutes the goal takes; rewards stay well under it so bounties add to income, not double it.
return {
	slots = 3,
	-- Pass XP action paid for every claimed bounty (see PassData.xp).
	passAction = "bounty",

	order = { "purify", "elite", "rift", "chest", "legend" },
	kinds = {
		purify = { nameKey = "bounty_purify", counter = "purifies", goal = 40, minutes = 1.2, effort = 2.7, minLevel = 1 },
		elite = { nameKey = "bounty_elite", counter = "elites", goal = 3, minutes = 1.5, effort = 3.3, minLevel = 3 },
		rift = { nameKey = "bounty_rift", counter = "rifts", goal = 1, minutes = 1.5, effort = 2.5, minLevel = 1 },
		chest = { nameKey = "bounty_chest", counter = "chests", goal = 2, minutes = 1, effort = 2, minLevel = 1 },
		legend = { nameKey = "bounty_legend", counter = "legendWins", goal = 1, minutes = 2, effort = 4, minLevel = 25 },
	},
}
