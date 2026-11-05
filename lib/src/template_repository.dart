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
  Future<int> publish(Design design, {required String authorName, required Uint8List poster});

  void close() {}
}

class SupabaseTemplateRepository implements TemplateRepository {
  SupabaseTemplateRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<int> publish(Design design, {required String authorName, required Uint8List poster}) async {
    final imagePath = _imagePath(design);
    await _uploadPoster(imagePath, poster);
    final body = <String, Object?>{
      'name': design.name.trim(),
      'category_id': _categoryId(design.category),
      'description': design.description,
      'bg_from': _hex(design.bg1),
      'bg_to': _hex(design.bg2),
      'background_image_path': imagePath,
      'author_name': authorName.trim().isEmpty ? 'Creator' : authorName.trim(),
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
      await _send(
        'POST',
        'template_elements',
        [
          for (var index = 0; index < design.elements.length; index++)
            _element(id, design.elements[index], index),
        ],
        expectRows: false,
      );
    }
    return id;
  }

  Map<String, Object?> _element(int templateId, DesignElement element, int index) {
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
      'z_index': index,
      'font_family': element.font,
      'font_size': element.size.round(),
      'text_align': element.align.name,
      'is_photo': element.photo,
      'text_content': element.text,
    };
  }

  String _imagePath(Design design) {
    final slug = design.name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    final base = slug.isEmpty ? 'design' : slug;
    return 'templates/$base-${design.id}.png';
  }

  Future<void> _uploadPoster(String objectPath, Uint8List bytes) async {
    final uri = Uri.parse('${SupabaseConfig.url}/storage/v1/object/app-assets/$objectPath');
    final response = await _client.post(
      uri,
      headers: {
        'apikey': SupabaseConfig.publishableKey,
        'Authorization': 'Bearer ${SupabaseConfig.publishableKey}',
        'Content-Type': 'image/png',
        'x-upsert': 'true',
      },
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('Publish storage error ${response.statusCode}: ${response.body}');
      throw TemplatePublishException(_storageMessage(response));
    }
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
    bool expectRows = true,
  }) async {
    final uri = Uri.parse('${SupabaseConfig.url}/rest/v1/$path');
    final headers = {
      'apikey': SupabaseConfig.publishableKey,
      'Authorization': 'Bearer ${SupabaseConfig.publishableKey}',
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
    final encoded = body == null ? null : jsonEncode(body);
    final http.Response response;
    switch (method) {
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
      debugPrint('Publish error $method $path ${response.statusCode}: ${response.body}');
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
