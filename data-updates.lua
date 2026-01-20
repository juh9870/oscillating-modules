local flib_locale = require("__flib__.locale")

local preset_name = settings.startup["oscillating-modules-preset"].value --[[@as string]]

local presets = {
	["sine"] = {
		steps = 100,
		spoil_ticks = "60",
		effect_strength = "sin(pi * x / 50) + 1",
	},
	["toggle"] = {
		steps = 2,
		spoil_ticks = "3600",
		effect_strength = "(1 - x) * 2",
	},
	["decay"] = {
		steps = 60,
		spoil_ticks = "x == 60 and 0 or 3600",
		effect_strength = "max(3 * 2 ^ (- x / 10), 0.05)",
	},
	["custom"] = {
		steps = settings.startup["oscillating-modules-steps-amount"].value --[[@as number]],
		spoil_ticks = settings.startup["oscillating-spoil-ticks-formula"].value --[[@as string]],
		effect_strength = settings.startup["oscillating-spoil-effect-strength-formula"].value --[[@as string]],
	},
}

---@param str string
---@return function|nil
---@return string|nil
eval = function(str)
	str = "return function(env) \n" .. "_ENV = env\n" .. " return " .. str .. " end"

	local func, err = load(str)
	if err ~= nil then
		return nil, err
	end
	local ok, fn_or_err = pcall(func --[[@as function]])
	if not ok then
		return nil, "function evaluation failed - " .. serpent.line(fn_or_err)
	end

	return fn_or_err, nil
end

local selected_preset = presets[preset_name]

local modules_to_add = {}

local effects = { "consumption", "speed", "productivity", "pollution", "quality" }
local cap = {
	consumption = 327,
	speed = 327,
	productivity = 327,
	pollution = 327,
	quality = 327,
}

local formula_err = nil

local effect_strength_formula, spoil_ticks_formula, err

effect_strength_formula, err = eval(selected_preset.effect_strength)
if err ~= nil then
	msg = "Failed to parse custom effect strength formula " .. serpent.line(err)
	formula_err = msg
end

spoil_ticks_formula, err = eval(selected_preset.spoil_ticks)
if err ~= nil then
	msg = "Failed to parse custom step duration formula " .. serpent.line(err)
	formula_err = msg
end

local math_env = {}
for k, v in pairs(math) do
	math_env[k] = v
end

function apply_effects(module, factor)
	for _, eff in pairs(effects) do
		local e = module.effect[eff]
		if e ~= nil then
			new_eff = factor * e
			if math.abs(new_eff) > cap[eff] then
				if new_eff > 0 then
					new_eff = cap[eff]
				else
					new_eff = -cap[eff]
				end
			end
			module.effect[eff] = new_eff
		end
	end
end

function apply_factor(module, i, previous_factor, item_name)
	local factor = 0
	local spoil_ticks = 60

	if formula_err == nil then
		math_env.x = i
		local ok, factor_eval = pcall(effect_strength_formula --[[@as function]], math_env)
		if not ok then
			formula_err = "Failed to execute the effect strength formula for x="
				.. i
				.. " - "
				.. serpent.line(factor_eval)
		else
			factor = factor_eval
		end
		if factor_eval == nil then
			formula_err = "Effect strength formula returned nil value for x=" .. i
			factor = 0
		end
	end

	if formula_err == nil then
		math_env.x = i
		local ok, spoil_ticks_eval = pcall(spoil_ticks_formula --[[@as function]], math_env)
		if not ok then
			formula_err = "Failed to execute the step duration formula for x="
				.. i
				.. " - "
				.. serpent.line(spoil_ticks_eval)
		else
			spoil_ticks = spoil_ticks_eval
		end
		if spoil_ticks == nil then
			formula_err = "Step duration formula formula returned nil value for x=" .. i
			spoil_ticks = 60
		end
	end

	local factor_p_display = math.floor(factor * 100 + 0.5)
	factor = factor_p_display / 100

	if factor > previous_factor then
		module.localised_name =
			{ "item-name.oscillating-module-template-rising", tostring(factor_p_display), item_name }
	elseif factor < previous_factor then
		module.localised_name =
			{ "item-name.oscillating-module-template-falling", tostring(factor_p_display), item_name }
	else
		module.localised_name =
			{ "item-name.oscillating-module-template-stable", tostring(factor_p_display), item_name }
	end

	if spoil_ticks > 0 then
		module.spoil_ticks = spoil_ticks
	end

	apply_effects(module, factor)
	return factor
end

for _, module in pairs(data.raw["module"]) do
	if module.spoil_result ~= nil then
		goto continue
	end
	local item_name = flib_locale.of_item(module)

	local steps = selected_preset.steps - 1

	local previous = module
	local previous_factor = 1
	for i = 1, steps do
		local clone = table.deepcopy(module)
		clone.name = clone.name .. "-oscillator-" .. i
		clone.hidden = true
		clone.hidden_in_factoriopedia = true
		clone.subgroup = nil

		local factor = apply_factor(clone, i, previous_factor, item_name)

		if previous.spoil_ticks ~= nil or i == 1 then
			previous.spoil_result = clone.name
		end

		previous = clone
		previous_factor = factor
		table.insert(modules_to_add, clone)
		if clone.spoil_ticks == nil then
			break
		end
	end

	previous.spoil_result = module.name
	apply_factor(module, 0, previous_factor, item_name)

	::continue::
end

if formula_err ~= nil then
	formula_err = string.gsub(formula_err, '%[string \\"return function%(env%) %.%.%.\\"]:3: ', "")
	-- error("Oscillating module misconfigured - " .. formula_err)
	for _, mod in pairs(modules_to_add) do
		if mod.localised_name ~= nil then
			mod.localised_name = formula_err
		end
	end
	for _, mod in pairs(data.raw["module"]) do
		if mod.localised_name ~= nil then
			mod.localised_name = formula_err
		end
	end
end

data:extend(modules_to_add)
