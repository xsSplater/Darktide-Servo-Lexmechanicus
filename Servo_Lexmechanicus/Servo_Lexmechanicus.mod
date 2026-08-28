return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Servo_Lexmechanicus` encountered an error loading the Darktide Mod Framework.")

		new_mod("Servo_Lexmechanicus", {
			mod_script		 = "Servo_Lexmechanicus/Servo_Lexmechanicus",
			mod_data		 = "Servo_Lexmechanicus/Servo_Lexmechanicus_data",
			mod_localization = "Servo_Lexmechanicus/Servo_Lexmechanicus_localization",
		})
	end,
	packages = {},
	require = {},
	load_before = {},
	load_after = {
		"SortModMenu"
	},
}
