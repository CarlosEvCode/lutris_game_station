import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:crclib/crclib.dart';
import 'package:crclib/catalog.dart';
import 'package:convert/convert.dart';

class RomHashes {
  final String crc32;
  final String md5;
  final String sha1;

  RomHashes({required this.crc32, required this.md5, required this.sha1});

  @override
  String toString() => 'CRC32: $crc32\nMD5: $md5\nSHA1: $sha1';
}

class HashService {
  /// Calculates CRC32, MD5 and SHA1 for a file in a single pass.
  /// Using streams to handle large files (ISOs) without memory issues.
  static Future<RomHashes> calculateHashes(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    // Accumulators to store the final results
    final md5Acc = AccumulatorSink<Digest>();
    final sha1Acc = AccumulatorSink<Digest>();
    final crcAcc = AccumulatorSink<CrcValue>();

    // Sinks for the chunked conversion
    final md5Sink = md5.startChunkedConversion(md5Acc);
    final sha1Sink = sha1.startChunkedConversion(sha1Acc);
    final crcSink = Crc32().startChunkedConversion(crcAcc);

    final stream = file.openRead();
    
    await for (final chunk in stream) {
      md5Sink.add(chunk);
      sha1Sink.add(chunk);
      crcSink.add(chunk);
    }

    md5Sink.close();
    sha1Sink.close();
    crcSink.close();

    final md5Hash = md5Acc.events.single.toString();
    final sha1Hash = sha1Acc.events.single.toString();
    
    // CRC32 needs to be formatted as hex (8 chars)
    final crc32Val = crcAcc.events.single;
    final crc32Hash = crc32Val.toRadixString(16).toUpperCase().padLeft(8, '0');

    return RomHashes(
      crc32: crc32Hash,
      md5: md5Hash,
      sha1: sha1Hash,
    );
  }
}
