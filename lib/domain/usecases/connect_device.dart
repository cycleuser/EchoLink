import '../models/models.dart';
import '../repositories/repositories.dart';
import '../../core/result.dart';

class ConnectDevice {
  final ConnectionRepository _repository;

  ConnectDevice(this._repository);

  Future<Result<void>> call(Device device) async {
    if (device.status == DeviceStatus.connected) {
      return const Success(null);
    }

    return _repository.connect(device);
  }

  Stream<EchoLinkConnectionState> watchConnectionState() => _repository.connectionState;
}