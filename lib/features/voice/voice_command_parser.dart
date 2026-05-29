import '../../data/models/room_model.dart';
import '../../data/models/tenant_model.dart';

enum VoiceCommandType {
  recordPayment,
  addDue,
  addExpense,
  navigate,
  showRooms,
  openDocument,
  uploadDocument,
  callTenant,
  sendWhatsAppReminder,
  unknown,
}

class VoiceCommandIntent {
  const VoiceCommandIntent({
    required this.type,
    required this.transcript,
    this.room,
    this.amount,
    this.paymentMethod = 'cash',
    this.expenseCategory = 'maintenance',
    this.roomFilter = 'all',
    this.tenant,
    this.document,
    this.documentType,
    this.route,
    this.message,
  });

  final VoiceCommandType type;
  final String transcript;
  final RoomModel? room;
  final num? amount;
  final String paymentMethod;
  final String expenseCategory;
  final String roomFilter;
  final TenantModel? tenant;
  final TenantDocument? document;
  final String? documentType;
  final String? route;
  final String? message;

  bool get canExecute {
    return switch (type) {
      VoiceCommandType.recordPayment ||
      VoiceCommandType.addDue => room != null && amount != null && amount! > 0,
      VoiceCommandType.addExpense => amount != null && amount! > 0,
      VoiceCommandType.navigate => route != null,
      VoiceCommandType.showRooms => true,
      VoiceCommandType.openDocument => tenant != null && document != null,
      VoiceCommandType.uploadDocument => tenant != null && route != null,
      VoiceCommandType.sendWhatsAppReminder =>
        tenant != null && _hasContactNumber(tenant!),
      VoiceCommandType.callTenant =>
        tenant != null && tenant!.phone.trim().isNotEmpty,
      VoiceCommandType.unknown => false,
    };
  }

  bool _hasContactNumber(TenantModel tenant) {
    return tenant.whatsappNumber?.trim().isNotEmpty == true ||
        tenant.phone.trim().isNotEmpty;
  }
}

class VoiceCommandParser {
  const VoiceCommandParser._();

  static VoiceCommandIntent parse({
    required String transcript,
    required List<RoomModel> rooms,
    required List<TenantModel> tenants,
  }) {
    final normalized = _normalize(transcript);

    if (normalized.trim().isEmpty) {
      return VoiceCommandIntent(
        type: VoiceCommandType.unknown,
        transcript: transcript,
        message: 'Please say a command first.',
      );
    }

    final tenant = _matchTenant(normalized, tenants);
    final matchedRoom = _matchRoom(normalized, rooms);
    final roomTenant = _tenantForRoom(matchedRoom, tenants);
    final commandTenant = tenant ?? roomTenant;
    final documentType = _documentTypeFor(normalized);

    if (_isMissingDocumentsQuery(normalized)) {
      return VoiceCommandIntent(
        type: VoiceCommandType.showRooms,
        transcript: transcript,
        roomFilter: 'missing_documents',
        route: '/rooms?filter=missing_documents',
      );
    }

    if (_isDocumentUploadCommand(normalized)) {
      final type = documentType ?? 'other';
      return VoiceCommandIntent(
        type: VoiceCommandType.uploadDocument,
        transcript: transcript,
        tenant: commandTenant,
        documentType: type,
        route: commandTenant == null
            ? null
            : '/tenant-document-upload/${commandTenant.id}?type=$type',
        message: commandTenant == null
            ? 'I heard document upload, but not the tenant name.'
            : 'Upload page will open for ${commandTenant.fullName}.',
      );
    }

    if (_isDocumentCommand(normalized)) {
      if (commandTenant == null) {
        return VoiceCommandIntent(
          type: VoiceCommandType.navigate,
          transcript: transcript,
          route: '/tenants',
          message:
              'I heard document, but not the tenant name. Opening tenant list.',
        );
      }

      final document = _documentFor(
        tenant: commandTenant,
        documentType: documentType,
      );

      if (document == null) {
        final type = documentType == null || documentType == 'document'
            ? 'other'
            : documentType;
        return VoiceCommandIntent(
          type: VoiceCommandType.uploadDocument,
          transcript: transcript,
          tenant: commandTenant,
          documentType: type,
          route: '/tenant-document-upload/${commandTenant.id}?type=$type',
          message:
              '${commandTenant.fullName} ke ${documentType ?? 'document'} uploaded nahi hain. Upload page open hoga.',
        );
      }

      return VoiceCommandIntent(
        type: VoiceCommandType.openDocument,
        transcript: transcript,
        tenant: commandTenant,
        document: document,
        documentType: documentType,
      );
    }

    if (commandTenant != null && _isTenantDetailCommand(normalized)) {
      return VoiceCommandIntent(
        type: VoiceCommandType.navigate,
        transcript: transcript,
        tenant: commandTenant,
        route: '/tenants/${commandTenant.id}',
        message: '${commandTenant.fullName} profile will open.',
      );
    }

    if (_isPaymentQrCommand(normalized)) {
      return VoiceCommandIntent(
        type: VoiceCommandType.navigate,
        transcript: transcript,
        route: '/payment-qr',
        message: 'Payment QR will open.',
      );
    }

    if (commandTenant != null && _isWhatsAppReminderCommand(normalized)) {
      return VoiceCommandIntent(
        type: VoiceCommandType.sendWhatsAppReminder,
        transcript: transcript,
        tenant: commandTenant,
        amount: _amountFor(normalized),
        message: 'WhatsApp reminder will open for ${commandTenant.fullName}.',
      );
    }

    if (_isCallCommand(normalized)) {
      return VoiceCommandIntent(
        type: VoiceCommandType.callTenant,
        transcript: transcript,
        tenant: commandTenant,
        message: commandTenant == null
            ? 'I heard call, but not the tenant name.'
            : null,
      );
    }

    final roomFilter = _roomFilterFor(normalized);
    if (roomFilter != null) {
      return VoiceCommandIntent(
        type: VoiceCommandType.showRooms,
        transcript: transcript,
        roomFilter: roomFilter,
        route: '/rooms?filter=$roomFilter',
      );
    }

    final navigationRoute = _routeFor(normalized);
    if (navigationRoute != null) {
      return VoiceCommandIntent(
        type: VoiceCommandType.navigate,
        transcript: transcript,
        route: navigationRoute,
      );
    }

    final room = matchedRoom;
    final amount = _amountFor(normalized, roomNumber: room?.roomNumber);

    if (_isExpenseCommand(normalized)) {
      return VoiceCommandIntent(
        type: VoiceCommandType.addExpense,
        transcript: transcript,
        amount: amount,
        expenseCategory: _expenseCategoryFor(normalized),
        message: amount == null ? 'I heard expense, but not the amount.' : null,
      );
    }

    if (_isDueCommand(normalized)) {
      return VoiceCommandIntent(
        type: VoiceCommandType.addDue,
        transcript: transcript,
        room: room,
        amount: amount,
        paymentMethod: _paymentMethodFor(normalized),
        message: _roomOrAmountMessage(room, amount),
      );
    }

    if (_isPaymentCommand(normalized) || room != null || amount != null) {
      final paymentAmount = _paymentAmountFor(normalized, room, amount);
      final inferredAmount = amount == null && paymentAmount != null;
      final message = _roomOrAmountMessage(room, paymentAmount);
      return VoiceCommandIntent(
        type: VoiceCommandType.recordPayment,
        transcript: transcript,
        room: room,
        amount: paymentAmount,
        paymentMethod: _paymentMethodFor(normalized),
        message: message.isNotEmpty
            ? message
            : inferredAmount
            ? 'Amount auto-filled from current pending rent.'
            : '',
      );
    }

    return VoiceCommandIntent(
      type: VoiceCommandType.unknown,
      transcript: transcript,
      message: 'Try saying: "Room 101 ka 2500 cash payment add karo".',
    );
  }

  static TenantModel? _tenantForRoom(
    RoomModel? room,
    List<TenantModel> tenants,
  ) {
    final roomTenantId = room?.currentTenant?.id;
    if (roomTenantId == null || roomTenantId.isEmpty) {
      return null;
    }

    for (final tenant in tenants) {
      if (tenant.id == roomTenantId) {
        return tenant;
      }
    }

    return null;
  }

  static String _roomOrAmountMessage(RoomModel? room, num? amount) {
    if (room == null && amount == null) {
      return 'I need the room or tenant name, and the amount.';
    }
    if (room == null) {
      return 'I heard the amount, but not the room or tenant name.';
    }
    if (amount == null || amount <= 0) {
      return 'I found the room, but not the amount.';
    }
    if (!room.isOccupied || room.currentTenant == null) {
      return 'That room is vacant. Assign a tenant before recording rent.';
    }
    return '';
  }

  static num? _paymentAmountFor(String text, RoomModel? room, num? amount) {
    if (amount != null && amount > 0) {
      return amount;
    }
    if (room == null || !_impliesFullPayment(text)) {
      return amount;
    }

    final payment = room.currentMonthPayment;
    final remaining = payment?.remainingAmount ?? 0;
    final totalDue = payment?.totalDue ?? 0;
    final carriedAndRent =
        (payment?.monthlyRentDue ?? room.monthlyRent) +
        (payment?.carriedForwardAmount ?? 0) +
        (payment?.manualDueAmount ?? 0);

    if (remaining > 0) {
      return remaining;
    }
    if (totalDue > 0) {
      return totalDue;
    }
    if (carriedAndRent > 0) {
      return carriedAndRent;
    }
    return room.monthlyRent;
  }

  static bool _impliesFullPayment(String text) {
    return _containsAny(text, const [
      'paid',
      'de diya',
      'diya',
      'diye',
      'jama ho gaya',
      'jama kar diya',
      'clear',
      'cleared',
      'full',
      'complete',
      'kiraya de diya',
      'rent de diya',
      'पे कर दिया',
      'दे दिया',
      'दिया',
      'जमा',
      'पूरा',
      'भर दिया',
    ]);
  }

  static RoomModel? _matchRoom(String text, List<RoomModel> rooms) {
    final sorted = [...rooms]
      ..sort((a, b) => b.roomNumber.length.compareTo(a.roomNumber.length));

    for (final room in sorted) {
      final roomNumber = _normalize(room.roomNumber);
      final escaped = RegExp.escape(roomNumber);
      final hasRoomKeyword = RegExp(
        '(room|room number|room no|kamra|कमरा|रूम)\\s*$escaped\\b',
      ).hasMatch(text);
      final hasSafeNumberMatch =
          roomNumber.length >= 2 && RegExp('\\b$escaped\\b').hasMatch(text);

      if (hasRoomKeyword || hasSafeNumberMatch) {
        return room;
      }

      final tenantName = room.currentTenant?.fullName;
      if (tenantName == null || tenantName.trim().isEmpty) {
        continue;
      }

      final normalizedName = _normalize(tenantName);
      final nameParts = normalizedName
          .split(' ')
          .where((part) => part.length >= 3)
          .toList(growable: false);
      final fullNameToken = normalizedName.replaceAll(' ', '');
      final compactText = text.replaceAll(' ', '');

      if (nameParts.any(
            (part) => RegExp('\\b${RegExp.escape(part)}\\b').hasMatch(text),
          ) ||
          (fullNameToken.length >= 4 && compactText.contains(fullNameToken))) {
        return room;
      }
    }

    return null;
  }

  static TenantModel? _matchTenant(String text, List<TenantModel> tenants) {
    for (final tenant in tenants) {
      final normalizedName = _normalize(tenant.fullName);
      final compactName = normalizedName.replaceAll(' ', '');
      final compactText = text.replaceAll(' ', '');

      if (compactName.length >= 4 && compactText.contains(compactName)) {
        return tenant;
      }

      final nameParts = normalizedName
          .split(' ')
          .where((part) => part.length >= 3)
          .toList(growable: false);

      if (nameParts.any(
        (part) => RegExp('\\b${RegExp.escape(part)}\\b').hasMatch(text),
      )) {
        return tenant;
      }
    }

    return null;
  }

  static TenantDocument? _documentFor({
    required TenantModel tenant,
    required String? documentType,
  }) {
    if (tenant.documents.isEmpty) {
      return null;
    }

    if (documentType == null || documentType == 'document') {
      return tenant.documents.first;
    }

    for (final document in tenant.documents) {
      final type = _normalize(document.type);
      final name = _normalize(document.name);
      final haystack = '$type $name';
      final aliases = switch (documentType) {
        'aadhaar' => const ['aadhaar', 'aadhar', 'adhar'],
        'id' => const ['id', 'identity', 'proof'],
        'pan' => const ['pan'],
        'police' => const ['police', 'verification'],
        'agreement' => const ['agreement', 'rent agreement'],
        'profile_photo' => const ['photo', 'profile', 'image'],
        _ => [documentType],
      };
      if (aliases.any(haystack.contains)) {
        return document;
      }
    }

    return null;
  }

  static num? _amountFor(String text, {String? roomNumber}) {
    final numbers = RegExp(r'\d+(?:\.\d+)?')
        .allMatches(text)
        .map((match) => num.tryParse(match.group(0)!))
        .whereType<num>()
        .toList();
    final normalizedRoomNumber = roomNumber == null
        ? null
        : num.tryParse(_normalize(roomNumber).replaceAll(RegExp(r'\D'), ''));

    if (numbers.isNotEmpty) {
      final amountCandidates = [...numbers];
      if (normalizedRoomNumber != null) {
        amountCandidates.remove(normalizedRoomNumber);
      }
      return (amountCandidates.isNotEmpty ? amountCandidates : numbers).last;
    }

    return _wordAmountFor(text);
  }

  static bool _isPaymentCommand(String text) {
    return _containsAny(text, const [
      'rent',
      'payment',
      'paid',
      'pay',
      'received',
      'collection',
      'kiraya',
      'diya',
      'diye',
      'liya',
      'jama',
      'किराया',
      'पेमेंट',
      'दिया',
      'दिये',
      'लिया',
      'जमा',
      'भरा',
    ]);
  }

  static bool _isDueCommand(String text) {
    final hasDueWord = _containsAny(text, const [
      'due',
      'dues',
      'pending',
      'remaining',
      'balance',
      'old balance',
      'baaki',
      'bakaya',
      'pichla',
      'बाकी',
      'बकाया',
      'पेंडिंग',
      'पुराना',
      'पिछला',
    ]);
    final hasAddWord = _containsAny(text, const [
      'add',
      'jod',
      'jodo',
      'lagao',
      'dalo',
      'dal do',
      'जोड़',
      'जोड़ो',
      'लगाओ',
      'डाल',
    ]);
    final soundsLikePayment = _containsAny(text, const [
      'paid',
      'pay',
      'diya',
      'diye',
      'liya',
      'दिया',
      'दिये',
      'लिया',
    ]);

    return hasDueWord && (hasAddWord || !soundsLikePayment);
  }

  static bool _isExpenseCommand(String text) {
    return _containsAny(text, const [
      'expense',
      'kharcha',
      'bill',
      'bijli',
      'pani',
      'repair',
      'cleaning',
      'internet',
      'maintenance',
      'खर्च',
      'खर्चा',
      'बिल',
      'बिजली',
      'पानी',
      'मरम्मत',
      'सफाई',
    ]);
  }

  static bool _isDocumentCommand(String text) {
    return _containsAny(text, const [
          'aadhaar',
          'aadhar',
          'adhar',
          'agreement',
          'document',
          'documents',
          'doc',
          'file',
          'files',
          'paper',
          'papers',
          'photo',
          'image',
          'proof',
          'id card',
          'id proof',
          'pan',
          'pan card',
          'police verification',
          'आधार',
          'एग्रीमेंट',
          'दस्तावेज',
          'फोटो',
        ]) &&
        _containsAny(text, const [
          'show',
          'view',
          'see',
          'open',
          'dikhao',
          'dikhana',
          'dikha do',
          'kholo',
          'khol do',
          'दिखाओ',
          'खोल',
        ]);
  }

  static bool _isDocumentUploadCommand(String text) {
    return _containsAny(text, const [
          'document',
          'documents',
          'doc',
          'file',
          'files',
          'paper',
          'papers',
          'aadhaar',
          'aadhar',
          'adhar',
          'agreement',
          'photo',
          'image',
          'pan',
          'pan card',
          'police verification',
          'दस्तावेज',
          'डॉक्यूमेंट',
          'आधार',
          'फोटो',
        ]) &&
        _containsAny(text, const [
          'upload',
          'add',
          'attach',
          'daal',
          'dalo',
          'dalna',
          'lagana',
          'lagao',
          'karna',
          'rakhna',
          'save',
          'अपलोड',
          'लगाना',
          'लगाओ',
          'जोड़',
          'सेव',
        ]);
  }

  static bool _isMissingDocumentsQuery(String text) {
    final talksAboutDocuments = _containsAny(text, const [
      'document',
      'documents',
      'doc',
      'file',
      'files',
      'paper',
      'papers',
      'aadhaar',
      'aadhar',
      'adhar',
      'agreement',
      'photo',
      'pan',
      'pan card',
      'police verification',
      'दस्तावेज',
      'डॉक्यूमेंट',
      'आधार',
    ]);
    final meansMissing = _containsAny(text, const [
      'not uploaded',
      'uploaded nahi',
      'upload nahi',
      'missing',
      'nahi hai',
      'nahin hai',
      'no document',
      'without document',
      'अपलोड नहीं',
      'नहीं है',
      'नही है',
    ]);
    final isQuery = _containsAny(text, const [
      'koi',
      'kaun',
      'kaunse',
      'which',
      'show',
      'dikhao',
      'dikhana',
      'list',
      'कौन',
      'दिखाओ',
    ]);

    return talksAboutDocuments && meansMissing && isQuery;
  }

  static bool _isCallCommand(String text) {
    return _containsAny(text, const [
      'call',
      'phone',
      'dial',
      'number lagao',
      'phone lagao',
      'baat karao',
      'कॉल',
      'फोन',
      'नंबर',
      'बात',
    ]);
  }

  static bool _isWhatsAppReminderCommand(String text) {
    final asksToSend = _containsAny(text, const [
      'reminder bhejo',
      'yaad dilao',
      'yaad dilana',
      'message bhejo',
      'msg bhejo',
      'whatsapp bhejo',
      'whatsapp karo',
      'rent reminder',
      'due reminder',
      'bhejo',
      'send reminder',
      'send message',
      'send whatsapp',
      'याद दिलाओ',
      'याद दिलाना',
      'मैसेज भेजो',
      'व्हाट्सऐप',
      'भेजो',
    ]);
    final rentContext = _containsAny(text, const [
      'rent',
      'kiraya',
      'due',
      'pending',
      'reminder',
      'yaad',
      'message',
      'whatsapp',
      'किराया',
      'बकाया',
      'याद',
      'मैसेज',
    ]);

    return asksToSend && rentContext;
  }

  static bool _isTenantDetailCommand(String text) {
    final talksAboutTenant = _containsAny(text, const [
      'tenant',
      'kirayedar',
      'person',
      'profile',
      'detail',
      'details',
      'history',
      'record',
      'info',
      'information',
      'à¤•à¤¿à¤°à¤¾à¤¯à¥‡à¤¦à¤¾à¤°',
    ]);
    final asksToOpen = _containsAny(text, const [
      'show',
      'view',
      'open',
      'dikhao',
      'dikhana',
      'kholo',
      'dikhana',
      'khol do',
      'add',
      'new',
      'create',
      'khol do',
      'add',
      'new',
      'create',
      'profile',
      'detail',
      'details',
      'history',
      'record',
      'info',
    ]);

    return talksAboutTenant && asksToOpen;
  }

  static bool _isPaymentQrCommand(String text) {
    final talksAboutQr = _containsAny(text, const [
      'qr',
      'q r',
      'payment qr',
      'upi qr',
      'scanner',
      'scan code',
      'code',
    ]);
    final asksToOpen = _containsAny(text, const [
      'show',
      'view',
      'open',
      'dikhao',
      'dikhana',
      'kholo',
      'bhejo',
      'send',
    ]);

    return talksAboutQr && asksToOpen;
  }

  static String _paymentMethodFor(String text) {
    if (_containsAny(text, const [
      'upi',
      'u p i',
      'gpay',
      'google pay',
      'phonepe',
      'यूपीआई',
    ])) {
      return 'upi';
    }
    if (_containsAny(text, const [
      'bank',
      'transfer',
      'neft',
      'imps',
      'बैंक',
    ])) {
      return 'bank_transfer';
    }
    if (_containsAny(text, const ['card', 'कार्ड'])) {
      return 'card';
    }
    if (_containsAny(text, const ['cash', 'nakad', 'कैश', 'नकद'])) {
      return 'cash';
    }
    return 'cash';
  }

  static String _expenseCategoryFor(String text) {
    if (_containsAny(text, const ['electricity', 'bijli', 'light', 'बिजली'])) {
      return 'electricity';
    }
    if (_containsAny(text, const ['water', 'pani', 'पानी'])) {
      return 'water';
    }
    if (_containsAny(text, const ['repair', 'marammat', 'मरम्मत'])) {
      return 'repair';
    }
    if (_containsAny(text, const ['cleaning', 'safai', 'सफाई'])) {
      return 'cleaning';
    }
    if (_containsAny(text, const ['internet', 'wifi', 'wi fi'])) {
      return 'internet';
    }
    if (_containsAny(text, const ['maintenance', 'maintain'])) {
      return 'maintenance';
    }
    return 'other';
  }

  static String? _documentTypeFor(String text) {
    if (_containsAny(text, const [
      'aadhaar card',
      'aadhar card',
      'adhar card',
    ])) {
      return 'aadhaar';
    }
    if (_containsAny(text, const ['rent agreement', 'kiraya agreement'])) {
      return 'agreement';
    }
    if (_containsAny(text, const ['pan', 'pan card'])) {
      return 'pan';
    }
    if (_containsAny(text, const ['police', 'verification'])) {
      return 'police';
    }
    if (_containsAny(text, const ['image', 'profile photo'])) {
      return 'profile_photo';
    }
    if (_containsAny(text, const ['identity'])) {
      return 'id';
    }

    if (_containsAny(text, const ['aadhaar', 'aadhar', 'adhar', 'आधार'])) {
      return 'aadhaar';
    }
    if (_containsAny(text, const ['agreement', 'एग्रीमेंट'])) {
      return 'agreement';
    }
    if (_containsAny(text, const ['photo', 'फोटो'])) {
      return 'photo';
    }
    if (_containsAny(text, const ['id card', 'id proof'])) {
      return 'id';
    }
    if (_containsAny(text, const [
      'document',
      'documents',
      'doc',
      'दस्तावेज',
    ])) {
      return 'document';
    }
    return null;
  }

  static String? _roomFilterFor(String text) {
    final pendingMonthThreshold = _pendingMonthThresholdFor(text);
    if (pendingMonthThreshold != null &&
        _containsAny(text, const [
          'pending',
          'due',
          'baaki',
          'bakaya',
          'rent',
          'kiraya',
          'बकाया',
          'बाकी',
          'किराया',
        ])) {
      return 'months_pending_$pendingMonthThreshold';
    }

    if (_containsAny(text, const [
      'deposit kam',
      'kam deposit',
      'low deposit',
      'less deposit',
      'security kam',
      'कम डिपॉजिट',
      'डिपॉजिट कम',
      'कम जमा',
    ])) {
      return 'low_deposit';
    }

    if (_containsAny(text, const [
      'sabse purana tenant',
      'sabse purana kirayedar',
      'oldest tenant',
      'old tenant',
      'purana tenant',
      'purana kirayedar',
      'सबसे पुराना',
      'पुराना किरायेदार',
    ])) {
      return 'oldest_tenant';
    }

    if (_containsAny(text, const [
      'kal kisko',
      'tomorrow reminder',
      'remind tomorrow',
      'yaad dilana',
      'yaad karana',
      'reminder',
      'कल किसको',
      'याद दिलाना',
    ])) {
      return 'pending';
    }

    if (_isMissingDocumentsQuery(text)) {
      return 'missing_documents';
    }

    final talksAboutRooms = _containsAny(text, const [
      'room',
      'rooms',
      'kamra',
      'कमरा',
      'रूम',
    ]);
    final asksToShow = _containsAny(text, const [
      'show',
      'open',
      'dikhao',
      'kholo',
      'which',
      'who',
      'whom',
      'kaunse',
      'kaunsa',
      'kiska',
      'kisko',
      'kis',
      'list',
      'दिखाओ',
      'खोल',
      'कौन',
    ]);

    if (!talksAboutRooms || !asksToShow) {
      return null;
    }

    if (_containsAny(text, const [
      'occupied',
      'full',
      'filled',
      'booked',
      'bhara',
      'bhare',
      'bharahua',
      'भरा',
      'भरे',
      'occupied',
    ])) {
      return 'occupied';
    }
    if (_containsAny(text, const [
      'vacant',
      'empty',
      'free',
      'available',
      'khali',
      'खाली',
    ])) {
      return 'vacant';
    }
    if (_containsAny(text, const [
      'pending',
      'due',
      'baaki',
      'bakaya',
      'बकाया',
      'बाकी',
    ])) {
      return 'pending';
    }
    if (_containsAny(text, const ['all', 'sare', 'saare', 'सब', 'सारे'])) {
      return 'all';
    }
    return 'all';
  }

  static int? _pendingMonthThresholdFor(String text) {
    const wordNumbers = {
      '1': 1,
      'one': 1,
      'ek': 1,
      'एक': 1,
      '१': 1,
      '2': 2,
      'two': 2,
      'do': 2,
      'दो': 2,
      '२': 2,
      '3': 3,
      'three': 3,
      'teen': 3,
      'तीन': 3,
      '३': 3,
      '4': 4,
      'four': 4,
      'char': 4,
      'chaar': 4,
      'चार': 4,
      '४': 4,
      '5': 5,
      'five': 5,
      'panch': 5,
      'paanch': 5,
      'पांच': 5,
      'पाँच': 5,
      '५': 5,
      '6': 6,
      'six': 6,
      'chhe': 6,
      'छह': 6,
      '६': 6,
    };

    final match = RegExp(
      r'\b([1-6]|one|two|three|four|five|six|ek|do|teen|char|chaar|panch|paanch|chhe|एक|दो|तीन|चार|पांच|पाँच|छह|१|२|३|४|५|६)\s*(month|months|mahina|mahine|महीना|महीने)\b',
    ).firstMatch(text);

    if (match == null) {
      return null;
    }

    return wordNumbers[match.group(1)];
  }

  static String? _routeFor(String text) {
    final hasOpenWord = _containsAny(text, const [
      'open',
      'show',
      'go',
      'dikhao',
      'kholo',
      'खोल',
      'दिखाओ',
      'जाओ',
    ]);
    if (!hasOpenWord) {
      return null;
    }

    if (_containsAny(text, const ['room', 'rooms', 'kamra', 'कमरा', 'रूम'])) {
      return '/rooms';
    }
    if (_containsAny(text, const [
      'payment',
      'payments',
      'rent',
      'किराया',
      'पेमेंट',
    ])) {
      return '/payments';
    }
    if (_containsAny(text, const [
      'tenant',
      'tenants',
      'person',
      'kirayedar',
      'किरायेदार',
    ])) {
      return '/tenants';
    }
    if (_containsAny(text, const ['expense', 'expenses', 'kharcha', 'खर्च'])) {
      return '/expenses';
    }
    if (_containsAny(text, const ['setting', 'settings'])) {
      return '/settings';
    }
    if (_containsAny(text, const ['report', 'reports', 'रिपोर्ट'])) {
      return '/reports';
    }
    if (_containsAny(text, const ['qr', 'q r', 'code', 'scanner', 'scan'])) {
      return '/payment-qr';
    }
    if (_containsAny(text, const ['home', 'dashboard', 'overview'])) {
      return '/dashboard';
    }
    return null;
  }

  static bool _containsAny(String text, List<String> tokens) {
    return tokens.any((token) => text.contains(token));
  }

  static String _normalize(String input) {
    final lower = input.toLowerCase();
    final convertedDigits = lower
        .replaceAll('०', '0')
        .replaceAll('१', '1')
        .replaceAll('२', '2')
        .replaceAll('३', '3')
        .replaceAll('४', '4')
        .replaceAll('५', '5')
        .replaceAll('६', '6')
        .replaceAll('७', '7')
        .replaceAll('८', '8')
        .replaceAll('९', '9');

    return convertedDigits
        .replaceAll(RegExp(r'[₹,.;:!?()\[\]{}]'), ' ')
        .replaceAll(RegExp(r'\b(rs|rupees|rupaye|rupay|रुपये|रुपए)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int? _wordAmountFor(String text) {
    const values = {
      'zero': 0,
      'shunya': 0,
      'ek': 1,
      'one': 1,
      'एक': 1,
      'do': 2,
      'two': 2,
      'दो': 2,
      'teen': 3,
      'three': 3,
      'तीन': 3,
      'char': 4,
      'chaar': 4,
      'four': 4,
      'चार': 4,
      'panch': 5,
      'paanch': 5,
      'five': 5,
      'पांच': 5,
      'पाँच': 5,
      'chhe': 6,
      'six': 6,
      'छह': 6,
      'saat': 7,
      'seven': 7,
      'सात': 7,
      'aath': 8,
      'eight': 8,
      'आठ': 8,
      'nau': 9,
      'nine': 9,
      'नौ': 9,
      'das': 10,
      'ten': 10,
      'दस': 10,
      'gyarah': 11,
      'eleven': 11,
      'ग्यारह': 11,
      'barah': 12,
      'twelve': 12,
      'बारह': 12,
      'pandrah': 15,
      'fifteen': 15,
      'पंद्रह': 15,
      'bees': 20,
      'twenty': 20,
      'बीस': 20,
      'tees': 30,
      'thirty': 30,
      'तीस': 30,
      'chalis': 40,
      'forty': 40,
      'चालीस': 40,
      'pachas': 50,
      'fifty': 50,
      'पचास': 50,
      'sattar': 70,
      'seventy': 70,
      'सत्तर': 70,
      'assi': 80,
      'eighty': 80,
      'अस्सी': 80,
      'ninety': 90,
      'nabbe': 90,
      'नब्बे': 90,
    };
    const multipliers = {
      'hundred': 100,
      'sau': 100,
      'सौ': 100,
      'thousand': 1000,
      'hazar': 1000,
      'hazaar': 1000,
      'हजार': 1000,
      'lakh': 100000,
      'lac': 100000,
      'लाख': 100000,
    };

    var total = 0;
    var current = 0;
    var found = false;

    for (final token in text.split(' ')) {
      final value = values[token];
      if (value != null) {
        current += value;
        found = true;
        continue;
      }

      final multiplier = multipliers[token];
      if (multiplier != null) {
        total += (current == 0 ? 1 : current) * multiplier;
        current = 0;
        found = true;
      }
    }

    if (!found) {
      return null;
    }

    return total + current;
  }
}
