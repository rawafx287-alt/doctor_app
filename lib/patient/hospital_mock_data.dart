/// Preview hospitals when Firestore `hospitals` is still empty.
/// Set to [false] once real documents exist so only live data shows.
const bool kShowMockHospitalsWhenEmpty = true;

/// `(id, data)` matches Firestore hospital document shape used by the UI.
final List<({String id, Map<String, dynamic> data})> kMockHospitalRows = [
  (
    id: 'mock_suli_general',
    data: <String, dynamic>{
      'sortOrder': 0,
      'name_ku': 'نەخۆشخانەی گشتی سلێمانی',
      'name_ar': 'المستشفى العام — السليمانية',
      'name_en': 'Sulaymaniyah General Hospital',
      'logoUrl':
          'https://images.unsplash.com/photo-1586773860418-d372422d8fce?auto=format&fit=crop&w=300&q=80',
      'description_ku':
          'نموونەیەکی کورت بۆ دیزاین: نەخۆشخانەیەکی گشتی لە سلێمانی.',
      'description_ar': 'معاينة تصميم: مستشفى عام نموذجي.',
      'description_en': 'Design preview: sample general hospital entry.',
    },
  ),
  (
    id: 'mock_hewler_medical',
    data: <String, dynamic>{
      'sortOrder': 1,
      'name_ku': 'نەخۆشخانەی پزیشکی هەولێر',
      'name_ar': 'المستشفى الطبي — أربيل',
      'name_en': 'Erbil Medical Center',
      'logoUrl':
          'https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?auto=format&fit=crop&w=300&q=80',
      'description_ku': 'نموونە: نەخۆشخانەی تایبەت بە پزیشکی ناوخۆ.',
      'description_en': 'Preview: urban medical center branding.',
    },
  ),
  (
    id: 'mock_duhok_children',
    data: <String, dynamic>{
      'sortOrder': 2,
      'name_ku': 'نەخۆشخانەی منداڵان — دهۆک',
      'name_ar': 'مستشفى الأطفال — دهوك',
      'name_en': "Duhok Children's Hospital",
      'logoUrl':
          'https://images.unsplash.com/photo-1631815588090-d4bfec5b1ccb?auto=format&fit=crop&w=300&q=80',
      'description_ku': 'نموونە بۆ لۆگۆ و ناوێکی تایبەت بە منداڵان.',
      'description_en': 'Preview card with pediatric-style imagery.',
    },
  ),
  (
    id: 'mock_koya_private',
    data: <String, dynamic>{
      'sortOrder': 3,
      'name_ku': 'نەخۆشخانەی تایبەت — کۆیە',
      'name_ar': 'مستشفى خاص — كوية',
      'name_en': 'Koya Private Hospital',
      'logoUrl': '',
      'description_ku': 'بێ وێنە: تەنها ئایکۆنی نەخۆشخانە دەردەکەوێت.',
      'description_en': 'No logo URL: shows the default hospital icon.',
    },
  ),
  (
    id: 'mock_ranya_emergency',
    data: <String, dynamic>{
      'sortOrder': 4,
      'name_ku': 'یەکەی فریاکەوتن — ڕانیە',
      'name_ar': 'وحدة طوارئ — رانية',
      'name_en': 'Ranya Emergency Unit',
      'logoUrl':
          'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&w=300&q=80',
      'description_ku': 'نموونەی کورت بۆ تەکستی درێژتر لە پەڕەی وردەکاری.',
      'description_en':
          'Preview with a slightly longer subtitle block for the detail header.',
    },
  ),
];
