import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../services/trip_service.dart';

/// Modal bottom sheet for creating or editing a trip.
class TripFormSheet extends StatefulWidget {
  const TripFormSheet({
    super.key,
    this.initialTrip,
    this.initialAttractionId,
  });

  final Trip? initialTrip;
  final String? initialAttractionId;

  /// Helper to show the sheet and return the saved [Trip].
  static Future<Trip?> show(
    BuildContext context, {
    Trip? initialTrip,
    String? initialAttractionId,
  }) {
    return showModalBottomSheet<Trip>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => TripFormSheet(
        initialTrip: initialTrip,
        initialAttractionId: initialAttractionId,
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
  late DateTime _startDate;
  late DateTime _endDate;
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
      text: widget.initialTrip?.destination ?? '',
    );

    _startDate = widget.initialTrip?.startDate ?? today;
    _endDate = widget.initialTrip?.endDate ?? today.add(const Duration(days: 3));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_endDate.isBefore(_startDate)) {
      setState(() {
        _errorMessage = 'End date cannot be before start date.';
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
        );
        final updatedTrip = widget.initialTrip!.copyWith(
          name: _nameController.text.trim(),
          destination: _destinationController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          updatedAt: DateTime.now(),
        );
        if (mounted) Navigator.of(context).pop(updatedTrip);
      } else {
        final attractionIds = widget.initialAttractionId != null
            ? <String>[widget.initialAttractionId!]
            : <String>[];
        final newTrip = await TripService.instance.createTrip(
          name: _nameController.text.trim(),
          destination: _destinationController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          attractionIds: attractionIds,
        );
        if (mounted) Navigator.of(context).pop(newTrip);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is TripServiceException ? e.message : 'Error saving trip: $e';
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
                  if (text.length > 100) return 'Name cannot exceed 100 characters.';
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Please enter a destination.';
                  if (text.length > 100) return 'Destination cannot exceed 100 characters.';
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
                          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
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
                          prefixIcon: const Icon(Icons.event_outlined, size: 20),
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
              const SizedBox(height: 24),

              // Action Buttons
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
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

