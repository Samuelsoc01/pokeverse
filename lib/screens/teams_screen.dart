import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/team_store.dart';
import '../services/pokeapi_service.dart';

// =====================================================
// PANTALLA DE EQUIPOS
// =====================================================

class TeamsScreen extends StatefulWidget {
  final TeamStore store;
  final PokeApiService apiService;
  final Future<void> Function(int pokemonId) onAddPokemon;

  const TeamsScreen({
    super.key,
    required this.store,
    required this.apiService,
    required this.onAddPokemon,
  });

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  static const Color red = Color(0xFFDC0A2D);

  // ===================================================
  // COLORES DINÁMICOS
  // ===================================================

  bool get dark => Theme.of(context).brightness == Brightness.dark;

  Color get surface => Theme.of(context).colorScheme.surface;

  Color get foreground => Theme.of(context).colorScheme.onSurface;

  Color get muted => dark ? const Color(0xFFB7C0D0) : const Color(0xFF778293);

  Color get slotColor =>
      dark ? const Color(0xFF293345) : const Color(0xFFF5F6FA);

  Color get accent => dark ? const Color(0xFFFF6679) : red;

  // ===================================================
  // MENSAJES
  // ===================================================

  void message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  // ===================================================
  // CREAR EQUIPO
  // ===================================================

  Future<void> createTeam() async {
    final name = await nameDialog(
      title: 'Crear equipo',
      button: 'Crear equipo',
    );

    if (!mounted || name == null) return;

    try {
      await widget.store.createTeam(name);

      if (!mounted) return;

      message('¡Equipo creado correctamente!');
    } catch (error) {
      if (!mounted) return;

      message('No se pudo crear el equipo: $error');
    }
  }

  // ===================================================
  // RENOMBRAR EQUIPO
  // ===================================================

  Future<void> renameTeam(String teamId, String currentName) async {
    final name = await nameDialog(
      title: 'Renombrar equipo',
      button: 'Guardar cambios',
      initial: currentName,
    );

    if (!mounted || name == null) return;

    // Evita guardar si el nombre no cambió.
    if (name == currentName) return;

    try {
      await widget.store.renameTeam(teamId, name);

      if (!mounted) return;

      message('Nombre actualizado correctamente.');
    } catch (error) {
      if (!mounted) return;

      message('No se pudo renombrar: $error');
    }
  }

  // ===================================================
  // DIÁLOGO PARA CREAR Y RENOMBRAR
  //
  // CORRECCIÓN:
  // El TextEditingController ya no se crea ni
  // destruye en este método.
  //
  // Ahora pertenece al StatefulWidget
  // _TeamNameDialog, definido al final del archivo.
  // ===================================================

  Future<String?> nameDialog({
    required String title,
    required String button,
    String initial = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _TeamNameDialog(
          title: title,
          buttonText: button,
          initialName: initial,
        );
      },
    );
  }

  // ===================================================
  // ELIMINAR EQUIPO
  // ===================================================

  Future<void> deleteTeam(String teamId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar equipo'),
          content: Text(
            '¿Seguro que deseas eliminar "$name"? '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFBC2445),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    try {
      await widget.store.deleteTeam(teamId);

      if (!mounted) return;

      message('Equipo eliminado correctamente.');
    } catch (error) {
      if (!mounted) return;

      message('No se pudo eliminar: $error');
    }
  }

  // ===================================================
  // QUITAR POKÉMON DE UN EQUIPO
  // ===================================================

  Future<void> removePokemon(String teamId, int pokemonId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Quitar Pokémon'),
          content: const Text('¿Deseas quitar este Pokémon del equipo?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Quitar'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    try {
      await widget.store.removePokemon(teamId, pokemonId);

      if (!mounted) return;

      message('Pokémon retirado del equipo.');
    } catch (error) {
      if (!mounted) return;

      message('No se pudo quitar el Pokémon: $error');
    }
  }

  // ===================================================
  // INTERFAZ PRINCIPAL
  // ===================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        if (widget.store.isLoading) {
          return Center(child: CircularProgressIndicator(color: accent));
        }

        if (widget.store.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Text(
                widget.store.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: foreground),
              ),
            ),
          );
        }

        final teams = widget.store.teams;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 35),
              children: [
                _header(teams.length),

                const SizedBox(height: 24),

                if (teams.isEmpty)
                  _emptyTeams()
                else
                  for (final team in teams)
                    Padding(
                      key: ValueKey(team.id),
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _teamCard(team.id, team.name, team.pokemonIds),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===================================================
  // ENCABEZADO
  // ===================================================

  Widget _header(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mis equipos',
          style: TextStyle(
            color: foreground,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          'Organiza tus Pokémon para cada aventura.',
          style: TextStyle(color: muted),
        ),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: dark
                  ? [const Color(0xFF7C1730), const Color(0xFF3F223F)]
                  : [red, const Color(0xFFFF6679)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_rounded, color: Colors.white, size: 37),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count equipos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Hasta seis Pokémon por equipo',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              FilledButton.icon(
                onPressed: createTeam,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: red,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===================================================
  // ESTADO SIN EQUIPOS
  // ===================================================

  Widget _emptyTeams() {
    return Container(
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(Icons.catching_pokemon, size: 65, color: accent),

          const SizedBox(height: 15),

          Text(
            'Todavía no tienes equipos',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Crea tu primer equipo y comienza '
            'a reunir a tus Pokémon.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),

          const SizedBox(height: 18),

          FilledButton.icon(
            onPressed: createTeam,
            icon: const Icon(Icons.add),
            label: const Text('Crear equipo'),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // TARJETAS DE EQUIPOS
  // ===================================================

  Widget _teamCard(String id, String name, List<int> ids) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark ? const Color(0xFF384357) : const Color(0xFFEAEDF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded, color: accent, size: 28),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              // Opciones: renombrar o eliminar.
              PopupMenuButton<String>(
                tooltip: 'Opciones del equipo',
                onSelected: (action) {
                  if (action == 'rename') {
                    renameTeam(id, name);
                  } else if (action == 'delete') {
                    deleteTeam(id, name);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Renombrar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Eliminar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),

          Text(
            '${ids.length}/6 Pokémon',
            style: TextStyle(color: muted, fontSize: 12),
          ),

          const SizedBox(height: 16),

          // Seis espacios del equipo.
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 390 ? 2 : 3;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 155,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  if (index < ids.length) {
                    return _occupiedSlot(id, ids[index]);
                  }

                  return _emptySlot();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ===================================================
  // ESPACIO OCUPADO
  // ===================================================

  Widget _occupiedSlot(String teamId, int pokemonId) {
    return Container(
      decoration: BoxDecoration(
        color: slotColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 6),

              Expanded(
                child: CachedNetworkImage(
                  imageUrl:
                      'https://raw.githubusercontent.com/'
                      'PokeAPI/sprites/master/sprites/'
                      'pokemon/other/official-artwork/'
                      '$pokemonId.png',
                  fit: BoxFit.contain,
                  placeholder: (context, url) {
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    );
                  },
                  errorWidget: (context, url, error) {
                    return Icon(Icons.catching_pokemon, color: muted, size: 48);
                  },
                ),
              ),

              Text(
                '#${pokemonId.toString().padLeft(4, '0')}',
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 9),
            ],
          ),

          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              tooltip: 'Quitar Pokémon',
              onPressed: () {
                removePokemon(teamId, pokemonId);
              },
              icon: const Icon(Icons.close, size: 17),
              style: IconButton.styleFrom(
                backgroundColor: surface,
                foregroundColor: accent,
                minimumSize: const Size(32, 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // ESPACIO VACÍO
  // ===================================================

  Widget _emptySlot() {
    return Material(
      color: slotColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          widget.onAddPokemon(0);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: accent, size: 32),

            const SizedBox(height: 8),

            Text(
              'Añadir',
              style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 3),

            Text('Desde Pokédex', style: TextStyle(color: muted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// DIÁLOGO DE NOMBRE DE EQUIPO
//
// CORRECCIÓN DEL ERROR DE ANDROID:
//
// Antes, el TextEditingController se destruía
// inmediatamente después de showDialog().
//
// Ahora el controlador pertenece a este widget y
// se destruye cuando Flutter termina su ciclo de vida.
// =====================================================

class _TeamNameDialog extends StatefulWidget {
  final String title;
  final String buttonText;
  final String initialName;

  const _TeamNameDialog({
    required this.title,
    required this.buttonText,
    required this.initialName,
  });

  @override
  State<_TeamNameDialog> createState() => _TeamNameDialogState();
}

class _TeamNameDialogState extends State<_TeamNameDialog> {
  late final TextEditingController _controller;

  // ===================================================
  // INICIALIZACIÓN DEL CONTROLADOR
  // ===================================================

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialName);

    // Actualizar el botón cuando cambie el texto.
    _controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  // ===================================================
  // VALIDACIÓN
  // ===================================================

  bool get _valid => _controller.text.trim().isNotEmpty;

  // ===================================================
  // GUARDAR NOMBRE
  // ===================================================

  void _save() {
    if (!_valid) return;

    final name = _controller.text.trim();

    // Quitar el foco antes de cerrar el diálogo.
    FocusScope.of(context).unfocus();

    Navigator.of(context).pop(name);
  }

  // ===================================================
  // ELIMINACIÓN SEGURA DEL CONTROLADOR
  // ===================================================

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();

    super.dispose();
  }

  // ===================================================
  // INTERFAZ DEL DIÁLOGO
  // ===================================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),

      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 35,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,

        onSubmitted: (_) {
          _save();
        },

        decoration: const InputDecoration(
          labelText: 'Nombre del equipo',
          hintText: 'Ej. Equipo Kanto',
          prefixIcon: Icon(Icons.groups),
          border: OutlineInputBorder(),
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();

            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),

        FilledButton(
          onPressed: _valid ? _save : null,
          child: Text(widget.buttonText),
        ),
      ],
    );
  }
}
