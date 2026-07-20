import '../models/models.dart';

/// Offline crop-calendar generator. Builds a season schedule from per-crop
/// growth-stage templates and the planting date — no internet or AI needed.
///
/// Each template entry is a task at N days after planting (DAP). Dates are
/// computed by adding DAP to the planting date. Templates are simplified and
/// should be reviewed against NaCRRI/MAAIF guidance before release.
class CalendarService {
  static CropPlan generate({
    required String cropKey,
    required String cropName,
    required DateTime planted,
    required String region,
    required String lang,
  }) {
    final template = _templates[cropKey] ?? _genericTemplate;
    final lg = lang == 'lg';

    final tasks = template.map((e) {
      final date = planted.add(Duration(days: e.dap));
      return CropTask(
        title: lg ? e.titleLg : e.titleEn,
        detail: lg ? e.detailLg : e.detailEn,
        date: _fmt(date),
        type: e.type,
        stage: lg ? e.stageLg : e.stageEn,
      );
    }).toList();

    final summary = lg
        ? 'Enteekateeka y\u2019omwaka gwa $cropName okuva lwe wasimba.'
        : 'Your $cropName season plan from planting to harvest.';

    return CropPlan(
      crop: cropName,
      summary: summary,
      plantedDate: _fmt(planted),
      tasks: tasks,
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // --- task template type ---
  // dap = days after planting.
  static const Map<String, List<_Task>> _templates = {
    'cassava': [
      _Task(0, 'weeding', 'Land & planting', 'Olusimbi',
          'Plant clean cuttings', 'Simba ebikolo ebirongoofu',
          'Use certified, disease-free cuttings spaced about 1 m apart.',
          'Kozesa ebikolo ebirongoofu nga oleseeyo mita emu.'),
      _Task(21, 'fertilizer', 'Early growth', 'Okukula okusooka',
          'First weeding', 'Okukuula okusooka',
          'Weed thoroughly; weeds compete strongly in the first weeks.',
          'Kuula bulungi; omuddo gulwanyisa nnyo mu wiiki ezisooka.'),
      _Task(45, 'scout', 'Leaf development', 'Amakoola',
          'Scout for mosaic/whitefly', 'Kebera kawuka/ensekere',
          'Check leaves for mosaic patterns and whiteflies; remove sick plants.',
          'Kebera amakoola olabe kawuka n\u2019ensekere; ggyawo ebirwadde.'),
      _Task(60, 'weeding', 'Canopy', 'Ekisaakaate',
          'Second weeding', 'Okukuula okwokubiri',
          'Weed again and earth-up around the stems.',
          'Kuula nate era otuume ettaka ku miti.'),
      _Task(90, 'scout', 'Bulking', 'Okugimuka',
          'Monitor brown streak', 'Kebera obulwadde bwa kakobe',
          'Watch for brown streak signs; tolerant varieties help.',
          'Kebera obubonero bwa brown streak; ebika ebigumira biyamba.'),
      _Task(270, 'harvest', 'Maturity', 'Okuyengera',
          'Harvest readiness', 'Okukungula',
          'Roots are usually ready 9-12 months after planting.',
          'Emizizi gibeera gyeetegese oluvannyuma lwa myezi 9-12.'),
    ],
    'maize': [
      _Task(0, 'weeding', 'Planting', 'Olusimbi',
          'Plant & basal fertilizer', 'Simba era oteeke obugimusa',
          'Plant treated seed and apply basal fertilizer (e.g. DAP) at planting.',
          'Simba ensigo era oteeke obugimusa nga DAP.'),
      _Task(14, 'fertilizer', 'Seedling', 'Akamera',
          'First weeding', 'Okukuula okusooka',
          'Weed early; maize is sensitive to competition when young.',
          'Kuula mangu; kasooli akwatibwa omuddo ng\u2019akyali muto.'),
      _Task(28, 'fertilizer', 'Vegetative', 'Okukula',
          'Top-dress with nitrogen', 'Ongeramu obugimusa bwa nayitrojeni',
          'Apply nitrogen top-dressing (e.g. urea) at knee height.',
          'Teeka obugimusa nga urea nga kasooli atuuse ku vviivi.'),
      _Task(45, 'scout', 'Pre-tassel', 'Nga tennakula bulungi',
          'Scout for fall armyworm', 'Kebera enkukunyi',
          'Check funnels for fall armyworm; act early if found.',
          'Kebera mu mutwe gwa kasooli olabe enkukunyi; nnyiikira mangu.'),
      _Task(65, 'water', 'Tasseling', 'Okumulisa',
          'Ensure moisture at flowering', 'Laba ng\u2019amazzi gamala',
          'Flowering is the most drought-sensitive stage; water if dry.',
          'Mu kumulisa kasooli ye ddagala ly\u2019amazzi; fukirira bwe wabaawo obukalu.'),
      _Task(120, 'harvest', 'Maturity', 'Okuyengera',
          'Harvest readiness', 'Okukungula',
          'Harvest when husks dry and grain is hard, about 4 months.',
          'Kungula ng\u2019ebikuta byomye era empeke nkalubo, nga myezi 4.'),
    ],
    'tomato': [
      _Task(0, 'weeding', 'Transplant', 'Okusimba',
          'Transplant seedlings', 'Simba obumera',
          'Transplant healthy seedlings in the cool of the day; water in.',
          'Simba obumera obulamu mu budde obunnyogovu; ofukirire.'),
      _Task(10, 'fertilizer', 'Establishment', 'Okunywera',
          'First feeding', 'Okuliisa okusooka',
          'Apply a balanced fertilizer and begin staking.',
          'Teeka obugimusa era otandike okusimba emiti.'),
      _Task(21, 'spray', 'Vegetative', 'Okukula',
          'Preventative blight spray', 'Eddagala ery\u2019okuziyiza',
          'Begin preventative copper/mancozeb sprays, especially if wet.',
          'Tandika eddagala lya copper/mancozeb okuziyiza, naddala mu budde obunnyogovu.'),
      _Task(35, 'scout', 'Flowering', 'Okumulisa',
          'Scout for blight & pests', 'Kebera obulwadde n\u2019ebiwuka',
          'Inspect daily for late blight blotches and remove affected leaves.',
          'Kebera buli lunaku olabe late blight era ggyawo amakoola agarwadde.'),
      _Task(50, 'fertilizer', 'Fruit set', 'Okubala',
          'Feed for fruiting', 'Okuliisa olw\u2019ebibala',
          'Switch to a potassium-rich feed to support fruit development.',
          'Kyuka okozese obugimusa obulimu potassium olw\u2019ebibala.'),
      _Task(75, 'harvest', 'Harvest', 'Okukungula',
          'Begin harvesting', 'Tandika okukungula',
          'Pick fruit as it colours; harvest regularly to keep plants productive.',
          'Noonyola ebibala nga bisiimuuka; kungula buli kiseera.'),
    ],
    'beans': [
      _Task(0, 'weeding', 'Planting', 'Olusimbi',
          'Plant clean seed', 'Simba ensigo ennongoofu',
          'Plant certified seed; avoid waterlogged ground.',
          'Simba ensigo ennongoofu; weewale ettaka erijjudde amazzi.'),
      _Task(15, 'weeding', 'Seedling', 'Akamera',
          'First weeding', 'Okukuula okusooka',
          'Weed early to reduce competition and disease carry-over.',
          'Kuula mangu okukendeeza omuddo n\u2019obulwadde.'),
      _Task(30, 'spray', 'Vegetative', 'Okukula',
          'Scout for leaf spot/rust', 'Kebera amabala/obukubo',
          'Check leaves for angular spot and rust; spray if pressure is high.',
          'Kebera amakoola olabe obulwadde; fukirira bwe buba bungi.'),
      _Task(40, 'water', 'Flowering', 'Okumulisa',
          'Ensure moisture at flowering', 'Laba ng\u2019amazzi gamala',
          'Flowering and pod-fill need steady moisture; water if dry.',
          'Mu kumulisa n\u2019okujjuza ebijanjaalo kyetaaga amazzi; fukirira bwe wabaawo obukalu.'),
      _Task(85, 'harvest', 'Maturity', 'Okuyengera',
          'Harvest readiness', 'Okukungula',
          'Harvest when pods dry and rattle, about 3 months.',
          'Kungula ng\u2019ebijanjaalo byomye, nga myezi 3.'),
    ],
  };

  static const List<_Task> _genericTemplate = [
    _Task(0, 'weeding', 'Planting', 'Olusimbi', 'Plant', 'Simba',
        'Plant clean, certified seed or cuttings.',
        'Simba ensigo oba ebikolo ebirongoofu.'),
    _Task(21, 'fertilizer', 'Early growth', 'Okukula okusooka',
        'First weeding & feeding', 'Okukuula n\u2019okuliisa',
        'Weed and apply appropriate fertilizer.',
        'Kuula era oteeke obugimusa obutuufu.'),
    _Task(45, 'scout', 'Growth', 'Okukula', 'Scout for pests/disease',
        'Kebera ebiwuka/obulwadde',
        'Inspect plants and act early on any problem.',
        'Kebera ebimera era onnyiikire mangu.'),
    _Task(90, 'harvest', 'Maturity', 'Okuyengera', 'Harvest readiness',
        'Okukungula', 'Harvest when the crop is mature.',
        'Kungula ng\u2019ekirime kiyengedde.'),
  ];
}

class _Task {
  final int dap;
  final String type;
  final String stageEn, stageLg;
  final String titleEn, titleLg;
  final String detailEn, detailLg;
  const _Task(this.dap, this.type, this.stageEn, this.stageLg, this.titleEn,
      this.titleLg, this.detailEn, this.detailLg);
}
