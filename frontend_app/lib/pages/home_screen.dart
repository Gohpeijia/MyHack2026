import 'package:flutter/material.dart';
import 'map.dart'; 
import 'dashboard.dart'; // Connected the Dashboard

class HomeScreen extends StatefulWidget {
  final bool isCaregiver;
  const HomeScreen({super.key, this.isCaregiver = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // ── LIFTED STATE FOR DASHBOARD SYNC ─────────────────────────────────────────
  // Moving schedules and contacts here so both Home and Dashboard share the exact same data!
  
  List<EmergencyContact> contacts = [
    EmergencyContact(
      name: 'Dr. Sarah (Doctor)',
      phone: '+60 12-345 6789',
      color: const Color(0xFFE74C3C),
      icon: Icons.favorite_rounded,
    ),
    EmergencyContact(
      name: 'Ali (Son)',
      phone: '+60 11-987 6543',
      color: const Color(0xFF4A90D9),
      icon: Icons.favorite_rounded,
    ),
  ];

  List<ScheduleItem> schedules = [
    ScheduleItem(
      time: '08:00 AM',
      title: 'Morning Medication',
      subtitle: 'Metformin 500mg + Vitamin D',
      icon: Icons.medication_rounded,
      color: const Color(0xFF2ECC8A),
      done: true,
      repeat: 'Daily', // 🔼 Shows the new repeating option
    ),
    ScheduleItem(
      time: '10:00 AM',
      title: 'Doctor Appointment',
      subtitle: 'Klinik Sejahtera, SS15 Subang Jaya',
      icon: Icons.medical_services_rounded,
      color: const Color(0xFF4A90D9),
      done: false,
      repeat: 'None',
    ),
    ScheduleItem(
      time: '01:00 PM',
      title: 'Lunch Reminder',
      subtitle: 'Low sodium meal recommended',
      icon: Icons.restaurant_rounded,
      color: const Color(0xFFF39C12),
      done: false,
      repeat: 'Daily',
    ),
  ];

  // ── TIMELINE MOCK (Backend handles population) ──────────────────────────────
  List<LocationCheckpoint> checkpoints = [
    const LocationCheckpoint(
      time: '08:00 AM',
      placeName: 'Home',
      address: 'USJ 1, Subang Jaya',
      icon: Icons.home_rounded,
      color: Color(0xFF4A90D9),
    ),
    const LocationCheckpoint(
      time: '09:00 AM',
      placeName: 'Sunway Pyramid',
      address: 'Bandar Sunway, Subang Jaya',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFF9B59B6),
    ),
    const LocationCheckpoint(
      time: '10:00 AM',
      placeName: 'Klinik Sejahtera',
      address: 'SS15, Subang Jaya, Selangor',
      icon: Icons.medical_services_rounded,
      color: Color(0xFFE74C3C),
      isCurrentLocation: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Rebuild pages array dynamically to pass the freshest data
    final List<Widget> pages = [
      _HomePage(
        isCaregiver: widget.isCaregiver,
        contacts: contacts,
        schedules: schedules,
        onStateChanged: () => setState(() {}), // Refresh tree when items modify
      ),
      const MapPage(),
      DashboardPage(
        schedules: schedules,
        checkpoints: checkpoints,
        onNavigateToMap: () => setState(() => _currentIndex = 1),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF4A90D9),
          unselectedItemColor: const Color(0xFFBBBBCC),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on_rounded),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── DATA MODELS ─────────────────────────────────────────────────────────────

class EmergencyContact {
  String name;
  String phone;
  Color color;
  IconData icon;

  EmergencyContact({
    required this.name,
    required this.phone,
    required this.color,
    required this.icon,
  });
}

class ScheduleItem {
  String time;
  String title;
  String subtitle;
  IconData icon;
  Color color;
  bool done;
  String repeat; // 🔼 Added repeat property

  ScheduleItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.done,
    this.repeat = 'None', // 🔼 Default is None so dashboard data doesn't break
  });
}

// ─── AVAILABLE SCHEDULE ICONS ─────────────────────────────────────────────────

const List<Map<String, dynamic>> kScheduleIconOptions = [
  {'icon': Icons.medication_rounded,      'label': 'Medication'},
  {'icon': Icons.medical_services_rounded,'label': 'Doctor'},
  {'icon': Icons.restaurant_rounded,      'label': 'Meal'},
  {'icon': Icons.fitness_center_rounded,  'label': 'Exercise'},
  {'icon': Icons.local_drink_rounded,     'label': 'Water'},
  {'icon': Icons.bedtime_rounded,         'label': 'Sleep'},
  {'icon': Icons.event_note_rounded,      'label': 'Event'},
  {'icon': Icons.directions_walk_rounded, 'label': 'Walk'},
];

// ─── HOME PAGE ───────────────────────────────────────────────────────────────

class _HomePage extends StatefulWidget {
  final bool isCaregiver;
  final List<EmergencyContact> contacts;
  final List<ScheduleItem> schedules;
  final VoidCallback onStateChanged;

  const _HomePage({
    required this.isCaregiver,
    required this.contacts,
    required this.schedules,
    required this.onStateChanged,
  });

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {

  // ── Contact Dialog ──────────────────────────────────────────────────────────
  void _showContactDialog({int? index}) {
    final isEditing = index != null;
    final nameCtrl  = TextEditingController(text: isEditing ? widget.contacts[index].name  : '');
    final phoneCtrl = TextEditingController(text: isEditing ? widget.contacts[index].phone : '');

    final List<Color> colorOptions = [
      const Color(0xFFE74C3C),
      const Color(0xFF4A90D9),
      const Color(0xFF2ECC8A),
      const Color(0xFFF39C12),
      const Color(0xFF9B59B6),
    ];

    Color selectedColor = isEditing ? widget.contacts[index].color : colorOptions[0];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(isEditing ? 'Edit Contact' : 'Add Contact'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name & Role'),
                  ),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                  ),
                  const SizedBox(height: 24),
                  const Text('Card Color:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: colorOptions.map((color) {
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = color),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == color ? Colors.black87 : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isEditing) {
                        widget.contacts[index].name  = nameCtrl.text;
                        widget.contacts[index].phone = phoneCtrl.text;
                        widget.contacts[index].color = selectedColor;
                      } else {
                        widget.contacts.add(EmergencyContact(
                          name:  nameCtrl.text,
                          phone: phoneCtrl.text,
                          color: selectedColor,
                          icon:  Icons.favorite_rounded, 
                        ));
                      }
                    });
                    widget.onStateChanged(); 
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Schedule Dialog (with icon & REPEAT picker) ────────────────────────────
  void _showScheduleDialog({int? index}) {
    final isEditing    = index != null;
    final timeCtrl     = TextEditingController(text: isEditing ? widget.schedules[index].time     : '');
    final titleCtrl    = TextEditingController(text: isEditing ? widget.schedules[index].title    : '');
    final subtitleCtrl = TextEditingController(text: isEditing ? widget.schedules[index].subtitle : '');

    final List<Color> colorOptions = [
      const Color(0xFF2ECC8A),
      const Color(0xFF4A90D9),
      const Color(0xFFF39C12),
      const Color(0xFFE74C3C),
      const Color(0xFF9B59B6),
    ];

    final List<String> repeatOptions = ['None', 'Daily', 'Weekly', 'Monthly'];

    IconData selectedIcon  = isEditing ? widget.schedules[index].icon  : kScheduleIconOptions[0]['icon'] as IconData;
    Color    selectedColor = isEditing ? widget.schedules[index].color : colorOptions[0];
    String   selectedRepeat = isEditing ? widget.schedules[index].repeat : 'None'; // 🔼 Track repeat state

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(isEditing ? 'Edit Schedule' : 'Add Schedule'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: timeCtrl,
                      decoration: const InputDecoration(labelText: 'Time (e.g., 08:00 AM)'),
                    ),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    TextField(
                      controller: subtitleCtrl,
                      decoration: const InputDecoration(labelText: 'Subtitle'),
                    ),
                    const SizedBox(height: 20),

                    // ── REPEAT Picker ────────────────────────────────────────
                    DropdownButtonFormField<String>(
                      value: selectedRepeat,
                      decoration: const InputDecoration(
                        labelText: 'Repeat Option',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: repeatOptions
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (val) => setDialogState(() => selectedRepeat = val!),
                    ),
                    const SizedBox(height: 20),

                    // ── Icon Picker ──────────────────────────────────────────
                    const Text('Icon:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: kScheduleIconOptions.map((opt) {
                        final icon    = opt['icon'] as IconData;
                        final label   = opt['label'] as String;
                        final isChosen = selectedIcon == icon;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedIcon = icon),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isChosen
                                      ? selectedColor.withOpacity(0.2)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isChosen ? selectedColor : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(icon,
                                    color: isChosen ? selectedColor : Colors.grey[500],
                                    size: 22),
                              ),
                              const SizedBox(height: 4),
                              Text(label,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: isChosen ? selectedColor : Colors.grey[500])),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // ── Color Picker ─────────────────────────────────────────
                    const Text('Color:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: colorOptions.map((color) {
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = color),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == color
                                    ? Colors.black87
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isEditing) {
                        widget.schedules[index].time     = timeCtrl.text;
                        widget.schedules[index].title    = titleCtrl.text;
                        widget.schedules[index].subtitle = subtitleCtrl.text;
                        widget.schedules[index].icon     = selectedIcon;
                        widget.schedules[index].color    = selectedColor;
                        widget.schedules[index].repeat   = selectedRepeat; // 🔼 Save edit
                      } else {
                        widget.schedules.add(ScheduleItem(
                          time:     timeCtrl.text,
                          title:    titleCtrl.text,
                          subtitle: subtitleCtrl.text,
                          icon:     selectedIcon,
                          color:    selectedColor,
                          repeat:   selectedRepeat, // 🔼 Save new
                          done:     false,
                        ));
                      }
                    });
                    widget.onStateChanged(); 
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good Day 👋',
                      style: TextStyle(fontSize: 30, color: Color(0xFF1A1A2E)),
                    ),
                    SizedBox(height: 2),
                  ],
                ),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF4A90D9).withOpacity(0.15),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF4A90D9),
                    size: 28,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Emergency Contacts Header ───────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Emergency Contacts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF4A90D9)),
                  onPressed: () => _showContactDialog(),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ── Emergency Contacts List ─────────────────────────────────────
            ...widget.contacts.asMap().entries.map((entry) {
              int idx = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EmergencyCard(
                  contact: entry.value,
                  onEdit:   () => _showContactDialog(index: idx),
                  onDelete: () {
                    setState(() => widget.contacts.removeAt(idx));
                    widget.onStateChanged();
                  },
                ),
              );
            }),

            const SizedBox(height: 20),

            // ── Schedule Header with menu ───────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Schedule",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFF4A90D9)),
                      onPressed: () => _showScheduleDialog(),
                    ),
                    // ── Schedule section options menu ──────────────────────
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Color(0xFF9999AA)),
                      onSelected: (value) {
                        setState(() {
                          if (value == 'mark_all_done') {
                            for (final s in widget.schedules) {
                              s.done = true;
                            }
                          } else if (value == 'clear_done') {
                            widget.schedules.removeWhere((s) => s.done);
                          } else if (value == 'unmark_all') {
                            for (final s in widget.schedules) {
                              s.done = false;
                            }
                          }
                        });
                        widget.onStateChanged(); // Notify dashboard
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'mark_all_done',
                          child: Row(children: [
                            Icon(Icons.check_circle_outline, size: 20, color: Color(0xFF2ECC8A)),
                            SizedBox(width: 8),
                            Text('Mark All Done'),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'unmark_all',
                          child: Row(children: [
                            Icon(Icons.radio_button_unchecked, size: 20, color: Color(0xFF4A90D9)),
                            SizedBox(width: 8),
                            Text('Unmark All'),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'clear_done',
                          child: Row(children: [
                            Icon(Icons.delete_sweep_rounded, size: 20, color: Color(0xFFE74C3C)),
                            SizedBox(width: 8),
                            Text('Clear Done Items'),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ── Schedule List ───────────────────────────────────────────────
            ...widget.schedules.asMap().entries.map((entry) {
              int idx = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ScheduleCard(
                  item:     entry.value,
                  onEdit:   () => _showScheduleDialog(index: idx),
                  onDelete: () {
                    setState(() => widget.schedules.removeAt(idx));
                    widget.onStateChanged();
                  },
                  onMarkDone: () {
                    setState(() => widget.schedules[idx].done = true);
                    widget.onStateChanged();
                  },
                  onMarkUndone: () {
                    setState(() => widget.schedules[idx].done = false);
                    widget.onStateChanged();
                  },
                ),
              );
            }),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─── EMERGENCY CARD ───────────────────────────────────────────────────────────
class _EmergencyCard extends StatelessWidget {
  final EmergencyContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EmergencyCard({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, right: 8, top: 20, bottom: 20),
      decoration: BoxDecoration(
        color: contact.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: contact.color.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Always use heart icon for emergency contacts
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.phone,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),

          // Call Button
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.call_rounded, color: Colors.white, size: 20),
            ),
          ),

          // Edit/Delete Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'edit')   onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit',   child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── SCHEDULE CARD ────────────────────────────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  final ScheduleItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMarkDone;
  final VoidCallback onMarkUndone;

  const _ScheduleCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkDone,
    required this.onMarkUndone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 8, top: 14, bottom: 14),
      decoration: BoxDecoration(
        color: item.done ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.done ? Colors.grey[200]! : item.color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.done
                  ? Colors.grey[200]
                  : item.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.done ? Icons.check_circle_rounded : item.icon,
              color: item.done ? Colors.grey[400] : item.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: item.done ? Colors.grey[400] : const Color(0xFF1A1A2E),
                    decoration: item.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          
          // ── Time & Repeat Column ──────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.time,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: item.done ? Colors.grey[300] : item.color,
                ),
              ),
              if (item.repeat != 'None') ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat_rounded, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      item.repeat,
                      style: TextStyle(fontSize: 15, color: Colors.grey[400], fontWeight: FontWeight.w600),
                    )
                  ],
                )
              ]
            ],
          ),

          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[400]),
            onSelected: (value) {
              if (value == 'mark_done')   onMarkDone();
              if (value == 'mark_undone') onMarkUndone();
              if (value == 'edit')        onEdit();
              if (value == 'delete')      onDelete();
            },
            itemBuilder: (context) => [
              if (!item.done)
                const PopupMenuItem(
                  value: 'mark_done',
                  child: Row(children: [
                    Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF2ECC8A)),
                    SizedBox(width: 8),
                    Text('Mark Done'),
                  ]),
                ),
              if (item.done)
                const PopupMenuItem(
                  value: 'mark_undone',
                  child: Row(children: [
                    Icon(Icons.radio_button_unchecked, size: 18, color: Color(0xFF4A90D9)),
                    SizedBox(width: 8),
                    Text('Mark Undone'),
                  ]),
                ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: Color(0xFF9999AA)),
                  SizedBox(width: 8),
                  Text('Edit'),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: Color(0xFFE74C3C)),
                  SizedBox(width: 8),
                  Text('Delete'),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}