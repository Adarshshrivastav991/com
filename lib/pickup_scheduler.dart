import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Add this import
import 'package:intl/intl.dart';


class PickupScheduler {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Requests a waste pickup with the given details
  static Future<void> requestPickup({
    required String userId,
    required String address,
    required LatLng location,  // Now properly recognized
    required String wasteType,
    String? notes,
  }) async {
    try {
      await _firestore.collection('pickup_requests').add({
        'userId': userId,
        'address': address,
        'location': _latLngToGeoPoint(location),  // Convert to Firestore GeoPoint
        'wasteType': wasteType,
        'status': 'pending',
        'notes': notes,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to schedule pickup: $e');
    }
  }

  /// Gets optimized pickup routes for drivers
  static Future<List<Map<String, dynamic>>> getOptimizedRoutes() async {
    try {
      final snapshot = await _firestore
          .collection('pickup_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp')
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'location': _geoPointToLatLng(data['location'] as GeoPoint),  // Convert back to LatLng
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get routes: $e');
    }
  }

  /// Helper to convert Firestore GeoPoint to LatLng
  static LatLng _geoPointToLatLng(GeoPoint geoPoint) {
    return LatLng(geoPoint.latitude, geoPoint.longitude);
  }

  /// Helper to convert LatLng to Firestore GeoPoint
  static GeoPoint _latLngToGeoPoint(LatLng latLng) {
    return GeoPoint(latLng.latitude, latLng.longitude);
  }

  /// Schedules a notification for the pickup time
  static Future<void> scheduleNotification({
    required String userId,
    required DateTime pickupTime,
    required String address,
  }) async {
    try {
      final formattedTime = DateFormat('MMM dd, yyyy - hh:mm a').format(pickupTime);
      print('Notification scheduled for $formattedTime at $address');

      // In a real app, implement FCM notification here
      // await _sendFcmNotification(userId, 'Pickup Scheduled',
      //   'Your waste pickup is scheduled for $formattedTime');
    } catch (e) {
      throw Exception('Failed to schedule notification: $e');
    }
  }
}