import 'package:gotrue/gotrue.dart';
import 'package:web/web.dart' as web;

GotrueAsyncStorage? createPkceStorage() => _WebLocalStorage();

class _WebLocalStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async {
    return web.window.localStorage.getItem(key);
  }

  @override
  Future<void> removeItem({required String key}) async {
    web.window.localStorage.removeItem(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    web.window.localStorage.setItem(key, value);
  }
}
