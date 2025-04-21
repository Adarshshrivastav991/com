import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  static Future<LatLng> getCurrentLatLng() async {
    final position = await _getCurrentLocation();
    return LatLng(position.latitude, position.longitude);
  }

  static Future<String> getAddressFromLatLng(LatLng latLng) async {
    final placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
    final place = placemarks.first;
    return '${place.street}, ${place.locality}, ${place.country}';
  }

  static Future<bool> isInPickupZone(LatLng userLocation) async {
    // Mock: Replace with your geofencing logic
    final pickupZones = [
      LatLng(28.6129, 77.2295),  // Example: Delhi coordinates
      LatLng(19.0760, 72.8777),  // Example: Mumbai coordinates
    ];

    for (var zone in pickupZones) {
      double distance = Geolocator.distanceBetween(
        userLocation.latitude, userLocation.longitude,
        zone.latitude, zone.longitude,
      );
      if (distance <= 5000) {  // 5km radius
        return true;
      }
    }
    return false;
  }
}