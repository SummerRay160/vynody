import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vynody/player/lyrics/lyrics_ai_openrouter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LyricsAiOpenRouterClient 403 handling', () {
    test('isOpenRouter403Forbidden detects 403 status code', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: 'https://openrouter.ai/api/v1/chat/completions'),
        response: Response(
          requestOptions: RequestOptions(path: 'https://openrouter.ai/api/v1/chat/completions'),
          statusCode: 403,
          data: {
            'error': {
              'message': 'User location is not supported for the provider using this model',
              'code': 403,
            }
          },
        ),
        type: DioExceptionType.badResponse,
      );

      expect(LyricsAiOpenRouterClient.isOpenRouter403Forbidden(dioError), isTrue);
    });

    test('isOpenRouter403Forbidden detects error body with 403', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: 'https://openrouter.ai/api/v1/chat/completions'),
        response: Response(
          requestOptions: RequestOptions(path: 'https://openrouter.ai/api/v1/chat/completions'),
          data: {
            'error': {
              'message': 'Forbidden',
              'code': 403,
            }
          },
        ),
      );

      expect(LyricsAiOpenRouterClient.isOpenRouter403Forbidden(dioError), isTrue);
    });

    test('isOpenRouter403Forbidden detects 403 in error string', () {
      expect(LyricsAiOpenRouterClient.isOpenRouter403Forbidden('HTTP status 403 Forbidden'), isTrue);
      expect(LyricsAiOpenRouterClient.isOpenRouter403Forbidden('Some other error 500'), isFalse);
    });
  });

  group('LyricsAiOpenRouterClient 401 handling', () {
    test('isOpenRouter401Unauthorized detects 401 status code', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: 'https://openrouter.ai/api/v1/chat/completions'),
        response: Response(
          requestOptions: RequestOptions(path: 'https://openrouter.ai/api/v1/chat/completions'),
          statusCode: 401,
          data: {
            'error': {
              'message': 'User key not found',
              'code': 401,
            }
          },
        ),
        type: DioExceptionType.badResponse,
      );

      expect(LyricsAiOpenRouterClient.isOpenRouter401Unauthorized(dioError), isTrue);
    });

    test('isOpenRouter401Unauthorized detects error body with 401', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: 'https://openrouter.ai/api/v1/chat/completions'),
        response: Response(
          requestOptions: RequestOptions(path: 'https://openrouter.ai/api/v1/chat/completions'),
          data: {
            'error': {
              'message': 'Unauthorized',
              'code': 401,
            }
          },
        ),
      );

      expect(LyricsAiOpenRouterClient.isOpenRouter401Unauthorized(dioError), isTrue);
    });

    test('isOpenRouter401Unauthorized detects 401 in error string', () {
      expect(LyricsAiOpenRouterClient.isOpenRouter401Unauthorized('HTTP status 401 Unauthorized'), isTrue);
      expect(LyricsAiOpenRouterClient.isOpenRouter401Unauthorized('Some other error 500'), isFalse);
    });
  });
}
