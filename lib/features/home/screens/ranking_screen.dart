import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF1D2D44),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('RANKING SEMANAL', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: const Color(0xFFFF8C00),
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'CONDUCTORES'),
              Tab(text: 'PASAJEROS'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RankingList(isDriver: true),
            RankingList(isDriver: false),
          ],
        ),
      ),
    );
  }
}

class RankingList extends StatelessWidget {
  final bool isDriver;
  const RankingList({super.key, required this.isDriver});

  @override
  Widget build(BuildContext context) {
    // Datos de ejemplo (Mock data) para que veas cómo queda
    final List<Map<String, dynamic>> topUsers = isDriver 
      ? [
          {'name': 'Carlos Ruiz', 'rating': 5.0, 'trips': 142},
          {'name': 'Ana Belén', 'rating': 4.9, 'trips': 128},
          {'name': 'Juan Pérez', 'rating': 4.9, 'trips': 115},
          {'name': 'María José', 'rating': 4.8, 'trips': 98},
          {'name': 'Luis Mera', 'rating': 4.7, 'trips': 85},
        ]
      : [
          {'name': 'Dario Calixto', 'rating': 5.0, 'trips': 45},
          {'name': 'Sofía Vega', 'rating': 4.9, 'trips': 38},
          {'name': 'Pedro Solís', 'rating': 4.9, 'trips': 32},
          {'name': 'Elena Paz', 'rating': 4.8, 'trips': 29},
          {'name': 'Roberto G.', 'rating': 4.7, 'trips': 25},
        ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: topUsers.length,
      itemBuilder: (context, index) {
        final user = topUsers[index];
        final isTopThree = index < 3;

        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: isTopThree ? Border.all(color: _getRankColor(index).withOpacity(0.5), width: 1) : null,
          ),
          child: Row(
            children: [
              _buildRankBadge(index),
              const SizedBox(width: 15),
              const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['name'], style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${user['trips']} viajes esta semana', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFFF8C00), size: 16),
                      const SizedBox(width: 4),
                      Text(user['rating'].toString(), style: const TextStyle(color: Color(0xFFFF8C00), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Text('Top', style: TextStyle(color: Colors.white24, fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRankBadge(int index) {
    if (index == 0) return const Icon(Icons.emoji_events, color: Color(0xFFFF8C00), size: 30);
    if (index == 1) return const Icon(Icons.emoji_events, color: Color(0xFFC0C0C0), size: 28);
    if (index == 2) return const Icon(Icons.emoji_events, color: Color(0xFFCD7F32), size: 26);
    return Text('#${index + 1}', style: const TextStyle(color: Colors.white24, fontWeight: FontWeight.bold));
  }

  Color _getRankColor(int index) {
    if (index == 0) return const Color(0xFFFF8C00);
    if (index == 1) return const Color(0xFFC0C0C0);
    if (index == 2) return const Color(0xFFCD7F32);
    return Colors.transparent;
  }
}
