import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/gif_asset.dart';

/// Open-source GIF discovery via public Giphy / Tenor-compatible endpoints.
///
/// Replace [giphyApiKey] / [tenorApiKey] with production keys. When keys are
/// absent, a curated offline demo catalog is returned so UI remains usable.
class GifSearchService {
  GifSearchService({
    this.giphyApiKey = const String.fromEnvironment('GIPHY_API_KEY'),
    this.tenorApiKey = const String.fromEnvironment('TENOR_API_KEY'),
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String giphyApiKey;
  final String tenorApiKey;
  final http.Client _client;

  static const _giphyBase = 'https://api.giphy.com/v1/gifs';
  static const _tenorBase = 'https://tenor.googleapis.com/v2';

  Future<List<GifAsset>> searchTrending({int limit = 24}) async {
    if (giphyApiKey.isNotEmpty) {
      try {
        return await _giphy(
          '$_giphyBase/trending',
          {'api_key': giphyApiKey, 'limit': '$limit', 'rating': 'pg'},
        );
      } catch (_) {/* fall through */}
    }
    if (tenorApiKey.isNotEmpty) {
      try {
        return await _tenor('$_tenorBase/featured', {
          'key': tenorApiKey,
          'limit': '$limit',
          'media_filter': 'gif,tinygif',
        });
      } catch (_) {/* fall through */}
    }
    return _demoCatalog();
  }

  Future<List<GifAsset>> search(String query, {int limit = 24}) async {
    final q = query.trim();
    if (q.isEmpty) return searchTrending(limit: limit);

    if (giphyApiKey.isNotEmpty) {
      try {
        return await _giphy('$_giphyBase/search', {
          'api_key': giphyApiKey,
          'q': q,
          'limit': '$limit',
          'rating': 'pg',
        });
      } catch (_) {/* fall through */}
    }
    if (tenorApiKey.isNotEmpty) {
      try {
        return await _tenor('$_tenorBase/search', {
          'key': tenorApiKey,
          'q': q,
          'limit': '$limit',
          'media_filter': 'gif,tinygif',
        });
      } catch (_) {/* fall through */}
    }
    return _demoCatalog()
        .where((g) => g.title.toLowerCase().contains(q.toLowerCase()))
        .toList();
  }

  Future<List<GifAsset>> _giphy(
    String url,
    Map<String, String> params,
  ) async {
    final uri = Uri.parse(url).replace(queryParameters: params);
    final res = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Giphy ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => GifAsset.fromGiphy(e as Map<String, dynamic>))
        .where((g) => g.gifUrl.isNotEmpty)
        .toList();
  }

  Future<List<GifAsset>> _tenor(
    String url,
    Map<String, String> params,
  ) async {
    final uri = Uri.parse(url).replace(queryParameters: params);
    final res = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Tenor ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? [];
    return results
        .map((e) => GifAsset.fromTenor(e as Map<String, dynamic>))
        .where((g) => g.gifUrl.isNotEmpty)
        .toList();
  }

  /// Public-domain style placeholders from Wikimedia / sample GIF hosts.
  List<GifAsset> _demoCatalog() {
    const samples = [
      (
        '1',
        'Happy dance',
        'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif',
        480,
        270
      ),
      (
        '2',
        'Thumbs up',
        'https://media.giphy.com/media/111ebonMs90YLu/giphy.gif',
        400,
        300
      ),
      (
        '3',
        'Mind blown',
        'https://media.giphy.com/media/26u4cqiYI30juCOGY/giphy.gif',
        480,
        270
      ),
      (
        '4',
        'Cat vibes',
        'https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif',
        480,
        480
      ),
      (
        '5',
        'Celebrate',
        'https://media.giphy.com/media/g9582DNuQppxC/giphy.gif',
        480,
        270
      ),
      (
        '6',
        'High five',
        'https://media.giphy.com/media/3o7abKhOpu0NwenH3O/giphy.gif',
        480,
        270
      ),
      (
        '7',
        'Coffee time',
        'https://media.giphy.com/media/3oKIPnAiaMCws8nOsE/giphy.gif',
        480,
        270
      ),
      (
        '8',
        'Wow',
        'https://media.giphy.com/media/5VKbvrjxpVJCM/giphy.gif',
        400,
        280
      ),
    ];
    return samples
        .map(
          (s) => GifAsset(
            id: s.$1,
            title: s.$2,
            previewUrl: s.$3,
            gifUrl: s.$3,
            width: s.$4,
            height: s.$5,
          ),
        )
        .toList();
  }

  void dispose() => _client.close();
}
