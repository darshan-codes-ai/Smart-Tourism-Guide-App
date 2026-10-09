import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/attraction.dart';
import '../../services/attraction_service.dart';

/// Modal dialog for creating or editing an attraction.
class AttractionFormDialog extends StatefulWidget {
  const AttractionFormDialog({
    super.key,
    this.attraction,
  });

  final Attraction? attraction;

  static Future<bool?> show(BuildContext context, {Attraction? attraction}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AttractionFormDialog(attraction: attraction),
    );
  }

  @override
  State<AttractionFormDialog> createState() => _AttractionFormDialogState();
}

class _AttractionFormDialogState extends State<AttractionFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _ratingController;
  late final TextEditingController _entryFeeController;
  late final TextEditingController _openingHoursController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.attraction != null;

  @override
  void initState() {
    super.initState();
    final a = widget.attraction;
    _nameController = TextEditingController(text: a?.name ?? '');
    _categoryController = TextEditingController(text: a?.category ?? 'Landmark');
    _cityController = TextEditingController(text: a?.city ?? '');
    _countryController = TextEditingController(text: a?.country ?? '');
    _locationController = TextEditingController(text: a?.location ?? '');
    _descriptionController = TextEditingController(text: a?.description ?? '');
    _imageUrlController = TextEditingController(text: a?.imageUrl ?? '');
    _ratingController = TextEditingController(text: a != null ? a.rating.toString() : '4.5');
    _entryFeeController = TextEditingController(text: a?.entryFee ?? 'Free');
    _openingHoursController = TextEditingController(text: a?.openingHours ?? '09:00 - 18:00');
    _latitudeController = TextEditingController(
      text: a?.latitude != null ? a!.latitude.toString() : '',
    );
    _longitudeController = TextEditingController(
      text: a?.longitude != null ? a!.longitude.toString() : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _ratingController.dispose();
    _entryFeeController.dispose();
    _openingHoursController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final rating = double.tryParse(_ratingController.text.trim()) ?? 0.0;
    final latText = _latitudeController.text.trim();
    final lngText = _longitudeController.text.trim();
    final latitude = latText.isNotEmpty ? double.tryParse(latText) : null;
    final longitude = lngText.isNotEmpty ? double.tryParse(lngText) : null;

    final city = _cityController.text.trim();
    final country = _countryController.text.trim();
    String location = _locationController.text.trim();
    if (location.isEmpty) {
      if (city.isNotEmpty && country.isNotEmpty) {
        location = '$city, $country';
      } else if (city.isNotEmpty) {
        location = city;
      } else if (country.isNotEmpty) {
        location = country;
      }
    }

    final attractionData = Attraction(
      id: widget.attraction?.id ?? '',
      name: _nameController.text.trim(),
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim(),
      imageUrl: _imageUrlController.text.trim(),
      rating: rating,
      city: city,
      country: country,
      location: location,
      entryFee: _entryFeeController.text.trim().isEmpty ? 'Free' : _entryFeeController.text.trim(),
      openingHours: _openingHoursController.text.trim().isEmpty
          ? '09:00 - 18:00'
          : _openingHoursController.text.trim(),
      distance: widget.attraction?.distance ?? '',
      latitude: latitude,
      longitude: longitude,
      reviewCount: widget.attraction?.reviewCount ?? 0,
      popularity: widget.attraction?.popularity ?? 0.0,
      currency: widget.attraction?.currency,
      openingTime: widget.attraction?.openingTime,
      closingTime: widget.attraction?.closingTime,
      isSaved: widget.attraction?.isSaved ?? false,
    );

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        await AttractionService.instance.updateAttraction(attractionData);
      } else {
        await AttractionService.instance.createAttraction(attractionData);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isEditing ? Icons.edit_rounded : Icons.add_location_alt_rounded,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit Attraction' : 'Add New Attraction',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Form fields
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // Name
                      TextFormField(
                        key: const Key('admin_attraction_name_field'),
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Attraction Name *',
                          hintText: 'e.g. Louvre Museum',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Attraction name is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Category & Rating Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('admin_attraction_category_field'),
                              controller: _categoryController,
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                hintText: 'e.g. Landmark, Museum, Nature',
                                prefixIcon: Icon(Icons.category_rounded),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Category is required.';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              key: const Key('admin_attraction_rating_field'),
                              controller: _ratingController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Rating (0.0 - 5.0) *',
                                hintText: 'e.g. 4.7',
                                prefixIcon: Icon(Icons.star_rounded, color: Colors.amber),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Rating is required.';
                                }
                                final parsed = double.tryParse(value.trim());
                                if (parsed == null || parsed < 0.0 || parsed > 5.0) {
                                  return 'Rating must be 0.0 - 5.0.';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // City & Country Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('admin_attraction_city_field'),
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'City',
                                hintText: 'e.g. Paris',
                                prefixIcon: Icon(Icons.location_city_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              key: const Key('admin_attraction_country_field'),
                              controller: _countryController,
                              decoration: const InputDecoration(
                                labelText: 'Country',
                                hintText: 'e.g. France',
                                prefixIcon: Icon(Icons.public_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Location string
                      TextFormField(
                        key: const Key('admin_attraction_location_field'),
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Display Location',
                          hintText: 'e.g. Paris, France',
                          prefixIcon: Icon(Icons.pin_drop_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Image URL
                      TextFormField(
                        key: const Key('admin_attraction_image_url_field'),
                        controller: _imageUrlController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Image URL *',
                          hintText: 'https://...',
                          prefixIcon: Icon(Icons.image_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Image URL is required.';
                          }
                          final uri = Uri.tryParse(value.trim());
                          if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
                            return 'Enter a valid HTTP or HTTPS URL.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Description
                      TextFormField(
                        key: const Key('admin_attraction_description_field'),
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          hintText: 'Detailed description of the attraction...',
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(bottom: 40),
                            child: Icon(Icons.description_rounded),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Description is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Entry Fee & Opening Hours Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('admin_attraction_fee_field'),
                              controller: _entryFeeController,
                              decoration: const InputDecoration(
                                labelText: 'Entry Fee',
                                hintText: 'e.g. Free, €22.0',
                                prefixIcon: Icon(Icons.payments_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              key: const Key('admin_attraction_hours_field'),
                              controller: _openingHoursController,
                              decoration: const InputDecoration(
                                labelText: 'Opening Hours',
                                hintText: 'e.g. 09:00 - 18:00',
                                prefixIcon: Icon(Icons.access_time_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Coordinates Row (Latitude / Longitude)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('admin_attraction_lat_field'),
                              controller: _latitudeController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Latitude (-90 to 90)',
                                hintText: 'e.g. 48.8584',
                                prefixIcon: Icon(Icons.my_location_rounded),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return null;
                                final parsed = double.tryParse(value.trim());
                                if (parsed == null || parsed < -90.0 || parsed > 90.0) {
                                  return 'Must be between -90 and 90.';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              key: const Key('admin_attraction_lng_field'),
                              controller: _longitudeController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Longitude (-180 to 180)',
                                hintText: 'e.g. 2.2945',
                                prefixIcon: Icon(Icons.map_rounded),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return null;
                                final parsed = double.tryParse(value.trim());
                                if (parsed == null || parsed < -180.0 || parsed > 180.0) {
                                  return 'Must be between -180 and 180.';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Actions Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    key: const Key('admin_attraction_cancel_button'),
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    key: const Key('admin_attraction_save_button'),
                    onPressed: _isSaving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 20),
                    label: Text(_isSaving ? 'Saving...' : (_isEditing ? 'Save Changes' : 'Create')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

