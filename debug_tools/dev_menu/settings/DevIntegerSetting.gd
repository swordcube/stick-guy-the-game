class_name DevIntegerSetting extends DevSetting

@export var minimum_value:int = 0
@export var maximum_value:int = 0
@export var increment_value:int = 1
@export var suffix:String = ""

## Converts stuff like value, minimum, maximum, etc
## to a human-readable format
func data_to_string() -> String:
	return "[value: %s / mi: %s / mx: %s / in: %s]" % [Settings.data[name], str(minimum_value) + suffix, str(maximum_value) + suffix, str(increment_value) + suffix]

func change(by:int = 0):
	Settings.data[name] = clampi(Settings.data[name] + (increment_value * by), minimum_value, maximum_value)
	Settings.apply_setting(name)
	Settings.save()
