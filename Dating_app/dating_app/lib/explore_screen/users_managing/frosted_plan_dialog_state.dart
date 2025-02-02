// frosted_plan_dialog_state.dart
part of 'user_info_check.dart';

class _FrostedPlanDialogState extends State<_FrostedPlanDialog> {
  late Future<List<Map<String, dynamic>>> _futureParticipants;

  @override
  void initState() {
    super.initState();
    _futureParticipants = widget.fetchParticipants(widget.plan);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final screenSize = MediaQuery.of(context).size;

    return SafeArea(
      child: Stack(
        children: [
          // Fondo difuminado para todo el fondo del diálogo
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.grey.withOpacity(0.3),
              ),
            ),
          ),
          // Tarjeta central con efecto cristalino
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                // Aplica un blur adicional para el contenido de la tarjeta
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: screenSize.width * 0.85,
                  constraints: BoxConstraints(
                    maxHeight: screenSize.height * 0.8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2), // Fondo semitransparente
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Título del plan
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: "Detalles del Plan de ",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                TextSpan(
                                  text: "${plan.type}",
                                  style: TextStyle(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),
                          // Fila con el ID y botón para copiar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "ID del Plan: ",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(
                                        text: "${plan.id}",
                                        style: TextStyle(
                                          color: AppColors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, color: AppColors.blue),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: plan.id));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('ID copiado al portapapeles'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Datos del plan
                          Text.rich(TextSpan(children: [TextSpan(
                                  text: "Descripción: ",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,),
                                  
                                ),
                                TextSpan(
                                  text: "${plan.description}",
                                  style: TextStyle(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text.rich(TextSpan(children: [TextSpan(
                                  text: "Restricción de Edad: ",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: "${plan.minAge} - ${plan.maxAge} años",
                                  style: TextStyle(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text.rich(TextSpan(children: [TextSpan(
                                  text: "Máximo Participantes: ",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: "${plan.maxParticipants ?? 'Sin límite'}",
                                  style: TextStyle(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text.rich(TextSpan(children: [TextSpan(
                                  text: "Ubicación: ",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: "${plan.location}",
                                  style: TextStyle(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text.rich(TextSpan(children: [TextSpan(
                                  text: "Fecha del Evento: ",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: "${plan.formattedDate(plan.date)}",
                                  style: TextStyle(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text.rich(TextSpan(children: [TextSpan(
                                  text: "Creado el: ",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: "${plan.formattedDate(plan.createdAt)}",
                                  style: TextStyle(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),
                          // FutureBuilder para mostrar Creador y Participantes
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _futureParticipants,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (snapshot.hasError) {
                                return Text(
                                  'Error: ${snapshot.error}',
                                  style: const TextStyle(color: Colors.black),
                                );
                              }
                              final all = snapshot.data ?? [];
                              if (all.isEmpty) {
                                return const Text(
                                  'No hay participantes en este plan.',
                                  style: TextStyle(color: AppColors.blue),
                                );
                              }
                              final creator = all.firstWhere(
                                (p) => p['isCreator'] == true,
                                orElse: () => {},
                              );
                              final participants =
                                  all.where((p) => p['isCreator'] == false).toList();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (creator.isNotEmpty) ...[
                                    const Text(
                                      "Creador del Plan:",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildCreatorTile(creator),
                                    const SizedBox(height: 10),
                                  ],
                                  const Text(
                                    "Participantes:",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (participants.isEmpty)
                                    Text(
                                      "No hay participantes en este plan.",
                                      style: TextStyle(color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else
                                    ...participants.map(_buildParticipantTile).toList(),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // Botón de cerrar
                          Align(
                            alignment: Alignment.bottomRight,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cerrar", style: TextStyle(color: AppColors.blue,
                                                                           fontWeight: FontWeight.bold,
                                                                          )
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorTile(Map<String, dynamic> creator) {
    final pic = creator['photoUrl'] ?? '';
    final name = creator['name'] ?? 'Usuario';
    final age = creator['age'] ?? '';
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
        backgroundColor: Colors.purple[100],
      ),
      title: Text('$name, $age', style: const TextStyle(color: AppColors.blue,
                                                        fontWeight: FontWeight.bold,)),
    );
  }

  Widget _buildParticipantTile(Map<String, dynamic> part) {
    final pic = part['photoUrl'] ?? '';
    final name = part['name'] ?? 'Usuario';
    final age = part['age'] ?? '';
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
        backgroundColor: Colors.blueGrey[100],
      ),
      title: Text('$name, $age', style: const TextStyle(color: AppColors.blue,
                                                      fontWeight: FontWeight.bold,)),
    );
  }
}
