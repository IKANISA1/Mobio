import 'package:flutter/material.dart';
import 'package:mobi_app/core/auth/account_context.dart';
class AccountBoundView extends StatelessWidget {
  const AccountBoundView({super.key,required this.account,required this.child});
  final AccountSnapshot account;
  final Widget child;
  @override Widget build(BuildContext context)=>ValueListenableBuilder<int>(
    valueListenable:AccountContext.changes,
    builder:(context,_,__)=>AccountContext.isCurrent(account)?child:
      const Material(child:Center(child:Text('Account changed. Close this view and sign in again.'))),
  );
}
