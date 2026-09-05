import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/backend/supabase_provider.dart';
import 'package:mobi_app/features/profile/data/driver_plus_service.dart';
import 'package:mobi_app/features/profile/data/favorite_address_service.dart';
import 'package:mobi_app/features/profile/data/profile_service.dart';
import 'package:mobi_app/features/profile/data/referral_attribution_service.dart';
import 'package:mobi_app/features/profile/data/referral_service.dart';
import 'package:mobi_app/features/profile/data/subscription_plan_service.dart';
import 'package:mobi_app/features/profile/data/vehicle_type_service.dart';
import 'package:mobi_app/features/profile/data/wallet_service.dart';

final profileServiceProvider = Provider(
  (ref) => ProfileService(supabase: ref.read(supabaseClientProvider)),
);

final favoriteAddressServiceProvider = Provider(
  (ref) => FavoriteAddressService(supabase: ref.read(supabaseClientProvider)),
);

final driverPlusServiceProvider = Provider(
  (ref) => DriverPlusService(supabase: ref.read(supabaseClientProvider)),
);

final referralServiceProvider = Provider(
  (ref) => ReferralService(supabase: ref.read(supabaseClientProvider)),
);

final referralAttributionServiceProvider = Provider(
  (ref) => ReferralAttributionService(
    referralService: ref.read(referralServiceProvider),
  ),
);

final subscriptionPlanServiceProvider = Provider(
  (ref) => SubscriptionPlanService(supabase: ref.read(supabaseClientProvider)),
);

final vehicleTypeServiceProvider = Provider(
  (ref) => VehicleTypeService(supabase: ref.read(supabaseClientProvider)),
);

final walletServiceProvider = Provider(
  (ref) => WalletService(supabase: ref.read(supabaseClientProvider)),
);
