import 'package:flutter/material.dart';

import '../models.dart';

const _both = {Exam.yds, Exam.yokdil};

/// Müfredat iskeleti. İleride assets/curriculum/*.json'a taşınabilir.
const List<Category> curriculum = [
  Category(
    id: 'vocabulary',
    name: 'Kelime',
    icon: Icons.menu_book_rounded,
    color: Color(0xFFE05252),
    exams: _both,
    topics: [
      Topic('vocab_academic', 'Akademik kelimeler'),
      Topic('vocab_phrasal', 'Phrasal verbs'),
      Topic('vocab_prepositions', 'Prepositions'),
      Topic('vocab_collocations', 'Collocations'),
      Topic('vocab_connectors', 'Bağlaçlar'),
      Topic('vocab_synonyms', 'Eş / zıt anlamlılar'),
    ],
  ),
  Category(
    id: 'grammar',
    name: 'Gramer',
    icon: Icons.spellcheck_rounded,
    color: Color(0xFF3B9BEA),
    exams: _both,
    topics: [
      Topic('gr_tenses', 'Tenses'),
      Topic('gr_modals', 'Modals'),
      Topic('gr_passive', 'Passive'),
      Topic('gr_conditionals', 'Conditionals'),
      Topic('gr_noun_clauses', 'Noun clauses'),
      Topic('gr_relative', 'Relative clauses'),
      Topic('gr_adverb_clauses', 'Adverb clauses'),
      Topic('gr_reduced', 'Reduced clauses'),
      Topic('gr_inversion', 'Inversion'),
      Topic('gr_gerunds', 'Gerunds / Infinitives'),
      Topic('gr_articles', 'Articles'),
      Topic('gr_quantifiers', 'Quantifiers'),
    ],
  ),
  Category(
    id: 'cloze',
    name: 'Cloze Test',
    icon: Icons.edit_note_rounded,
    color: Color(0xFF1FB8CC),
    exams: _both,
    topics: [
      Topic('cloze_grammar', 'Gramer odaklı cloze'),
      Topic('cloze_vocab', 'Kelime odaklı cloze'),
      Topic('cloze_connectors', 'Bağlaç odaklı cloze'),
    ],
  ),
  Category(
    id: 'reading',
    name: 'Okuma',
    icon: Icons.auto_stories_rounded,
    color: Color(0xFF7B52C4),
    exams: _both,
    topics: [
      Topic('read_main_idea', 'Ana fikir'),
      Topic('read_inference', 'Çıkarım'),
      Topic('read_reference', 'Referans'),
      Topic('read_tone', 'Ton / amaç'),
      Topic('read_paragraph_completion', 'Paragraf tamamlama'),
      Topic('read_irrelevant', 'Anlam bütünlüğünü bozan cümle'),
    ],
  ),
  Category(
    id: 'translation',
    name: 'Çeviri',
    icon: Icons.translate_rounded,
    color: Color(0xFFEFA02A),
    exams: _both,
    topics: [
      Topic('tr_en_tr', 'İngilizce → Türkçe'),
      Topic('tr_tr_en', 'Türkçe → İngilizce'),
      Topic('tr_close_meaning', 'Anlamca yakın cümle'),
    ],
  ),
  Category(
    id: 'dialogue',
    name: 'Diyalog',
    icon: Icons.forum_rounded,
    color: Color(0xFF5DB36B),
    exams: {Exam.yds},
    topics: [
      Topic('dlg_completion', 'Diyalog tamamlama'),
      Topic('dlg_sentence_completion', 'Cümle tamamlama'),
    ],
  ),
  Category(
    id: 'science',
    name: 'Fen Bilimleri',
    icon: Icons.biotech_rounded,
    color: Color(0xFF26A69A),
    exams: {Exam.yokdil},
    field: 'science',
    topics: [
      Topic('sci_physics', 'Physics & Chemistry terms'),
      Topic('sci_biology', 'Biology terms'),
      Topic('sci_earth', 'Earth & Environment'),
      Topic('sci_engineering', 'Engineering & Technology'),
    ],
  ),
  Category(
    id: 'health',
    name: 'Sağlık Bilimleri',
    icon: Icons.favorite_rounded,
    color: Color(0xFFEC6A9B),
    exams: {Exam.yokdil},
    field: 'health',
    topics: [
      Topic('hlt_anatomy', 'Anatomy & Physiology'),
      Topic('hlt_disease', 'Disease & Treatment'),
      Topic('hlt_pharma', 'Pharmacology'),
      Topic('hlt_public', 'Public health'),
    ],
  ),
  Category(
    id: 'social',
    name: 'Sosyal Bilimler',
    icon: Icons.groups_rounded,
    color: Color(0xFF8D9DF0),
    exams: {Exam.yokdil},
    field: 'social',
    topics: [
      Topic('soc_psych', 'Psychology & Sociology'),
      Topic('soc_econ', 'Economics & Business'),
      Topic('soc_history', 'History & Politics'),
      Topic('soc_education', 'Education & Linguistics'),
    ],
  ),
];

Category categoryOf(String id) => curriculum.firstWhere((c) => c.id == id);

Category categoryOfTopic(String topicId) =>
    curriculum.firstWhere((c) => c.topics.any((t) => t.id == topicId));

Topic topicById(String id) => curriculum
    .expand((c) => c.topics)
    .firstWhere((t) => t.id == id);

List<Category> categoriesFor(Exam exam) =>
    curriculum.where((c) => c.exams.contains(exam)).toList();
