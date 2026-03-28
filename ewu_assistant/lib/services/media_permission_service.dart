import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaPermissionResult {
  const MediaPermissionResult({
    required this.granted,
    required this.message,
    this.permanentlyDenied = false,
  });

  final bool granted;
  final String message;
  final bool permanentlyDenied;
}

class MediaPermissionService {
  const MediaPermissionService._();

  static Future<MediaPermissionResult> ensureAccess(ImageSource source) async {
    if (source == ImageSource.camera) {
      return _requestCamera();
    }
    return _requestGallery();
  }

  static Future<MediaPermissionResult> _requestCamera() async {
    final PermissionStatus current = await Permission.camera.status;
    if (current.isGranted) {
      return const MediaPermissionResult(
        granted: true,
        message: 'Camera permission already granted.',
      );
    }

    if (current.isPermanentlyDenied || current.isRestricted) {
      return const MediaPermissionResult(
        granted: false,
        permanentlyDenied: true,
        message:
            'Camera permission is turned off for EWU Assistant. Enable it from app settings to take photos.',
      );
    }

    final PermissionStatus status = await Permission.camera.request();
    if (status.isGranted) {
      return const MediaPermissionResult(
        granted: true,
        message: 'Camera permission granted.',
      );
    }

    return MediaPermissionResult(
      granted: false,
      permanentlyDenied: status.isPermanentlyDenied,
      message: status.isPermanentlyDenied
          ? 'Camera permission is turned off for EWU Assistant. Enable it from app settings to take photos.'
          : 'Camera permission was denied, so we could not open the camera.',
    );
  }

  static Future<MediaPermissionResult> _requestGallery() async {
    if (Platform.isIOS) {
      return _requestPhotosPermission(Permission.photos);
    }

    if (Platform.isAndroid) {
      final MediaPermissionResult photosResult = await _requestPhotosPermission(
        Permission.photos,
      );
      if (photosResult.granted) {
        return photosResult;
      }

      final MediaPermissionResult storageResult =
          await _requestPhotosPermission(Permission.storage);
      if (storageResult.granted) {
        return const MediaPermissionResult(
          granted: true,
          message: 'Gallery permission granted.',
        );
      }

      if (photosResult.permanentlyDenied || storageResult.permanentlyDenied) {
        return const MediaPermissionResult(
          granted: false,
          permanentlyDenied: true,
          message:
              'Gallery permission is turned off for EWU Assistant. Enable photo access from app settings to choose images.',
        );
      }

      return const MediaPermissionResult(
        granted: false,
        message:
            'Gallery permission was denied, so we could not open your photos.',
      );
    }

    return const MediaPermissionResult(
      granted: true,
      message: 'Gallery access is available.',
    );
  }

  static Future<MediaPermissionResult> _requestPhotosPermission(
    Permission permission,
  ) async {
    final PermissionStatus current = await permission.status;
    if (current.isGranted || current.isLimited) {
      return const MediaPermissionResult(
        granted: true,
        message: 'Photo access granted.',
      );
    }

    if (current.isPermanentlyDenied || current.isRestricted) {
      return const MediaPermissionResult(
        granted: false,
        permanentlyDenied: true,
        message:
            'Photo access is turned off for EWU Assistant. Enable it from app settings to choose images.',
      );
    }

    final PermissionStatus status = await permission.request();
    if (status.isGranted || status.isLimited) {
      return const MediaPermissionResult(
        granted: true,
        message: 'Photo access granted.',
      );
    }

    return MediaPermissionResult(
      granted: false,
      permanentlyDenied: status.isPermanentlyDenied,
      message: status.isPermanentlyDenied
          ? 'Photo access is turned off for EWU Assistant. Enable it from app settings to choose images.'
          : 'Photo access was denied, so we could not open your gallery.',
    );
  }
}
