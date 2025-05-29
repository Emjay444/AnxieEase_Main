class BreathingExercise {
  final String id;
  final String name;
  final String description;
  final int inhaleTime;
  final int holdTime;
  final int exhaleTime;
  final int holdOutTime;
  final String? soundUrl;
  final String technique;

  BreathingExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.inhaleTime,
    required this.exhaleTime,
    this.holdTime = 0,
    this.holdOutTime = 0,
    this.soundUrl,
    required this.technique,
  });

  static List<BreathingExercise> anxietyExercises = [
    BreathingExercise(
      id: '1',
      name: '4-7-8 Breathing',
      description: 'Calming breath technique to reduce anxiety and help sleep',
      inhaleTime: 4,
      holdTime: 7,
      exhaleTime: 8,
      technique: 'Inhale through nose, hold, then exhale through mouth',
      soundUrl: 'assets/audio/Bilateral1.mp3',
    ),
    BreathingExercise(
      id: '2',
      name: 'Box Breathing',
      description: 'Equal breathing to calm your nervous system',
      inhaleTime: 4,
      holdTime: 4,
      exhaleTime: 4,
      holdOutTime: 4,
      technique: 'Equal counts for inhale, hold, exhale, and hold',
      soundUrl: 'assets/audio/Bilateral2.mp3',
    ),
    BreathingExercise(
      id: '3',
      name: 'Calming Breath',
      description: 'Quick anxiety relief breathing',
      inhaleTime: 4,
      exhaleTime: 6,
      technique: 'Longer exhale to activate relaxation response',
      soundUrl: 'assets/audio/Bilateral3.mp3',
    ),
  ];
}
