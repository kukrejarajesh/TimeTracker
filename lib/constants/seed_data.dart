// SeedData
// Default categories and subcategories loaded on first app launch.

class SeedData {
  SeedData._();

  static final List<Map<String, dynamic>> categories = [
    {'name': 'Health and fitness', 'color': '#1D9E75'},
    {'name': 'Learning and development', 'color': '#534AB7'},
    {'name': 'Family and personal life', 'color': '#BA7517'},
    {'name': 'Daily routine', 'color': '#185FA5'},
  ];

  static final List<Map<String, dynamic>> subcategories = [
    // Health and fitness
    {'category_name': 'Health and fitness', 'name': 'Gym'},
    {'category_name': 'Health and fitness', 'name': 'Running / cardio'},
    {'category_name': 'Health and fitness', 'name': 'Walking'},
    {'category_name': 'Health and fitness', 'name': 'Yoga'},
    {'category_name': 'Health and fitness', 'name': 'Sports'},
    {'category_name': 'Health and fitness', 'name': 'Outdoor activity'},
    {'category_name': 'Health and fitness', 'name': 'Meditation'},

    // Learning and development
    {'category_name': 'Learning and development', 'name': 'AI and machine learning'},
    {'category_name': 'Learning and development', 'name': 'App development'},
    {'category_name': 'Learning and development', 'name': 'Reading / books'},
    {'category_name': 'Learning and development', 'name': 'Online courses'},
    {'category_name': 'Learning and development', 'name': 'Research and exploration'},

    // Family and personal life
    {'category_name': 'Family and personal life', 'name': 'Family time / bonding'},
    {'category_name': 'Family and personal life', 'name': 'Social activities'},
    {'category_name': 'Family and personal life', 'name': 'Errands'},
    {'category_name': 'Family and personal life', 'name': 'Entertainment / leisure'},
    {'category_name': 'Family and personal life', 'name': 'Travel / outing'},

    // Daily routine
    {'category_name': 'Daily routine', 'name': 'Sleep / rest'},
    {'category_name': 'Daily routine', 'name': 'Morning routine'},
    {'category_name': 'Daily routine', 'name': 'Meals / eating'},
    {'category_name': 'Daily routine', 'name': 'Commute / travel'},
    {'category_name': 'Daily routine', 'name': 'Household chores'},
    {'category_name': 'Daily routine', 'name': 'Evening wind-down'},
  ];
}
