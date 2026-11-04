import 'package:flutter/material.dart';
import 'package:mideas_touch_creator/src/models.dart';

class Sticker {
  const Sticker(this.emoji, this.keywords);

  final String emoji;
  final String keywords;
}

class Catalog {
  static const categories = [
    'Festivals',
    'Offers',
    'Promotions',
    'Business',
    'Events',
    'Food',
    'Retail',
    'Announcements',
    'Greetings',
    'Social Media',
    'Seasonal',
    'Other',
  ];

  static const fonts = [
    'Poppins',
    'Playfair Display',
    'Pacifico',
    'Bebas Neue',
    'Noto Sans Devanagari',
    'Hind',
    'Baloo 2',
  ];

  static const stickers = [
    Sticker('🪔', 'diya diwali lamp'),
    Sticker('🍔', 'burger food'),
    Sticker('🎂', 'cake birthday'),
    Sticker('🛍️', 'shopping sale offer'),
    Sticker('🎉', 'party event'),
    Sticker('☀️', 'summer sun'),
    Sticker('👟', 'shoes retail'),
    Sticker('🍕', 'pizza restaurant food'),
    Sticker('🎁', 'gift offer'),
    Sticker('🌸', 'flower spring'),
    Sticker('☕', 'coffee cafe'),
    Sticker('🚀', 'launch new'),
  ];

  static const backgrounds = <(Color, Color)>[
    (Color(0xFF8A6A00), Color(0xFFEFBF05)),
    (Color(0xFF7C2D12), Color(0xFFF59E0B)),
    (Color(0xFF0E7490), Color(0xFFA78BFA)),
    (Color(0xFF111827), Color(0xFF6D28D9)),
    (Color(0xFF15803D), Color(0xFFFACC15)),
    (Color(0xFFBE185D), Color(0xFFFB923C)),
  ];

  static const tools = [
    (EditorTool.designs, '▦', 'Designs'),
    (EditorTool.text, 'T', 'Text'),
    (EditorTool.images, '🌄', 'Images'),
    (EditorTool.elements, '◆', 'Elements'),
    (EditorTool.background, '🎨', 'Background'),
  ];

  static String tagline(String language) {
    if (language == 'hi') {
      return 'क्रिएटर स्टूडियो · ऐसे डिज़ाइन बनाएं जो सबको पसंद आएं';
    }
    return 'Creator Studio · Create designs people love';
  }

  static final templates = <Design>[
    _template(
      id: 1,
      name: 'Diwali Sale',
      category: 'Festivals',
      description: 'Festive offer poster with a glowing diya.',
      c1: const Color(0xFF7C2D12),
      c2: const Color(0xFFF59E0B),
      emoji: '🪔',
      title: 'Diwali\nSale',
      subtitle: 'Up to 50% OFF',
      textColor: const Color(0xFFFFFFFF),
      font: 'Playfair Display',
    ),
    _template(
      id: 2,
      name: 'Weekend Offer',
      category: 'Offers',
      description: 'Bold weekend discount creative for shops.',
      c1: const Color(0xFF4C1D95),
      c2: const Color(0xFFEC4899),
      emoji: '🛍️',
      title: 'Weekend\nOffer',
      subtitle: 'Flat 30% on everything',
      textColor: const Color(0xFFFFFFFF),
      font: 'Bebas Neue',
    ),
    _template(
      id: 3,
      name: 'Birthday Bash',
      category: 'Greetings',
      description: 'A cheerful birthday invitation.',
      c1: const Color(0xFF0E7490),
      c2: const Color(0xFFA78BFA),
      emoji: '🎂',
      title: 'Happy\nBirthday',
      subtitle: 'Join the party at 7 PM',
      textColor: const Color(0xFFFFFFFF),
      font: 'Pacifico',
    ),
    _template(
      id: 4,
      name: 'Restaurant Special',
      category: 'Food',
      description: 'Daily special card for cafes and restaurants.',
      c1: const Color(0xFF991B1B),
      c2: const Color(0xFFF97316),
      emoji: '🍔',
      title: 'Chef’s\nSpecial',
      subtitle: 'Fresh and hot, every day',
      textColor: const Color(0xFFFFF7ED),
      font: 'Playfair Display',
    ),
    _template(
      id: 5,
      name: 'Independence Day',
      category: 'Festivals',
      description: 'Patriotic greeting in Hindi.',
      c1: const Color(0xFFEA580C),
      c2: const Color(0xFF15803D),
      emoji: '🇮🇳',
      title: 'स्वतंत्रता\nदिवस',
      subtitle: 'शुभकामनाएं',
      textColor: const Color(0xFFFFFFFF),
      font: 'Noto Sans Devanagari',
    ),
    _template(
      id: 6,
      name: 'Grand Opening',
      category: 'Events',
      description: 'Announce your new store opening.',
      c1: const Color(0xFF1E3A8A),
      c2: const Color(0xFF06B6D4),
      emoji: '🎉',
      title: 'Grand\nOpening',
      subtitle: 'This Saturday, 10 AM',
      textColor: const Color(0xFFFFFFFF),
      font: 'Bebas Neue',
    ),
    _template(
      id: 7,
      name: 'New Arrival',
      category: 'Retail',
      description: 'Launch card for new products.',
      c1: const Color(0xFF111827),
      c2: const Color(0xFF6D28D9),
      emoji: '👟',
      title: 'New\nArrival',
      subtitle: 'Now in stores',
      textColor: const Color(0xFFFFFFFF),
      font: 'Poppins',
    ),
    _template(
      id: 8,
      name: 'Summer Sale',
      category: 'Seasonal',
      description: 'Bright seasonal sale creative.',
      c1: const Color(0xFFF59E0B),
      c2: const Color(0xFFEF4444),
      emoji: '☀️',
      title: 'Summer\nSale',
      subtitle: 'Cool deals, hot prices',
      textColor: const Color(0xFFFFFFFF),
      font: 'Pacifico',
    ),
  ];

  static Design? byId(int id) {
    for (final template in templates) {
      if (template.id == id) return template;
    }
    return null;
  }
}

Design _template({
  required int id,
  required String name,
  required String category,
  required String description,
  required Color c1,
  required Color c2,
  required String emoji,
  required String title,
  required String subtitle,
  required Color textColor,
  required String font,
}) {
  return Design(
    id: id,
    name: name,
    category: category,
    description: description,
    bg1: c1,
    bg2: c2,
    elements: [
      DesignElement.text(
        x: 8,
        y: 9,
        w: 84,
        text: title,
        font: font,
        size: 44,
        color: textColor,
        bold: true,
      ),
      DesignElement.image(x: 29, y: 37, w: 42, emoji: emoji),
      const DesignElement.shape(
        x: 12,
        y: 77,
        w: 76,
        h: 12,
        fill: Color(0x47000000),
        radius: '999px',
      ),
      DesignElement.text(
        x: 12,
        y: 79.6,
        w: 76,
        text: subtitle,
        font: 'Poppins',
        size: 18,
        color: textColor,
      ),
    ],
  );
}
