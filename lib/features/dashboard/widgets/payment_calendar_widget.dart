import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../../data/models/dashboard_stats_model.dart';

class PaymentCalendarWidget extends StatefulWidget {
  const PaymentCalendarWidget({
    required this.events,
    super.key,
  });

  final List<PaymentCalendarEvent> events;

  @override
  State<PaymentCalendarWidget> createState() => _PaymentCalendarWidgetState();
}

class _PaymentCalendarWidgetState extends State<PaymentCalendarWidget> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  List<PaymentCalendarEvent> _eventsForDay(DateTime day) {
    return widget.events
        .where((event) => isSameDay(event.date, day))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _eventsForDay(_selectedDay ?? _focusedDay);

    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            eyebrow: 'Payment calendar',
            title: 'Who paid on which date',
            subtitle: 'Tap a date to see all payment entries for that day.',
          ),
          const SizedBox(height: 14),
          TableCalendar<PaymentCalendarEvent>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            eventLoader: _eventsForDay,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              leftChevronIcon: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textSecondaryDark,
              ),
              rightChevronIcon: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondaryDark,
              ),
              titleTextStyle: Theme.of(context).textTheme.titleMedium!,
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: Theme.of(context).textTheme.bodySmall!,
              defaultTextStyle: Theme.of(context).textTheme.bodySmall!,
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.primaryDim,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary),
              ),
              markerDecoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
          ),
          const SizedBox(height: 14),
          if (selectedEvents.isEmpty)
            const AppEmptyState(
              title: 'No payments on this date',
              message: 'Choose another marked day to see who recorded rent.',
              icon: Icons.event_busy_rounded,
            )
          else
            Column(
              children: selectedEvents
                  .map(
                    (event) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).inputDecorationTheme.fillColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.accentDim,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              event.roomNumber,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.tenantName,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Room ${event.roomNumber} | ${event.recordedByName} | ${event.paymentMethod.toUpperCase()}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if ((event.remark ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    event.remark!,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.inr(event.amountPaid),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (event.remainingAmount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Rem ${CurrencyFormatter.inr(event.remainingAmount)}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
