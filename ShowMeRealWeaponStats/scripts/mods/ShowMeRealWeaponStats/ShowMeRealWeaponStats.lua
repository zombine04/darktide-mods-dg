local mod = get_mod("ShowMeRealWeaponStats")
require("scripts/ui/view_content_blueprints/item_stats_blueprints")
local WeaponStats = require("scripts/utilities/weapon_stats")
local ViewElementWeaponInfo = require("scripts/ui/view_elements/view_element_weapon_info/view_element_weapon_info")

local bar_size = 100

local function fake_item(item)
	local clone = table.clone(item)
	setmetatable(clone, {
		__index = function(t, field_name)
			if field_name == "gear_id" then
				return rawget(clone, "__gear_id")
			end
			if field_name == "gear" then
				return rawget(clone, "__gear")
			end

			local master_item = rawget(clone, "__master_item")
			if not master_item then
				return nil
			end

			local field_value = master_item[field_name]
			if field_name == "rarity" and field_value == -1 then
				return nil
			end
			return field_value
		end,
	})
	return clone
end

local function get_breakdown_compare_string(breakdown)
	local type_data = breakdown.type_data
	local group_type_data = breakdown.group_type_data
	local override_data = breakdown.override_data or {}

	local name = override_data.display_name or type_data.display_name
	local group_prefix = group_type_data and group_type_data.prefix and group_type_data.prefix or ""
	local prefix = override_data.prefix or type_data.prefix
	prefix = prefix and prefix .. " " or ""
	local postfix = group_type_data and group_type_data.postfix and group_type_data.postfix .. " " or ""
	local suffix = (override_data.suffix or type_data.suffix) and (override_data.suffix or type_data.suffix) or ""
	return string.format("%s %s%s%s%s", group_prefix, prefix, name, suffix, postfix)
end

local function breakdown_equal(a, b)
	return get_breakdown_compare_string(a) == get_breakdown_compare_string(b)
end

local x = true
mod:hook(package.loaded, "scripts/ui/view_content_blueprints/item_stats_blueprints", function(generate_blueprints_function, grid_size, optional_item)
	local blueprints = generate_blueprints_function(grid_size, optional_item)
	if not blueprints.weapon_stats or not blueprints.weapon_stats.init or not blueprints.weapon_stats.update then
		return blueprints
	end

	local old_init = blueprints.weapon_stats.init
	blueprints.weapon_stats.init = function(parent, widget, element, callback_name)
		local ret = old_init(parent, widget, element, callback_name)

		local content = widget.content
		local style = widget.style
		local item = element.item
		local item_clone = fake_item(item)
		for _, stat in pairs(item_clone.base_stats) do
			stat.value = 0.80
		end
		local weapon_stats = WeaponStats:new(item_clone)
		local compairing_stats = weapon_stats:get_compairing_stats()
		local num_stats = table.size(compairing_stats)
		local compairing_stats_array = {}
		for key, stat in pairs(compairing_stats) do
			compairing_stats_array[#compairing_stats_array + 1] = stat
		end

		local weapon_stats_sort_order = {
			rate_of_fire = 2,
			attack_speed = 2,
			damage = 1,
			stamina_block_cost = 4,
			reload_speed = 4,
			stagger = 3
		}
		local function sort_function(a, b)
			local a_sort_order = weapon_stats_sort_order[a.type] or math.huge
			local b_sort_order = weapon_stats_sort_order[b.type] or math.huge

			return a_sort_order < b_sort_order
		end
		table.sort(compairing_stats_array, sort_function)

		local bar_breakdown = table.clone(weapon_stats._weapon_statistics.bar_breakdown)
		table.sort(bar_breakdown, sort_function)
		for i = 1, num_stats do
			for _, breakdown in ipairs(content["bar_breakdown_" .. i]) do
				for _, breakdown_fake in ipairs(bar_breakdown[i]) do
					if breakdown_equal(breakdown, breakdown_fake) then
						breakdown.max_real = breakdown_fake.value
					end
				end
			end
			local value = content["bar_breakdown_" .. i].value
			local bar_style = style["bar_" .. i]
			if mod:get("show_full_bar") then
				bar_style.size[1] = bar_size * value * 1.25
			end
		end
		return ret
	end
	return blueprints
end)

mod:hook(ViewElementWeaponInfo, "_get_stats_text", function(func, self, stat)
	local stat_clone = table.clone(stat)
	if mod:get("show_real_max_breakdown") then
		stat_clone.max = stat_clone.max_real or stat_clone.max
	end
	return func(self, stat_clone)
end)
