import '../models/models.dart';
import '../repositories/repositories.dart';
import '../../core/result.dart';

class DiscoverDevices {
  final ConnectionRepository _repository;

  DiscoverDevices(this._repository);

  Future<Result<List<Device>>> call() async {
    final startResult = await _repository.startDiscovery();
    if (startResult.isFailure) {
      return Failure(startResult.error);
    }

    await Future.delayed(const Duration(seconds: 3));

    return _repository.getDiscoveredDevices();
  }

  Stream<Device> watch() => _repository.discoveredDevices;
}