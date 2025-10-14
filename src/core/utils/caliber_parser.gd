# res://src/core/utils/caliber_parser.gd
class_name CaliberParser

static func parse(cal: String) -> Dictionary:
	# Early return for FSP/gr designations
	if cal.find("FSP") != -1 or cal.find("gr") != -1:
		return {"bore_mm": 0.0, "case_mm": 0.0, "rimmed": false}
	
	# Normalize the input
	var clean = cal.replace("×", "x").replace(" mm", "").strip_edges()
	clean = clean.replace("X", "x")  # Handle uppercase X
	
	# Handle .30-06 explicitly first - use regex for exact matching
	var thirty_aught_six_regex = RegEx.new()
	thirty_aught_six_regex.compile("^\\.?30-06")
	if thirty_aught_six_regex.search(clean):
		return {"bore_mm": 7.62, "case_mm": 63.0, "rimmed": false}
	
	# Handle common pistol calibers with regex
	var common_calibers = {
		"^\\.45\\s*ACP": {"bore_mm": 11.43, "case_mm": 22.8, "rimmed": false},
		"^\\.40\\s*S&W": {"bore_mm": 10.16, "case_mm": 21.6, "rimmed": false},
		"^\\.22\\s*LR": {"bore_mm": 5.56, "case_mm": 15.6, "rimmed": true},
		"^\\.44\\s*Magnum": {"bore_mm": 10.9, "case_mm": 32.6, "rimmed": true},
		"^\\.357\\s*Magnum": {"bore_mm": 9.07, "case_mm": 33.0, "rimmed": true},
		"^\\.357\\s*SIG": {"bore_mm": 9.02, "case_mm": 21.9, "rimmed": false},
		"^\\.380\\s*ACP": {"bore_mm": 9.65, "case_mm": 17.3, "rimmed": false},
		"^9mm": {"bore_mm": 9.0, "case_mm": 19.0, "rimmed": false},
	}
	
	for pattern in common_calibers:
		var regex = RegEx.new()
		regex.compile(pattern)
		if regex.search(clean):
			return common_calibers[pattern].duplicate()
	
	# Handle x-format calibers with regex
	var x_format_regex = RegEx.new()
	# Simple pattern to extract numbers on either side of 'x'
	x_format_regex.compile("(\\d+\\.?\\d*)x(\\d+\\.?\\d*)")
	var x_match = x_format_regex.search(clean)
	
	if x_match:
		var bore_str = x_match.strings[1]
		var case_str = x_match.strings[2]
		
		var bore = 0.0
		if bore_str.is_valid_float():
			bore = float(bore_str)
		
		var case_len = 0.0
		if case_str.is_valid_float():
			case_len = float(case_str)
		
		# More specific rimmed detection
		# Check if the caliber ends with R/r or has R/r right after the case length
		var rimmed = false
		var base_part = clean.split(" ")[0]  # Get just the caliber part before any spaces
		
		# Check if base part ends with R or r
		if base_part.ends_with("R") or base_part.ends_with("r"):
			rimmed = true
		else:
			# Check if there's an R/r immediately after the case length numbers
			var case_end_index = base_part.find(case_str) + case_str.length()
			if case_end_index < base_part.length():
				var next_char = base_part[case_end_index]
				if next_char == "R" or next_char == "r":
					rimmed = true
		
		return {
			"bore_mm": bore,
			"case_mm": case_len,
			"rimmed": rimmed
		}
	
	# Default return for unrecognized formats
	return {"bore_mm": 0.0, "case_mm": 0.0, "rimmed": false}
