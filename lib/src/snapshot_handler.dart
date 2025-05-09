import 'package:flutter/material.dart';

enum SnapshotTransition { fade, scale, slide, rotate, size,none}

class SnapshotHandler<T> extends StatelessWidget {
  final AsyncSnapshot<T> snapshot;
  final Widget Function(T data) onSuccess;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? noDataWidget;
  final SnapshotTransition transitionType;
  final Duration duration;
  final Curve curve;

  const SnapshotHandler({
    super.key,
    required this.snapshot,
    required this.onSuccess,
    this.loadingWidget,
    this.errorWidget,
    this.transitionType = SnapshotTransition.fade,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeInOut, this.noDataWidget,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: curve,
      transitionBuilder: (child, animation) {
        switch (transitionType) {
          case SnapshotTransition.scale:
            return ScaleTransition(scale: animation, child: child);

          case SnapshotTransition.slide:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );

          case SnapshotTransition.rotate:
            return RotationTransition(
              turns: animation,
              child: child,
            );

          case SnapshotTransition.size:
            return SizeTransition(
              sizeFactor: animation,
              axis: Axis.vertical,
              child: child,
            );

          case SnapshotTransition.fade:
            return FadeTransition(opacity: animation, child: child);

          case SnapshotTransition.none:
            return child;
        }
      },
      child: _buildChild(),
    );
  }

  Widget _buildChild() {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return loadingWidget ??
          const Center(
            key: ValueKey('loading'),
            child: CircularProgressIndicator(),
          );
    } else if (snapshot.hasError) {
      return errorWidget ??
          Center(
            key: const ValueKey('error'),
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
    } else if (snapshot.hasData) {
      return onSuccess(snapshot.data as T);
    } else {
      return noDataWidget ?? Center(
        key: ValueKey('noData'),
        child: Text('No data available'),
      );
    }
  }
}
