// Thanks to https://github.com/wppconnect-team/wa-js

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:whatsapp_bot_platform_interface/whatsapp_bot_platform_interface.dart';

class WppConnect {
  /// make sure to call [init] to Initialize Wpp
  static Future init(
    WpClientInterface wpClient, {
    String? wppJsContent,
    required Duration waitTimeOut,
  }) async {
    String primaryUrl =
        "https://github.com/Noninus/whatsapp_bot_flutter/releases/latest/download/wppconnect-wa.js";
    String fallbackUrl =
        "https://github.com/wppconnect-team/wa-js/releases/latest/download/wppconnect-wa.js";

    String content;
    if (wppJsContent != null) {
      content = wppJsContent;
    } else {
      // Tenta primeiro do servidor válido
      try {
        WhatsappLogger.log(
            "Tentando baixar wppconnect-wa.js do servidor primário...");
        content = await http.read(Uri.parse(primaryUrl));
        WhatsappLogger.log("Download do servidor primário bem-sucedido!");
      } catch (e) {
        // Se falhar, tenta do GitHub como fallback
        WhatsappLogger.log(
            "Falha no servidor primário, tentando fallback do GitHub...");
        try {
          content = await http.read(Uri.parse(fallbackUrl));
          WhatsappLogger.log("Download do fallback bem-sucedido!");
        } catch (fallbackError) {
          throw WhatsappException(
            exceptionType: WhatsappExceptionType.failedToConnect,
            message:
                "Falha ao baixar wppconnect-wa.js de ambas as fontes: $e | $fallbackError",
          );
        }
      }
    }
    await wpClient.injectJs(content);

    WhatsappLogger.log("injected Wpp");

    if (!await _waitForWppReady(wpClient, waitTimeOut)) {
      throw WhatsappException(
        exceptionType: WhatsappExceptionType.failedToConnect,
        message: "Failed to initialize WPP",
      );
    }

    await wpClient.evaluateJs(
      "WPP.chat.defaultSendMessageOptions.createChat = true;",
      tryPromise: false,
    );
    await wpClient.evaluateJs(
      "WPP.conn.setKeepAlive(true);",
      tryPromise: false,
    );
    await wpClient.evaluateJs(
      "WPP.config.poweredBy = 'Whatsapp-Bot-Flutter';",
      tryPromise: false,
    );
  }

  static Future<bool> _waitForWppReady(
    WpClientInterface wpClient,
    Duration waitTimeOut,
  ) async {
    var startTime = DateTime.now();
    while (DateTime.now().difference(startTime) < waitTimeOut) {
      await Future.delayed(const Duration(seconds: 1));
      var result = await wpClient.evaluateJs(
        '''typeof window.WPP !== 'undefined' && window.WPP.isReady;''',
        tryPromise: false,
      );
      if (result == true) return true;
      WhatsappLogger.log("Checking WPP, Retrying..");
    }
    return false;
  }
}
