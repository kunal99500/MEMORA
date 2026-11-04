import 'package:flutter/material.dart';

enum AccountMode { personal, family, business }

extension AccountModeLabel on AccountMode {
  String get label => switch (this) {
        AccountMode.personal => 'Personal',
        AccountMode.family => 'Family',
        AccountMode.business => 'Business',
      };
  IconData get icon => switch (this) {
        AccountMode.personal => Icons.person_outline_rounded,
        AccountMode.family => Icons.family_restroom_rounded,
        AccountMode.business => Icons.business_center_rounded,
      };
  String get subtitle => switch (this) {
        AccountMode.personal => 'Your private visual memory',
        AccountMode.family => 'One shared household memory',
        AccountMode.business => 'Spaces, equipment and inventory',
      };
}

class RoomData {
  final String name;
  final int objects;
  final IconData icon;
  final Color accent;
  final String updated;
  const RoomData(this.name, this.objects, this.icon, this.accent, this.updated);
}

class ObjectData {
  final String name;
  final String room;
  final String lastSeen;
  final IconData icon;
  final Color accent;
  final String confidence;
  const ObjectData(this.name, this.room, this.lastSeen, this.icon, this.accent,
      this.confidence);
}
