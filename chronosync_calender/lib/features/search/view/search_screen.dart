import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:chronosync_calender/core/l10n/strings.dart';
import 'package:chronosync_calender/core/theme/app_theme.dart';
import 'package:chronosync_calender/core/widgets/empty_state.dart';
import 'package:chronosync_calender/data/models/occurrence.dart';
import 'package:chronosync_calender/features/calendar/view/event_tile.dart';
import 'package:chronosync_calender/features/calendar/view_model/calendar_view_model.dart';
import 'package:chronosync_calender/features/events/view/event_actions.dart';

Future<void> openSearch(BuildContext context, CalendarViewModel controller) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => SearchScreen(controller: controller)),
  );
}

/// Searches titles, locations and notes across visible calendars (one year either side of today).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.controller});

  final CalendarViewModel controller;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _field = TextEditingController();
  Future<List<Occurrence>>? _future;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _future = value.trim().isEmpty ? null : widget.controller.search(value);
    });
  }

  void _clear() {
    _field.clear();
    _onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final controller = widget.controller;

    return Scaffold(
      appBar: AppBar(title: Text(Strings.t('search'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
            child: TextField(
              controller: _field,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: Strings.t('search_hint'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _field.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: Strings.t('close'),
                        icon: const Icon(Icons.close),
                        onPressed: _clear,
                      ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Occurrence>>(
              future: _future,
              builder: (context, snapshot) {
                if (_future == null) {
                  return EmptyState(
                    icon: Icons.search,
                    title: Strings.t('search'),
                    message: Strings.t('search_empty'),
                  );
                }
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final results = snapshot.data ?? const <Occurrence>[];
                if (results.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: Strings.t('search_none'),
                    message: '',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
                      child: Text(
                        Strings.t('results_count', {'n': results.length}),
                        style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.xl),
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final occ = results[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.xs, 0, AppSpace.xs),
                                  child: Text(
                                    DateFormat.yMMMEd().format(occ.start),
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                EventTile(
                                  occurrence: occ,
                                  color: eventColor(controller, occ.event),
                                  calendarName: controller.calendarById(occ.event.calendarId)?.name ?? '',
                                  onTap: () => openEventDetail(context, controller, occ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
