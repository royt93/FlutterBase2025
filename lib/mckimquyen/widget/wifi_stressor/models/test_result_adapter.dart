import 'package:hive/hive.dart';
import 'test_result.dart';
import 'network_info.dart';

/// Manual Hive adapter cho TestResult
class TestResultAdapter extends TypeAdapter<TestResult> {
  @override
  final int typeId = 1;

  @override
  TestResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TestResult(
      id: fields[0] as String,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime?,
      avgSpeed: fields[3] as double,
      peakSpeed: fields[4] as double,
      minSpeed: fields[5] as double,
      medianSpeed: fields[6] as double,
      speedHistory: (fields[7] as List).cast<double>(),
      status: fields[8] as String,
      networkInfo: fields[9] as NetworkInfo?,
      totalDownloadedBytes: fields[10] as int,
      downloadCount: fields[11] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TestResult obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.avgSpeed)
      ..writeByte(4)
      ..write(obj.peakSpeed)
      ..writeByte(5)
      ..write(obj.minSpeed)
      ..writeByte(6)
      ..write(obj.medianSpeed)
      ..writeByte(7)
      ..write(obj.speedHistory)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.networkInfo)
      ..writeByte(10)
      ..write(obj.totalDownloadedBytes)
      ..writeByte(11)
      ..write(obj.downloadCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
