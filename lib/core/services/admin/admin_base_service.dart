import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AdminBaseService {
  AdminBaseService({SupabaseClient? supabase})
    : supabaseClient = supabase ?? Supabase.instance.client;

  final SupabaseClient supabaseClient;

  String? get currentUserId => supabaseClient.auth.currentUser?.id;
}
