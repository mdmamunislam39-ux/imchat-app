import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse('https://firestore.googleapis.com/v1/projects/imchat-84519/databases/(default)/documents/global_settings/app_theme');
  final request = await HttpClient().getUrl(url);
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  print(responseBody);
}
