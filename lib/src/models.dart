import 'dart:typed_data';

import 'package:flutter/material.dart';

enum ElementKind { text, image, shape }

enum PosterAlign { left, center, right }

enum StudioView { create, mine, published }

enum AuthTab { login, register }

enum DesignFilter { all, published, drafts }

enum EditorTool { designs, text, images, elements, background }

class DesignStatus {
  static const draft = 'Draft';
  static const published = 'Published';
}

class StudioUser {
  const StudioUser({required this.name, required this.email});

  final String name;
  final String email;
}

class DesignElement {
  const DesignElement({
    required this.kind,
    required this.x,
    required this.y,
    required this.w,
    this.h = 30,
    this.rotation = 0,
    this.text = '',
    this.font = 'Poppins',
    this.size = 40,
    this.color = const Color(0xFFFFFFFF),
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.align = PosterAlign.center,
    this.emoji = '',
    this.imageBytes,
    this.photo = true,
    this.fill = const Color(0xFFFDE68A),
    this.radius = '0',
  });

  const DesignElement.text({
    required this.x,
    required this.y,
    required this.w,
    required this.text,
    required this.font,
    required this.size,
    required this.color,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.align = PosterAlign.center,
    this.rotation = 0,
  })  : kind = ElementKind.text,
        h = 0,
        emoji = '',
        imageBytes = null,
        photo = false,
        fill = const Color(0x00000000),
        radius = '0';

  const DesignElement.image({
    required this.x,
    required this.y,
    required this.w,
    required this.emoji,
    this.imageBytes,
    this.photo = true,
    this.rotation = 0,
  })  : kind = ElementKind.image,
        h = 0,
        text = '',
        font = 'Poppins',
        size = 40,
        color = const Color(0xFFFFFFFF),
        bold = false,
        italic = false,
        underline = false,
        align = PosterAlign.center,
        fill = const Color(0x00000000),
        radius = '0';

  const DesignElement.shape({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.fill,
    required this.radius,
    this.rotation = 0,
  })  : kind = ElementKind.shape,
        text = '',
        font = 'Poppins',
        size = 40,
        color = const Color(0xFFFFFFFF),
        bold = false,
        italic = false,
        underline = false,
        align = PosterAlign.center,
        emoji = '',
        imageBytes = null,
        photo = false;

  final ElementKind kind;
  final double x;
  final double y;
  final double w;
  final double h;
  final double rotation;
  final String text;
  final String font;
  final double size;
  final Color color;
  final bool bold;
  final bool italic;
  final bool underline;
  final PosterAlign align;
  final String emoji;
  final Uint8List? imageBytes;
  final bool photo;
  final Color fill;
  final String radius;

  TextAlign get textAlign {
    switch (align) {
      case PosterAlign.left:
        return TextAlign.left;
      case PosterAlign.right:
        return TextAlign.right;
      case PosterAlign.center:
        return TextAlign.center;
    }
  }

  static const _unset = Object();

  DesignElement copyWith({
    double? x,
    double? y,
    double? w,
    double? h,
    double? rotation,
    String? text,
    String? font,
    double? size,
    Color? color,
    bool? bold,
    bool? italic,
    bool? underline,
    PosterAlign? align,
    String? emoji,
    Object? imageBytes = _unset,
    bool? photo,
    Color? fill,
    String? radius,
  }) {
    return DesignElement(
      kind: kind,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      rotation: rotation ?? this.rotation,
      text: text ?? this.text,
      font: font ?? this.font,
      size: size ?? this.size,
      color: color ?? this.color,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      align: align ?? this.align,
      emoji: emoji ?? this.emoji,
      imageBytes: identical(imageBytes, _unset) ? this.imageBytes : imageBytes as Uint8List?,
      photo: photo ?? this.photo,
      fill: fill ?? this.fill,
      radius: radius ?? this.radius,
    );
  }
}

class Design {
  const Design({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.bg1,
    required this.bg2,
    required this.elements,
    this.backgroundImage,
    this.status = '',
    this.savedAt = '',
    this.remoteId,
  });

  final int id;
  final String name;
  final String category;
  final String description;
  final Color bg1;
  final Color bg2;
  final Uint8List? backgroundImage;
  final List<DesignElement> elements;
  final String status;
  final String savedAt;
  final int? remoteId;

  List<int> get textIndexes => [
        for (var i = 0; i < elements.length; i++)
          if (elements[i].kind == ElementKind.text) i,
      ];

  int? get firstImage {
    for (var i = 0; i < elements.length; i++) {
      if (elements[i].kind == ElementKind.image) return i;
    }
    return null;
  }

  static const _unset = Object();

  Design copyWith({
    int? id,
    String? name,
    String? category,
    String? description,
    Color? bg1,
    Color? bg2,
    Object? backgroundImage = _unset,
    List<DesignElement>? elements,
    String? status,
    String? savedAt,
    int? remoteId,
    bool clearRemote = false,
  }) {
    return Design(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      bg1: bg1 ?? this.bg1,
      bg2: bg2 ?? this.bg2,
      backgroundImage: identical(backgroundImage, _unset) ? this.backgroundImage : backgroundImage as Uint8List?,
      elements: elements ?? this.elements,
      status: status ?? this.status,
      savedAt: savedAt ?? this.savedAt,
      remoteId: clearRemote ? null : (remoteId ?? this.remoteId),
    );
  }
}

class EditorSnapshot {
  const EditorSnapshot({
    required this.bg1,
    required this.bg2,
    required this.backgroundImage,
    required this.elements,
  });

  final Color bg1;
  final Color bg2;
  final Uint8List? backgroundImage;
  final List<DesignElement> elements;
}
