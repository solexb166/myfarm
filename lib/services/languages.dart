/// The languages MY FARM is offered in. A language is only selectable once
/// its text is translated and checked ([ready]); the rest are listed as
/// coming soon so farmers can see their language is planned.
class AppLanguage {
  final String code; // stored in settings, e.g. 'lg'
  final String name; // in the language itself, e.g. 'Luganda'
  final String english; // e.g. 'Luganda'
  final String short; // shown on the language button, e.g. 'LG'
  final bool ready;
  const AppLanguage(this.code, this.name, this.english, this.short,
      {this.ready = false});
}

class Languages {
  static const all = <AppLanguage>[
    AppLanguage('en', 'English', 'English', 'EN', ready: true),
    AppLanguage('lg', 'Luganda', 'Luganda', 'LG', ready: true),
    AppLanguage('sw', 'Kiswahili', 'Swahili', 'SW'),
    AppLanguage('nyn', 'Runyankore-Rukiga', 'Runyankore-Rukiga', 'RN'),
    AppLanguage('xog', 'Lusoga', 'Lusoga', 'LS'),
    AppLanguage('ach', 'Leb Acoli', 'Acholi', 'AC'),
    AppLanguage('teo', 'Ateso', 'Ateso', 'AT'),
  ];

  static AppLanguage of(String code) =>
      all.firstWhere((l) => l.code == code, orElse: () => all.first);
}
