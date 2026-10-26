/// RollerGuard example of an HTTPS gateway CLIENT, not a complete integration.
/// No auth token is bundled. Inject a short-lived token from a real identity
/// provider. Configure HTTPS with a trusted certificate (do not disable TLS).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class SecureGatewayClient {
  SecureGatewayClient({
    required Uri baseUri,
    required Future<String> Function() tokenProvider,
  }) : _baseUri = baseUri,
       _tokenProvider = tokenProvider {
    if (baseUri.scheme != 'https') {
      throw ArgumentError('HTTPS required: insecure URLs are refused');
    }
  }

  final Uri _baseUri;
  final Future<String> Function() _tokenProvider;

  static String _newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<Map<String, dynamic>> status({String doorId = 'door-1'}) async {
    return _request('GET', '/v1/doors/$doorId/status');
  }

  Future<Map<String, dynamic>> requestCommand({
    required String command,
    String doorId = 'door-1',
    required int observedStateVersion,
    required bool areaVisuallyConfirmedClear,
  }) async {
    if (!const {'OPEN', 'CLOSE', 'STOP'}.contains(command)) {
      throw ArgumentError('Unsupported command');
    }
    return _request('POST', '/v1/doors/$doorId/commands', data: {
      'command': command,
      'request_id': _newRequestId(),
      'client_observed_state_version': observedStateVersion,
      'user_confirmed_clear_area': areaVisuallyConfirmedClear,
    });
  }

  Future<Map<String, dynamic>> _request(String method, String path,
      {Map<String, dynamic>? data}) async {
    final token = await _tokenProvider();
    if (token.isEmpty) throw StateError('Not authenticated');
    final uri = _baseUri.resolve(path);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await (method == 'GET'
          ? client.getUrl(uri) : client.postUrl(uri)).timeout(const Duration(seconds: 8));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (data != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(data));
      }
      final response = await request.close().timeout(const Duration(seconds: 8));
      final body = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Gateway rejected request (${response.statusCode}): $body');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) throw const FormatException('Bad gateway response');
      // Accepted is NOT the same as the gate position being verified.
      return decoded;
    } finally {
      client.close(force: true);
    }
  }
}
