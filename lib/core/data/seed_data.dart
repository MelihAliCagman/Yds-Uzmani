import '../models.dart';

/// Başlangıç soruları (özgün, örnek amaçlı). Gerisi Gemini ile üretilir.
const List<Question> seedQuestions = [
  Question(
    id: 'seed_q1',
    topicId: 'vocab_academic',
    stem:
        'The committee decided to ------- the new regulations until further notice because of public objections.',
    options: ['suspend', 'enhance', 'illustrate', 'convey', 'predict'],
    correctIndex: 0,
    explanation:
        '"Suspend" = askıya almak; "until further notice" ile uyumlu. Diğer şıklar bağlama uymaz.',
    level: 2,
  ),
  Question(
    id: 'seed_q2',
    topicId: 'vocab_phrasal',
    stem: 'The meeting was ------- due to the heavy snowstorm.',
    options: ['called off', 'put up', 'set out', 'taken after', 'turned into'],
    correctIndex: 0,
    explanation: '"Call off" = iptal etmek. Kar fırtınası nedeniyle toplantı iptal edildi.',
    level: 2,
  ),
  Question(
    id: 'seed_q3',
    topicId: 'gr_conditionals',
    stem: 'If the experiment ------- successful, the team would have published the results last month.',
    options: ['was', 'had been', 'were', 'has been', 'would be'],
    correctIndex: 1,
    explanation:
        'Geçmişe yönelik varsayım (Type 3): If + past perfect, would have + V3.',
    level: 3,
  ),
  Question(
    id: 'seed_q4',
    topicId: 'gr_passive',
    stem: 'The new bridge ------- by the end of next year.',
    options: [
      'will complete',
      'will be completed',
      'is completing',
      'has completed',
      'completes'
    ],
    correctIndex: 1,
    explanation: 'Özne işi yapmıyor, yapılıyor → gelecek zaman edilgen: will be + V3.',
    level: 2,
  ),
  Question(
    id: 'seed_q5',
    topicId: 'gr_relative',
    stem: 'The scientist ------- research on climate change was funded by the EU has won the prize.',
    options: ['who', 'whom', 'whose', 'which', 'that'],
    correctIndex: 2,
    explanation: 'Aitlik bildirir (scientist\'s research) → whose.',
    level: 3,
  ),
  Question(
    id: 'seed_q6',
    topicId: 'vocab_connectors',
    stem: '------- the economy has recovered slightly, unemployment remains a serious problem.',
    options: ['Because', 'Although', 'Unless', 'Since', 'So that'],
    correctIndex: 1,
    explanation: 'Zıtlık ilişkisi var → Although (her ne kadar).',
    level: 2,
  ),
  Question(
    id: 'seed_q7',
    topicId: 'gr_inversion',
    stem: 'Not only ------- the exam, but she also got the highest score in the class.',
    options: ['she passed', 'did she pass', 'she did pass', 'has she passed', 'passed she'],
    correctIndex: 1,
    explanation: '"Not only" cümle başındayken devrik yapı: did + özne + V1.',
    level: 4,
  ),
  Question(
    id: 'seed_q8',
    topicId: 'tr_en_tr',
    stem:
        'Despite the fact that renewable energy is becoming cheaper, many countries still depend heavily on fossil fuels.\n\nCümlenin Türkçesi hangisidir?',
    options: [
      'Yenilenebilir enerji ucuzladığı için birçok ülke fosil yakıtlardan vazgeçmiştir.',
      'Yenilenebilir enerji ucuzlamasına rağmen birçok ülke hâlâ büyük ölçüde fosil yakıtlara bağımlıdır.',
      'Birçok ülke fosil yakıt kullandığı için yenilenebilir enerji ucuzlamamaktadır.',
      'Fosil yakıtlar ucuzladığından yenilenebilir enerjiye ilgi azalmıştır.',
      'Yenilenebilir enerjiye bağımlı ülkeler fosil yakıtları azaltmaktadır.'
    ],
    correctIndex: 1,
    explanation: '"Despite the fact that" = -e rağmen; "still depend heavily on" = hâlâ büyük ölçüde bağımlı.',
    level: 3,
  ),
  Question(
    id: 'seed_q9',
    topicId: 'hlt_disease',
    stem: 'Early ------- of the disease significantly increases the chances of successful treatment.',
    options: ['detection', 'resistance', 'suspension', 'contribution', 'consumption'],
    correctIndex: 0,
    explanation: '"Early detection" = erken teşhis; tedavi şansını artırır.',
    level: 2,
  ),
  Question(
    id: 'seed_q10',
    topicId: 'soc_econ',
    stem: 'Inflation ------- the purchasing power of consumers, which in turn reduces demand.',
    options: ['erodes', 'enriches', 'accelerates', 'proclaims', 'resumes'],
    correctIndex: 0,
    explanation: '"Erode" = aşındırmak, azaltmak; satın alma gücünü düşürür.',
    level: 3,
  ),
];

const List<Flashcard> seedCards = [
  Flashcard(id: 'c1', front: 'mitigate', back: 'hafifletmek, azaltmak', example: 'Governments must mitigate the effects of climate change.'),
  Flashcard(id: 'c2', front: 'reluctant', back: 'isteksiz', example: 'He was reluctant to share his findings.'),
  Flashcard(id: 'c3', front: 'comprehensive', back: 'kapsamlı', example: 'The report provides a comprehensive analysis.'),
  Flashcard(id: 'c4', front: 'put forward', back: 'öne sürmek, önermek', example: 'She put forward a new theory.'),
  Flashcard(id: 'c5', front: 'give rise to', back: 'neden olmak, yol açmak', example: 'Poor diet can give rise to serious illnesses.'),
  Flashcard(id: 'c6', front: 'substantial', back: 'önemli ölçüde, hatırı sayılır', example: 'There was a substantial increase in prices.'),
  Flashcard(id: 'c7', front: 'hinder', back: 'engellemek, geciktirmek', example: 'Lack of funding hindered the project.'),
  Flashcard(id: 'c8', front: 'inevitable', back: 'kaçınılmaz', example: 'Change is inevitable in any society.'),
  Flashcard(id: 'c9', front: 'catalyst', back: 'katalizör', example: 'The enzyme acts as a catalyst.', field: 'science'),
  Flashcard(id: 'c10', front: 'ecosystem', back: 'ekosistem', example: 'Pollution threatens the marine ecosystem.', field: 'science'),
  Flashcard(id: 'c11', front: 'symptom', back: 'belirti', example: 'Fever is a common symptom of infection.', field: 'health'),
  Flashcard(id: 'c12', front: 'diagnosis', back: 'teşhis', example: 'An accurate diagnosis is essential.', field: 'health'),
  Flashcard(id: 'c13', front: 'inequality', back: 'eşitsizlik', example: 'Income inequality has widened.', field: 'social'),
  Flashcard(id: 'c14', front: 'bias', back: 'önyargı, yanlılık', example: 'The study showed a clear gender bias.', field: 'social'),
];
