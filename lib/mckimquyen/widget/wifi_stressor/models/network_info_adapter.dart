import 'package:hive/hive.dart';
import 'network_info.dart';

/// Manual Hive adapter cho NetworkInfo
class NetworkInfoAdapter extends TypeAdapter<NetworkInfo> {
  @override
  final int typeId = 0;

  @override
  NetworkInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NetworkInfo(
      ssid: fields[0] as String?,
      signalStrength: fields[1] as int?,
      frequency: fields[2] as String?,
      ipAddress: fields[3] as String?,
      channel: fields[4] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, NetworkInfo obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.ssid)
      ..writeByte(1)
      ..write(obj.signalStrength)
      ..writeByte(2)
      ..write(obj.frequency)
      ..writeByte(3)
      ..write(obj.ipAddress)
      ..writeByte(4)
      ..write(obj.channel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
