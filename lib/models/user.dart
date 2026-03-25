enum UserRole { passenger, driver, admin }

class AppUser {
  final String id;
  final String name;
  final String phone;
  final UserRole role;
  final String? location;
  final String? vehicle;
  final String? category;

  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.location,
    this.vehicle,
    this.category,
  });
}
