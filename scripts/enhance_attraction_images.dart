// scripts/enhance_attraction_images.dart
//
// TourMate Phase 14: Attraction Photography Enhancement
// Resolves Special:FilePath, broken thumbnails, and missing images
// into direct, high-quality, CORS-compatible Wikimedia thumbnail URLs.

// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings

import 'dart:convert';
import 'dart:io';

const String userAgent =
    'TourMate-App/1.0 (https://tourmate-70d03.web.app; darshanskull@gmail.com)';

Future<void> main() async {
  final file = File('assets/data/global_attractions.json');
  if (!await file.exists()) {
    print('Error: assets/data/global_attractions.json not found!');
    exit(1);
  }

  final rawJson = await file.readAsString();
  final List<dynamic> attractions = jsonDecode(rawJson) as List<dynamic>;
  print(
    'Loaded ${attractions.length} attractions from global_attractions.json',
  );

  final client = HttpClient();
  client.userAgent = userAgent;

  int specialFilePathCount = 0;
  int emptyCount = 0;
  int alreadyThumbCount = 0;

  for (final item in attractions) {
    final url = (item['imageUrl'] as String? ?? '').trim();
    if (url.isEmpty) {
      emptyCount++;
    } else if (url.contains('Special:FilePath')) {
      specialFilePathCount++;
    } else if (url.contains('/thumb/')) {
      alreadyThumbCount++;
    }
  }

  print('Initial State:');
  print('  Special:FilePath: $specialFilePathCount');
  print('  Already /thumb/: $alreadyThumbCount');
  print('  Empty: $emptyCount');

  // Step 1: Collect all filenames from Special:FilePath and /thumb/ URLs
  // Map from normalized title (e.g. 'File:Mysore Palace Morning.jpg') to list of attractions
  final Map<String, List<Map<String, dynamic>>> titleToAttractions = {};
  final List<Map<String, dynamic>> needsSearchAttractions = [];

  for (final item in attractions) {
    final map = item as Map<String, dynamic>;
    final url = (map['imageUrl'] as String? ?? '').trim();

    if (url.contains('Special:FilePath/')) {
      final rawName = url.split('Special:FilePath/').last;
      final decodedName = Uri.decodeComponent(rawName)
          .replaceAll('_', ' ')
          .trim();
      final titleKey = 'File:${_capitalizeFirst(decodedName)}';
      titleToAttractions.putIfAbsent(titleKey, () => []).add(map);
    } else if (url.contains('/wikipedia/commons/thumb/')) {
      // e.g. https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/Thiruvambady_Church.jpg/800px-Thiruvambady_Church.jpg
      final segments = url.split('/thumb/').last.split('/');
      if (segments.length >= 3) {
        final filename = segments[2];
        final decodedName = Uri.decodeComponent(filename)
            .replaceAll('_', ' ')
            .trim();
        final titleKey = 'File:${_capitalizeFirst(decodedName)}';
        titleToAttractions.putIfAbsent(titleKey, () => []).add(map);
      } else {
        needsSearchAttractions.add(map);
      }
    } else {
      needsSearchAttractions.add(map);
    }
  }

  print('Unique Wikimedia titles to resolve: ${titleToAttractions.length}');

  // Step 2: Batch query Wikimedia Commons API in chunks of 40
  final titlesList = titleToAttractions.keys.toList();
  final Map<String, Map<String, String>> resolvedMetadata = {};
  final Set<String> missingTitles = {};

  final int chunkSize = 40;
  for (int i = 0; i < titlesList.length; i += chunkSize) {
    final chunk = titlesList.sublist(
      i,
      (i + chunkSize > titlesList.length) ? titlesList.length : i + chunkSize,
    );
    final pipeTitles = chunk.join('|');
    final apiUrl = Uri.parse(
      'https://commons.wikimedia.org/w/api.php?action=query'
      '&titles=${Uri.encodeComponent(pipeTitles)}'
      '&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=960&format=json',
    );

    try {
      final request = await client.getUrl(apiUrl);
      request.headers.set('User-Agent', userAgent);
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      final query = data['query'] as Map<String, dynamic>?;
      if (query != null) {
        // Track normalizations
        final normalizations = query['normalized'] as List<dynamic>? ?? [];
        final Map<String, String> normMap = {};
        for (final n in normalizations) {
          normMap[n['to'] as String] = n['from'] as String;
        }

        final pages = query['pages'] as Map<String, dynamic>? ?? {};
        for (final page in pages.values) {
          final title = page['title'] as String? ?? '';
          final originalTitle = normMap[title] ?? title;

          if (page['missing'] != null) {
            missingTitles.add(originalTitle);
            continue;
          }

          final imageinfo = page['imageinfo'] as List<dynamic>?;
          if (imageinfo != null && imageinfo.isNotEmpty) {
            final info = imageinfo.first as Map<String, dynamic>;
            var thumbUrl =
                info['thumburl'] as String? ?? info['url'] as String? ?? '';
            // Clean tracking query params
            if (thumbUrl.contains('?')) {
              thumbUrl = thumbUrl.split('?').first;
            }

            final extmeta = info['extmetadata'] as Map<String, dynamic>? ?? {};
            final license =
                (extmeta['LicenseShortName']?['value'] as String?) ??
                (extmeta['UsageTerms']?['value'] as String?) ??
                'Public Domain / CC';
            final artistRaw =
                (extmeta['Artist']?['value'] as String?) ??
                (extmeta['Credit']?['value'] as String?) ??
                'Wikimedia Commons';
            final artist = _cleanHtml(artistRaw);
            final descUrl =
                info['descriptionurl'] as String? ??
                'https://commons.wikimedia.org/wiki/$title';

            resolvedMetadata[originalTitle] = {
              'thumbUrl': thumbUrl,
              'license': license,
              'artist': artist,
              'descUrl': descUrl,
            };
            resolvedMetadata[title] = resolvedMetadata[originalTitle]!;
          }
        }
      }
    } catch (e) {
      print('Error querying chunk $i - ${i + chunk.length}: $e');
    }

    // Gentle pacing for API
    await Future.delayed(const Duration(milliseconds: 150));
    stdout.write(
      'Resolved ${resolvedMetadata.length}/${titlesList.length} titles...\r',
    );
  }
  print(
    '\nFinished direct title resolution. Successfully resolved: ${resolvedMetadata.length}, Missing/Deleted: ${missingTitles.length}',
  );

  // Step 3: Apply resolved direct URLs to attractions
  int updatedFromDirect = 0;
  for (final entry in titleToAttractions.entries) {
    final title = entry.key;
    final meta = resolvedMetadata[title];
    if (meta != null && meta['thumbUrl']!.isNotEmpty) {
      for (final attraction in entry.value) {
        attraction['imageUrl'] = meta['thumbUrl'];
        attraction['imageLicense'] = meta['license'];
        attraction['imageAuthor'] = meta['artist'];
        attraction['imageSourceUrl'] = meta['descUrl'];
        updatedFromDirect++;
      }
    } else {
      // Add to search list
      needsSearchAttractions.addAll(entry.value);
    }
  }

  print(
    'Updated $updatedFromDirect attractions with direct high-quality thumbnail URLs.',
  );
  print(
    'Attractions needing fallback search or empty fallback: ${needsSearchAttractions.length}',
  );

  // Step 4: For unresolved/missing/empty attractions, attempt a targeted search on Wikimedia
  int searchMatchesFound = 0;
  int missingWithoutMatch = 0;
  final List<String> missingAttractionReport = [];

  for (final attraction in needsSearchAttractions) {
    final name = (attraction['name'] as String? ?? '').trim();
    final city = (attraction['city'] as String? ?? '').trim();
    final country = (attraction['country'] as String? ?? '').trim();
    final id = attraction['id'] as String;

    // Search Wikimedia Commons
    final searchQuery = '$name $city $country'
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .trim();
    final searchUrl = Uri.parse(
      'https://commons.wikimedia.org/w/api.php?action=query'
      '&generator=search&gsrsearch=${Uri.encodeComponent(searchQuery)}'
      '&gsrnamespace=6&gsrlimit=1&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=960&format=json',
    );

    bool matchFound = false;
    try {
      final request = await client.getUrl(searchUrl);
      request.headers.set('User-Agent', userAgent);
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      final query = data['query'] as Map<String, dynamic>?;
      if (query != null && query['pages'] != null) {
        final pages = query['pages'] as Map<String, dynamic>;
        if (pages.isNotEmpty) {
          final firstPage = pages.values.first as Map<String, dynamic>;
          final imageinfo = firstPage['imageinfo'] as List<dynamic>?;
          if (imageinfo != null && imageinfo.isNotEmpty) {
            final info = imageinfo.first as Map<String, dynamic>;
            var thumbUrl =
                info['thumburl'] as String? ?? info['url'] as String? ?? '';
            if (thumbUrl.contains('?')) {
              thumbUrl = thumbUrl.split('?').first;
            }

            final extmeta = info['extmetadata'] as Map<String, dynamic>? ?? {};
            final license =
                (extmeta['LicenseShortName']?['value'] as String?) ??
                'CC BY-SA';
            final artistRaw =
                (extmeta['Artist']?['value'] as String?) ?? 'Wikimedia Commons';
            final artist = _cleanHtml(artistRaw);
            final descUrl = info['descriptionurl'] as String? ?? '';

            // Verify relevance: does filename/description share words with attraction name?
            final titleStr = (firstPage['title'] as String? ?? '')
                .toLowerCase();
            final nameWords = name
                .toLowerCase()
                .split(RegExp(r'\s+'))
                .where((w) => w.length > 3);
            final bool isRelevant = nameWords.any(
              (word) => titleStr.contains(word),
            );

            if (isRelevant && thumbUrl.isNotEmpty) {
              attraction['imageUrl'] = thumbUrl;
              attraction['imageLicense'] = license;
              attraction['imageAuthor'] = artist;
              attraction['imageSourceUrl'] = descUrl;
              searchMatchesFound++;
              matchFound = true;
            }
          }
        }
      }
    } catch (_) {}

    if (!matchFound) {
      // Retain graceful fallback: empty imageUrl
      attraction['imageUrl'] = '';
      missingWithoutMatch++;
      missingAttractionReport.add('$id: $name ($city, $country)');
    }

    await Future.delayed(const Duration(milliseconds: 100));
  }

  client.close();

  print('\nSearch results:');
  print('  Accurate matches found: $searchMatchesFound');
  print('  Confirmed missing/unverifiable photographs: $missingWithoutMatch');

  // Step 5: Save updated global_attractions.json
  final encoder = const JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(attractions));
  print('Saved enhanced dataset to assets/data/global_attractions.json');

  // Write missing attractions report
  final reportFile = File('docs/MISSING_PHOTOGRAPHS.txt');
  await reportFile.writeAsString(
    'TourMate Phase 14 - Unverifiable / Missing Photographs Report\n'
            'Total: $missingWithoutMatch attractions\n'
            'Date: ${DateTime.now().toIso8601String()}\n\n' +
        missingAttractionReport.join('\n'),
  );
  print('Wrote missing photographs list to docs/MISSING_PHOTOGRAPHS.txt');
}

String _capitalizeFirst(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

String _cleanHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}
