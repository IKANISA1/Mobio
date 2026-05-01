import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobi_app/core/errors/app_error_utils.dart';
import 'package:mobi_app/shared/widgets/mobi_error_state.dart';

/// Standard async state renderer for Riverpod-backed screens.
///
/// Keeps loading and error treatment consistent while still allowing each screen
/// to provide a domain-specific skeleton or error layout.
class MobiAsyncStateView<T> extends StatelessWidget {
  const MobiAsyncStateView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.errorTitle = 'Something went wrong',
    this.errorHeight,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.errorMessageBuilder,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final WidgetBuilder? loading;
  final Widget Function(Object error, StackTrace stackTrace)? error;
  final String errorTitle;
  final double? errorHeight;
  final VoidCallback? onRetry;
  final String retryLabel;
  final String Function(Object error)? errorMessageBuilder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () {
        final loadingBuilder = loading;
        if (loadingBuilder != null) {
          return loadingBuilder(context);
        }

        return Center(
          child: Semantics(
            label: 'Loading',
            liveRegion: true,
            child: const CircularProgressIndicator(),
          ),
        );
      },
      error: (err, stackTrace) {
        final errorBuilder = error;
        if (errorBuilder != null) {
          return errorBuilder(err, stackTrace);
        }

        return Center(
          child: MobiErrorState(
            title: errorTitle,
            subtitle:
                errorMessageBuilder?.call(err) ?? userMessageForError(err),
            height: errorHeight,
            onRetry: onRetry,
            retryLabel: retryLabel,
          ),
        );
      },
    );
  }
}
