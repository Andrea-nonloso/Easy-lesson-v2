import 'i18n.dart';

/// Formulario offline (3.9): matematica, fisica, tavola periodica, verbi irregolari inglesi.
/// Tutto nel codice, niente rete. I preferiti stanno nell'opzione "form.fav" (lista di id).

class Formula {
  const Formula(this.id, this.group, this.it, this.en, this.text, [this.noteIt = '', this.noteEn = '']);
  final String id;
  final String group;
  final String it;
  final String en;
  final String text;
  final String noteIt;
  final String noteEn;

  String get title => tr(it, en);
  String get note => noteIt.isEmpty ? '' : tr(noteIt, noteEn.isEmpty ? noteIt : noteEn);
}

class FormulaSection {
  const FormulaSection(this.id, this.emoji, this.it, this.en, this.groups);
  final String id;
  final String emoji;
  final String it;
  final String en;

  /// (id gruppo, nome it, nome en)
  final List<(String, String, String)> groups;
  String get title => tr(it, en);
}

const formulaSections = [
  FormulaSection('mat', '📐', 'Matematica', 'Maths', [
    ('alg', 'Algebra', 'Algebra'),
    ('geo', 'Geometria', 'Geometry'),
    ('ana', 'Geometria analitica', 'Analytic geometry'),
    ('trig', 'Trigonometria', 'Trigonometry'),
    ('expl', 'Esponenziali e logaritmi', 'Exponentials and logarithms'),
    ('calc', 'Analisi', 'Calculus'),
    ('prob', 'Probabilità e statistica', 'Probability and statistics'),
  ]),
  FormulaSection('fis', '⚛️', 'Fisica', 'Physics', [
    ('kin', 'Cinematica', 'Kinematics'),
    ('dyn', 'Dinamica', 'Dynamics'),
    ('en', 'Lavoro ed energia', 'Work and energy'),
    ('flu', 'Fluidi', 'Fluids'),
    ('term', 'Termodinamica', 'Thermodynamics'),
    ('ele', 'Elettricità e magnetismo', 'Electricity and magnetism'),
    ('wave', 'Onde e ottica', 'Waves and optics'),
    ('const', 'Costanti', 'Constants'),
  ]),
  FormulaSection('chi', '🧪', 'Chimica', 'Chemistry', [
    ('gen', 'Formule', 'Formulas'),
  ]),
];

const formulas = <Formula>[
  // ---- Algebra
  Formula('m1', 'alg', 'Quadrato di binomio', 'Square of a binomial', '(a ± b)² = a² ± 2ab + b²'),
  Formula('m2', 'alg', 'Differenza di quadrati', 'Difference of squares', 'a² − b² = (a + b)(a − b)'),
  Formula('m3', 'alg', 'Cubo di binomio', 'Cube of a binomial', '(a ± b)³ = a³ ± 3a²b + 3ab² ± b³'),
  Formula('m4', 'alg', 'Somma e differenza di cubi', 'Sum and difference of cubes', 'a³ ± b³ = (a ± b)(a² ∓ ab + b²)'),
  Formula('m5', 'alg', 'Equazione di secondo grado', 'Quadratic equation', 'ax² + bx + c = 0  →  x = (−b ± √Δ) / 2a', 'Δ = b² − 4ac: Δ > 0 due soluzioni, Δ = 0 una, Δ < 0 nessuna reale',
      'Δ = b² − 4ac: Δ > 0 two solutions, Δ = 0 one, Δ < 0 no real ones'),
  Formula('m6', 'alg', 'Formula ridotta', 'Reduced formula', 'b pari: x = (−b/2 ± √(Δ/4)) / a', 'Δ/4 = (b/2)² − ac'),
  Formula('m7', 'alg', 'Somma e prodotto delle radici', 'Sum and product of roots', 'x₁ + x₂ = −b/a    x₁ · x₂ = c/a'),
  Formula('m8', 'alg', 'Scomposizione del trinomio', 'Factoring a trinomial', 'ax² + bx + c = a(x − x₁)(x − x₂)'),
  Formula('m9', 'alg', 'Proprietà delle potenze', 'Power rules', 'aᵐ · aⁿ = aᵐ⁺ⁿ    aᵐ / aⁿ = aᵐ⁻ⁿ    (aᵐ)ⁿ = aᵐⁿ    a⁻ⁿ = 1/aⁿ    a^(m/n) = ⁿ√aᵐ'),
  Formula('m10', 'alg', 'Valore assoluto', 'Absolute value', '|x| < k  ↔  −k < x < k        |x| > k  ↔  x < −k ∨ x > k'),
  Formula('m11', 'alg', 'Progressione aritmetica', 'Arithmetic progression', 'aₙ = a₁ + (n − 1)d        Sₙ = n(a₁ + aₙ) / 2'),
  Formula('m12', 'alg', 'Progressione geometrica', 'Geometric progression', 'aₙ = a₁ · qⁿ⁻¹        Sₙ = a₁(1 − qⁿ) / (1 − q)'),
  // ---- Geometria
  Formula('m20', 'geo', 'Teorema di Pitagora', 'Pythagorean theorem', 'c² = a² + b²', 'c è l\'ipotenusa', 'c is the hypotenuse'),
  Formula('m21', 'geo', 'Triangolo', 'Triangle', 'A = b · h / 2        Erone: A = √(p(p−a)(p−b)(p−c))', 'p = semiperimetro', 'p = semi-perimeter'),
  Formula('m22', 'geo', 'Quadrato e rettangolo', 'Square and rectangle', 'A = l²    d = l√2        A = b · h    d = √(b² + h²)'),
  Formula('m23', 'geo', 'Parallelogramma, rombo, trapezio', 'Parallelogram, rhombus, trapezoid', 'A = b · h        A = D · d / 2        A = (B + b) · h / 2'),
  Formula('m24', 'geo', 'Cerchio', 'Circle', 'C = 2πr        A = πr²        arco = r · α (radianti)        settore = r²α / 2'),
  Formula('m25', 'geo', 'Poligono regolare', 'Regular polygon', 'A = p · a / 2', 'p = perimetro, a = apotema', 'p = perimeter, a = apothem'),
  Formula('m26', 'geo', 'Cubo e parallelepipedo', 'Cube and cuboid', 'V = l³    S = 6l²        V = abc    S = 2(ab + bc + ac)'),
  Formula('m27', 'geo', 'Prisma e cilindro', 'Prism and cylinder', 'V = A_base · h        cilindro: V = πr²h    S_lat = 2πrh'),
  Formula('m28', 'geo', 'Piramide e cono', 'Pyramid and cone', 'V = A_base · h / 3        cono: V = πr²h / 3    S_lat = πra', 'a = apotema', 'a = slant height'),
  Formula('m29', 'geo', 'Sfera', 'Sphere', 'V = 4πr³ / 3        S = 4πr²'),
  // ---- Analitica
  Formula('m40', 'ana', 'Distanza tra due punti', 'Distance between two points', 'd = √((x₂ − x₁)² + (y₂ − y₁)²)'),
  Formula('m41', 'ana', 'Punto medio', 'Midpoint', 'M = ((x₁ + x₂)/2 ; (y₁ + y₂)/2)'),
  Formula('m42', 'ana', 'Retta', 'Line', 'y = mx + q        ax + by + c = 0  →  m = −a/b'),
  Formula('m43', 'ana', 'Coefficiente angolare', 'Slope', 'm = (y₂ − y₁) / (x₂ − x₁)'),
  Formula('m44', 'ana', 'Retta per un punto', 'Line through a point', 'y − y₀ = m(x − x₀)'),
  Formula('m45', 'ana', 'Parallele e perpendicolari', 'Parallel and perpendicular', 'parallele: m₁ = m₂        perpendicolari: m₁ · m₂ = −1'),
  Formula('m46', 'ana', 'Distanza punto-retta', 'Point-line distance', 'd = |ax₀ + by₀ + c| / √(a² + b²)'),
  Formula('m47', 'ana', 'Parabola', 'Parabola', 'y = ax² + bx + c    V = (−b/2a ; −Δ/4a)    F = (−b/2a ; (1−Δ)/4a)    direttrice y = −(1+Δ)/4a'),
  Formula('m48', 'ana', 'Circonferenza', 'Circle', 'x² + y² + ax + by + c = 0    C = (−a/2 ; −b/2)    r = √(a²/4 + b²/4 − c)'),
  Formula('m49', 'ana', 'Ellisse', 'Ellipse', 'x²/a² + y²/b² = 1        c² = a² − b² (a > b)        e = c/a'),
  Formula('m50', 'ana', 'Iperbole', 'Hyperbola', 'x²/a² − y²/b² = 1        c² = a² + b²        asintoti y = ±(b/a)x'),
  // ---- Trigonometria
  Formula('m60', 'trig', 'Relazione fondamentale', 'Pythagorean identity', 'sin²α + cos²α = 1        tan α = sin α / cos α'),
  Formula('m61', 'trig', 'Valori notevoli', 'Special values', '30°: sin ½, cos √3/2, tan √3/3\n45°: sin √2/2, cos √2/2, tan 1\n60°: sin √3/2, cos ½, tan √3'),
  Formula('m62', 'trig', 'Gradi e radianti', 'Degrees and radians', 'α_rad = α° · π / 180'),
  Formula('m63', 'trig', 'Addizione', 'Addition formulas', 'sin(α ± β) = sin α cos β ± cos α sin β\ncos(α ± β) = cos α cos β ∓ sin α sin β\ntan(α ± β) = (tan α ± tan β) / (1 ∓ tan α tan β)'),
  Formula('m64', 'trig', 'Duplicazione', 'Double angle', 'sin 2α = 2 sin α cos α\ncos 2α = cos²α − sin²α = 1 − 2sin²α = 2cos²α − 1'),
  Formula('m65', 'trig', 'Bisezione', 'Half angle', 'sin(α/2) = ±√((1 − cos α)/2)        cos(α/2) = ±√((1 + cos α)/2)'),
  Formula('m66', 'trig', 'Triangolo rettangolo', 'Right triangle', 'cateto = ipotenusa · sin(angolo opposto) = ipotenusa · cos(angolo adiacente)'),
  Formula('m67', 'trig', 'Teorema dei seni', 'Law of sines', 'a / sin α = b / sin β = c / sin γ = 2R'),
  Formula('m68', 'trig', 'Teorema del coseno (Carnot)', 'Law of cosines', 'a² = b² + c² − 2bc · cos α'),
  Formula('m69', 'trig', 'Area con il seno', 'Area with sine', 'A = ½ · a · b · sin γ'),
  // ---- Esponenziali e logaritmi
  Formula('m80', 'expl', 'Definizione di logaritmo', 'Definition of logarithm', 'log_a b = c  ↔  aᶜ = b        (a > 0, a ≠ 1, b > 0)'),
  Formula('m81', 'expl', 'Proprietà dei logaritmi', 'Logarithm rules', 'log(xy) = log x + log y    log(x/y) = log x − log y    log xⁿ = n log x'),
  Formula('m82', 'expl', 'Cambio di base', 'Change of base', 'log_a b = log_c b / log_c a'),
  Formula('m83', 'expl', 'Equazioni esponenziali', 'Exponential equations', 'aˣ = b  →  x = log_a b        a^f(x) = a^g(x)  →  f(x) = g(x)'),
  // ---- Analisi
  Formula('m90', 'calc', 'Limiti notevoli', 'Notable limits', 'lim(x→0) sin x / x = 1        lim(x→0) (1 − cos x)/x² = ½\nlim(x→∞) (1 + 1/x)ˣ = e        lim(x→0) (eˣ − 1)/x = 1        lim(x→0) ln(1 + x)/x = 1'),
  Formula('m91', 'calc', 'Derivate fondamentali', 'Basic derivatives', 'D xⁿ = nxⁿ⁻¹    D eˣ = eˣ    D aˣ = aˣ ln a    D ln x = 1/x\nD sin x = cos x    D cos x = −sin x    D tan x = 1/cos²x'),
  Formula('m92', 'calc', 'Regole di derivazione', 'Differentiation rules', 'D(f·g) = f′g + fg′    D(f/g) = (f′g − fg′)/g²    D f(g(x)) = f′(g(x)) · g′(x)'),
  Formula('m93', 'calc', 'Retta tangente', 'Tangent line', 'y − f(x₀) = f′(x₀)(x − x₀)'),
  Formula('m94', 'calc', 'Integrali immediati', 'Basic integrals', '∫xⁿ dx = xⁿ⁺¹/(n+1) + c    ∫1/x dx = ln|x| + c    ∫eˣ dx = eˣ + c\n∫sin x dx = −cos x + c    ∫cos x dx = sin x + c'),
  Formula('m95', 'calc', 'Integrazione per parti', 'Integration by parts', '∫f · g′ dx = f · g − ∫f′ · g dx'),
  Formula('m96', 'calc', 'Teorema fondamentale', 'Fundamental theorem', '∫ₐᵇ f(x) dx = F(b) − F(a)'),
  // ---- Probabilità e statistica
  Formula('m100', 'prob', 'Probabilità classica', 'Classical probability', 'P(E) = casi favorevoli / casi possibili'),
  Formula('m101', 'prob', 'Somma e prodotto', 'Sum and product rules', 'P(A ∪ B) = P(A) + P(B) − P(A ∩ B)        indipendenti: P(A ∩ B) = P(A) · P(B)'),
  Formula('m102', 'prob', 'Probabilità condizionata', 'Conditional probability', 'P(A|B) = P(A ∩ B) / P(B)'),
  Formula('m103', 'prob', 'Calcolo combinatorio', 'Combinatorics', 'Pₙ = n!        Dₙ,ₖ = n!/(n−k)!        Cₙ,ₖ = n!/(k!(n−k)!)'),
  Formula('m104', 'prob', 'Media e varianza', 'Mean and variance', 'x̄ = Σxᵢ / n        σ² = Σ(xᵢ − x̄)² / n        σ = √σ²'),

  // ---- Cinematica
  Formula('f1', 'kin', 'Velocità media', 'Average velocity', 'v = Δs / Δt', 'm/s (1 m/s = 3,6 km/h)', 'm/s (1 m/s = 3.6 km/h)'),
  Formula('f2', 'kin', 'Moto rettilineo uniforme', 'Uniform motion', 's = s₀ + v · t'),
  Formula('f3', 'kin', 'Accelerazione', 'Acceleration', 'a = Δv / Δt', 'm/s²'),
  Formula('f4', 'kin', 'Moto uniformemente accelerato', 'Uniformly accelerated motion', 'v = v₀ + at        s = s₀ + v₀t + ½at²        v² = v₀² + 2aΔs'),
  Formula('f5', 'kin', 'Caduta libera', 'Free fall', 'h = ½gt²        v = √(2gh)', 'g ≈ 9,81 m/s²', 'g ≈ 9.81 m/s²'),
  Formula('f6', 'kin', 'Moto circolare uniforme', 'Uniform circular motion', 'v = 2πr / T = ωr        ω = 2π / T = 2πf        a_c = v²/r = ω²r'),
  Formula('f7', 'kin', 'Moto del proiettile', 'Projectile motion', 'x = v₀cos α · t        y = v₀sin α · t − ½gt²        gittata = v₀² sin 2α / g'),
  Formula('f8', 'kin', 'Moto armonico', 'Simple harmonic motion', 'x = A cos(ωt)        T = 2π√(m/k)        pendolo: T = 2π√(l/g)'),
  // ---- Dinamica
  Formula('f20', 'dyn', 'Secondo principio', 'Newton\'s second law', 'F = m · a', 'N = kg · m/s²'),
  Formula('f21', 'dyn', 'Forza peso', 'Weight', 'P = m · g'),
  Formula('f22', 'dyn', 'Attrito', 'Friction', 'F_a = μ · N'),
  Formula('f23', 'dyn', 'Legge di Hooke', 'Hooke\'s law', 'F = −k · Δx'),
  Formula('f24', 'dyn', 'Forza centripeta', 'Centripetal force', 'F = m · v² / r'),
  Formula('f25', 'dyn', 'Piano inclinato', 'Inclined plane', 'F_∥ = mg sin α        N = mg cos α'),
  Formula('f26', 'dyn', 'Quantità di moto e impulso', 'Momentum and impulse', 'p = m · v        I = F · Δt = Δp'),
  Formula('f27', 'dyn', 'Gravitazione universale', 'Universal gravitation', 'F = G · m₁m₂ / r²'),
  Formula('f28', 'dyn', 'Momento di una forza', 'Torque', 'M = F · b = r · F · sin α'),
  // ---- Energia
  Formula('f40', 'en', 'Lavoro', 'Work', 'L = F · s · cos α', 'J = N · m'),
  Formula('f41', 'en', 'Energia cinetica', 'Kinetic energy', 'K = ½mv²'),
  Formula('f42', 'en', 'Energia potenziale', 'Potential energy', 'gravitazionale: U = mgh        elastica: U = ½kx²'),
  Formula('f43', 'en', 'Conservazione dell\'energia', 'Conservation of energy', 'K₁ + U₁ = K₂ + U₂        L = ΔK'),
  Formula('f44', 'en', 'Potenza', 'Power', 'P = L / t = F · v', 'W = J/s'),
  Formula('f45', 'en', 'Rendimento', 'Efficiency', 'η = L_utile / E_spesa'),
  // ---- Fluidi
  Formula('f50', 'flu', 'Densità e pressione', 'Density and pressure', 'd = m / V        p = F / S', 'Pa = N/m²'),
  Formula('f51', 'flu', 'Legge di Stevino', 'Stevin\'s law', 'p = p₀ + d · g · h'),
  Formula('f52', 'flu', 'Spinta di Archimede', 'Archimedes\' principle', 'S_A = d_fluido · g · V_immerso'),
  Formula('f53', 'flu', 'Portata e Bernoulli', 'Flow rate and Bernoulli', 'Q = S · v        p + ½dv² + dgh = costante'),
  // ---- Termodinamica
  Formula('f60', 'term', 'Calore', 'Heat', 'Q = m · c · ΔT        cambiamento di stato: Q = m · λ'),
  Formula('f61', 'term', 'Gradi', 'Temperature scales', 'T(K) = t(°C) + 273,15        °F = °C · 9/5 + 32'),
  Formula('f62', 'term', 'Dilatazione', 'Thermal expansion', 'ΔL = λ · L₀ · ΔT        ΔV = α · V₀ · ΔT'),
  Formula('f63', 'term', 'Gas perfetti', 'Ideal gas', 'pV = nRT        Boyle: pV = cost.    Gay-Lussac: V/T = cost.    p/T = cost.'),
  Formula('f64', 'term', 'Primo principio', 'First law', 'ΔU = Q − L'),
  Formula('f65', 'term', 'Rendimento di una macchina', 'Heat engine efficiency', 'η = L / Q_ass = 1 − Q_ced / Q_ass        Carnot: η = 1 − T_f / T_c'),
  Formula('f66', 'term', 'Entropia', 'Entropy', 'ΔS = Q / T'),
  // ---- Elettricità e magnetismo
  Formula('f80', 'ele', 'Legge di Coulomb', 'Coulomb\'s law', 'F = k · q₁q₂ / r²', 'k ≈ 8,99 · 10⁹ N·m²/C²', 'k ≈ 8.99 · 10⁹ N·m²/C²'),
  Formula('f81', 'ele', 'Campo e potenziale', 'Field and potential', 'E = F / q = kQ / r²        V = kQ / r        U = qV'),
  Formula('f82', 'ele', 'Condensatore', 'Capacitor', 'C = Q / V        piano: C = ε₀ · S / d        U = ½CV²'),
  Formula('f83', 'ele', 'Corrente', 'Current', 'i = ΔQ / Δt', 'A = C/s'),
  Formula('f84', 'ele', 'Leggi di Ohm', 'Ohm\'s laws', 'V = R · i        R = ρ · L / S'),
  Formula('f85', 'ele', 'Resistenze', 'Resistors', 'serie: R = R₁ + R₂ + …        parallelo: 1/R = 1/R₁ + 1/R₂ + …'),
  Formula('f86', 'ele', 'Potenza elettrica', 'Electric power', 'P = V · i = R · i² = V² / R'),
  Formula('f87', 'ele', 'Forza di Lorentz', 'Lorentz force', 'F = q · v · B · sin α        filo: F = i · L · B'),
  Formula('f88', 'ele', 'Campo di un filo e di un solenoide', 'Field of a wire and solenoid', 'filo: B = μ₀i / 2πr        solenoide: B = μ₀ · N · i / L'),
  Formula('f89', 'ele', 'Induzione (Faraday-Neumann-Lenz)', 'Induction (Faraday)', 'ε = −ΔΦ / Δt        Φ = B · S · cos α'),
  // ---- Onde e ottica
  Formula('f100', 'wave', 'Onde', 'Waves', 'v = λ · f        f = 1 / T'),
  Formula('f101', 'wave', 'Riflessione e rifrazione', 'Reflection and refraction', 'i = r        Snell: n₁ sin θ₁ = n₂ sin θ₂        n = c / v'),
  Formula('f102', 'wave', 'Lenti e specchi', 'Lenses and mirrors', '1/p + 1/q = 1/f        G = q / p'),
  Formula('f103', 'wave', 'Energia di un fotone', 'Photon energy', 'E = h · f'),
  Formula('f104', 'wave', 'Relatività', 'Relativity', 'E = mc²        γ = 1/√(1 − v²/c²)'),
  // ---- Costanti
  Formula('f120', 'const', 'Costanti fondamentali', 'Fundamental constants',
      'g = 9,81 m/s²\nG = 6,67 · 10⁻¹¹ N·m²/kg²\nc = 3,00 · 10⁸ m/s\ne = 1,60 · 10⁻¹⁹ C\nh = 6,63 · 10⁻³⁴ J·s\nk_B = 1,38 · 10⁻²³ J/K\nR = 8,31 J/(mol·K)\nN_A = 6,02 · 10²³ mol⁻¹\nε₀ = 8,85 · 10⁻¹² F/m\nμ₀ = 4π · 10⁻⁷ T·m/A\nmₑ = 9,11 · 10⁻³¹ kg    mₚ = 1,67 · 10⁻²⁷ kg'),

  // ---- Chimica
  Formula('c1', 'gen', 'Moli', 'Moles', 'n = m / MM        N = n · N_A'),
  Formula('c2', 'gen', 'Molarità', 'Molarity', 'M = n_soluto / V_soluzione (L)'),
  Formula('c3', 'gen', 'Molalità', 'Molality', 'm = n_soluto / kg_solvente'),
  Formula('c4', 'gen', 'Diluizione', 'Dilution', 'M₁ · V₁ = M₂ · V₂'),
  Formula('c5', 'gen', 'Percentuali', 'Percentages', '% m/m = m_soluto / m_soluzione · 100        % m/V = g / mL · 100'),
  Formula('c6', 'gen', 'pH', 'pH', 'pH = −log[H₃O⁺]        pOH = −log[OH⁻]        pH + pOH = 14 (25 °C)'),
  Formula('c7', 'gen', 'Costante di equilibrio', 'Equilibrium constant', 'aA + bB ⇌ cC + dD    K = [C]ᶜ[D]ᵈ / [A]ᵃ[B]ᵇ'),
  Formula('c8', 'gen', 'Gas', 'Gases', 'pV = nRT', 'volume molare a STP ≈ 22,4 L', 'molar volume at STP ≈ 22.4 L'),
  Formula('c9', 'gen', 'Abbassamento crioscopico e innalzamento ebullioscopico', 'Freezing point depression / boiling point elevation', 'ΔT = K · m · i'),
  Formula('c10', 'gen', 'Pressione osmotica', 'Osmotic pressure', 'π = M · R · T · i'),
  Formula('c11', 'gen', 'Energia libera', 'Gibbs free energy', 'ΔG = ΔH − TΔS        spontanea se ΔG < 0'),
];

// ---------------------------------------------------------------------------- tavola periodica

class ChemElement {
  const ChemElement(this.z, this.symbol, this.it, this.en, this.mass, this.row, this.col, this.kind);
  final int z;
  final String symbol;
  final String it;
  final String en;
  final double mass;

  /// Posizione nella tavola: periodo 1-7 (8-9 = lantanidi/attinidi sotto), gruppo 1-18.
  final int row;
  final int col;

  /// am alcalini, at alcalino-terrosi, tr transizione, pt post-transizione, sm semimetalli, nm non metalli,
  /// al alogeni, ng gas nobili, la lantanidi, ac attinidi.
  final String kind;
  String get name => tr(it, en);
}

/// Nomi in italiano e inglese; masse atomiche standard (arrotondate).
const elements = <ChemElement>[
  ChemElement(1, 'H', 'Idrogeno', 'Hydrogen', 1.008, 1, 1, 'nm'),
  ChemElement(2, 'He', 'Elio', 'Helium', 4.003, 1, 18, 'ng'),
  ChemElement(3, 'Li', 'Litio', 'Lithium', 6.94, 2, 1, 'am'),
  ChemElement(4, 'Be', 'Berillio', 'Beryllium', 9.012, 2, 2, 'at'),
  ChemElement(5, 'B', 'Boro', 'Boron', 10.81, 2, 13, 'sm'),
  ChemElement(6, 'C', 'Carbonio', 'Carbon', 12.011, 2, 14, 'nm'),
  ChemElement(7, 'N', 'Azoto', 'Nitrogen', 14.007, 2, 15, 'nm'),
  ChemElement(8, 'O', 'Ossigeno', 'Oxygen', 15.999, 2, 16, 'nm'),
  ChemElement(9, 'F', 'Fluoro', 'Fluorine', 18.998, 2, 17, 'al'),
  ChemElement(10, 'Ne', 'Neon', 'Neon', 20.180, 2, 18, 'ng'),
  ChemElement(11, 'Na', 'Sodio', 'Sodium', 22.990, 3, 1, 'am'),
  ChemElement(12, 'Mg', 'Magnesio', 'Magnesium', 24.305, 3, 2, 'at'),
  ChemElement(13, 'Al', 'Alluminio', 'Aluminium', 26.982, 3, 13, 'pt'),
  ChemElement(14, 'Si', 'Silicio', 'Silicon', 28.085, 3, 14, 'sm'),
  ChemElement(15, 'P', 'Fosforo', 'Phosphorus', 30.974, 3, 15, 'nm'),
  ChemElement(16, 'S', 'Zolfo', 'Sulfur', 32.06, 3, 16, 'nm'),
  ChemElement(17, 'Cl', 'Cloro', 'Chlorine', 35.45, 3, 17, 'al'),
  ChemElement(18, 'Ar', 'Argon', 'Argon', 39.948, 3, 18, 'ng'),
  ChemElement(19, 'K', 'Potassio', 'Potassium', 39.098, 4, 1, 'am'),
  ChemElement(20, 'Ca', 'Calcio', 'Calcium', 40.078, 4, 2, 'at'),
  ChemElement(21, 'Sc', 'Scandio', 'Scandium', 44.956, 4, 3, 'tr'),
  ChemElement(22, 'Ti', 'Titanio', 'Titanium', 47.867, 4, 4, 'tr'),
  ChemElement(23, 'V', 'Vanadio', 'Vanadium', 50.942, 4, 5, 'tr'),
  ChemElement(24, 'Cr', 'Cromo', 'Chromium', 51.996, 4, 6, 'tr'),
  ChemElement(25, 'Mn', 'Manganese', 'Manganese', 54.938, 4, 7, 'tr'),
  ChemElement(26, 'Fe', 'Ferro', 'Iron', 55.845, 4, 8, 'tr'),
  ChemElement(27, 'Co', 'Cobalto', 'Cobalt', 58.933, 4, 9, 'tr'),
  ChemElement(28, 'Ni', 'Nichel', 'Nickel', 58.693, 4, 10, 'tr'),
  ChemElement(29, 'Cu', 'Rame', 'Copper', 63.546, 4, 11, 'tr'),
  ChemElement(30, 'Zn', 'Zinco', 'Zinc', 65.38, 4, 12, 'tr'),
  ChemElement(31, 'Ga', 'Gallio', 'Gallium', 69.723, 4, 13, 'pt'),
  ChemElement(32, 'Ge', 'Germanio', 'Germanium', 72.630, 4, 14, 'sm'),
  ChemElement(33, 'As', 'Arsenico', 'Arsenic', 74.922, 4, 15, 'sm'),
  ChemElement(34, 'Se', 'Selenio', 'Selenium', 78.971, 4, 16, 'nm'),
  ChemElement(35, 'Br', 'Bromo', 'Bromine', 79.904, 4, 17, 'al'),
  ChemElement(36, 'Kr', 'Kripton', 'Krypton', 83.798, 4, 18, 'ng'),
  ChemElement(37, 'Rb', 'Rubidio', 'Rubidium', 85.468, 5, 1, 'am'),
  ChemElement(38, 'Sr', 'Stronzio', 'Strontium', 87.62, 5, 2, 'at'),
  ChemElement(39, 'Y', 'Ittrio', 'Yttrium', 88.906, 5, 3, 'tr'),
  ChemElement(40, 'Zr', 'Zirconio', 'Zirconium', 91.224, 5, 4, 'tr'),
  ChemElement(41, 'Nb', 'Niobio', 'Niobium', 92.906, 5, 5, 'tr'),
  ChemElement(42, 'Mo', 'Molibdeno', 'Molybdenum', 95.95, 5, 6, 'tr'),
  ChemElement(43, 'Tc', 'Tecnezio', 'Technetium', 98, 5, 7, 'tr'),
  ChemElement(44, 'Ru', 'Rutenio', 'Ruthenium', 101.07, 5, 8, 'tr'),
  ChemElement(45, 'Rh', 'Rodio', 'Rhodium', 102.91, 5, 9, 'tr'),
  ChemElement(46, 'Pd', 'Palladio', 'Palladium', 106.42, 5, 10, 'tr'),
  ChemElement(47, 'Ag', 'Argento', 'Silver', 107.87, 5, 11, 'tr'),
  ChemElement(48, 'Cd', 'Cadmio', 'Cadmium', 112.41, 5, 12, 'tr'),
  ChemElement(49, 'In', 'Indio', 'Indium', 114.82, 5, 13, 'pt'),
  ChemElement(50, 'Sn', 'Stagno', 'Tin', 118.71, 5, 14, 'pt'),
  ChemElement(51, 'Sb', 'Antimonio', 'Antimony', 121.76, 5, 15, 'sm'),
  ChemElement(52, 'Te', 'Tellurio', 'Tellurium', 127.60, 5, 16, 'sm'),
  ChemElement(53, 'I', 'Iodio', 'Iodine', 126.90, 5, 17, 'al'),
  ChemElement(54, 'Xe', 'Xeno', 'Xenon', 131.29, 5, 18, 'ng'),
  ChemElement(55, 'Cs', 'Cesio', 'Caesium', 132.91, 6, 1, 'am'),
  ChemElement(56, 'Ba', 'Bario', 'Barium', 137.33, 6, 2, 'at'),
  ChemElement(57, 'La', 'Lantanio', 'Lanthanum', 138.91, 8, 3, 'la'),
  ChemElement(58, 'Ce', 'Cerio', 'Cerium', 140.12, 8, 4, 'la'),
  ChemElement(59, 'Pr', 'Praseodimio', 'Praseodymium', 140.91, 8, 5, 'la'),
  ChemElement(60, 'Nd', 'Neodimio', 'Neodymium', 144.24, 8, 6, 'la'),
  ChemElement(61, 'Pm', 'Promezio', 'Promethium', 145, 8, 7, 'la'),
  ChemElement(62, 'Sm', 'Samario', 'Samarium', 150.36, 8, 8, 'la'),
  ChemElement(63, 'Eu', 'Europio', 'Europium', 151.96, 8, 9, 'la'),
  ChemElement(64, 'Gd', 'Gadolinio', 'Gadolinium', 157.25, 8, 10, 'la'),
  ChemElement(65, 'Tb', 'Terbio', 'Terbium', 158.93, 8, 11, 'la'),
  ChemElement(66, 'Dy', 'Disprosio', 'Dysprosium', 162.50, 8, 12, 'la'),
  ChemElement(67, 'Ho', 'Olmio', 'Holmium', 164.93, 8, 13, 'la'),
  ChemElement(68, 'Er', 'Erbio', 'Erbium', 167.26, 8, 14, 'la'),
  ChemElement(69, 'Tm', 'Tulio', 'Thulium', 168.93, 8, 15, 'la'),
  ChemElement(70, 'Yb', 'Itterbio', 'Ytterbium', 173.05, 8, 16, 'la'),
  ChemElement(71, 'Lu', 'Lutezio', 'Lutetium', 174.97, 8, 17, 'la'),
  ChemElement(72, 'Hf', 'Afnio', 'Hafnium', 178.49, 6, 4, 'tr'),
  ChemElement(73, 'Ta', 'Tantalio', 'Tantalum', 180.95, 6, 5, 'tr'),
  ChemElement(74, 'W', 'Tungsteno', 'Tungsten', 183.84, 6, 6, 'tr'),
  ChemElement(75, 'Re', 'Renio', 'Rhenium', 186.21, 6, 7, 'tr'),
  ChemElement(76, 'Os', 'Osmio', 'Osmium', 190.23, 6, 8, 'tr'),
  ChemElement(77, 'Ir', 'Iridio', 'Iridium', 192.22, 6, 9, 'tr'),
  ChemElement(78, 'Pt', 'Platino', 'Platinum', 195.08, 6, 10, 'tr'),
  ChemElement(79, 'Au', 'Oro', 'Gold', 196.97, 6, 11, 'tr'),
  ChemElement(80, 'Hg', 'Mercurio', 'Mercury', 200.59, 6, 12, 'tr'),
  ChemElement(81, 'Tl', 'Tallio', 'Thallium', 204.38, 6, 13, 'pt'),
  ChemElement(82, 'Pb', 'Piombo', 'Lead', 207.2, 6, 14, 'pt'),
  ChemElement(83, 'Bi', 'Bismuto', 'Bismuth', 208.98, 6, 15, 'pt'),
  ChemElement(84, 'Po', 'Polonio', 'Polonium', 209, 6, 16, 'pt'),
  ChemElement(85, 'At', 'Astato', 'Astatine', 210, 6, 17, 'al'),
  ChemElement(86, 'Rn', 'Radon', 'Radon', 222, 6, 18, 'ng'),
  ChemElement(87, 'Fr', 'Francio', 'Francium', 223, 7, 1, 'am'),
  ChemElement(88, 'Ra', 'Radio', 'Radium', 226, 7, 2, 'at'),
  ChemElement(89, 'Ac', 'Attinio', 'Actinium', 227, 9, 3, 'ac'),
  ChemElement(90, 'Th', 'Torio', 'Thorium', 232.04, 9, 4, 'ac'),
  ChemElement(91, 'Pa', 'Protoattinio', 'Protactinium', 231.04, 9, 5, 'ac'),
  ChemElement(92, 'U', 'Uranio', 'Uranium', 238.03, 9, 6, 'ac'),
  ChemElement(93, 'Np', 'Nettunio', 'Neptunium', 237, 9, 7, 'ac'),
  ChemElement(94, 'Pu', 'Plutonio', 'Plutonium', 244, 9, 8, 'ac'),
  ChemElement(95, 'Am', 'Americio', 'Americium', 243, 9, 9, 'ac'),
  ChemElement(96, 'Cm', 'Curio', 'Curium', 247, 9, 10, 'ac'),
  ChemElement(97, 'Bk', 'Berkelio', 'Berkelium', 247, 9, 11, 'ac'),
  ChemElement(98, 'Cf', 'Californio', 'Californium', 251, 9, 12, 'ac'),
  ChemElement(99, 'Es', 'Einsteinio', 'Einsteinium', 252, 9, 13, 'ac'),
  ChemElement(100, 'Fm', 'Fermio', 'Fermium', 257, 9, 14, 'ac'),
  ChemElement(101, 'Md', 'Mendelevio', 'Mendelevium', 258, 9, 15, 'ac'),
  ChemElement(102, 'No', 'Nobelio', 'Nobelium', 259, 9, 16, 'ac'),
  ChemElement(103, 'Lr', 'Laurenzio', 'Lawrencium', 266, 9, 17, 'ac'),
  ChemElement(104, 'Rf', 'Rutherfordio', 'Rutherfordium', 267, 7, 4, 'tr'),
  ChemElement(105, 'Db', 'Dubnio', 'Dubnium', 268, 7, 5, 'tr'),
  ChemElement(106, 'Sg', 'Seaborgio', 'Seaborgium', 269, 7, 6, 'tr'),
  ChemElement(107, 'Bh', 'Bohrio', 'Bohrium', 270, 7, 7, 'tr'),
  ChemElement(108, 'Hs', 'Hassio', 'Hassium', 277, 7, 8, 'tr'),
  ChemElement(109, 'Mt', 'Meitnerio', 'Meitnerium', 278, 7, 9, 'tr'),
  ChemElement(110, 'Ds', 'Darmstadtio', 'Darmstadtium', 281, 7, 10, 'tr'),
  ChemElement(111, 'Rg', 'Roentgenio', 'Roentgenium', 282, 7, 11, 'tr'),
  ChemElement(112, 'Cn', 'Copernicio', 'Copernicium', 285, 7, 12, 'tr'),
  ChemElement(113, 'Nh', 'Nihonio', 'Nihonium', 286, 7, 13, 'pt'),
  ChemElement(114, 'Fl', 'Flerovio', 'Flerovium', 289, 7, 14, 'pt'),
  ChemElement(115, 'Mc', 'Moscovio', 'Moscovium', 290, 7, 15, 'pt'),
  ChemElement(116, 'Lv', 'Livermorio', 'Livermorium', 293, 7, 16, 'pt'),
  ChemElement(117, 'Ts', 'Tennesso', 'Tennessine', 294, 7, 17, 'al'),
  ChemElement(118, 'Og', 'Oganesson', 'Oganesson', 294, 7, 18, 'ng'),
];

String elementKindName(String k) => switch (k) {
      'am' => tr('Metalli alcalini', 'Alkali metals'),
      'at' => tr('Metalli alcalino-terrosi', 'Alkaline earth metals'),
      'tr' => tr('Metalli di transizione', 'Transition metals'),
      'pt' => tr('Altri metalli', 'Post-transition metals'),
      'sm' => tr('Semimetalli', 'Metalloids'),
      'nm' => tr('Non metalli', 'Nonmetals'),
      'al' => tr('Alogeni', 'Halogens'),
      'ng' => tr('Gas nobili', 'Noble gases'),
      'la' => tr('Lantanidi', 'Lanthanides'),
      'ac' => tr('Attinidi', 'Actinides'),
      _ => k,
    };

// ---------------------------------------------------------------------------- verbi irregolari

/// (base, past simple, past participle, italiano)
const irregularVerbs = <(String, String, String, String)>[
  ('arise', 'arose', 'arisen', 'sorgere'),
  ('awake', 'awoke', 'awoken', 'svegliarsi'),
  ('be', 'was/were', 'been', 'essere'),
  ('bear', 'bore', 'borne', 'sopportare'),
  ('beat', 'beat', 'beaten', 'battere'),
  ('become', 'became', 'become', 'diventare'),
  ('begin', 'began', 'begun', 'cominciare'),
  ('bend', 'bent', 'bent', 'piegare'),
  ('bet', 'bet', 'bet', 'scommettere'),
  ('bite', 'bit', 'bitten', 'mordere'),
  ('bleed', 'bled', 'bled', 'sanguinare'),
  ('blow', 'blew', 'blown', 'soffiare'),
  ('break', 'broke', 'broken', 'rompere'),
  ('bring', 'brought', 'brought', 'portare'),
  ('build', 'built', 'built', 'costruire'),
  ('burn', 'burnt/burned', 'burnt/burned', 'bruciare'),
  ('buy', 'bought', 'bought', 'comprare'),
  ('catch', 'caught', 'caught', 'prendere, afferrare'),
  ('choose', 'chose', 'chosen', 'scegliere'),
  ('come', 'came', 'come', 'venire'),
  ('cost', 'cost', 'cost', 'costare'),
  ('cut', 'cut', 'cut', 'tagliare'),
  ('deal', 'dealt', 'dealt', 'trattare'),
  ('dig', 'dug', 'dug', 'scavare'),
  ('do', 'did', 'done', 'fare'),
  ('draw', 'drew', 'drawn', 'disegnare'),
  ('dream', 'dreamt/dreamed', 'dreamt/dreamed', 'sognare'),
  ('drink', 'drank', 'drunk', 'bere'),
  ('drive', 'drove', 'driven', 'guidare'),
  ('eat', 'ate', 'eaten', 'mangiare'),
  ('fall', 'fell', 'fallen', 'cadere'),
  ('feed', 'fed', 'fed', 'nutrire'),
  ('feel', 'felt', 'felt', 'sentire, provare'),
  ('fight', 'fought', 'fought', 'combattere'),
  ('find', 'found', 'found', 'trovare'),
  ('fly', 'flew', 'flown', 'volare'),
  ('forbid', 'forbade', 'forbidden', 'proibire'),
  ('forget', 'forgot', 'forgotten', 'dimenticare'),
  ('forgive', 'forgave', 'forgiven', 'perdonare'),
  ('freeze', 'froze', 'frozen', 'congelare'),
  ('get', 'got', 'got/gotten', 'ottenere, diventare'),
  ('give', 'gave', 'given', 'dare'),
  ('go', 'went', 'gone', 'andare'),
  ('grow', 'grew', 'grown', 'crescere'),
  ('hang', 'hung', 'hung', 'appendere'),
  ('have', 'had', 'had', 'avere'),
  ('hear', 'heard', 'heard', 'sentire, udire'),
  ('hide', 'hid', 'hidden', 'nascondere'),
  ('hit', 'hit', 'hit', 'colpire'),
  ('hold', 'held', 'held', 'tenere'),
  ('hurt', 'hurt', 'hurt', 'ferire, fare male'),
  ('keep', 'kept', 'kept', 'tenere, mantenere'),
  ('know', 'knew', 'known', 'sapere, conoscere'),
  ('lay', 'laid', 'laid', 'posare, apparecchiare'),
  ('lead', 'led', 'led', 'guidare, condurre'),
  ('learn', 'learnt/learned', 'learnt/learned', 'imparare'),
  ('leave', 'left', 'left', 'lasciare, partire'),
  ('lend', 'lent', 'lent', 'prestare'),
  ('let', 'let', 'let', 'lasciare, permettere'),
  ('lie', 'lay', 'lain', 'giacere, sdraiarsi'),
  ('light', 'lit', 'lit', 'accendere'),
  ('lose', 'lost', 'lost', 'perdere'),
  ('make', 'made', 'made', 'fare, costruire'),
  ('mean', 'meant', 'meant', 'significare'),
  ('meet', 'met', 'met', 'incontrare'),
  ('pay', 'paid', 'paid', 'pagare'),
  ('put', 'put', 'put', 'mettere'),
  ('quit', 'quit', 'quit', 'smettere'),
  ('read', 'read', 'read', 'leggere'),
  ('ride', 'rode', 'ridden', 'cavalcare, andare in bici'),
  ('ring', 'rang', 'rung', 'suonare (campanello)'),
  ('rise', 'rose', 'risen', 'sorgere, alzarsi'),
  ('run', 'ran', 'run', 'correre'),
  ('say', 'said', 'said', 'dire'),
  ('see', 'saw', 'seen', 'vedere'),
  ('seek', 'sought', 'sought', 'cercare'),
  ('sell', 'sold', 'sold', 'vendere'),
  ('send', 'sent', 'sent', 'mandare'),
  ('set', 'set', 'set', 'porre, fissare'),
  ('shake', 'shook', 'shaken', 'scuotere'),
  ('shine', 'shone', 'shone', 'splendere'),
  ('shoot', 'shot', 'shot', 'sparare, girare (film)'),
  ('show', 'showed', 'shown', 'mostrare'),
  ('shut', 'shut', 'shut', 'chiudere'),
  ('sing', 'sang', 'sung', 'cantare'),
  ('sink', 'sank', 'sunk', 'affondare'),
  ('sit', 'sat', 'sat', 'sedersi'),
  ('sleep', 'slept', 'slept', 'dormire'),
  ('slide', 'slid', 'slid', 'scivolare'),
  ('smell', 'smelt/smelled', 'smelt/smelled', 'odorare'),
  ('speak', 'spoke', 'spoken', 'parlare'),
  ('spell', 'spelt/spelled', 'spelt/spelled', 'compitare'),
  ('spend', 'spent', 'spent', 'spendere, trascorrere'),
  ('spread', 'spread', 'spread', 'spargere, diffondere'),
  ('stand', 'stood', 'stood', 'stare in piedi'),
  ('steal', 'stole', 'stolen', 'rubare'),
  ('stick', 'stuck', 'stuck', 'attaccare'),
  ('sting', 'stung', 'stung', 'pungere'),
  ('strike', 'struck', 'struck', 'colpire'),
  ('swear', 'swore', 'sworn', 'giurare'),
  ('sweep', 'swept', 'swept', 'spazzare'),
  ('swim', 'swam', 'swum', 'nuotare'),
  ('take', 'took', 'taken', 'prendere'),
  ('teach', 'taught', 'taught', 'insegnare'),
  ('tear', 'tore', 'torn', 'strappare'),
  ('tell', 'told', 'told', 'dire, raccontare'),
  ('think', 'thought', 'thought', 'pensare'),
  ('throw', 'threw', 'thrown', 'lanciare'),
  ('understand', 'understood', 'understood', 'capire'),
  ('wake', 'woke', 'woken', 'svegliare'),
  ('wear', 'wore', 'worn', 'indossare'),
  ('win', 'won', 'won', 'vincere'),
  ('write', 'wrote', 'written', 'scrivere'),
];

// ---------------------------------------------------------------------------- ricerca

/// Testo normalizzato per la ricerca: minuscolo, senza accenti.
String foldText(String s) {
  const from = 'àáâäèéêëìíîïòóôöùúûüç';
  const to = 'aaaaeeeeiiiioooouuuuc';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}

bool _hit(String q, List<String> fields) => fields.any((f) => foldText(f).contains(q));

List<Formula> searchFormulas(String query) {
  final q = foldText(query.trim());
  if (q.isEmpty) return const [];
  return [
    for (final f in formulas)
      if (_hit(q, [f.it, f.en, f.text, f.noteIt])) f,
  ];
}

List<ChemElement> searchElements(String query) {
  final q = foldText(query.trim());
  if (q.isEmpty) return const [];
  // Prima il simbolo o il numero esatto (Fe, 26), poi i nomi che contengono la parola.
  final exact = [for (final e in elements) if (foldText(e.symbol) == q || '${e.z}' == q) e];
  return [
    ...exact,
    for (final e in elements)
      if (!exact.contains(e) && _hit(q, [e.it, e.en])) e,
  ];
}

List<(String, String, String, String)> searchVerbs(String query) {
  final q = foldText(query.trim());
  if (q.isEmpty) return irregularVerbs;
  return [
    for (final v in irregularVerbs)
      if (_hit(q, [v.$1, v.$2, v.$3, v.$4])) v,
  ];
}
