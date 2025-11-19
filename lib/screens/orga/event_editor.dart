import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../api_client.dart';
import '../../token_storage.dart';
import '../../utils/app_colors.dart';
import '../../services/sync_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/local_database.dart';
import '../events_content.dart' as events_content;
import '../event_details_screen.dart';

class EventItem {
  final int eventId;
  final String title;
  final String? description;
  final String? location;
  final double? latitude;
  final double? longitude;
  final DateTime startAt;
  final DateTime? endAt;
  final String? category;
  final String? imageUrl;
  final int? createdBy;

  EventItem({
    required this.eventId,
    required this.title,
    this.description,
    this.location,
    this.latitude,
    this.longitude,
    required this.startAt,
    this.endAt,
    this.category,
    this.imageUrl,
    this.createdBy,
  });

  factory EventItem.fromJson(Map<String, dynamic> json) {
    // Gérer created_by qui peut être un int (API) ou un String (cache local)
    int? createdBy;
    final createdByValue = json['created_by'];
    if (createdByValue != null) {
      if (createdByValue is int) {
        createdBy = createdByValue;
      } else if (createdByValue is String) {
        createdBy = int.tryParse(createdByValue.trim());
      } else {
        createdBy = int.tryParse(createdByValue.toString().trim());
      }
    }
    
    return EventItem(
      eventId: json['event_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] is num ? json['latitude'].toDouble() : double.tryParse(json['latitude'].toString())) : null,
      longitude: json['longitude'] != null ? (json['longitude'] is num ? json['longitude'].toDouble() : double.tryParse(json['longitude'].toString())) : null,
      startAt: DateTime.parse(json['startAt'] as String),
      endAt: json['endAt'] != null ? DateTime.parse(json['endAt'] as String) : null,
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
      createdBy: createdBy,
    );
  }

  // Convertir vers EventItem de events_content.dart pour EventDetailsScreen
  events_content.EventItem toEventsContentEventItem() {
    return events_content.EventItem(
      eventId: eventId,
      title: title,
      description: description,
      location: location,
      latitude: latitude,
      longitude: longitude,
      startAt: startAt,
      endAt: endAt,
      category: category,
      imageUrl: imageUrl,
      createdBy: createdBy?.toString(),
    );
  }
}

class EventEditor extends StatefulWidget {
  const EventEditor({super.key});

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  List<EventItem> _myEvents = [];
  bool _isLoading = true;
  String? _error;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadMyEvents();
  }

  Future<void> _loadMyEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Récupérer l'ID de l'utilisateur actuel
      final userId = await SyncService.getCurrentUserId();
      if (userId == null) {
        setState(() {
          _error = 'Impossible de récupérer l\'ID utilisateur';
          _isLoading = false;
        });
        return;
      }

      _currentUserId = userId;

      // Vérifier la connectivité
      final isOnline = await ConnectivityService.checkConnectivity();
      
      if (isOnline) {
        // En ligne -> charger depuis l'API
        try {
          final response = await ApiClient.getEvents(page: 1, pageSize: 200);
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final eventsData = data['data'] as List<dynamic>;
            
            // Sauvegarder dans le cache local
            try {
              final eventsList = eventsData
                  .map((e) => e is Map<String, dynamic> ? e : e as Map<String, dynamic>)
                  .toList();
              await LocalDatabase.saveEvents(eventsList);
            } catch (e) {
              print(' Erreur lors de la sauvegarde dans le cache: $e');
            }
            
            final allEvents = eventsData
                .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
                .toList();

            // Filtrer pour ne garder que les événements créés par l'utilisateur
            final myEvents = allEvents
                .where((event) => event.createdBy == userId)
                .toList();

            // Trier par date de début (plus récents en premier)
            myEvents.sort((a, b) => b.startAt.compareTo(a.startAt));

            setState(() {
              _myEvents = myEvents;
              _isLoading = false;
              _error = null;
            });

            print(' ${myEvents.length} événement(s) créé(s) par l\'utilisateur chargé(s) depuis l\'API');
            return;
          } else {
            throw Exception('Erreur ${response.statusCode}: ${response.body}');
          }
        } catch (e) {
          print(' Erreur API, chargement depuis le cache: $e');
          // En cas d'erreur API, charger depuis le cache
        }
      }
      
      // Hors ligne ou erreur API -> charger depuis le cache local
      print(' Chargement depuis le cache local...');
      try {
        final eventsJson = await LocalDatabase.getAllEvents();
        
        if (eventsJson.isNotEmpty) {
          final allEvents = eventsJson
              .map((json) => EventItem.fromJson(json as Map<String, dynamic>))
              .toList();

          // Filtrer pour ne garder que les événements créés par l'utilisateur
          final myEvents = allEvents
              .where((event) => event.createdBy == userId)
              .toList();

          // Trier par date de début (plus récents en premier)
          myEvents.sort((a, b) => b.startAt.compareTo(a.startAt));

          setState(() {
            _myEvents = myEvents;
            _isLoading = false;
            _error = null; // Pas d'erreur, même si la liste est vide
          });

          print(' ${myEvents.length} événement(s) créé(s) par l\'utilisateur chargé(s) depuis le cache (${allEvents.length} au total)');
        } else {
          setState(() {
            _myEvents = [];
            _isLoading = false;
            _error = null; // Pas d'erreur, juste pas d'événements
          });
          print(' Aucun événement trouvé dans le cache local');
        }
      } catch (e) {
        print(' Erreur lors du chargement depuis le cache: $e');
        setState(() {
          _myEvents = [];
          _isLoading = false;
          _error = null; // Pas d'erreur, juste pas d'événements
        });
      }
    } catch (e) {
      print(' Erreur lors du chargement des événements: $e');
      setState(() {
        _error = 'Erreur lors du chargement: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _showCreateEventDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateEventDialog(),
    );

    if (result != null && result['success'] == true) {
      // Recharger la liste après création
      _loadMyEvents();
    }
  }

  Future<void> _showEditEventDialog(EventItem event) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateEventDialog(event: event),
    );

    if (result != null && result['success'] == true) {
      // Recharger la liste après modification
      _loadMyEvents();
    }
  }

  Future<void> _deleteEvent(EventItem event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'événement'),
        content: Text('Êtes-vous sûr de vouloir supprimer "${event.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await TokenStorage.read();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Non authentifié')),
        );
        return;
      }

      final response = await ApiClient.deleteEvent(
        token: token,
        eventId: event.eventId,
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Événement supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _loadMyEvents();
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getPrimaryBackground(context),
      body: Stack(
        children: [
          // Contenu principal
          Column(
            children: [
              // Liste des événements
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadMyEvents,
                                  child: const Text('Réessayer'),
                                ),
                              ],
                            ),
                          )
                        : _myEvents.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.event_note, size: 64, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Aucun événement créé',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Appuyez sur le bouton + pour créer votre premier événement',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadMyEvents,
                                child: ListView.builder(
                                  padding: EdgeInsets.only(
                                    top: MediaQuery.of(context).padding.top + 80,
                                    left: 16,
                                    right: 16,
                                    bottom: 16,
                                  ),
                                  itemCount: _myEvents.length,
                                  itemBuilder: (context, index) {
                                    final event = _myEvents[index];
                                    return InkWell(
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EventDetailsScreen(
                                              event: event.toEventsContentEventItem(),
                                            ),
                                          ),
                                        );
                                        // Recharger la liste après retour
                                        _loadMyEvents();
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.getCardBackground(context),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Date à gauche
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryButton.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${event.startAt.day}',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primaryButton,
                                                  ),
                                                ),
                                                Text(
                                                  '${event.startAt.month}',
                                                  style: const TextStyle(
                                                    color: AppColors.secondaryText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Contenu au milieu
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  event.title,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.getTextPrimary(context),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                if (event.location != null)
                                                  Text(
                                                    event.location!,
                                                    style: const TextStyle(
                                                      color: AppColors.secondaryText,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  )
                                                else
                                                  const Text(
                                                    'Lieu non spécifié',
                                                    style: TextStyle(
                                                      color: AppColors.secondaryText,
                                                    ),
                                                  ),
                                                if (event.description != null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    event.description!,
                                                    style: const TextStyle(
                                                      color: AppColors.secondaryText,
                                                      fontSize: 12,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          // Boutons actions à droite
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                _formatDate(event.startAt),
                                                style: TextStyle(
                                                  color: AppColors.getTextPrimary(context),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    onPressed: () => _showEditEventDialog(event),
                                                    icon: const Icon(
                                                      Icons.edit,
                                                      color: AppColors.primaryButton,
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    tooltip: 'Modifier',
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    onPressed: () => _deleteEvent(event),
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    tooltip: 'Supprimer',
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
          // Bouton flottant en haut à gauche
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: FloatingActionButton(
              mini: true,
              onPressed: _showCreateEventDialog,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateEventDialog extends StatefulWidget {
  final EventItem? event; // Si fourni, c'est une édition, sinon c'est une création

  const _CreateEventDialog({this.event});

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _streetNumberController;
  late final TextEditingController _streetNameController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _cityController;
  late final TextEditingController _categoryController;
  late final TextEditingController _imageUrlController;
  final _imagePicker = ImagePicker();
  
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSubmitting = false;
  bool _useImageFile = false; // true = fichier, false = URL
  File? _selectedImageFile;
  String? _selectedImageBase64;
  String? _currentImageUrl; // URL de l'image actuelle (pour l'édition)

  bool get isEditMode => widget.event != null;

  /// Vérifie si une URL est interne (uploadée sur le serveur)
  bool _isInternalUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    // URL interne si elle commence par /images/ ou contient le baseUrl de l'API
    return url.startsWith('/images/') || 
           url.startsWith('images/') ||
           url.contains(ApiClient.baseUrl);
  }

  /// Parse une adresse complète en champs séparés (pour le mode édition)
  void _parseAddress(String? address) {
    if (address == null || address.trim().isEmpty) {
      _streetNumberController = TextEditingController();
      _streetNameController = TextEditingController();
      _postalCodeController = TextEditingController();
      _cityController = TextEditingController();
      return;
    }

    // Format attendu: "Numéro Rue, Code Postal Ville, France"
    final parts = address.split(',');
    if (parts.length >= 2) {
      // Partie rue (numéro + nom)
      final streetPart = parts[0].trim();
      final streetMatch = RegExp(r'^(\d+)\s*(.+)$').firstMatch(streetPart);
      if (streetMatch != null) {
        _streetNumberController = TextEditingController(text: streetMatch.group(1) ?? '');
        _streetNameController = TextEditingController(text: streetMatch.group(2)?.trim() ?? '');
      } else {
        _streetNumberController = TextEditingController();
        _streetNameController = TextEditingController(text: streetPart);
      }

      // Partie code postal + ville
      final cityPart = parts[1].trim();
      final cityMatch = RegExp(r'^(\d{5})\s*(.+)$').firstMatch(cityPart);
      if (cityMatch != null) {
        _postalCodeController = TextEditingController(text: cityMatch.group(1) ?? '');
        _cityController = TextEditingController(text: cityMatch.group(2)?.trim() ?? '');
      } else {
        _postalCodeController = TextEditingController();
        _cityController = TextEditingController(text: cityPart);
      }
    } else {
      _streetNumberController = TextEditingController();
      _streetNameController = TextEditingController();
      _postalCodeController = TextEditingController();
      _cityController = TextEditingController();
    }
  }

  /// Construit l'adresse complète à partir des champs séparés
  String? _buildFullAddress() {
    final streetNumber = _streetNumberController.text.trim();
    final streetName = _streetNameController.text.trim();
    final postalCode = _postalCodeController.text.trim();
    final city = _cityController.text.trim();

    // Si tous les champs sont vides, retourner null
    if (streetNumber.isEmpty && streetName.isEmpty && postalCode.isEmpty && city.isEmpty) {
      return null;
    }

    // Construire l'adresse complète : "Numéro Rue, Code Postal Ville, France"
    final street = streetNumber.isEmpty 
        ? streetName 
        : streetName.isEmpty 
            ? streetNumber 
            : '$streetNumber $streetName';
    
    final cityPart = postalCode.isEmpty 
        ? city 
        : city.isEmpty 
            ? postalCode 
            : '$postalCode $city';

    if (street.isEmpty && cityPart.isEmpty) {
      return null;
    }

    // Ajouter "France" automatiquement
    return '$street, $cityPart, France';
  }

  /// Valide les champs d'adresse
  String? _validateStreetNumber(String? value) {
    // Optionnel, mais si rempli doit contenir un numéro
    if (value != null && value.trim().isNotEmpty) {
      if (!RegExp(r'^\d+').hasMatch(value.trim())) {
        return 'Le numéro doit commencer par un chiffre';
      }
    }
    return null;
  }

  String? _validatePostalCode(String? value) {
    // Optionnel, mais si rempli doit être un code postal valide (5 chiffres)
    if (value != null && value.trim().isNotEmpty) {
      if (!RegExp(r'^\d{5}$').hasMatch(value.trim())) {
        return 'Le code postal doit contenir 5 chiffres';
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    
    _titleController = TextEditingController(text: event?.title ?? '');
    _descriptionController = TextEditingController(text: event?.description ?? '');
    
    // Parser l'adresse existante en champs séparés
    _parseAddress(event?.location);
    
    _categoryController = TextEditingController(text: event?.category ?? '');
    
    // Ne pas pré-remplir le champ URL si c'est une URL interne
    final imageUrl = event?.imageUrl ?? '';
    if (imageUrl.isNotEmpty && !_isInternalUrl(imageUrl)) {
      _imageUrlController = TextEditingController(text: imageUrl);
    } else {
      _imageUrlController = TextEditingController();
    }
    
    if (event != null) {
      // Mode édition : pré-remplir les champs
      _startDate = event.startAt;
      _startTime = TimeOfDay.fromDateTime(event.startAt);
      if (event.endAt != null) {
        _endDate = event.endAt;
        _endTime = TimeOfDay.fromDateTime(event.endAt!);
      }
      _currentImageUrl = event.imageUrl;
      _useImageFile = false; // Par défaut, on affiche l'URL existante
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _streetNumberController.dispose();
    _streetNameController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _categoryController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromDevice() async {
    try {
      // Réduire la taille de l'image pour éviter les payloads trop volumineux
      // Limite à 1920px de largeur/hauteur max et qualité à 70%
      // imageQuality force la conversion en JPEG quand possible
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final bytes = await file.readAsBytes();
        
        // Vérifier la taille du fichier (limite à ~10MB pour base64 = ~13MB en base64)
        const maxSizeBytes = 10 * 1024 * 1024; // 10MB
        if (bytes.length > maxSizeBytes) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('L\'image est trop volumineuse. Veuillez choisir une image plus petite (max 10MB).'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        
        final base64String = base64Encode(bytes);
        
        setState(() {
          _selectedImageFile = file;
          _selectedImageBase64 = base64String;
          _useImageFile = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection de l\'image: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initialDate = isStart 
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      
      final initialTime = isStart
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now());
      
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: initialTime,
      );
      if (time != null) {
        setState(() {
          if (isStart) {
            _startTime = time;
          } else {
            _endTime = time;
          }
        });
      }
    }
  }

  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate == null || _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une date et une heure de début')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final token = await TokenStorage.read();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Non authentifié')),
        );
        return;
      }

      final startAt = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      DateTime? endAt;
      if (_endDate != null && _endTime != null) {
        endAt = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          _endTime!.hour,
          _endTime!.minute,
        );
      }

      // Déterminer l'URL de l'image : soit uploader le fichier, soit utiliser l'URL
      String? imageUrl;
      if (_useImageFile && _selectedImageFile != null) {
        // Uploader l'image sur le serveur
        final uploadResponse = await ApiClient.uploadEventImage(
          token: token,
          imageFile: _selectedImageFile!,
        );

        if (uploadResponse.statusCode == 200) {
          final uploadData = jsonDecode(uploadResponse.body);
          imageUrl = uploadData['imageUrl'] as String?;
          print(' Image uploadée avec succès: $imageUrl');
        } else {
          print(' Erreur upload - Status: ${uploadResponse.statusCode}');
          print(' Erreur upload - Body: ${uploadResponse.body}');
          String errorMessage = 'Erreur lors de l\'upload de l\'image';
          try {
            final errorData = jsonDecode(uploadResponse.body);
            errorMessage = errorData['message'] ?? errorMessage;
          } catch (e) {
            errorMessage = uploadResponse.body;
          }
          throw Exception(errorMessage);
        }
      } else if (!_useImageFile && _imageUrlController.text.trim().isNotEmpty) {
        imageUrl = _imageUrlController.text.trim();
      } else if (isEditMode && _currentImageUrl != null && !_useImageFile && _imageUrlController.text.trim().isEmpty) {
        // En mode édition, si aucune nouvelle image n'est fournie, garder l'ancienne
        imageUrl = _currentImageUrl;
      }

      http.Response response;
      if (isEditMode) {
        // Mode édition
        response = await ApiClient.updateEvent(
          token: token,
          eventId: widget.event!.eventId,
          title: _titleController.text.trim(),
          startAt: startAt,
          endAt: endAt,
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          location: _buildFullAddress(),
          category: _categoryController.text.trim().isEmpty 
              ? null 
              : _categoryController.text.trim(),
          imageUrl: imageUrl,
        );

        if (response.statusCode == 200) {
          final eventData = jsonDecode(response.body);
          final hasCoordinates = eventData['latitude'] != null && eventData['longitude'] != null;
          
          if (mounted) {
            Navigator.of(context).pop({'success': true});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(hasCoordinates 
                  ? 'Événement modifié avec succès ! Le pin sur la carte a été mis à jour.'
                  : 'Événement modifié avec succès !'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          final errorData = jsonDecode(response.body);
          final isGeocodeError = errorData['geocodeError'] == true;
          
          if (isGeocodeError && mounted) {
            // Erreur de géocodage : afficher un dialogue pour redemander l'adresse
            _showGeocodeErrorDialog(
              errorData['message'] ?? 'Adresse introuvable',
              errorData['addressFormat'] ?? 'Format requis: "Numéro Rue, Code Postal Ville"',
            );
            return; // Ne pas fermer le dialogue
          }
          
          throw Exception(errorData['message'] ?? 'Erreur lors de la modification');
        }
      } else {
        // Mode création
        response = await ApiClient.createEvent(
          token: token,
          title: _titleController.text.trim(),
          startAt: startAt,
          endAt: endAt,
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          location: _buildFullAddress(),
          category: _categoryController.text.trim().isEmpty 
              ? null 
              : _categoryController.text.trim(),
          imageUrl: imageUrl,
        );

        if (response.statusCode == 201) {
          final eventData = jsonDecode(response.body);
          final hasCoordinates = eventData['latitude'] != null && eventData['longitude'] != null;
          
          if (mounted) {
            Navigator.of(context).pop({'success': true});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(hasCoordinates 
                  ? 'Événement créé avec succès ! Le pin a été ajouté sur la carte.'
                  : 'Événement créé avec succès !'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          final errorData = jsonDecode(response.body);
          final isGeocodeError = errorData['geocodeError'] == true;
          
          if (isGeocodeError && mounted) {
            // Erreur de géocodage : afficher un dialogue pour redemander l'adresse
            _showGeocodeErrorDialog(
              errorData['message'] ?? 'Adresse introuvable',
              errorData['addressFormat'] ?? 'Format requis: "Numéro Rue, Code Postal Ville"',
            );
            return; // Ne pas fermer le dialogue
          }
          
          throw Exception(errorData['message'] ?? 'Erreur lors de la création');
        }
      }
    } catch (e) {
      print('Erreur création événement: $e');
      if (mounted) {
        // Vérifier si c'est une erreur de géocodage dans le message
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('adresse') || errorString.contains('géocodage') || errorString.contains('coordonnées')) {
          _showGeocodeErrorDialog(
            e.toString().replaceAll('Exception: ', ''),
            'Format requis: "Numéro Rue, Code Postal Ville" (France sera ajouté automatiquement)',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// Affiche un dialogue d'erreur pour le géocodage et demande à l'utilisateur de corriger l'adresse
  void _showGeocodeErrorDialog(String errorMessage, String formatHint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Flexible(
              child: Text('Adresse introuvable'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                errorMessage,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Veuillez corriger l\'adresse en respectant le format suivant:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Format requis:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '"Numéro Rue, Code Postal Ville"',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '(Le pays "France" sera ajouté automatiquement)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Exemples:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 18 rue du 8 mai 1945, 49124 Saint barthelemy d\'Anjou\n'
                      '• 1 Place du Ralliement, 49100 Angers\n'
                      '• 10 Avenue de la Gare, 49000 Angers',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Focus sur le premier champ d'adresse
              FocusScope.of(context).requestFocus(FocusNode());
            },
            child: const Text('Corriger l\'adresse'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: 600,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditMode ? 'Modifier l\'événement' : 'Créer un événement',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre *',
                      hintText: 'Ex : Concert de jazz',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le titre est requis';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Description de l\'événement',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // Titre de la section adresse
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Adresse',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Numéro de rue
                  TextFormField(
                    controller: _streetNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Numéro de rue',
                      hintText: 'Ex : 18',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                    validator: _validateStreetNumber,
                  ),
                  const SizedBox(height: 12),
                  // Nom de rue
                  TextFormField(
                    controller: _streetNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom de la rue *',
                      hintText: 'Ex : rue du 8 mai 1945',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.streetview),
                    ),
                    validator: (value) {
                      // Vérifier qu'au moins le nom de rue ou le numéro est rempli
                      final streetNumber = _streetNumberController.text.trim();
                      if ((value == null || value.trim().isEmpty) && streetNumber.isEmpty) {
                        return 'Veuillez remplir au moins le numéro ou le nom de rue';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Code postal
                  TextFormField(
                    controller: _postalCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Code postal *',
                      hintText: 'Ex : 49124',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.markunread_mailbox),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    validator: (value) {
                      // Vérifier qu'au moins le code postal ou la ville est rempli
                      final city = _cityController.text.trim();
                      if ((value == null || value.trim().isEmpty) && city.isEmpty) {
                        return 'Veuillez remplir au moins le code postal ou la ville';
                      }
                      return _validatePostalCode(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Ville
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Ville *',
                      hintText: 'Ex : Saint barthelemy d\'Anjou',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                    validator: (value) {
                      // Vérifier qu'au moins le code postal ou la ville est rempli
                      final postalCode = _postalCodeController.text.trim();
                      if ((value == null || value.trim().isEmpty) && postalCode.isEmpty) {
                        return 'Veuillez remplir au moins le code postal ou la ville';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Le pays "France" sera ajouté automatiquement',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      hintText: 'Ex : Musique, Sport, Culture...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Section Image
                  const Text(
                    'Image de l\'événement',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  // Choix entre URL et fichier
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('URL'),
                          selected: !_useImageFile,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _useImageFile = false;
                                _selectedImageFile = null;
                                _selectedImageBase64 = null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Depuis l\'appareil'),
                          selected: _useImageFile,
                          onSelected: (selected) {
                            if (selected) {
                              _pickImageFromDevice();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Champ URL ou affichage de l'image sélectionnée
                  if (!_useImageFile)
                    Builder(
                      builder: (context) {
                        // Vérifier si on a une URL interne à afficher
                        final urlToShow = isEditMode && _currentImageUrl != null && _currentImageUrl!.isNotEmpty
                            ? _currentImageUrl!
                            : (_imageUrlController.text.trim().isNotEmpty ? _imageUrlController.text.trim() : null);
                        
                        final isInternal = urlToShow != null && _isInternalUrl(urlToShow);
                        
                        // Construire l'URL complète si c'est une URL relative
                        String? fullImageUrl;
                        if (urlToShow != null) {
                          // Utiliser la fonction de nettoyage d'URL pour éviter les erreurs
                          fullImageUrl = ApiClient.cleanUrl(urlToShow);
                        }
                        
                        if (isInternal && fullImageUrl != null) {
                          // Afficher directement l'image pour les URLs internes
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isEditMode ? 'Image actuelle:' : 'Image:',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    if (isEditMode)
                                      TextButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _currentImageUrl = null;
                                            _imageUrlController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.delete, size: 16),
                                        label: const Text('Supprimer'),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: SizedBox(
                                    height: 150,
                                    width: double.infinity,
                                    child: FlexibleImage(
                                      imageUrl: fullImageUrl,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          // Afficher le champ URL pour les URLs externes
                          return TextFormField(
                            controller: _imageUrlController,
                            decoration: const InputDecoration(
                              labelText: 'URL de l\'image',
                              hintText: 'https://example.com/image.jpg',
                              border: OutlineInputBorder(),
                            ),
                          );
                        }
                      },
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedImageFile != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                _selectedImageFile!,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedImageFile!.path.split('/').last,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedImageFile = null;
                                      _selectedImageBase64 = null;
                                      _useImageFile = false;
                                    });
                                  },
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: const Text('Supprimer'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _pickImageFromDevice,
                                icon: const Icon(Icons.image),
                                label: const Text('Sélectionner une image'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Date et heure de début *',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectDate(context, true),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _startDate != null && _startTime != null
                                ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} à ${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                                : 'Sélectionner la date et l\'heure',
                            style: TextStyle(
                              color: _startDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Date et heure de fin (optionnel)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectDate(context, false),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _endDate != null && _endTime != null
                                ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year} à ${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                                : 'Sélectionner la date et l\'heure',
                            style: TextStyle(
                              color: _endDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: Text(_isSubmitting 
                          ? (isEditMode ? 'Modification en cours...' : 'Création en cours...') 
                          : (isEditMode ? 'Modifier l\'événement' : 'Créer l\'événement')),
                      onPressed: _isSubmitting ? null : _submitEvent,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
