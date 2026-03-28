/// Maps `weekly_schedule` map key (`saturday` … `friday`) to [kAppStrings] entry (e.g. [weekday_sat]).
String scheduleDayTranslationKey(String id) {
  switch (id) {
    case 'saturday':
      return 'weekday_sat';
    case 'sunday':
      return 'weekday_sun';
    case 'monday':
      return 'weekday_mon';
    case 'tuesday':
      return 'weekday_tue';
    case 'wednesday':
      return 'weekday_wed';
    case 'thursday':
      return 'weekday_thu';
    case 'friday':
      return 'weekday_fri';
    default:
      return 'weekday_mon';
  }
}
