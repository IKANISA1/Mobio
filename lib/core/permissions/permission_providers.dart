import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/permissions/app_permission_service.dart';

final appPermissionServiceProvider = Provider((ref) => AppPermissionService());
