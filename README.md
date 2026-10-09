# BeerEngineer — Slice 1 (prototype)

Godot 4.3-project. Open de map `beer-engineer/` in de Godot-editor en druk op F5 (hoofdscene is ingesteld).

## Wat er in deze slice zit

- Top-down fabriek: 12×8 grid (groter dan scherm → camera pan/zoom)
- Camera: **WASD/pijltjes**, **middelklik-sleep**, **scrollwiel zoom** (0.5×–2×)
- Volledige brouwketen: **Schroten → Maischen → Koken → Vergisten → Rijpen** (met voortgangsbalken en tooltips)
- **Bierproductie**: klik de schrotmolen (recept: 2 graan, 1 hop, 1 gist) → sleep elke output naar de volgende machine → rijping klaar = 5 units bier in de opslagbox
- **Verkooporder**: De Zythoeker — klik de opslagbox om bier op te pakken, sleep het naar het order-gebied; 5 units = 40 goud, daarna herhaalt de order
- **Leverancier**: koop graan (2), hop (3), gist (4) — knoppen linksboven met hover-tooltips
- **HUD**: geld + ingrediëntenvoorraad; onderaan dynamische tooltips (machines: status/voortgang)
- **Rechtsklik**: sleepactie annuleren (item gaat terug naar bron)

## Placeholder-art

Alle visuals zijn in code getekende gekleurde blokken (16-bit cartoony art wordt later AI-gegenereerd en vervangt de blokken). De opzet met `STEP_COLORS`/per-machine visuals maakt dat een kwestie van textures toevoegen.

## Nog niet in slice 1 (bewust, volgens GDD-v1)

- Bouwmodus (machines plaatsen/rotatie), kameruitbreidingen
- Meerdere gistingsvaten/rijpingstanks, parallelliteit
- Techtree, XP/levels, meerdere recepten en klanten
- Save/load, pauzemenu

## Volgende stappen (voorstel)

1. Jij test de slice in Godot → feedback op feel (tijden, sleep-flow)
2. Slice 2: bouwmodus + meerdere gist/rijp-tanks (parallelliteit)
3. Slice 3: orders-systeem met meerdere klanten + XP/techtree
