/// Pure account/request generation fence. Refreshing a token within the same
/// Auth session does not invalidate work; sign-out/account/session change does.
class AccountEpoch {
  String? _identity;
  int _generation = 0;
  int update(String? identity) {
    if (identity != _identity) { _identity = identity; _generation++; }
    return _generation;
  }
  void invalidate() => _generation++;
  int get generation => _generation;
  bool matches(String? identity, int generation) =>
      identity == _identity && generation == _generation;
}
class StaleAccountWork implements Exception {
  const StaleAccountWork();
  @override String toString() => 'ACCOUNT_CHANGED';
}
