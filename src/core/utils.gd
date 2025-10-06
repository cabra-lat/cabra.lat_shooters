class_name Utils
extends Object

static func create_timer(wait):
	var timer = Timer.new()
	timer.wait_time = wait
	return timer

## Calculates bullet energy, mass in g, speed in m/s
static func bullet_energy(mass: float, speed: float):
	return 0.5 * (mass / 1000.0) * (speed * speed)  # Joules

static func parse_caliber(cal: String) -> Dictionary:
	var clean = cal.replace("×", "x").replace(" mm", "").strip_edges()
	var base = clean.split(" ")[0]  # "7.62x51mm" from "7.62x51mm M80"
	
	# Handle x-format calibers (7.62x51mm, 5.56x45mm, etc.)
	if base.find("x") != -1:
		var parts = base.split("x")
		if parts.size() == 2:
			# Extract just the numeric part for bore diameter
			var bore_str = parts[0].replace(".", "").replace(",", "")
			# Handle decimal conversion properly
			var bore = float(parts[0])
			
			# Extract case length - take only numbers before any non-numeric characters
			var case_str = parts[1]
			var case_len = 0.0
			# Find the numeric portion at the start
			var numeric_chars = ""
			for i in range(case_str.length()):
				var char = case_str[i]
				if char.is_valid_float() or char == ".":
					numeric_chars += char
				else:
					break
			if numeric_chars != "":
				case_len = float(numeric_chars)
			
			return {
				"bore_mm": bore,
				"case_mm": case_len,
				"rimmed": base.ends_with("R") or base.ends_with("r")
			}
	
	# Handle .30-06 Springfield
	if base.begins_with(".30-") or base.begins_with("30-"):
		var case_part = base.trim_prefix(".30-").trim_prefix("30-")
		var case_len = 0.0
		if case_part.is_valid_float():
			case_len = float(case_part)
		return {"bore_mm": 7.62, "case_mm": case_len, "rimmed": false}
	
	# Handle common pistol calibers
	var common_calibers = {
		".45 ACP": {"bore_mm": 11.43, "case_mm": 22.8, "rimmed": false},
		".40 S&W": {"bore_mm": 10.16, "case_mm": 21.6, "rimmed": false},
		".22 LR": {"bore_mm": 5.56, "case_mm": 15.6, "rimmed": true},
		".44 Magnum": {"bore_mm": 10.9, "case_mm": 32.6, "rimmed": true},
		".357 Magnum": {"bore_mm": 9.07, "case_mm": 33.0, "rimmed": true},
		".357 SIG": {"bore_mm": 9.02, "case_mm": 21.9, "rimmed": false},
		".380 ACP": {"bore_mm": 9.65, "case_mm": 17.3, "rimmed": false},
		"9mm": {"bore_mm": 9.0, "case_mm": 19.0, "rimmed": false},
	}
	
	for caliber_pattern in common_calibers:
		if base.find(caliber_pattern) != -1:
			return common_calibers[caliber_pattern].duplicate()
	
	# Handle FSP (fragmenting projectile) - these aren't standard calibers
	if base.find("FSP") != -1 or base.find("gr") != -1:
		return {"bore_mm": 0.0, "case_mm": 0.0, "rimmed": false}
	
	return {"bore_mm": 0.0, "case_mm": 0.0, "rimmed": false}
