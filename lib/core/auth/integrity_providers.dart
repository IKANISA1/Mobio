import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/auth/play_integrity_service.dart';

final playIntegrityServiceProvider = Provider((ref) => PlayIntegrityService());
