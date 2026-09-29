-- Robux purchases (Developer Products). Receipts are granted exactly once and only reported as
-- granted after the purchase id is saved (PlayerProfiles.processPurchase). Contents are fixed
-- and defined in StoreData; StoreLogic gives them.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local StoreData = require(Shared.StoreData)
local Progression = require(Shared.Progression)
local StoreLogic = require(script.Parent.StoreLogic)
local PlayerProfiles = require(script.Parent.PlayerProfiles)

local Remotes = ReplicatedStorage.Remotes
local notice = Remotes.Notice :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

local StoreService = {}

local function productKeyFor(productId: number): string?
	for key, product in StoreData.products do
		if product.productId ~= 0 and product.productId == productId then
			return key
		end
	end
	return nil
end

-- Gives a product to a loaded profile and tells the player what they got.
local function give(player: Player, productKey: string)
	return function(profile)
		local granted = StoreLogic.grant(profile, productKey, Progression.levelForXp(profile.xp), os.time())
		if granted then
			notice:FireClient(player, "notice_store_thanks", StoreData.products[productKey].nameKey)
			fx:FireClient(player, "purchased", granted)
		end
	end
end

function StoreService.processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local productKey = productKeyFor(receipt.ProductId)
	if not player or not productKey then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok = PlayerProfiles.processPurchase(player, tostring(receipt.PurchaseId), give(player, productKey))
	return if ok then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

function StoreService.start()
	MarketplaceService.ProcessReceipt = StoreService.processReceipt
	-- Studio-only helper: set the Workspace attribute LvDebugGrant to a product key (e.g.
	-- "coins_small") to give it to every loaded player without buying, for testing the store UI.
	if RunService:IsStudio() then
		local count = 0
		workspace:GetAttributeChangedSignal("LvDebugGrant"):Connect(function()
			local key = workspace:GetAttribute("LvDebugGrant")
			if typeof(key) ~= "string" or not StoreData.products[key] then
				return
			end
			for _, player in Players:GetPlayers() do
				count += 1
				PlayerProfiles.processPurchase(player, `studio-{os.time()}-{count}`, give(player, key))
			end
		end)
	end
end

return StoreService
