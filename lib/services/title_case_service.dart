import 'sentence_case_service.dart';

export 'sentence_case_service.dart';

/// Legacy alias mapping to sentence case as required by Version 2.3.0.
String toTitleCase(String text) => toSentenceCase(text);

/// Legacy alias mapping to SentenceCaseTextInputFormatter as required by Version 2.3.0.
typedef TitleCaseTextInputFormatter = SentenceCaseTextInputFormatter;
