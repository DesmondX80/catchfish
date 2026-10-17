class_name Waves
## Sama aaltomalli kuin shaders/waves.gdshaderinc. Peli kuljettaa aikaa
## ja välittää sen shadereille, joten vene keinuu näkyvissä aalloissa.

const GRAVITY := 9.81
const SWELL_LENGTH := 14.0
const SWELL_STEEPNESS := 0.010

static var strength := 0.3
static var angle := 0.0
static var time := 0.0


static func swell_height(p: Vector2) -> float:
	var k := TAU / SWELL_LENGTH
	var amp := SWELL_STEEPNESS * SWELL_LENGTH * (0.2 + strength)
	var dir := Vector2(sin(angle), -cos(angle))
	return amp * sin(p.dot(dir) * k - sqrt(GRAVITY * k) * time)


## Aseta shaderin aaltoparametrit
static func apply(material: ShaderMaterial) -> void:
	material.set_shader_parameter("wave_strength", strength)
	material.set_shader_parameter("wind_angle", angle)
	material.set_shader_parameter("wave_time", time)
