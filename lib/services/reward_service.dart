class RewardService {
  static String levelName(int level) => switch (level) {
    1 => 'Beginner',
    2 => 'Learner',
    3 => 'Intermediate',
    4 => 'Advanced',
    _ => 'Master',
  };

  static int xpForNextLevel(int level) => switch (level) {
    1 => 100,
    2 => 300,
    3 => 700,
    4 => 1500,
    _ => 1500,
  };
}
