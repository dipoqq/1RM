import 'package:flutter/material.dart';

/// Below this width the app is a single scrolling column (phone, narrow window);
/// at or above it, content splits into two columns capped at [_maxWidth].
const double kWideBreakpoint = 900;
const double _maxWidth = 1180;

/// The one place the phone/desktop split is decided.
///
/// Both tabs use this, so there is a single breakpoint and a single max-width
/// rule rather than a copy of the logic in each.
///
/// Narrow: [primary] then [secondary], stacked in one scroll view.
/// Wide:   two independently-scrolling columns, centred and width-capped, so
///         cards do not stretch to 1920 px on a desktop monitor.
class AdaptiveColumns extends StatelessWidget {
  const AdaptiveColumns({
    super.key,
    required this.primary,
    required this.secondary,
    this.header,
    this.onRefresh,
  });

  /// Left column when wide; first when narrow.
  final List<Widget> primary;

  /// Right column when wide; second when narrow.
  final List<Widget> secondary;

  /// Pinned above both columns at every width (e.g. the calendar strip).
  final Widget? header;

  final Future<void> Function()? onRefresh;

  static const _gap = SizedBox(height: 16);
  static const _pad = EdgeInsets.fromLTRB(16, 16, 16, 32);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kWideBreakpoint;

        final Widget body = wide
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxWidth),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _column(primary)),
                      const SizedBox(width: 16),
                      Expanded(child: _column(secondary)),
                    ],
                  ),
                ),
              )
            : _column([...primary, ...secondary]);

        final withHeader = header == null
            ? body
            : Column(children: [header!, Expanded(child: body)]);

        return onRefresh == null
            ? withHeader
            : RefreshIndicator(onRefresh: onRefresh!, child: withHeader);
      },
    );
  }

  Widget _column(List<Widget> children) => ListView.separated(
        // Always scrollable so RefreshIndicator still works on a short page.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _pad,
        itemCount: children.length,
        separatorBuilder: (_, _) => _gap,
        itemBuilder: (context, i) => children[i],
      );
}
