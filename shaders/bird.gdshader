shader_type spatial;
// Lentävä lintu: siivet kääntyvät tyvestä ja kyynärtaipeesta (siiven ulko-osa
// taipuu enemmän). Siiven asento (flap, radiaaneina) tulee skriptistä joka ruudulle,
// jolloin liito, räpyttely ja kaarrot hoituvat linnun lentotavan mukaan.
// UV.x = 0 ruumis, > 0 siipi; UV2.x = siiven tyven etäisyys keskiviivasta,
// UV2.y = kyynärtaipeen etäisyys tyvestä. COLOR.rgb = väri.
render_mode cull_disabled, specular_disabled;

instance uniform float flap = 0.0;

void vertex() {
	if (UV.x > 0.0) {
		float side = sign(VERTEX.x);
		float r = abs(VERTEX.x) - UV2.x;
		float inner = min(r, UV2.y);
		float outer = max(r - UV2.y, 0.0);
		float a1 = flap;
		float a2 = flap * 1.6;
		vec2 p = vec2(inner * cos(a1), inner * sin(a1)) + vec2(outer * cos(a2), outer * sin(a2));
		VERTEX.x = side * (UV2.x + p.x);
		VERTEX.y += p.y;
		float a = outer > 0.0 ? a2 : a1;
		NORMAL = vec3(-side * sin(a), cos(a), 0.0);
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
}
