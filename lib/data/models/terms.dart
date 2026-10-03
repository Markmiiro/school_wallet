// The Terms of Use and Privacy Policy a parent is asked to accept —
// matches GET /auth/terms (app/terms.py on the backend).
//
// `version` is what the app sends back as proof of what was accepted,
// so a payload without one is refused rather than shown.

class TermsPoint {
  final String title;
  final String body;

  TermsPoint({required this.title, required this.body});

  factory TermsPoint.fromJson(Map<String, dynamic> json) => TermsPoint(
        title: json['title'] as String,
        body: json['body'] as String,
      );
}

class TermsSection {
  final String heading;
  final String body;

  TermsSection({required this.heading, required this.body});

  factory TermsSection.fromJson(Map<String, dynamic> json) => TermsSection(
        heading: json['heading'] as String,
        body: json['body'] as String,
      );
}

class TermsDocument {
  final String title;
  final List<TermsSection> sections;

  TermsDocument({required this.title, required this.sections});

  factory TermsDocument.fromJson(Map<String, dynamic> json) => TermsDocument(
        title: json['title'] as String,
        sections: (json['sections'] as List)
            .map((s) => TermsSection.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class Terms {
  final String version;

  /// Short, plain points shown on the acceptance screen itself.
  final List<TermsPoint> summary;

  /// The full text, opened from the acceptance screen.
  final List<TermsDocument> documents;

  Terms({
    required this.version,
    required this.summary,
    required this.documents,
  });

  factory Terms.fromJson(Map<String, dynamic> json) => Terms(
        version: json['version'] as String,
        summary: (json['summary'] as List)
            .map((p) => TermsPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        documents: (json['documents'] as List)
            .map((d) => TermsDocument.fromJson(d as Map<String, dynamic>))
            .toList(),
      );
}
