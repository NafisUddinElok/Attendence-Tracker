import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

/// Global middleware — CORS + JSON content type + request logging.
Handler middleware(Handler handler) {
  return handler.use(requestLogger()).use(_cors());
}

Middleware _cors() {
  return (handler) {
    return (context) async {
      if (context.request.method == HttpMethod.options) {
        return Response(
          statusCode: HttpStatus.ok,
          headers: _corsHeaders,
        );
      }
      final response = await handler(context);
      return response.copyWith(
        headers: {
          ...response.headers,
          ..._corsHeaders,
        },
      );
    };
  };
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
};
