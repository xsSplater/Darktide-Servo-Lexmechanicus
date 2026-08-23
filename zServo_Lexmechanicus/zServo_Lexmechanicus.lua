-- zServo_Lexmechanicus.lua
local mod = get_mod("zServo_Lexmechanicus")

-- Loading categorization data
local MOD_LIST = {}
local MOD_CATEGORIES = {}

local function safe_load_file(file_path)
	local success, result = pcall(function()
		return mod:io_dofile(file_path)
	end)
	if success and result then
		return result
	else
		mod:error("Failed to load %s: %s", file_path, tostring(result))
		return {}
	end
end

-- Secure JSON Upload
local function safe_load_json(relative_path)
	local content = mod:io_read_content(relative_path, "json")
	if not content then
		mod:error("Failed to read JSON file: %s.json", relative_path)
		return nil
	end
	local ok, data = pcall(cjson.decode, content)
	if not ok then
		mod:error("Failed to parse JSON %s.json: %s", relative_path, tostring(data))
		return nil
	end
	return data
end

-- ============================================================================
-- DATA INITIALIZATION
-- ============================================================================

function mod.initialize_data()
	MOD_CATEGORIES = safe_load_file("zServo_Lexmechanicus/zServo_Lexmechanicus_categories") or {}

	local json_data = safe_load_json("zServo_Lexmechanicus/mod_database")
	if not json_data then
		mod:error("Failed to load mod_database.json, mod will not work")
		MOD_LIST = {}
		return MOD_LIST
	end

	-- Extracting an array from the "mod_database" field
	local mod_array = json_data.mod_database
	if not mod_array or type(mod_array) ~= "table" then
		mod:error("mod_database.json missing 'mod_database' array")
		MOD_LIST = {}
		return MOD_LIST
	end

	MOD_LIST = {}
	for _, entry in ipairs(mod_array) do
		local folder = entry.folder
		if folder and type(folder) == "string" and folder ~= "" then
			local category = entry.category or ""
			if category ~= "" then
				-- Store the key in lowercase for case-insensitive searching
				MOD_LIST[folder:lower()] = {
					category = category,
					localized_name = entry.name or {}
				}
			end
		end
	end

	mod:info("Loaded %d mods from JSON database", table.size(MOD_LIST))
	local keys = {}
	for k in pairs(MOD_LIST) do table.insert(keys, k) end
	mod:info("MOD_LIST keys: %s", table.concat(keys, ", "))

	return MOD_LIST
end

mod.initialize_data()

-- ============================================================================
-- LOCALIZATION FUNCTIONS
-- ============================================================================

local _current_language = nil
local _language_fallback = "en"

local LANGUAGE_KEY_MAP = {
	["zh-cn"] = { "zh-cn", "zh-hans", "zh-Hans", "zh_CN" },
	["zh-tw"] = { "zh-tw", "zh-hant", "zh-Hant", "zh_TW" },
	["pt-br"] = { "pt-br", "pt-BR", "pt_BR" },
}

local function get_current_language()
	if _current_language then
		return _current_language
	end

	local language_override = mod:get("language_override")
	if language_override and language_override ~= "auto" then
		_current_language = language_override
		return _current_language
	end

	if Managers and Managers.localization then
		_current_language = Managers.localization:language() or _language_fallback
		return _current_language
	end

	return _language_fallback
end

local function localize_text(localization_table)
	if not localization_table or type(localization_table) ~= "table" then
		return ""
	end

	local lang = get_current_language()

	if localization_table[lang] then
		return localization_table[lang]
	end

	local synonyms = LANGUAGE_KEY_MAP[lang]
	if synonyms then
		for _, synonym in ipairs(synonyms) do
			if localization_table[synonym] then
				return localization_table[synonym]
			end
		end
	end

	if localization_table.en then
		return localization_table.en
	end

	for _, text in pairs(localization_table) do
		if type(text) == "string" then
			return text
		end
	end

	return ""
end

-- ============================================================================
-- CORE LOGIC: HOOK FOR CREATING MOD OPTIONS
-- ============================================================================

local dmf = get_mod("DMF")
if not dmf then
	mod:error("DMF not found!")
	return
end

-- Function to get the clean name of a mod
function mod.get_clean_mod_name(mod_id, current_name)
	if not mod._clean_names_cache then
		mod._clean_names_cache = {}
	end

	if mod._clean_names_cache[mod_id] then
		return mod._clean_names_cache[mod_id]
	end

	local clean_name = current_name
	clean_name = string.gsub(clean_name, "^%[.-%]%s+", "")
	clean_name = string.gsub(clean_name, "^%s+", "")
	clean_name = string.gsub(clean_name, "%s+$", "")
	if clean_name == "" then
		clean_name = mod_id
	end

	mod._clean_names_cache[mod_id] = clean_name
	return clean_name
end

-- Function for formatting the mod name
function mod.format_mod_name(mod_id, clean_name)
	if not mod:get("enable_servo") then
		return clean_name
	end

	local mod_info = MOD_LIST[mod_id:lower()]
	if not mod_info then
		return clean_name
	end

	local category_text = localize_text(MOD_CATEGORIES[mod_info.category] or mod_info.category)
	local mod_name_text = ""
	if mod:get("use_custom_names") then
		mod_name_text = localize_text(mod_info.localized_name) or clean_name
	else
		mod_name_text = clean_name
	end

	local add_prefix = mod:get("show_category_prefix") and category_text ~= ""
	if add_prefix then
		return "[" .. category_text .. "] " .. mod_name_text
	else
		return mod_name_text
	end
end

-- Function for updating mod names in options_widgets_data
function mod.update_all_mod_names_in_options()
	if not dmf or not dmf.options_widgets_data then
		if mod:get("debug_mode") then
			mod:warning("DMF options data not available yet")
		end
		return 0
	end

	local updated = 0
	local debug_mode = mod:get("debug_mode")

	for _, mod_widgets in ipairs(dmf.options_widgets_data) do
		if type(mod_widgets) == "table" and #mod_widgets > 0 then
			local header_widget = mod_widgets[1]
			if header_widget and header_widget.mod_name then
				local mod_id = header_widget.mod_name
				local current_name = header_widget.readable_mod_name or header_widget.title or mod_id
				local clean_name = mod.get_clean_mod_name(mod_id, current_name)
				local new_name = mod.format_mod_name(mod_id, clean_name)

				if new_name ~= current_name then
					if not mod._original_names then
						mod._original_names = {}
					end
					if not mod._original_names[mod_id] then
						mod._original_names[mod_id] = clean_name
					end

					header_widget.readable_mod_name = new_name
					header_widget.title = new_name
					updated = updated + 1

					if debug_mode then
						mod:info("Updated: %s -> %s", mod_id, new_name)
					end
				end
			end
		end
	end

	if debug_mode then
		mod:info("=== Updated %d mod names ===", updated)
	end

	return updated
end

-- ============================================================================
-- DMF Hooks
-- ============================================================================

mod:hook("DMFOptionsView", "_setup_category_config", function(func, self, config)
	local result = func(self, config)
	if mod:get("enable_servo") then
		mod.update_all_mod_names_in_options()
	end
	return result
end)

mod:hook_safe("DMFOptionsView", "on_enter", function(self)
	if mod:get("enable_servo") then
		mod.update_all_mod_names_in_options()
	end
end)

mod:hook("DMFOptionsView", "_reset_options_view", function(func, self, reset_all)
	local result = func(self, reset_all)
	if mod:get("enable_servo") then
		mod.update_all_mod_names_in_options()
	end
	return result
end)

-- ============================================================================
-- HOOK ON create_mod_options_settings
-- ============================================================================

local original_create_mod_options_settings = dmf.create_mod_options_settings

function dmf.create_mod_options_settings(self, options_templates)
	local result = original_create_mod_options_settings(self, options_templates)

	if mod:get("enable_servo") then
		local settings = options_templates.settings
		for i = 1, #settings do
			local setting = settings[i]
			if setting.mod_name and MOD_LIST[setting.mod_name:lower()] then
				local mod_id = setting.mod_name
				if setting.widget_type == "group_header" and setting.display_name then
					local current_name = setting.display_name
					local clean_name = mod.get_clean_mod_name(mod_id, current_name)
					local new_name = mod.format_mod_name(mod_id, clean_name)
					if new_name ~= current_name then
						if not mod._original_names then mod._original_names = {} end
						if not mod._original_names[mod_id] then
							mod._original_names[mod_id] = clean_name
						end
						setting.display_name = new_name
						if mod:get("debug_mode") then
							mod:info("Updated category header: %s -> %s", mod_id, new_name)
						end
					end
				end
			end
		end
	end

	return result
end

-- ============================================================================
-- INITIALIZING THE MOD
-- ============================================================================

mod.on_all_mods_loaded = function()
	mod:info("=== zServo_Lexmechanicus Initialized ===")
	mod:info("Language: %s", get_current_language())
	mod:info("Categories loaded: %d", table.size(MOD_LIST))
	mod._clean_names_cache = {}
	if mod:get("enable_servo") then
		mod.update_all_mod_names_in_options()
	end
end

mod.on_enabled = function()
	mod:info("zServo_Lexmechanicus enabled")
	if mod:get("enable_servo") then
		mod.update_all_mod_names_in_options()
	end
end

mod.on_disabled = function()
	mod:info("zServo_Lexmechanicus disabled")
	if dmf.options_widgets_data and mod._original_names then
		for mod_id, original_name in pairs(mod._original_names) do
			for _, mod_data in ipairs(dmf.options_widgets_data) do
				if mod_data[1] and mod_data[1].mod_name == mod_id then
					mod_data[1].readable_mod_name = original_name
					mod_data[1].title = original_name
					break
				end
			end
		end
	end
end

mod.on_setting_changed = function(setting_id)
	 if setting_id == "enable_servo" or 
		setting_id == "show_category_prefix" or 
		setting_id == "use_custom_names" or
		setting_id == "language_override" then
		
		if setting_id == "language_override" then
			_current_language = nil
			mod._clean_names_cache = {}
		end
		
		if mod:get("enable_servo") then
			mod.update_all_mod_names_in_options()
			mod:info("Settings changed, mod names updated")
		end
	end
end

-- Clear memory on reboot
mod._clean_names_cache = {}
mod._original_names = {}
