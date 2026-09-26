-- Run: lune run tests/api
-- Static check of Roblox API names against the reflection database bundled with Lune:
-- Enum items, Instance.new/GetService class names, property keys in property tables passed to
-- our instance helpers, and "x.Prop =" writes on variables created with Instance.new.
-- It cannot see types, so it only covers these patterns; it is a guard against typos and
-- invented members, not a full type checker.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local db = roblox.getReflectionDatabase()
local failures, checks = 0, 0

local function fail(message: string)
	failures += 1
	print("FAIL " .. message)
end

local function hasProperty(className: string, property: string): boolean
	local class = db:GetClass(className)
	while class do
		if class.Properties[property] then
			return true
		end
		class = class.Superclass and db:GetClass(class.Superclass)
	end
	return false
end

-- Keys our helpers consume themselves instead of setting as properties.
local HELPER_KEYS = { Corner = true, ClassName = true }

-- Helper call prefixes that are followed by a property table, and the class they create.
local helperPatterns = {
	{ "UiKit%.panel%(%s*{", "Frame" },
	{ "UiKit%.label%(%s*{", "TextLabel" },
	{ "UiKit%.button%(%s*{", "TextButton" },
	{ "[^%w]panel%(%s*{", "Frame" },
	{ "[^%w]label%(%s*{", "TextLabel" },
	{ "newPart%(%s*{", "Part" },
	{ "localPart%(%s*{", "Part" },
	{ "decorPart%([^{\n]-{", "Part" },
	{ "[^%w]part%([^{\n]-{", "Part" },
	{ "ballPart%([^{\n]-{", "Part" },
	{ "cylinder%([^{\n]-{", "Part" },
	{ "pillar%([^{\n]-{", "Part" },
}

local function tableKeys(source: string, openIndex: number): { string }
	local keys = {}
	local depth = 0
	local index = openIndex
	local length = #source
	local expectKey = true
	while index <= length do
		local char = string.sub(source, index, index)
		if char == "{" or char == "(" or char == "[" then
			depth += 1
			expectKey = depth == 1
		elseif char == "}" or char == ")" or char == "]" then
			depth -= 1
			if depth == 0 then
				break
			end
		elseif char == "," and depth == 1 then
			expectKey = true
		elseif char == '"' then
			local closing = string.find(source, '"', index + 1, true)
			index = closing or length
		elseif depth == 1 and expectKey and string.match(char, "[%a_]") then
			local key, after = string.match(source, "^([%a_][%w_]*)%s*=()", index)
			if key and string.sub(source, after, after) ~= "=" then
				table.insert(keys, key)
			end
			expectKey = false
		elseif depth == 1 and not string.match(char, "%s") then
			expectKey = false
		end
		index += 1
	end
	return keys
end

local function checkTable(path: string, source: string, openIndex: number, className: string)
	for _, key in tableKeys(source, openIndex) do
		if not HELPER_KEYS[key] then
			checks += 1
			if not hasProperty(className, key) then
				fail(`{path}: {className} has no property "{key}"`)
			end
		end
	end
end

local function checkFile(path: string)
	local source = fs.readFile(path)

	for enumName, item in string.gmatch(source, "Enum%.([%a][%w]*)%.([%a][%w]*)") do
		checks += 1
		local enum = db:GetEnum(enumName)
		if not enum or enum.Items[item] == nil then
			fail(`{path}: Enum.{enumName}.{item} does not exist`)
		end
	end

	for className in string.gmatch(source, "Instance%.new%(%s*\"([%a][%w]*)\"") do
		checks += 1
		if not db:GetClass(className) then
			fail(`{path}: class {className} does not exist`)
		end
	end

	for serviceName in string.gmatch(source, "GetService%(%s*\"([%a]+)\"") do
		checks += 1
		if not db:GetClass(serviceName) then
			fail(`{path}: service {serviceName} does not exist`)
		end
	end

	-- Property tables with an explicit class: create("X", {..}) / ensure(a, b, "X", {..}) / part(.., { ClassName = "X" }).
	local position = 1
	while true do
		local start, finish, className = string.find(source, "create%(%s*\"([%a]+)\"%s*,%s*{", position)
		if not start then
			break
		end
		checkTable(path, source, finish, className)
		position = finish + 1
	end
	position = 1
	while true do
		local start, finish, className = string.find(source, "ensure%([^,]+,[^,]+,%s*\"([%a]+)\"%s*,%s*{", position)
		if not start then
			break
		end
		checkTable(path, source, finish, className)
		position = finish + 1
	end
	for _, helper in helperPatterns do
		position = 1
		while true do
			local start, finish = string.find(source, helper[1], position)
			if not start then
				break
			end
			local className = helper[2]
			local override = string.match(string.sub(source, finish, finish + 400), "^{[^}]-ClassName%s*=%s*\"([%a]+)\"")
			checkTable(path, source, finish, override or className)
			position = finish + 1
		end
	end

	-- x.Prop = value on locals created with Instance.new("Class").
	for variable, className in string.gmatch(source, "local%s+([%w_]+)%s*=%s*Instance%.new%(%s*\"([%a][%w]*)\"%s*%)") do
		for property in string.gmatch(source, "[^%w_%.]" .. variable .. "%.(%u[%w_]*)%s*=[^=]") do
			checks += 1
			if not hasProperty(className, property) then
				fail(`{path}: {variable} ({className}) has no property "{property}"`)
			end
		end
	end
end

local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			if name ~= "Packages" then
				walk(path)
			end
		elseif string.sub(name, -5) == ".luau" then
			checkFile(path)
		end
	end
end

walk("src")
print(`api check: {checks} references checked, {failures} failures`)
if failures > 0 then
	error("api check failed")
end
