-- Short, kid-readable numbers for damage, coins and costs: 950, 12.3K, 150K, 4.5M, 2.1B.
local Format = {}

local UNITS = { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

function Format.short(value: number): string
	local sign = if value < 0 then "-" else ""
	local n = math.abs(value)
	for _, unit in UNITS do
		if n >= unit[1] then
			local scaled = n / unit[1]
			-- One decimal below 100 (12.3K), none above (150K); never shows a trailing ".0".
			local text = if scaled < 100 then string.format("%.1f", math.floor(scaled * 10) / 10) else tostring(math.floor(scaled))
			text = string.gsub(text, "%.0$", "")
			return sign .. text .. unit[2]
		end
	end
	return sign .. tostring(math.floor(n))
end

return Format
