import 'dart:async';

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
  Future<List<RoomModel>> build() async {
    final repository = ref.read(roomRepositoryProvider);
    final cached = repository.readCachedRooms();

    if (cached != null) {
      Future.microtask(() => refresh(silent: true));
      return cached;
    }

    return repository.fetchRooms();
  }

  Future<void> refresh({bool silent = false}) async {
    final previous = state.asData?.value;

    try {
      final fresh = await ref.read(roomRepositoryProvider).fetchRooms();
      state = AsyncData(fresh);
    } catch (error, stackTrace) {
      if (!silent || previous == null) {
        state = AsyncError(error, stackTrace);
      }
    }
  }
}
