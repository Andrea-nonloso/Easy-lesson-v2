import 'package:flutter/material.dart';

import 'agenda_page.dart';
import 'now_page.dart';
import 'school_life_pages.dart';
import 'settings_sheet.dart';
import 'themes_page.dart';

/// Voce extra del menu ⋮ specifica di una schermata.
class AppMenuItem {
  const AppMenuItem(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Menu ⋮ presente in tutte le schermate: voci della pagina + Temi + Impostazioni.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key, this.items = const []});

  final List<AppMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final all = [
      ...items,
      AppMenuItem(Icons.event_note_rounded, 'Agenda', () => openAgenda(context)),
      AppMenuItem(Icons.person_search_rounded, 'Adesso a scuola', () => openNowAtSchool(context)),
      AppMenuItem(Icons.grade_outlined, 'Voti', () => openGrades(context)),
      AppMenuItem(Icons.event_busy_outlined, 'Assenze e permessi', () => openAbsences(context)),
      AppMenuItem(Icons.timer_outlined, 'Timer per studiare', () => openStudyTimer(context)),
      AppMenuItem(Icons.palette_outlined, 'Temi', () => openThemesPage(context)),
      AppMenuItem(Icons.settings_outlined, 'Impostazioni', () => showSettingsSheet(context)),
    ];
    return PopupMenuButton<int>(
      tooltip: 'Altre opzioni',
      icon: Icon(Icons.more_vert_rounded, color: Theme.of(context).colorScheme.onSurface),
      onSelected: (i) => all[i].onTap(),
      itemBuilder: (_) => [
        for (var i = 0; i < all.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(all[i].icon),
              title: Text(all[i].label),
            ),
          ),
      ],
    );
  }
}
