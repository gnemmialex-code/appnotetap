// Recherche : un mot -> définition (dictionnaire FR) puis explication (Wikipédia FR).
import 'dart:convert';
import 'package:http/http.dart' as http;

class LookupResult {
  final String type; // "Définition" | "Explication"
  final String term;
  final String body;
  final String source;
  final String? url;

  LookupResult({
    required this.type,
    required this.term,
    required this.body,
    required this.source,
    this.url,
  });
}

class SearchService {
  /// Tente une définition (dictionaryapi.dev/fr) puis une explication (Wikipédia FR).
  static Future<LookupResult?> lookup(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;

    // 1) Dictionnaire français
    try {
      final r = await http
          .get(Uri.parse(
              'https://api.dictionaryapi.dev/api/v2/entries/fr/${Uri.encodeComponent(q)}'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final data = jsonDecode(utf8.decode(r.bodyBytes));
        if (data is List && data.isNotEmpty) {
          final first = data.first as Map<String, dynamic>;
          final meanings = (first['meanings'] as List?) ?? [];
          final buf = <String>[];
          for (final m in meanings.take(3)) {
            final pos = (m['partOfSpeech'] ?? '').toString();
            final defs = (m['definitions'] as List?) ?? [];
            for (final d in defs.take(3)) {
              final def = (d['definition'] ?? '').toString();
              if (def.isNotEmpty) {
                buf.add(pos.isEmpty ? def : '($pos) $def');
              }
            }
          }
          if (buf.isNotEmpty) {
            return LookupResult(
              type: 'Définition',
              term: (first['word'] ?? q).toString(),
              body: buf.map((d) => '• $d').join('\n'),
              source: 'Wiktionnaire / dictionaryapi.dev',
            );
          }
        }
      }
    } catch (_) {/* on tente Wikipédia */}

    // 2) Wikipédia FR (résumé)
    try {
      final r = await http
          .get(
            Uri.parse(
                'https://fr.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(q)}'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
        final extract = (d['extract'] ?? '').toString();
        if (extract.isNotEmpty && d['type'] != 'disambiguation') {
          final url = (d['content_urls']?['desktop']?['page'])?.toString();
          return LookupResult(
            type: 'Explication',
            term: (d['title'] ?? q).toString(),
            body: extract,
            source: 'Wikipédia',
            url: url,
          );
        }
      }
    } catch (_) {/* aucun résultat */}

    return null;
  }
}
