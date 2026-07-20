/// Offline treatment knowledge base.
///
/// The on-device TFLite model outputs only a disease *label*. Because the app
/// now works fully offline, the cause / treatment / prevention text must live
/// in the app itself (previously the online AI produced it). This file is that
/// knowledge base, curated for Ugandan crops and locally available inputs.
///
/// Sources to verify against before publishing: NaCRRI / MAAIF extension
/// guidance and Uganda agro-input availability. Treatments here are written
/// for a student project and should be reviewed by an agronomist for release.
library;

class Treatment {
  final String cause;
  final String organic;
  final String chemical;
  final String prevent;
  const Treatment({
    required this.cause,
    required this.organic,
    required this.chemical,
    required this.prevent,
  });
}

class TreatmentDB {
  /// key = class label from <crop>_labels.txt ; value per language.
  static const Map<String, Map<String, Treatment>> _db = {
    // ----------------- CASSAVA -----------------
    'cassava_mosaic_disease': {
      'en': Treatment(
        cause:
            'A viral disease spread by whiteflies and infected cuttings. Leaves show yellow-green mosaic patterns and become distorted, reducing root yield.',
        organic:
            'Uproot and burn badly infected plants. Plant only certified disease-free, resistant varieties (e.g. NASE 14, NAROCASS 1). Control whiteflies by keeping fields weed-free.',
        chemical:
            'No chemical cures the virus. Whitefly vectors can be reduced with imidacloprid-based insecticides applied per label, but resistant varieties are the main control.',
        prevent:
            'Always source cuttings from clean, certified plants and remove infected plants early to stop spread.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa kawuka obusaasaanyizibwa ensekere (whitefly) n\u2019ebikolo ebirwadde. Amakoola gafuna langi eza kyenvu ne kiragala era ne gakyukakyuka.',
        organic:
            'Kuula okweko ebimera ebirwadde nnyo obyokye. Simba ebika ebigumira obulwadde nga NASE 14 oba NAROCASS 1. Ziyiza ensekere ng\u2019oggyawo omuddo.',
        chemical:
            'Tewali ddagala liwonya kawuka. Ensekere ziyinza okukendeezebwa n\u2019eddagala nga imidacloprid, naye ebika ebigumira bye bisinga.',
        prevent:
            'Funa ebikolo okuva mu bimera ebirongoofu era ggyawo ebirwadde mangu.',
      ),
    },
    'cassava_brown_streak_disease': {
      'en': Treatment(
        cause:
            'A viral disease spread by whiteflies. It causes yellow blotches on leaves and brown, rotting streaks inside the roots, often unseen until harvest.',
        organic:
            'Remove and destroy infected plants. Use tolerant varieties recommended by NaCRRI. Harvest early in high-risk areas to limit root damage.',
        chemical:
            'No chemical cures the virus. Manage whitefly vectors with recommended insecticides; rely mainly on clean planting material and tolerant varieties.',
        prevent:
            'Plant certified tolerant cuttings, control whiteflies, and avoid moving cuttings from affected areas.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa kawuka obuva mu nsekere. Buleeta amabala aga kyenvu ku makoola n\u2019obukubo obwa kakobe obuvunda munda mu mizizi.',
        organic:
            'Ggyawo era ozikirize ebimera ebirwadde. Kozesa ebika ebigumira okuva ku NaCRRI. Kungula amangu mu bitundu ebirimu obulabe.',
        chemical:
            'Tewali ddagala liwonya kawuka. Ddukanya ensekere n\u2019eddagala erikkirizibwa; weesigame ku bikolo ebirongoofu.',
        prevent:
            'Simba ebikolo ebigumira, ziyiza ensekere, era toleeta bikolo kuva mu bitundu ebirwadde.',
      ),
    },
    'cassava_bacterial_blight': {
      'en': Treatment(
        cause:
            'A bacterial disease spread by rain splash and tools. Causes angular leaf spots, wilting, dieback and gum on stems, worst in wet weather.',
        organic:
            'Cut and burn affected shoots. Disinfect tools (e.g. with bleach solution) between plants. Use clean cuttings and practise crop rotation.',
        chemical:
            'Copper-based bactericides (e.g. copper oxychloride at the label rate) can slow spread on young plants. Sanitation and resistant varieties matter most.',
        prevent:
            'Use disease-free cuttings, avoid working in fields when wet, and rotate with non-host crops.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa bakitiriya obusaasaanyizibwa enkuba n\u2019ebikozesebwa. Buleeta amabala ku makoola, okuwotoka n\u2019envuumuulo ku miti.',
        organic:
            'Salako era oyokye amatabi agarwadde. Yoza ebikozesebwa wakati w\u2019ebimera. Kozesa ebikolo ebirongoofu era okyuse ebirime.',
        chemical:
            'Eddagala lya copper (nga copper oxychloride) liyinza okukendeeza okusaasaana ku bimera ebito. Obuyonjo n\u2019ebika ebigumira bye bisinga.',
        prevent:
            'Kozesa ebikolo ebitali birwadde, toweereza mu nnimiro nga nnyonyi, era okyuse ebirime.',
      ),
    },
    'cassava_green_mottle': {
      'en': Treatment(
        cause:
            'A viral disease causing green mottling and mild leaf distortion. Effects on yield are usually milder than mosaic or brown streak.',
        organic:
            'Remove visibly affected plants and use clean, certified cuttings. Keep whitefly populations down through good field hygiene.',
        chemical:
            'No chemical cures the virus. Focus on clean planting material and vector management.',
        prevent:
            'Source cuttings from healthy plants and monitor fields regularly for early symptoms.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa kawuka obuleeta amabala aga kiragala n\u2019okukyukakyuka okutono ku makoola.',
        organic:
            'Ggyawo ebimera ebirwadde era okozese ebikolo ebirongoofu. Kuuma ensekere nga ntono.',
        chemical:
            'Tewali ddagala liwonya kawuka. Ssa essira ku bikolo ebirongoofu.',
        prevent:
            'Funa ebikolo okuva mu bimera ebiramu era okebere ennimiro buli kiseera.',
      ),
    },

    // ----------------- MAIZE -----------------
    'maize_northern_leaf_blight': {
      'en': Treatment(
        cause:
            'A fungal disease favoured by humid, cool conditions. Long grey-green to tan cigar-shaped lesions appear on leaves, reducing grain fill.',
        organic:
            'Rotate maize with non-cereal crops, remove crop residue after harvest, and plant resistant hybrids where available.',
        chemical:
            'Apply a recommended fungicide (e.g. mancozeb or a strobilurin) at first sign and repeat per label if pressure is high.',
        prevent:
            'Use resistant varieties, rotate crops, and avoid dense planting that keeps leaves wet.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa kawuka (fungus) olw\u2019obunnyogovu. Buleeta amabala amawanvu ku makoola.',
        organic:
            'Kyuusa kasooli n\u2019ebirime ebirala, ggyawo ebisigalira, era simba ebika ebigumira.',
        chemical:
            'Kozesa eddagala nga mancozeb ng\u2019obulwadde butandika era oddiremu nga bwe kyetaagisa.',
        prevent:
            'Kozesa ebika ebigumira, kyuusa ebirime, era tosimba kumpi nnyo.',
      ),
    },
    'maize_common_rust': {
      'en': Treatment(
        cause:
            'A fungal disease showing small reddish-brown pustules on both leaf surfaces. Severe infection reduces photosynthesis and yield.',
        organic:
            'Plant resistant hybrids, ensure good spacing for airflow, and remove heavily infected leaves early.',
        chemical:
            'Fungicides such as mancozeb or triazoles control rust when applied early per label.',
        prevent:
            'Choose resistant varieties and avoid late planting into cool, moist periods.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa kawuka obulaga obukubo obumyufu ku makoola.',
        organic:
            'Simba ebika ebigumira, leka ebbanga wakati w\u2019ebimera, era ggyawo amakoola agarwadde.',
        chemical:
            'Eddagala nga mancozeb liyinza okuyamba nga likozesebwa mangu.',
        prevent:
            'Londa ebika ebigumira era tosimba kibula mu budde obunnyogovu.',
      ),
    },
    'maize_gray_leaf_spot': {
      'en': Treatment(
        cause:
            'A fungal disease producing rectangular grey lesions bounded by leaf veins, worsened by minimum tillage and continuous maize.',
        organic:
            'Rotate away from maize, bury residue, and plant tolerant hybrids.',
        chemical:
            'Strobilurin or triazole fungicides applied at early infection reduce spread.',
        prevent:
            'Rotate crops, manage residue, and avoid continuous maize on the same plot.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa kawuka obuleeta amabala aga kyenvu-kiragala ku makoola.',
        organic:
            'Kyuusa okuva ku kasooli, ziika ebisigalira, era simba ebika ebigumira.',
        chemical:
            'Eddagala nga triazole likendeeza okusaasaana nga likozesebwa mangu.',
        prevent:
            'Kyuusa ebirime era toddiŋŋana kusimba kasooli mu kifo kye kimu.',
      ),
    },

    // ----------------- TOMATO -----------------
    'tomato_late_blight': {
      'en': Treatment(
        cause:
            'A fast-moving fungal-like disease in cool, wet weather. Dark water-soaked blotches spread on leaves and fruit, destroying crops within days.',
        organic:
            'Remove and destroy infected plants immediately. Improve airflow, avoid overhead watering, and never compost infected material.',
        chemical:
            'Apply copper oxychloride (about 3 g/L) or mancozeb every 7 days during wet weather, following the label.',
        prevent:
            'Use resistant varieties, space plants well, water at the base, and scout daily in wet spells.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde obw\u2019amaanyi mu budde obunnyogovu. Buleeta amabala amaddugavu ku makoola ne ku bibala ne bizikiriza ebimera.',
        organic:
            'Ggyawo era ozikirize ebimera ebirwadde mangu. Tofukirira kungulu, era tokozesa ebirwadde mu bolovu.',
        chemical:
            'Kozesa copper oxychloride (3g/L) oba mancozeb buli nnaku 7 mu budde obunnyogovu.',
        prevent:
            'Kozesa ebika ebigumira, leka ebbanga, fukirira wansi, era okebere buli lunaku.',
      ),
    },
    'tomato_early_blight': {
      'en': Treatment(
        cause:
            'A fungal disease causing dark concentric-ring spots on older leaves, leading to defoliation and sun-scalded fruit.',
        organic:
            'Remove lower infected leaves, mulch to stop soil splash, and rotate away from tomato and potato.',
        chemical:
            'Mancozeb or chlorothalonil applied per label at first symptoms limits spread.',
        prevent:
            'Rotate crops, mulch, stake plants, and avoid wetting leaves when watering.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa kawuka obuleeta amabala ag\u2019empeta ku makoola amakulu.',
        organic:
            'Ggyawo amakoola ag\u2019emmanga agarwadde, ssaako omuddo, era okyuse ebirime.',
        chemical:
            'Mancozeb oba chlorothalonil nga bukozesebwa mangu kukendeeza okusaasaana.',
        prevent:
            'Kyuusa ebirime, ssaako omuddo, simba ku miti, era tonnyikiza makoola.',
      ),
    },
    'tomato_leaf_mold': {
      'en': Treatment(
        cause:
            'A fungal disease of humid conditions. Pale yellow spots appear on upper leaf surfaces with olive mould beneath.',
        organic:
            'Increase ventilation, reduce humidity, and remove affected leaves. Avoid crowding plants.',
        chemical:
            'Copper or mancozeb fungicides applied per label help in persistent cases.',
        prevent:
            'Space and prune plants for airflow and keep humidity down, especially under cover.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa kawuka mu budde obunnyogovu. Amabala aga kyenvu ku makoola.',
        organic:
            'Yongera empewo, kendeeza obunnyogovu, era ggyawo amakoola agarwadde.',
        chemical:
            'Eddagala lya copper oba mancozeb liyamba mu mbeera enkalubo.',
        prevent:
            'Leka ebbanga era osaleko ebimera, era kendeeza obunnyogovu.',
      ),
    },
    'tomato_septoria_leaf_spot': {
      'en': Treatment(
        cause:
            'A fungal disease causing many small circular spots with grey centres on lower leaves, spreading upward.',
        organic:
            'Remove infected leaves, mulch, and rotate crops. Avoid working with plants when wet.',
        chemical:
            'Chlorothalonil or mancozeb applied per label slows progression.',
        prevent:
            'Rotate, mulch, stake plants, and water at the base only.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa kawuka obuleeta obubala obutono obungi ku makoola ag\u2019emmanga.',
        organic:
            'Ggyawo amakoola agarwadde, ssaako omuddo, era okyuse ebirime.',
        chemical:
            'Chlorothalonil oba mancozeb kukendeeza okusaasaana.',
        prevent:
            'Kyuusa, ssaako omuddo, simba ku miti, era fukirira wansi.',
      ),
    },
    'tomato_yellow_leaf_curl_virus': {
      'en': Treatment(
        cause:
            'A viral disease spread by whiteflies. Leaves curl upward, yellow and shrink, and plants are stunted with poor fruit set.',
        organic:
            'Remove infected plants, control whiteflies with yellow sticky traps and field hygiene, and use resistant varieties.',
        chemical:
            'No chemical cures the virus. Reduce whitefly vectors with recommended insecticides; resistant varieties are key.',
        prevent:
            'Plant resistant varieties, control whiteflies early, and remove infected plants promptly.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa kawuka obuva mu nsekere. Amakoola gewamba, gafuuka kyenvu, era ebimera tebikula bulungi.',
        organic:
            'Ggyawo ebimera ebirwadde, ziyiza ensekere, era kozesa ebika ebigumira.',
        chemical:
            'Tewali ddagala liwonya kawuka. Kendeeza ensekere n\u2019eddagala erikkirizibwa.',
        prevent:
            'Simba ebika ebigumira, ziyiza ensekere mangu, era ggyawo ebirwadde.',
      ),
    },

    // ----------------- BEANS -----------------

    // ----------------- MAIZE -----------------
    'maize_lethal_necrosis': {
      'en': Treatment(
        cause:
            'A viral disease (MCMV combined with a potyvirus) spread by insects and infected seed. Leaves show yellow mottling and dead streaks, plants are stunted, and cobs are small or empty.',
        organic:
            'Uproot and destroy infected plants early. Plant clean, certified seed of tolerant varieties. Practise a closed season and rotate with non-cereal crops (e.g. beans) to break the cycle.',
        chemical:
            'No chemical cures the virus. Reduce insect vectors (thrips, beetles) with a recommended insecticide per label, but clean seed, tolerant varieties and rotation are the main controls.',
        prevent:
            'Use certified seed, avoid continuous maize on the same land, control insect vectors and remove volunteer maize plants between seasons.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa kawuka (MCMV ne potyvirus) obusaasaanyizibwa ebiwuka n\u2019ensigo ezirwadde. Amakoola gafuna langi eya kyenvu n\u2019obukubo obufu, ebimera tebikula, n\u2019ebigombe biba bitono.',
        organic:
            'Kuula era ozikirize ebimera ebirwadde amangu. Simba ensigo ennongoofu ez\u2019ebika ebigumira. Wummuza ennimiro era okyuse n\u2019ebirime ebirala nga ebijanjaalo.',
        chemical:
            'Tewali ddagala liwonya kawuka. Kendeeza ebiwuka n\u2019eddagala erikkirizibwa, naye ensigo ennongoofu n\u2019ebika ebigumira bye bisinga.',
        prevent:
            'Kozesa ensigo ennongoofu, tolima kasooli buli mwaka mu ttaka limu, ziyiza ebiwuka era ggyawo kasooli eyeemezeemeze.',
      ),
    },
    'maize_streak_virus': {
      'en': Treatment(
        cause:
            'A viral disease spread by leafhoppers. Leaves show long, pale yellow-to-white broken stripes running along the veins; infected young plants are badly stunted.',
        organic:
            'Remove and destroy infected plants. Plant early and synchronise planting with neighbours to avoid leafhopper peaks. Grow streak-resistant varieties recommended locally.',
        chemical:
            'No chemical cures the virus. Leafhopper numbers can be lowered with a recommended systemic insecticide per label, but resistant varieties and early planting are the main control.',
        prevent:
            'Use resistant varieties, plant early in the season, control grassy weeds that host leafhoppers, and remove infected plants quickly.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa kawuka obuva mu biwuka (leafhoppers). Amakoola galaga obukubo obuwanvu obwa kyenvu oba obweru nga bugoberera emisuwa; ebimera ebito birwala nnyo.',
        organic:
            'Ggyawo era ozikirize ebimera ebirwadde. Simba amangu era simba awamu ne baliraanwa okwewala ebiwuka. Simba ebika ebigumira obulwadde.',
        chemical:
            'Tewali ddagala liwonya kawuka. Ebiwuka biyinza okukendeezebwa n\u2019eddagala erikkirizibwa, naye ebika ebigumira n\u2019okusimba amangu bye bisinga.',
        prevent:
            'Kozesa ebika ebigumira, simba amangu, ziyiza omuddo oguwa ebiwuka ekifo, era ggyawo ebirwadde amangu.',
      ),
    },
    // ----------------- BEANS -----------------
    'bean_angular_leaf_spot': {
      'en': Treatment(
        cause:
            'A fungal disease favoured by warm, humid weather. It causes grey-brown angular spots bounded by leaf veins; severe attacks cause early leaf drop and lower pod yield.',
        organic:
            'Use clean, certified seed and resistant varieties. Rotate beans with non-host crops (e.g. maize) for 2 seasons. Remove and compost crop residues after harvest and avoid working in wet fields.',
        chemical:
            'Where pressure is high, protectant fungicides such as copper-based products or chlorothalonil can be applied per label at early flowering and repeated as directed.',
        prevent:
            'Plant certified seed, rotate crops, give wider spacing for airflow, and avoid overhead irrigation late in the day.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa ffene (fungus) obwagalwa obudde obw\u2019ebbugumu n\u2019obunnyogovu. Buleeta amabala aga kyenvu-kakobe agalina enkukunala nga gakomekkerezebwa emisuwa; bwe gweyongera amakoola gagwa.',
        organic:
            'Kozesa ensigo ennongoofu n\u2019ebika ebigumira. Kyuse ebijanjaalo n\u2019ebirime ebirala (nga kasooli) okumala ebiseera bibiri. Ggyawo ebisigadde era toweereza mu nnimiro ennyogovu.',
        chemical:
            'Bwe wabaawo obulwadde bungi, kozesa eddagala (copper oba chlorothalonil) ng\u2019ekiragiro bwe kigamba, ng\u2019osooka ku kumulisa.',
        prevent:
            'Simba ensigo ennongoofu, kyuse ebirime, ssa ebbanga eggazi era weewale okufukirira waggulu akawungeezi.',
      ),
    },
    'bean_rust': {
      'en': Treatment(
        cause:
            'A fungal disease producing small reddish-brown raised pustules (like rust powder) mainly on the underside of leaves. Heavy infection dries leaves and reduces yield.',
        organic:
            'Plant resistant varieties and certified seed. Remove and destroy infected debris. Give wider spacing to improve airflow and reduce leaf wetness; rotate with cereals.',
        chemical:
            'If rust appears early and spreads, apply a recommended fungicide (e.g. mancozeb or a triazole) per label and repeat at the stated interval.',
        prevent:
            'Use resistant varieties, avoid dense planting, remove crop residues, and scout regularly so spraying starts early if needed.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa ffene obuleeta obutulututtu obutono obumyufu-kakobe (ng\u2019enfuufu ya butalo) okusinga wansi w\u2019amakoola. Bwe guyitirira amakoola gakala.',
        organic:
            'Simba ebika ebigumira n\u2019ensigo ennongoofu. Ggyawo era ozikirize ebisigadde ebirwadde. Ssa ebbanga eggazi okuyamba empewo; kyuse n\u2019ebirime ebirala.',
        chemical:
            'Singa obulwadde busooka amangu, kozesa eddagala (mancozeb oba triazole) ng\u2019ekiragiro bwe kigamba era oddiremu.',
        prevent:
            'Kozesa ebika ebigumira, weewale okusimba okunyweera, ggyawo ebisigadde era okebere buli kiseera.',
      ),
    },
    // ----------------- MATOOKE / BANANA -----------------
    'banana_black_sigatoka': {
      'en': Treatment(
        cause:
            'A fungal leaf disease (Pseudocercospora fijiensis) spread by airborne spores in wet conditions. It starts as small dark streaks that merge into large black blotches, killing leaves and shrinking bunches.',
        organic:
            'Cut off and bury or burn affected leaves (de-leafing). Improve drainage and remove weeds to lower humidity. Maintain wider spacing and grow tolerant cultivars where available.',
        chemical:
            'In severe cases, protectant or systemic fungicides (e.g. mancozeb, or a triazole) may be applied per label; rotate fungicide groups to avoid resistance.',
        prevent:
            'Regular de-leafing of infected leaves, good drainage, proper spacing for airflow, and avoiding movement of infected material between fields.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa ffene ku makoola (Pseudocercospora fijiensis) obusaasaanyizibwa empewo mu budde obunnyogovu. Butandika ng\u2019obukubo obutono obuddugavu ne bugatta ne bufuuka amabala amaddugavu, amakoola ne gafa.',
        organic:
            'Salako era oziike oba ookye amakoola amalwadde. Longoosa enkulukuto y\u2019amazzi era ggyawo omuddo okukendeeza obunnyogovu. Ssa ebbanga eggazi era simba ebika ebigumira.',
        chemical:
            'Bwe kiba kibi nnyo, kozesa eddagala lya ffene (mancozeb oba triazole) ng\u2019ekiragiro bwe kigamba; kyusa ebika by\u2019eddagala okwewala obukakanyavu.',
        prevent:
            'Salangako amakoola amalwadde buli kiseera, longoosa enkulukuto, ssa ebbanga era toleeta bintu birwadde mu nnimiro.',
      ),
    },
    'banana_fusarium_wilt': {
      'en': Treatment(
        cause:
            'A soil-borne fungal disease (Fusarium oxysporum) that blocks the plant\u2019s water channels. Older leaves yellow and collapse around the pseudostem, and cut stems show brown discoloured rings. It persists in soil for years.',
        organic:
            'There is no cure once a mat is infected. Remove and destroy affected mats, do not move soil or suckers from infected sites, and plant clean suckers of resistant cultivars in unaffected ground. Improve soil health and drainage.',
        chemical:
            'No effective chemical control exists for this soil-borne fungus. Management relies on resistant cultivars, clean planting material and strict field sanitation rather than spraying.',
        prevent:
            'Use disease-free, resistant planting material, disinfect tools, control movement of soil and suckers, and avoid replanting bananas immediately on infected land.',
      ),
      'lg': Treatment(
        cause:
            'Bulwadde bwa ffene obuva mu ttaka (Fusarium oxysporum) obuziyiza amazzi okutambula mu kimera. Amakoola amakulu gakyuka kyenvu ne gagwa ku kikolo, era ssinga osala olaba empeta eza kakobe. Busigala mu ttaka emyaka mingi.',
        organic:
            'Tewali ddagala liwonya bwe kimera kimaze okulwala. Ggyawo era ozikirize ebimera ebirwadde, toleeta ttaka oba ensukusa okuva mu kifo ekirwadde, era simba ensukusa ennongoofu ez\u2019ebika ebigumira mu ttaka eddongoofu.',
        chemical:
            'Tewali ddagala lirikola ku ffene eno ey\u2019omu ttaka. Weesigame ku bika ebigumira, ebikolo ebirongoofu n\u2019obuyonjo bw\u2019ennimiro.',
        prevent:
            'Kozesa ensukusa ennongoofu ezigumira, yoza ebikozesebwa, ziyiza okutambuza ttaka n\u2019ensukusa, era tosimba bananas mangu mu ttaka eryalimu obulwadde.',
      ),
    },

    // ----------------- HEALTHY (shared) -----------------
    'healthy': {
      'en': Treatment(
        cause:
            'No disease detected. The plant looks healthy.',
        organic:
            'Keep up good practices: balanced feeding, proper spacing, weeding, and regular scouting.',
        chemical:
            'No treatment needed. Continue routine monitoring.',
        prevent:
            'Maintain field hygiene and inspect plants regularly to catch any problem early.',
      ),
      'lg': Treatment(
        cause:
            'Tewali bulwadde bulabise. Ekimera kiramu bulungi.',
        organic:
            'Weeyongere okukola obulungi: okuliisa, ebbanga, okukuula, n\u2019okukebera.',
        chemical:
            'Tewali ddagala lyetaagisa. Weeyongere okukebera.',
        prevent:
            'Kuuma obuyonjo era okebere ebimera buli kiseera.',
      ),
    },
  };

  /// Look up treatment for a label. Falls back to a generic message if a label
  /// has no entry yet (e.g. a newly added crop class).
  static Treatment lookup(String label, String lang) {
    final byLang = _db[label];
    if (byLang != null) {
      return byLang[lang] ?? byLang['en']!;
    }
    return lang == 'lg'
        ? const Treatment(
            cause: 'Ekirwadde kizuuliddwa naye okunnyonnyola tekunnabaawo.',
            organic: 'Saba amagezi okuva ku mukugu w\u2019ebyobulimi.',
            chemical: 'Saba amagezi okuva ku mukugu w\u2019ebyobulimi.',
            prevent: 'Kebera ebimera era okuume obuyonjo.')
        : const Treatment(
            cause: 'A condition was detected, but detailed guidance is not yet available for this class.',
            organic: 'Consult a local agricultural extension officer for treatment.',
            chemical: 'Consult a local agricultural extension officer for treatment.',
            prevent: 'Monitor the crop and maintain good field hygiene.');
  }

  static bool isHealthy(String label) => label.toLowerCase().contains('healthy');
}
