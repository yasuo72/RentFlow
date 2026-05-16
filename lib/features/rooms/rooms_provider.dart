import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/room_model.dart';
import '../../data/repositories/room_repository.dart';

final roomsProvider = AsyncNotifierProvider<RoomsController, List<RoomModel>>(
  RoomsController.new,
);

final roomDetailProvider = FutureProvider.family<RoomModel, String>((
  ref,
  roomId,
) async {
  return ref.read(roomRepositoryProvider).fetchRoom(roomId);
});

class RoomsController extends AsyncNotifier<List<RoomModel>> {
  @override
  Future<List<RoomModel>> build() {
    return ref.read(roomRepositoryProvider).fetchRooms();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(roomRepositoryProvider).fetchRooms(),
    );
  }
}
