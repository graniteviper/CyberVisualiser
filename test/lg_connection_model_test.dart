import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cyber_visualiser/services/lg_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LgConnectionModel', () {
    test('updateConnection updates values correctly', () {
      final model = LgConnectionModel();
      model.updateConnection(
        ip: '192.168.1.100',
        port: 2222,
        username: 'test',
        password: 'secret',
        screens: 4,
      );

      expect(model.ip, '192.168.1.100');
      expect(model.port, 2222);
      expect(model.username, 'test');
      expect(model.password, 'secret');
      expect(model.screens, 4);
    });

    test('saveToPreferences and loadFromPreferences persist values', () async {
      SharedPreferences.setMockInitialValues({});
      final model = LgConnectionModel(
        ip: '127.0.0.1',
        port: 2200,
        username: 'lg',
        password: 'pass123',
        screens: 5,
      );

      await model.saveToPreferences();
      final loaded = await LgConnectionModel.loadFromPreferences();

      expect(loaded.ip, '127.0.0.1');
      expect(loaded.port, 2200);
      expect(loaded.username, 'lg');
      expect(loaded.password, 'pass123');
      expect(loaded.screens, 5);
    });
  });

  group('LgService', () {
    test('calculateRightMostScreen and calculateLeftMostScreen return correct values', () {
      final service = LgService();

      expect(service.calculateRightMostScreen(1), 1);
      expect(service.calculateRightMostScreen(5), 3);
      expect(service.calculateLeftMostScreen(1), 1);
      expect(service.calculateLeftMostScreen(5), 4);
    });

    test('saveConnectionSettings persists service connection settings', () async {
      SharedPreferences.setMockInitialValues({});
      final service = LgService();
      service.updateConnectionSettings(
        ip: '10.0.0.10',
        port: 2201,
        username: 'lg',
        password: 'secret',
        screens: 3,
      );

      await service.saveConnectionSettings();
      final loaded = await LgConnectionModel.loadFromPreferences();

      expect(loaded.ip, '10.0.0.10');
      expect(loaded.port, 2201);
      expect(loaded.username, 'lg');
      expect(loaded.password, 'secret');
      expect(loaded.screens, 3);
    });
  });
}
