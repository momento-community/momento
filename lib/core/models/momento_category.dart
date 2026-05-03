enum MomentoCategory {
  art('Art', 'art'),
  music('Music', 'music'),
  food('Food & Drink', 'food'),
  nightlife('Nightlife', 'nightlife'),
  fashion('Fashion', 'fashion'),
  sports('Sports', 'sports'),
  markets('Markets', 'markets'),
  culture('Culture', 'culture'),
  comedy('Comedy', 'comedy'),
  wellness('Wellness', 'wellness'),
  kids('Kids', 'kids'),
  other('Other', 'other');

  const MomentoCategory(this.displayName, this.id);

  final String displayName;
  final String id;

  String get badge => displayName.toUpperCase();

  static MomentoCategory fromId(String id) =>
      values.firstWhere((c) => c.id == id, orElse: () => MomentoCategory.other);
}
