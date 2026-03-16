import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lutris_game_station/core/metadata/hash_service.dart';

void main() {
  group('HashService Tests', () {
    late File tempFile;
    const testContent = 'Hello World';
    
    // Expected hashes for "Hello World" (no newline)
    const expectedCrc32 = '411AF231';
    const expectedMd5 = 'b10a8db164e0754105b7a99be72e3fe5';
    const expectedSha1 = '0a4d55a8d778e5022fab701977c5d840bbc486d0';

    setUp(() async {
      tempFile = File('test_rom.tmp');
      await tempFile.writeAsString(testContent);
    });

    tearDown(() async {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    });

    test('Should calculate correct CRC32, MD5 and SHA1 for a small file', () async {
      final hashes = await HashService.calculateHashes(tempFile.path);

      expect(hashes.crc32, expectedCrc32);
      expect(hashes.md5, expectedMd5);
      expect(hashes.sha1, expectedSha1);
      
      print('--- Verification Results ---');
      print('File: ${tempFile.path}');
      print('Content: "$testContent"');
      print(hashes.toString());
      print('---------------------------');
    });
  });
}
