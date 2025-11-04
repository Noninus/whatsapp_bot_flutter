import 'dart:convert';
import 'package:whatsapp_bot_platform_interface/whatsapp_bot_platform_interface.dart';

class WppChat {
  WpClientInterface wpClient;
  WppChat(this.wpClient);

  Future openChatAt({
    required String phone,
    required MessageId messageId,
  }) =>
      wpClient.evaluateJs(
          'WPP.chat.openChatAt(${phone.phoneParse}, ${messageId.serialized.jsParse});');

  /// [sendMessage] may throw errors if passed an invalid contact
  /// or if this method completed without any issue , then probably message sent successfully
  /// add `replyMessageId` to quote message
  Future sendTextMessage({
    required String phone,
    required String message,
    String? templateTitle,
    String? templateFooter,
    bool useTemplate = false,
    List<MessageButtons>? buttons,
    MessageId? replyMessageId,
  }) async {
    String? replyText = replyMessageId?.serialized;
    String? buttonsText = buttons?.map((e) => e.toJson()).toList().toString();
    return await wpClient.evaluateJs(
        '''WPP.chat.sendTextMessage(${phone.phoneParse}, ${message.jsParse}, {
            quotedMsg: ${replyText.jsParse},
            useTemplateButtons: ${useTemplate.jsParse},
            buttons:$buttonsText,
            title: ${templateTitle.jsParse},
            footer: ${templateFooter.jsParse}
          });''',
        methodName: "sendTextMessage");
  }

  ///send file messages using [sendFileMessage]
  /// make sure to send fileType , we can also pass optional mimeType
  /// `replyMessageId` will send a quote message to the given messageId
  /// add `caption` to attach a text with the file
  Future sendFileMessage({
    required String phone,
    required WhatsappFileType fileType,
    required List<int> fileBytes,
    String? fileName,
    String? caption,
    String? mimetype,
    MessageId? replyMessageId,
    String? templateTitle,
    String? templateFooter,
    bool useTemplate = false,
    bool isViewOnce = false,
    bool audioAsPtt = false,
    List<MessageButtons>? buttons,
  }) async {
    String base64Image = base64Encode(fileBytes);
    String mimeType = mimetype ?? getMimeType(fileType, fileName, fileBytes);
    String fileData = "data:$mimeType;base64,$base64Image";

    String fileTypeName = "image";
    if (mimeType.split("/").length > 1) {
      fileTypeName = mimeType.split("/").first;
    }

    // Check for video file type
    if (fileTypeName == "video") {
      fileTypeName = "video"; // Set the correct file type for videos
    }

    String? replyTextId = replyMessageId?.serialized;
    String? buttonsText = buttons?.map((e) => e.toJson()).toList().toString();

    String source =
        '''WPP.chat.sendFileMessage(${phone.phoneParse},${fileData.jsParse},{
    type: ${fileTypeName.jsParse},
    isPtt: ${audioAsPtt.jsParse},
    isViewOnce: ${isViewOnce.jsParse},
    filename: ${fileName.jsParse},
    caption: ${caption.jsParse},
    quotedMsg: ${replyTextId.jsParse},
    useTemplateButtons: ${useTemplate.jsParse},
    buttons:$buttonsText,
    title: ${templateTitle.jsParse},
    footer: ${templateFooter.jsParse}
  });''';

    var sendResult = await wpClient.evaluateJs(source);
    WhatsappLogger.log("SendResult : $sendResult");
    return sendResult;
  }

  Future sendContactCard({
    required String phone,
    required String contactPhone,
    required String contactName,
  }) async {
    return await wpClient
        .evaluateJs('''WPP.chat.sendVCardContactMessage(${phone.phoneParse}, {
            id: ${contactPhone.phoneParse},
            name: ${contactName.jsParse}
          });''', methodName: "sendContactCard");
  }

  ///send a locationMessage using [sendLocationMessage]
  Future sendLocationMessage({
    required String phone,
    required String lat,
    required String long,
    String? name,
    String? address,
    String? url,
  }) async {
    return await wpClient
        .evaluateJs('''WPP.chat.sendLocationMessage(${phone.phoneParse}, {
              lat: ${lat.jsParse},
              lng: ${long.jsParse},
              name: ${name.jsParse},
              address: ${address.jsParse},
              url: ${url.jsParse},
            });
            ''', methodName: "sendLocationMessage");
  }

  ///Pass phone with correct format in [archive] , and
  ///archive = true to archive , and false to unarchive
  Future<void> archive({required String phone, bool archive = true}) async {
    return await wpClient.evaluateJs(
      '''WPP.chat.archive(${phone.phoneParse}, $archive);''',
      methodName: "Archive",
    );
  }

  /// check if the given Phone number is a valid phone number
  Future<bool> isValidContact({required String phone}) async {
    await wpClient.evaluateJs(
      '''WPP.contact.queryExists(${phone.phoneParse});''',
      methodName: "isValidContact",
    );
    // return true by default , it will crash on any issue
    return true;
  }

  /// to check if we [canMute] phone number
  Future<bool> canMute({required String phone}) async =>
      await wpClient.evaluateJs('''WPP.chat.canMute(${phone.phoneParse});''',
          methodName: "CanMute");

  /// Mute a chat, you can use  expiration and use unix timestamp (seconds only)
  /// or duration (in seconds )
  Future mute({
    required String phone,
    int? duration,
    int? expirationUnixTimeStamp,
  }) async {
    if (!await canMute(phone: phone)) throw "Cannot Mute $phone";
    if (duration != null) {
      return wpClient.evaluateJs(
        '''WPP.chat.mute(${phone.phoneParse},{duration: $duration});''',
        methodName: "Mute",
      );
    } else if (expirationUnixTimeStamp != null) {
      return wpClient.evaluateJs(
        '''WPP.chat.mute(${phone.phoneParse},{expiration: $expirationUnixTimeStamp});''',
        methodName: "Mute",
      );
    }
    throw Exception("duration or expiration must be provided");
  }

  /// Un mute chat
  Future unmute({required String phone}) async {
    return await wpClient.evaluateJs(
        '''WPP.chat.unmute(${phone.phoneParse});''',
        methodName: "unmute");
  }

  /// [clear] chat
  Future clear({
    required String phone,
    bool keepStarred = false,
  }) async =>
      await wpClient.evaluateJs(
          '''WPP.chat.clear(${phone.phoneParse},$keepStarred);''',
          methodName: "ClearChat");

  /// [delete] chat
  Future delete({
    required String phone,
  }) async =>
      await wpClient.evaluateJs('''WPP.chat.delete(${phone.phoneParse});''',
          methodName: "DeleteChat");

  ///Get timestamp of last seen using [getLastSeen]
  /// return either a timestamp or 0 if last seen off
  Future<int?> getLastSeen({required String phone}) async {
    var lastSeen = await wpClient.evaluateJs(
        '''WPP.chat.getLastSeen(${phone.phoneParse});''',
        methodName: "GetLastSeen");
    if (lastSeen.runtimeType == bool) return lastSeen ? 1 : 0;
    if (lastSeen.runtimeType == int) return lastSeen;
    return null;
  }

  /// get all Chats using [getChats]
  Future getChats({
    bool onlyUser = false,
    bool onlyGroups = false,
  }) =>
      wpClient.evaluateJs(
        '''WPP.chat.list({
            onlyUsers: ${onlyUser.jsParse},
            onlyGroups: ${onlyGroups.jsParse}
         });''',
        methodName: "GetChats",
        forceJsonParseResult: true,
      );

  ///Mark a chat as read and send SEEN event
  Future markAsSeen({required String phone}) async {
    return await wpClient.evaluateJs(
      '''WPP.chat.markIsRead(${phone.phoneParse});''',
      methodName: "MarkIsRead",
    );
  }

  Future markIsComposing({required String phone, int timeout = 5000}) async {
    await wpClient.evaluateJs(
      '''WPP.chat.markIsComposing(${phone.phoneParse});''',
      methodName: "markIsComposing",
    );

    // Wait for the timeout period.
    await Future.delayed(Duration(milliseconds: timeout));

    // Mark the chat as paused.
    await wpClient.evaluateJs(
      '''WPP.chat.markIsPaused(${phone.phoneParse});''',
      methodName: "markIsPaused",
    );
  }

  Future markIsRecording({required String phone, int timeout = 5000}) async {
    await wpClient.evaluateJs(
      '''WPP.chat.markIsRecording(${phone.phoneParse});''',
      methodName: "markIsRecording",
    );

    // Wait for the timeout period.
    await Future.delayed(Duration(milliseconds: timeout));

    // Mark the chat as paused.
    await wpClient.evaluateJs(
      '''WPP.chat.markIsPaused(${phone.phoneParse});''',
      methodName: "markIsPaused",
    );
  }

  ///Mark a chat as unread
  Future markAsUnread({required String phone}) async {
    return await wpClient.evaluateJs(
      '''WPP.chat.markIsUnread(${phone.phoneParse});''',
      methodName: "MarkIsUnread",
    );
  }

  ///pin/unpin to chat
  Future pin({required String phone, bool pin = true}) async {
    return await wpClient.evaluateJs(
      '''WPP.chat.pin(${phone.phoneParse},$pin);''',
      methodName: "pin",
    );
  }

  /// Delete message
  /// Set revoke: true if you want to delete for everyone in group chat
  Future deleteMessage({
    required String phone,
    required String messageId,
    bool deleteMediaInDevice = false,
    bool revoke = false,
  }) async {
    return await wpClient.evaluateJs(
      '''WPP.chat.deleteMessage(${phone.phoneParse},${messageId.jsParse}, $deleteMediaInDevice, $revoke);''',
      methodName: "deleteMessage",
    );
  }

  /// Download the base64 of a media message
  Future<Map<String, dynamic>?> downloadMedia({
    required MessageId messageId,
  }) async {
    String? mediaSerialized = messageId.serialized;
    String? base64 = await wpClient.evaluateJs(
      '''WPP.chat.downloadMedia(${mediaSerialized.jsParse}).then(WPP.util.blobToBase64);''',
      methodName: "downloadMedia",
    );
    if (base64 == null) return null;
    return base64ToMap(base64);
  }

  /// Fetch messages from a chat
  Future getMessages({required String phone, int count = -1}) async {
    return await wpClient.evaluateJs(
      '''WPP.chat.getMessages(${phone.phoneParse},{count: $count,});''',
      methodName: "getMessages",
      forceJsonParseResult: true,
    );
  }

  /// Send a create poll message , Note: This only works for groups
  Future sendCreatePollMessage(
      {required String phone,
      required String pollName,
      required List<String> pollOptions}) async {
    return await wpClient.evaluateJs(
      '''WPP.chat.sendCreatePollMessage(${phone.phoneParse},${pollName.jsParse},${pollOptions.jsParse});''',
      methodName: "sendCreatePollMessage",
    );
  }

  /// [rejectCall] will reject incoming call
  Future rejectCall({String? callId}) async {
    return await wpClient.evaluateJs(
      '''WPP.call.rejectCall(${callId.jsParse});''',
      methodName: "RejectCallResult",
    );
  }

  /// Emoji list: https://unicode.org/emoji/charts/full-emoji-list.html
  /// To remove reaction, set [emoji] to null
  Future sendReactionToMessage({
    required MessageId messageId,
    String? emoji,
  }) async {
    String? serialized = messageId.serialized;
    return await wpClient.evaluateJs(
      '''WPP.chat.sendReactionToMessage(${serialized.jsParse}, ${emoji != null ? emoji.jsParse : false});''',
      methodName: "sendReactionToMessage",
    );
  }

  /// [forwardTextMessage] may throw errors if passed an invalid contact
  /// or if this method completed without any issue , then probably message sent successfully
  Future forwardTextMessage({
    required String phone,
    required MessageId messageId,
    bool displayCaptionText = false,
    bool multicast = false,
  }) async {
    String? serialized = messageId.serialized;
    return await wpClient.evaluateJs(
        '''WPP.chat.forwardMessage(${phone.phoneParse}, ${serialized.jsParse}, {
            displayCaptionText: $displayCaptionText,
            multicast: $multicast,
          });''',
        methodName: "forwardMessage");
  }

  // ==================== NOVOS MÉTODOS PARA LID ==================== //

  /// Request the real phone number for a LID chat (@lid format)
  /// This method uses WPP.chat.requestPhoneNumber to get the actual phone number
  Future<String?> requestPhoneNumber({required String lidJid}) async {
    try {
      var result = await wpClient.evaluateJs(
        '''WPP.chat.requestPhoneNumber(${lidJid.jsParse});''',
        methodName: "requestPhoneNumber",
      );

      // O resultado pode vir em diferentes formatos dependendo da versão do wa-js
      if (result != null) {
        // Se for string, retorna diretamente
        if (result is String) return result;

        // Se for Map, tenta extrair o campo 'to' ou 'phone'
        if (result is Map) {
          return result['to']?.toString() ?? result['phone']?.toString();
        }
      }
    } catch (e) {
      WhatsappLogger.log("Erro ao requisitar número de telefone: $e");
    }
    return null;
  }

  /// Get phone number from LID using multiple wa-js methods
  /// This is a more robust approach that tries different ways to resolve @lid to phone number
  Future<String?> resolvePhoneFromLid({required String lidJid}) async {
    try {
      var result = await wpClient.evaluateJs(
        '''
        (async function() {
          try {
            const jid = ${lidJid.jsParse};
            
            // Método 1: Tentar obter informações do contato
            try {
              const contact = await WPP.contact.get(jid);
              if (contact && contact.id && contact.id._serialized) {
                return contact.id._serialized;
              }
            } catch (e) {
              console.log("Método 1 falhou:", e);
            }
            
            // Método 2: Usar WPP.contact.getPhoneNumber se disponível
            try {
              if (WPP.contact.getPhoneNumber) {
                const phoneNumber = await WPP.contact.getPhoneNumber(jid);
                if (phoneNumber) {
                  return phoneNumber;
                }
              }
            } catch (e) {
              console.log("Método 2 falhou:", e);
            }
            
            // Método 3: Usar requestPhoneNumber
            try {
              const result = await WPP.chat.requestPhoneNumber(jid);
              if (result && result.to) {
                return result.to;
              }
              return result;
            } catch (e) {
              console.log("Método 3 falhou:", e);
            }
            
            // Método 4: Tentar buscar na lista de contatos
            try {
              const contacts = await WPP.contact.list();
              const foundContact = contacts.find(contact => 
                contact.id && contact.id._serialized === jid
              );
              if (foundContact && foundContact.formattedName) {
                return foundContact.id._serialized;
              }
            } catch (e) {
              console.log("Método 4 falhou:", e);
            }
            
            return null;
          } catch (error) {
            console.log("Erro geral ao resolver LID:", error);
            return null;
          }
        })();
        ''',
        methodName: "resolvePhoneFromLid",
      );

      return result?.toString();
    } catch (e) {
      WhatsappLogger.log("Erro ao resolver telefone do LID: $e");
    }
    return null;
  }

  /// Extract phone number from any JID format (@c.us or @lid)
  /// For @c.us: extracts directly
  /// For @lid: uses wa-js methods to resolve to phone number
  Future<String?> extractPhoneNumber({required String jid}) async {
    try {
      if (jid.contains('@c.us')) {
        // Formato antigo - extrair diretamente
        return jid.split('@')[0];
      }

      if (jid.contains('@lid')) {
        // Formato novo - usar wa-js para resolver
        return await resolvePhoneFromLid(lidJid: jid);
      }

      // Se não tem @ no final, pode ser só o número
      if (!jid.contains('@')) {
        return jid;
      }
    } catch (e) {
      WhatsappLogger.log("Erro ao extrair número de telefone: $e");
    }
    return null;
  }

  /// Check if a JID is in LID format (@lid)
  bool isLidFormat({required String jid}) {
    return jid.contains('@lid');
  }

  /// Check if a JID is in classic format (@c.us)
  bool isClassicFormat({required String jid}) {
    return jid.contains('@c.us');
  }

  /// Get contact information including phone mapping for LID
  Future<Map<String, dynamic>?> getContactInfo({required String jid}) async {
    try {
      var result = await wpClient.evaluateJs(
        '''
        (async function() {
          try {
            const jid = ${jid.jsParse};
            const contact = await WPP.contact.get(jid);
            
            if (contact) {
              return {
                id: contact.id ? contact.id._serialized : null,
                name: contact.name || contact.formattedName || null,
                pushname: contact.pushname || null,
                isMyContact: contact.isMyContact || false,
                isWAContact: contact.isWAContact || false,
                originalJid: jid
              };
            }
            return null;
          } catch (error) {
            console.log("Erro ao obter informações do contato:", error);
            return null;
          }
        })();
        ''',
        methodName: "getContactInfo",
        forceJsonParseResult: true,
      );

      if (result is Map<String, dynamic>) {
        return result;
      }
    } catch (e) {
      WhatsappLogger.log("Erro ao obter informações do contato: $e");
    }
    return null;
  }

  /// Batch resolve multiple JIDs to phone numbers (useful for optimization)
  Future<Map<String, String?>> batchResolvePhoneNumbers({
    required List<String> jids,
  }) async {
    Map<String, String?> results = {};

    try {
      var result = await wpClient.evaluateJs(
        '''
        (async function() {
          const jids = ${jsonEncode(jids)};
          const results = {};
          
          for (const jid of jids) {
            try {
              if (jid.includes('@c.us')) {
                // Formato antigo - extrair diretamente
                results[jid] = jid.split('@')[0];
              } else if (jid.includes('@lid')) {
                // Tentar resolver LID
                try {
                  const contact = await WPP.contact.get(jid);
                  if (contact && contact.id && contact.id._serialized) {
                    results[jid] = contact.id._serialized;
                    continue;
                  }
                } catch (e) {}
                
                try {
                  const result = await WPP.chat.requestPhoneNumber(jid);
                  if (result && result.to) {
                    results[jid] = result.to;
                    continue;
                  }
                } catch (e) {}
                
                results[jid] = null;
              } else {
                results[jid] = jid.includes('@') ? null : jid;
              }
            } catch (error) {
              console.log("Erro ao processar JID:", jid, error);
              results[jid] = null;
            }
          }
          
          return results;
        })();
        ''',
        methodName: "batchResolvePhoneNumbers",
        forceJsonParseResult: true,
      );

      if (result is Map) {
        result.forEach((key, value) {
          results[key.toString()] = value?.toString();
        });
      }
    } catch (e) {
      WhatsappLogger.log("Erro ao resolver JIDs em lote: $e");
    }

    return results;
  }
}
