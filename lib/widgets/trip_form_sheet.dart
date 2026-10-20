import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/dummy_data.dart';
import '../models/attraction.dart';
import '../models/trip.dart';
import '../services/attraction_service.dart';
import '../services/itinerary_service.dart';
import '../services/recommendation_service.dart';
import '../services/trip_service.dart';
import 'destination_search_sheet.dart';

/// Modal bottom sheet for creating or editing a trip.
class TripFormSheet extends StatefulWidget {
  const TripFormSheet({
    super.key,
    this.initialTrip,
    this.initialAttractionId,
    this.initialDestination,
  });

  final Trip? initialTrip;
  final String? initialAttractionId;
  final String? initialDestination;

  /// Helper to show the sheet and return the saved [Trip].
  static Future<Trip?> show(
    BuildContext context, {
    Trip? initialTrip,
    String? initialAttractionId,
    String? initialDestination,
  }) {
    return showModalBottomSheet<Trip>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => TripFormSheet(
        initialTrip: initialTrip,
        initialAttractionId: initialAttractionId,
        initialDestination: initialDestination,
      ),
    );
  }

  @override
  State<TripFormSheet> createState() => _TripFormSheetState();
}

class _TripFormSheetState extends State<TripFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _destinationController;
  late final TextEditingController _budgetController;
  late DateTime _startDate;
  late DateTime _endDate;
  int _travelerCount = 1;
  bool _autoGenerateItinerary = false;
  bool _submitting = false;
  String? _errorMessage;

  bool get isEditing => widget.initialTrip != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _nameController = TextEditingController(
      text: widget.initialTrip?.name ?? '',
    );
    _destinationController = TextEditingController(
      text: widget.initialTrip?.destination ?? widget.initialDestination ?? '',
    );
    _budgetController = TextEditingController(
      text:
          widget.initialTrip?.budget != null && widget.initialTrip!.budget! > 0
          ? widget.initialTrip!.budget!.toStringAsFixed(0)
          : '',
    );

    _startDate = widget.initialTrip?.startDate ?? today;
    _endDate =
        widget.initialTrip?.endDate ?? today.add(const Duration(days: 3));
    _travelerCount = widget.initialTrip?.travelerCount ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<List<Attraction>> _fetchAttractionPool() async {
    try {
      final list = await AttractionService.instance
          .watchAttractions()
          .first
          .timeout(const Duration(seconds: 2));
      if (list.isNotEmpty) return list;
    } catch (_) {}
    return DummyData.attractions;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_endDate.isBefore(_startDate)) {
      setState(() {
        _errorMessage = 'End date cannot be before start date.';
      });
      return;
    }

    final budgetText = _budgetController.text.trim();
    final double? budget = budgetText.isEmpty
        ? null
        : double.tryParse(budgetText);
    if (budgetText.isNotEmpty && (budget == null || budget < 0)) {
      setState(() {
        _errorMessage = 'Please enter a valid positive budget.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      if (isEditing) {
        final tripId = widget.initialTrip!.id;
        await TripService.instance.updateTrip(
          tripId: tripId,
          name: _nameController.text.trim(),
          destination: _destinationController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          budget: budget,
          clearBudget: budget == null,
          travelerCount: _travelerCount,
        );
        final updatedTrip = widget.initialTrip!.copyWith(
          name: _nameController.text.trim(),
          destination: _destinationController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          budget: budget,
          clearBudget: budget == null,
          travelerCount: _travelerCount,
          updatedAt: DateTime.now(),
        );
        if (mounted) Navigator.of(context).pop(updatedTrip);
      } else {
        List<String> attractionIds = widget.initialAttractionId != null
            ? <String>[widget.initialAttractionId!]
            : <String>[];
        Map<int, List<String>> dayItinerary = const <int, List<String>>{};

        if (_autoGenerateItinerary) {
          final pool = await _fetchAttractionPool();
          final userInterests = RecommendationService
              .instance
              .currentPreference
              .selectedInterests;
          final generated = ItineraryService.instance.generateItinerary(
            destination: _destinationController.text.trim(),
            startDate: _startDate,
            endDate: _endDate,
            availableAttractions: pool,
            interests: userInterests.isNotEmpty ? userInterests : null,
            budget: budget,
            travelerCount: _travelerCount,
          );
          if (generated.allAttractionIds.isNotEmpty) {
            attractionIds = generated.allAttractionIds;
            dayItinerary = generated.dayItineraryIds;
          }
        }

        final newTrip = await TripService.instance.createTrip(
          name: _nameController.text.trim(),
          destination: _destinationController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          attractionIds: attractionIds,
          budget: budget,
          travelerCount: _travelerCount,
          dayItinerary: dayItinerary,
        );
        if (mounted) Navigator.of(context).pop(newTrip);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is TripServiceException
              ? e.message
              : 'Error saving trip: $e';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Edit Trip' : 'Create New Trip',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Trip Name
              TextFormField(
                controller: _nameController,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Trip Name *',
                  hintText: 'e.g. Paris Adventure',
                  prefixIcon: const Icon(Icons.luggage_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Please enter a trip name.';
                  if (text.length > 100) {
                    return 'Name cannot exceed 100 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Destination
              TextFormField(
                controller: _destinationController,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Destination *',
                  hintText: 'e.g. Paris, France',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: IconButton(
                    key: const Key('trip_form_search_destination_button'),
                    icon: const Icon(Icons.travel_explore_rounded),
                    tooltip: 'Search Worldwide Destinations',
                    onPressed: () async {
                      final selected = await DestinationSearchSheet.show(
                        context,
                        initialQuery: _destinationController.text.trim(),
                      );
                      if (selected != null) {
                        setState(() {
                          _destinationController.text = selected.name;
                        });
                      }
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Please enter a destination.';
                  if (text.length > 100) {
                    return 'Destination cannot exceed 100 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Dates Row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickStartDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Start Date',
                          prefixIcon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _formatDate(_startDate),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickEndDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'End Date',
                          prefixIcon: const Icon(
                            Icons.event_outlined,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _formatDate(_endDate),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Budget & Travelers Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Available Budget (optional)
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _budgetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Budget (optional)',
                        hintText: 'e.g. 1500',
                        prefixIcon: const Icon(
                          Icons.attach_money_rounded,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isNotEmpty) {
                          final val = double.tryParse(text);
                          if (val == null || val < 0) return 'Invalid budget';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Traveler Count Stepper
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16),
                            tooltip: 'Decrease travelers',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _travelerCount > 1
                                ? () => setState(() => _travelerCount--)
                                : null,
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$_travelerCount',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _travelerCount == 1
                                    ? 'Traveller'
                                    : 'Travellers',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16),
                            tooltip: 'Increase travelers',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() => _travelerCount++),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Smart AI Itinerary Checkbox (when creating)
              if (!isEditing) ...[
                Material(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: SwitchListTile(
                      key: const Key('trip_form_auto_itinerary_switch'),
                      value: _autoGenerateItinerary,
                      activeThumbColor: AppTheme.primary,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Generate Smart Itinerary',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: const Text(
                        'Auto-schedule recommended attractions for this destination across trip days',
                        style: TextStyle(fontSize: 11),
                      ),
                      secondary: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppTheme.primary,
                      ),
                      onChanged: (val) =>
                          setState(() => _autoGenerateItinerary = val),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Action Buttons
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEditing ? 'Save Changes' : 'Create Trip',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
