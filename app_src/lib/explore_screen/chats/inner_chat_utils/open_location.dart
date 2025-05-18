// inner_chat_utils/open_location.dart
import 'package:url_launcher/url_launcher.dart';

/// Abre la ubicación [lat, lng] (y opcionalmente [address]) en Google Maps u otra app.
Future<void> openLocation({
  required double lat,
  required double lng,
  String? address,
}) async {
  // Construimos la query para Google Maps. Si no hay dirección, usamos lat,lng
  final encodedQuery = Uri.encodeComponent(address ?? '$lat,$lng');
  final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedQuery');

  if (await canLaunchUrl(googleMapsUrl)) {
    // Abre en modo externo (fuera de la app, p.e. Google Maps)
    await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
  } else {
    // Fallback
    print("No se pudo abrir la ubicación en Google Maps");
  }
}
