-- Run: lune run tests/all
-- Runs every automated check (needs lune and rojo on PATH). Works on Windows and Linux.
local fs = require("@lune/fs")
local process = require("@lune/process")

if not fs.isDir("build") then
	fs.writeDir("build")
end

local steps = {
	{ "lune", { "run", "tests/logic" } },
	{ "lune", { "run", "tests/api" } },
	{ "lune", { "run", "tests/scene" } },
	{ "lune", { "run", "tests/sim" } },
	{ "lune", { "run", "tests/client", "desktop" } },
	{ "lune", { "run", "tests/client", "touch" } },
	{ "lune", { "run", "tests/client", "touch-cas" } },
	{ "rojo", { "build", "default.project.json", "-o", "build/test.rbxlx" } },
	{ "lune", { "run", "tests/place", "build/test.rbxlx" } },
}

local failed = 0
for _, step in steps do
	local result = process.exec(step[1], step[2])
	local output = result.stdout .. result.stderr
	local lastLine = string.match(output, "([^\n]+)\n?$") or ""
	print((if result.ok then "ok   " else "FAIL ") .. step[1] .. " " .. table.concat(step[2], " ") .. "  ->  " .. lastLine)
	if not result.ok then
		failed += 1
		print(output)
	end
end

if failed > 0 then
	error(`{failed} check(s) failed`)
end
print("all checks passed")
