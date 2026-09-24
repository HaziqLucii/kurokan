/// `incident` pins one monitor DOWN and one host gauge at CRIT,
/// unconditionally (not tick-dependent), so a screenshot taken at any fixed
/// clock value reliably shows a "bad state" panel. `calm` is what
/// production demo mode uses: everything varies smoothly, nothing is ever
/// down or critical.
enum DemoScenario { calm, incident }
