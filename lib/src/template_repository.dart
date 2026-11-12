import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mideas_touch_creator/src/catalog.dart';
import 'package:mideas_touch_creator/src/models.dart';
import 'package:mideas_touch_creator/src/supabase_config.dart';

class TemplatePublishException implements Exception {
  TemplatePublishException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class TemplateRepository {
  void setAuth({String? accessToken, String? userId, String? email});

  Future<int> publish(Design design, {required String authorName, Uint8List? poster});

  Future<int> saveDraft(Design design, {required String authorName, Uint8List? poster});

  Future<List<Design>> fetchDrafts();

  /// Published templates from the last [within] window (default 1 day).
  Future<List<Design>> fetchPublished({Duration within = const Duration(days: 1)});

  Future<void> deleteDraft(int draftId);

  void close() {}
}

class SupabaseTemplateRepository implements TemplateRepository {
  SupabaseTemplateRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _accessToken;
  String? _userId;
  String? _email;

  @override
  void setAuth({String? accessToken, String? userId, String? email}) {
    _accessToken = accessToken;
    _userId = userId;
    _email = email?.trim().toLowerCase();
  }

  @override
  Future<int> publish(Design design, {required String authorName, Uint8List? poster}) async {
    final userId = _requireUserId();
    final email = _requireEmail();
    if (poster == null || poster.isEmpty) {
      throw TemplatePublishException(
        'Could not create the full design image. Try publishing again.',
      );
    }
    final imagePath = _imagePath(design);
    await _uploadPoster(imagePath, poster);
    final body = <String, Object?>{
      'name': design.name.trim(),
      'category_id': _categoryId(design.category),
      'description': design.description,
      'bg_from': _hex(design.bg1),
      'bg_to': _hex(design.bg2),
      // Single flattened template image (bg + main + text baked in).
      'background_image_path': imagePath,
      'author_name': authorName.trim().isEmpty ? 'Creator' : authorName.trim(),
      'published_by': email,
      'creator_id': userId,
      'is_premium': false,
      'price_inr': 0,
      'status': 'published',
      'sort_order': 0,
    };

    final int id;
    if (design.remoteId == null) {
      final rows = await _send('POST', 'templates', body);
      final rawId = rows.first['id'];
      if (rawId is! num) {
        throw TemplatePublishException('The library did not return a design id');
      }
      id = rawId.toInt();
    } else {
      id = design.remoteId!;
      await _send('PATCH', 'templates?id=eq.$id', body, expectRows: false);
      await _send('DELETE', 'template_elements?template_id=eq.$id', null, expectRows: false);
    }

    if (design.elements.isNotEmpty) {
      final payload = <Map<String, Object?>>[];
      for (var index = 0; index < design.elements.length; index++) {
        payload.add(await _elementPayload(id, design.elements[index], index));
      }
      await _send('POST', 'template_elements', payload, expectRows: false);
    }
    return id;
  }

  @override
  Future<int> saveDraft(Design design, {required String authorName, Uint8List? poster}) async {
    final email = _requireEmail();
    String? imagePath;
    if (poster != null && poster.isNotEmpty) {
      imagePath = _draftImagePath(design);
      await _uploadPoster(imagePath, poster);
    }
    final body = <String, Object?>{
      'name': design.name.trim().isEmpty ? 'Untitled design' : design.name.trim(),
      'category': design.category,
      'description': design.description,
      'bg_from': _hex(design.bg1),
      'bg_to': _hex(design.bg2),
      'background_image': design.backgroundImage == null ? null : base64Encode(design.backgroundImage!),
      if (imagePath != null) 'preview_image_path': imagePath,
      'author_name': authorName.trim().isEmpty ? 'Creator' : authorName.trim(),
      'published_by': email,
      'status': 'draft',
      'elements': [for (final element in design.elements) _draftElement(element)],
      // saved_templates.updated_at is timestamptz — must be ISO-8601, not IST display text.
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (design.draftId == null) {
      final rows = await _send('POST', 'saved_templates', body);
      final rawId = rows.first['id'];
      if (rawId is! num) {
        throw TemplatePublishException('The library did not return a draft id');
      }
      return rawId.toInt();
    }
    await _send('PATCH', 'saved_templates?id=eq.${design.draftId}', body, expectRows: false);
    return design.draftId!;
  }

  @override
  Future<List<Design>> fetchDrafts() async {
    final email = _requireEmail();
    final rows = await _send(
      'GET',
      'saved_templates',
      null,
      query: {
        'status': 'eq.draft',
        'published_by': 'eq.$email',
        'order': 'updated_at.desc.nullslast,id.desc',
      },
    );
    return Future.wait([for (final row in rows) _hydrateDraft(row)]);
  }

  Future<Design> _hydrateDraft(Map<String, dynamic> row) async {
    final design = _draftFromRow(row);
    final previewPath = row['preview_image_path'] as String?;
    if (previewPath == null || previewPath.isEmpty) return design;
    final preview = await _downloadObject(previewPath);
    if (preview == null || preview.isEmpty) return design;
    return design.copyWith(previewImage: preview);
  }

  @override
  Future<List<Design>> fetchPublished({Duration within = const Duration(days: 1)}) async {
    final email = _requireEmail();
    final since = _formatIstDateTime(DateTime.now().toUtc().subtract(within));
    final rows = await _send(
      'GET',
      'templates',
      null,
      query: {
        'status': 'eq.published',
        'published_by': 'eq.$email',
        'created_at': 'gte.$since',
        'order': 'created_at.desc.nullslast,id.desc',
      },
    );
    if (rows.isEmpty) return const [];

    final ids = [for (final row in rows) (row['id'] as num).toInt()];
    final elementRows = await _send(
      'GET',
      'template_elements?template_id=in.(${ids.join(',')})&order=z_index.asc',
      null,
    );
    final byTemplate = <int, List<Map<String, dynamic>>>{};
    for (final row in elementRows) {
      final templateId = (row['template_id'] as num?)?.toInt();
      if (templateId == null) continue;
      byTemplate.putIfAbsent(templateId, () => []).add(row);
    }

    return Future.wait([
      for (final row in rows)
        _hydratePublished(
          row,
          byTemplate[(row['id'] as num).toInt()] ?? const [],
        ),
    ]);
  }

  Future<Design> _hydratePublished(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> elementRows,
  ) async {
    final elements = [
      for (final item in elementRows) await _hydratePublishedElement(item),
    ];

    // Always load the flattened full-template image for My designs list.
    Uint8List? previewImage;
    final previewPath = row['background_image_path'] as String?;
    if (previewPath != null && previewPath.isNotEmpty) {
      previewImage = await _downloadObject(previewPath);
    }

    return _publishedFromRow(row, elements, previewImage: previewImage);
  }

  Future<DesignElement> _hydratePublishedElement(Map<String, dynamic> json) async {
    final element = _publishedElementFrom(json);
    final path = json['image_path'] as String?;
    if (path == null || path.isEmpty) return element;
    final bytes = await _downloadObject(path);
    if (bytes == null || bytes.isEmpty) return element;
    return element.copyWith(imageBytes: bytes);
  }

  @override
  Future<void> deleteDraft(int draftId) async {
    final email = _requireEmail();
    await _send(
      'DELETE',
      'saved_templates?id=eq.$draftId&published_by=eq.$email',
      null,
      expectRows: false,
    );
  }

  String _requireUserId() {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      throw TemplatePublishException('Please login to continue');
    }
    return userId;
  }

  String _requireEmail() {
    final email = _email;
    if (email == null || email.isEmpty) {
      throw TemplatePublishException('Please login to continue');
    }
    return email;
  }

  String _bearerToken() =>
      (_accessToken != null && _accessToken!.isNotEmpty) ? _accessToken! : SupabaseConfig.publishableKey;

  Design _publishedFromRow(
    Map<String, dynamic> row,
    List<DesignElement> elements, {
    Uint8List? previewImage,
  }) {
    final id = (row['id'] as num).toInt();
    final categoryId = (row['category_id'] as num?)?.toInt() ?? 12;
    final categoryIndex = (categoryId - 1).clamp(0, Catalog.categories.length - 1);
    return Design(
      id: id,
      remoteId: id,
      name: row['name'] as String? ?? 'Untitled design',
      category: Catalog.categories[categoryIndex],
      description: row['description'] as String? ?? '',
      bg1: _color(row['bg_from'], Catalog.backgrounds.first.$1),
      bg2: _color(row['bg_to'], Catalog.backgrounds.first.$2),
      previewImage: previewImage,
      elements: elements,
      status: DesignStatus.published,
      savedAt: _formatSavedAt(row['created_at'] ?? row['updated_at']),
      updatedAt: _parseDateTime(row['created_at'] ?? row['updated_at']),
    );
  }

  DesignElement _publishedElementFrom(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? 'text';
    final kind = ElementKind.values.firstWhere((value) => value.name == kindName, orElse: () => ElementKind.text);
    final alignName = json['text_align'] as String? ?? 'center';
    final align = PosterAlign.values.firstWhere((value) => value.name == alignName, orElse: () => PosterAlign.center);
    return DesignElement(
      kind: kind,
      x: _number(json['x']),
      y: _number(json['y']),
      w: _number(json['w'], 30),
      h: _number(json['h']),
      rotation: _number(json['rotation']),
      text: json['text_content'] as String? ?? '',
      font: json['font_family'] as String? ?? 'Poppins',
      size: _number(json['font_size'], 40),
      color: _color(json['color'], const Color(0xFFFFFFFF)),
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      underline: json['underline'] == true,
      align: align,
      emoji: json['emoji'] as String? ?? '',
      photo: json['is_photo'] == true,
      fill: _color(json['fill'], const Color(0x00000000)),
      radius: _radiusFromShapeStyle(json['shape_style'] as String?),
    );
  }

  Design _draftFromRow(Map<String, dynamic> row) {
    final id = (row['id'] as num).toInt();
    final elements = row['elements'];
    return Design(
      id: id,
      draftId: id,
      name: row['name'] as String? ?? 'Untitled design',
      category: row['category'] as String? ?? Catalog.categories.first,
      description: row['description'] as String? ?? '',
      bg1: _color(row['bg_from'], Catalog.backgrounds.first.$1),
      bg2: _color(row['bg_to'], Catalog.backgrounds.first.$2),
      backgroundImage: row['background_image'] is String ? base64Decode(row['background_image'] as String) : null,
      elements: elements is List
          ? [for (final item in elements) if (item is Map) _draftElementFrom(Map<String, dynamic>.from(item))]
          : const [],
      status: DesignStatus.draft,
      savedAt: _formatSavedAt(row['updated_at'] ?? row['created_at']),
      updatedAt: _parseDateTime(row['updated_at'] ?? row['created_at']),
    );
  }

  Map<String, Object?> _draftElement(DesignElement element) {
    return {
      'kind': element.kind.name,
      'x': element.x,
      'y': element.y,
      'w': element.w,
      'h': element.h,
      'rotation': element.rotation,
      'text': element.text,
      'font': element.font,
      'size': element.size,
      'color': _hex(element.color),
      'bold': element.bold,
      'italic': element.italic,
      'underline': element.underline,
      'align': element.align.name,
      'emoji': element.emoji,
      'image': element.imageBytes == null ? null : base64Encode(element.imageBytes!),
      'photo': element.photo,
      'fill': _hex(element.fill, alpha: true),
      'radius': element.radius,
    };
  }

  DesignElement _draftElementFrom(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? 'text';
    final kind = ElementKind.values.firstWhere((value) => value.name == kindName, orElse: () => ElementKind.text);
    final alignName = json['align'] as String? ?? 'center';
    final align = PosterAlign.values.firstWhere((value) => value.name == alignName, orElse: () => PosterAlign.center);
    return DesignElement(
      kind: kind,
      x: _number(json['x']),
      y: _number(json['y']),
      w: _number(json['w'], 30),
      h: _number(json['h']),
      rotation: _number(json['rotation']),
      text: json['text'] as String? ?? '',
      font: json['font'] as String? ?? 'Poppins',
      size: _number(json['size'], 40),
      color: _color(json['color'], const Color(0xFFFFFFFF)),
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      underline: json['underline'] == true,
      align: align,
      emoji: json['emoji'] as String? ?? '',
      imageBytes: json['image'] is String ? base64Decode(json['image'] as String) : null,
      photo: json['photo'] == true,
      fill: _color(json['fill'], const Color(0x00000000)),
      radius: json['radius'] as String? ?? '0',
    );
  }

  double _number(Object? value, [double fallback = 0]) => value is num ? value.toDouble() : fallback;

  String _formatSavedAt(Object? value) {
    if (value is String && _istPattern.hasMatch(value)) return value;
    final date = _parseDateTime(value);
    if (date == null) return '';
    return _formatIstDateTime(date);
  }

  DateTime? _parseDateTime(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final match = _istPattern.firstMatch(value);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
        int.parse(match.group(6)!),
      );
    }
    return DateTime.tryParse(value);
  }

  static final _istPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2})-(\d{2})-(\d{2})$');

  /// Indian Standard Time: `yyyy-mm-dd HH-mm-ss`
  String _formatIstDateTime(DateTime date) {
    final ist = date.toUtc().add(const Duration(hours: 5, minutes: 30));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${ist.year}-${two(ist.month)}-${two(ist.day)} ${two(ist.hour)}-${two(ist.minute)}-${two(ist.second)}';
  }

  String _draftImagePath(Design design) {
    final slug = design.name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    final base = slug.isEmpty ? 'draft' : slug;
    // Timestamp prefix so Storage Files name-sort matches upload time.
    return 'templates/${_uploadStamp()}-draft-$base.png';
  }

  Future<Map<String, Object?>> _elementPayload(int templateId, DesignElement element, int index) async {
    String? imagePath;
    final bytes = element.imageBytes;
    if (element.kind == ElementKind.image && bytes != null && bytes.isNotEmpty) {
      imagePath = _elementImagePath(templateId, index, bytes);
      await _uploadPoster(imagePath, bytes);
    }
    return _element(templateId, element, index, imagePath: imagePath);
  }

  Map<String, Object?> _element(
    int templateId,
    DesignElement element,
    int index, {
    String? imagePath,
  }) {
    return {
      'template_id': templateId,
      'kind': element.kind.name,
      'x': element.x,
      'y': element.y,
      'w': element.w,
      'h': element.h,
      'rotation': element.rotation,
      'color': _hex(element.color),
      'bold': element.bold,
      'italic': element.italic,
      'underline': element.underline,
      'emoji': element.emoji,
      'fill': _hex(element.fill, alpha: true),
      'shape_style': _shapeStyleForDb(element),
      'z_index': index,
      'font_family': element.font,
      'font_size': element.size.round(),
      'text_align': element.align.name,
      'is_photo': element.photo,
      'text_content': element.text,
      'image_path': imagePath,
    };
  }

  /// Supabase allows only null / `rect` / `pill` on template_elements.shape_style.
  String? _shapeStyleForDb(DesignElement element) {
    if (element.kind != ElementKind.shape) return null;
    switch (element.radius) {
      case '50%':
      case '999px':
        return 'pill';
      default:
        return 'rect';
    }
  }

  String _radiusFromShapeStyle(String? style) {
    switch (style) {
      case 'pill':
        return '999px';
      case 'rect':
      default:
        return '0';
    }
  }

  String _imagePath(Design design) {
    final slug = design.name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    final base = slug.isEmpty ? 'design' : slug;
    // Timestamp prefix so Storage Files name-sort matches upload time.
    return 'templates/${_uploadStamp()}-$base.png';
  }

  String _elementImagePath(int templateId, int index, Uint8List bytes) {
    final ext = _imageExtension(bytes);
    return 'templates/elements/$templateId/${_uploadStamp()}-$index.$ext';
  }

  /// Lexicographically sortable UTC stamp (ascending name == ascending upload time).
  String _uploadStamp() {
    final now = DateTime.now().toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}T${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  String _imageExtension(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpg';
    }
    return 'png';
  }

  String _imageContentType(Uint8List bytes) {
    return _imageExtension(bytes) == 'jpg' ? 'image/jpeg' : 'image/png';
  }

  Future<void> _uploadPoster(String objectPath, Uint8List bytes) async {
    final uri = Uri.parse('${SupabaseConfig.url}/storage/v1/object/app-assets/$objectPath');
    final response = await _client.post(
      uri,
      headers: {
        'apikey': SupabaseConfig.publishableKey,
        'Authorization': 'Bearer ${_bearerToken()}',
        'Content-Type': _imageContentType(bytes),
        'x-upsert': 'true',
      },
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('Publish storage error ${response.statusCode}: ${response.body}');
      throw TemplatePublishException(_storageMessage(response));
    }
  }

  Future<Uint8List?> _downloadObject(String objectPath) async {
    final uri = Uri.parse('${SupabaseConfig.url}/storage/v1/object/app-assets/$objectPath');
    final response = await _client.get(
      uri,
      headers: {
        'apikey': SupabaseConfig.publishableKey,
        'Authorization': 'Bearer ${_bearerToken()}',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('Storage download error ${response.statusCode}: $objectPath');
      return null;
    }
    return response.bodyBytes;
  }

  String _storageMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && (decoded['statusCode'] == '403' || decoded['code'] == 'AccessDenied')) {
        return 'The design image was blocked by Storage. Allow uploads to the app-assets bucket, then publish again.';
      }
      final message = decoded is Map ? decoded['message'] : null;
      if (message is String && message.isNotEmpty && message.length < 160) return message;
    } catch (_) {}
    return 'Could not save the design image';
  }

  int _categoryId(String name) {
    final index = Catalog.categories.indexOf(name);
    return index < 0 ? 12 : index + 1;
  }

  Future<List<Map<String, dynamic>>> _send(
    String method,
    String path,
    Object? body, {
    Map<String, String>? query,
    bool expectRows = true,
  }) async {
    final raw = Uri.parse('${SupabaseConfig.url}/rest/v1/$path');
    final uri = (query == null || query.isEmpty)
        ? raw
        : raw.replace(queryParameters: {...raw.queryParameters, ...query});
    final headers = <String, String>{
      'apikey': SupabaseConfig.publishableKey,
      'Authorization': 'Bearer ${_bearerToken()}',
      'Prefer': 'return=representation',
      if (body != null) 'Content-Type': 'application/json',
    };
    final encoded = body == null ? null : jsonEncode(body);
    final http.Response response;
    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers);
      case 'POST':
        response = await _client.post(uri, headers: headers, body: encoded);
      case 'PATCH':
        response = await _client.patch(uri, headers: headers, body: encoded);
      case 'DELETE':
        response = await _client.delete(uri, headers: headers);
      default:
        throw TemplatePublishException('Could not publish the design');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('Publish error $method $uri ${response.statusCode}: ${response.body}');
      throw TemplatePublishException(_message(response));
    }
    if (!expectRows || response.body.isEmpty) return const [];
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw TemplatePublishException('The library returned an unexpected response');
    }
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  String _message(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['code'] == '42501') {
        return 'The library is not accepting new designs yet. Allow inserts on templates and template elements, then publish again.';
      }
      final message = decoded is Map ? decoded['message'] : null;
      if (message is String && message.isNotEmpty && message.length < 160) return message;
    } catch (_) {}
    return 'Could not publish the design';
  }

  @override
  void close() => _client.close();
}

String _hex(Color color, {bool alpha = false}) {
  final red = color.red.toRadixString(16).padLeft(2, '0');
  final green = color.green.toRadixString(16).padLeft(2, '0');
  final blue = color.blue.toRadixString(16).padLeft(2, '0');
  if (!alpha || color.alpha == 255) return '#$red$green$blue';
  final opacity = color.alpha.toRadixString(16).padLeft(2, '0');
  return '#$red$green$blue$opacity';
}

Color _color(Object? value, Color fallback) {
  if (value is! String) return fallback;
  var hex = value.trim().replaceFirst('#', '');
  if (hex.length == 6) return _parseColor('FF$hex') ?? fallback;
  if (hex.length == 8) return _parseColor('${hex.substring(6)}${hex.substring(0, 6)}') ?? fallback;
  return fallback;
}

Color? _parseColor(String argb) {
  final value = int.tryParse(argb, radix: 16);
  return value == null ? null : Color(value);
}
