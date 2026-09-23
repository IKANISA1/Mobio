/// Agency names supplied in the 2026-09-20 product review.
///
/// This is the offline/preview catalog. Live agency availability remains managed
/// by `transport_agencies`; do not merge this list over admin deactivations.
const rwandaTransportAgencyNames = [
  'ALPHA EXPRESS COMPANY',
  'CAPITAL',
  'CITY EXPRESS',
  'DIFFERENT EXPRESS',
  'EA BUS & TRAVEL LIMITED',
  'EBENEZER EXPRESS',
  'EXCEL TRAVEL&TOURS AGENCY',
  'FIDELITY EXPRESS',
  'GICUMBI TRANSPORT COOPERATIVE',
  'HORIZON EXPRESS',
  'HUYE TC',
  'INDONYI EXPRESS',
  'INTERNATIONAL EXPRESS',
  'JALI TRANSPORT',
  'KAYONZA TC',
  'KIGALI BUS SERVICES',
  'KIGALI COACH TOURS & TRAVEL',
  'KIVU BELT EXPRESS',
  'LA COLOMBE EXPRESS',
  'MASH BUS SERVICES',
  'MATUNDA EXPRESS',
  'MODERN COAST',
  'MUHANGA TC',
  'MUSANZE TC',
  'NGOMA TC',
  'NYABUGOGO TC',
  'NYAGATARE TC',
  'OMEGA',
  'RITCO',
  'ROYAL EXPRESS',
  'RUBAVU TC',
  'RUHIRE EXPRESS',
  'RUSIZI TC',
  'SELECT EXPRESS AGENCY',
  'SHALOM TRANSPORTATION LIMITED',
  'SIMBA COACH',
  'STAR EXPRESS',
  'STELLA EXPRESS',
  'TRINITY TRANSPORTERS',
  'TRIPARTITE TOURS',
  'VIRUNGA EXPRESS',
  'VOLCANO',
  'YAHOO CAR EXPRESS',
];

/// Matches existing saved preferences to the current catalog without changing
/// the agency's stored identity or requiring users to reselect it.
String transportAgencyIdentity(String value) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
  return switch (normalized) {
    'TRINITY EXPRESS' => 'TRINITY TRANSPORTERS',
    'VOLCANO EXPRESS' => 'VOLCANO',
    _ => normalized,
  };
}
