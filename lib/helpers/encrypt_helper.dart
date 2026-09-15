import 'dart:convert';
import 'package:encrypt/encrypt.dart';

class EncryptHelper {
  //
  static String encrypt(String text, String key) {
    if (text.isEmpty) return text;
    final encrypter = Encrypter(AES(Key.fromUtf8(key.substring(0, 32))));
    final iv = IV.fromSecureRandom(16);

    final String encodedIv = base64.encode(iv.bytes);
    final String encodedText = encrypter.encrypt(text, iv: iv).base64;

    return '$encodedIv:$encodedText';
  }

  static String decrypt(String encryptedText, String key) {
    if (encryptedText.isEmpty) return encryptedText;

    try {
      final List<String> parts = encryptedText.split(':');
      if (parts.length != 2) {
        return encryptedText;
      }

      final String encodedIv = parts[0];
      final String encodedText = parts[1];

      // Base64 representation of a 16-byte IV is always 24 characters
      if (encodedIv.length != 24) {
        return encryptedText;
      }

      final iv = IV.fromBase64(encodedIv);
      final keyString = key.length >= 32 ? key.substring(0, 32) : key.padRight(32, '0');
      final encrypter = Encrypter(AES(Key.fromUtf8(keyString)));

      return encrypter.decrypt64(encodedText, iv: iv);
    } catch (_) {
      // If decryption fails, it was plain text or couldn't be decrypted
      return encryptedText;
    }
  }
}

// import 'package:encrypt/encrypt.dart';

// class EncryptHelper {
//   static final _iv = IV.fromLength(16);
//   static final _encrypter = Encrypter(AES(Key.fromLength(32)));

//   static String encrypt(String text) {
//     return _encrypter.encrypt(text, iv: _iv).base64;
//   }

//   static String decrypt(String encryptedText) {
//     if (encryptedText.isEmpty) return encryptedText;
//     final encrypted = Encrypted.fromBase64(encryptedText);
//     return _encrypter.decrypt(encrypted, iv: _iv);
//     //return _encrypter.decrypt64(encryptedText, iv: _iv);
//   }
// }
