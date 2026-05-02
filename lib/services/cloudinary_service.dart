import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';

class CloudinaryService {
  static late String _cloudName;
  static late String _uploadPreset;
  static late String? _apiKey;
  static late String? _apiSecret;
  
  static final Dio _dio = Dio();

  /// Initialize Cloudinary with your credentials
  static void initialize({
    required String cloudName,
    required String uploadPreset,
    String? apiKey,
    String? apiSecret,
  }) {
    _cloudName = cloudName;
    _uploadPreset = uploadPreset;
    _apiKey = apiKey;
    _apiSecret = apiSecret;
  }

  /// Upload an image to Cloudinary from device
  static Future<String?> uploadImage({
    required String filePath,
    String folder = 'showroom_app',
    String? publicId,
  }) async {
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        print('File does not exist: $filePath');
        return null;
      }

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'upload_preset': _uploadPreset,
        'folder': folder,
        'public_id': ?publicId,
      });

      final response = await _dio.post(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
        data: formData,
        onSendProgress: (int sent, int total) {
          print('Upload progress: ${(sent / total * 100).toStringAsFixed(0)}%');
        },
      );

      if (response.statusCode == 200) {
        final url = response.data['secure_url'] ?? response.data['url'];
        print('✓ Image uploaded successfully: $url');
        return url;
      } else {
        print('Upload failed: ${response.statusMessage}');
        return null;
      }
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// Pick an image from device and upload to Cloudinary
  static Future<String?> pickAndUploadImage({
    String folder = 'showroom_app',
    ImageSource source = ImageSource.gallery,
    String? publicId,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image == null) {
        print('No image selected');
        return null;
      }

      return await uploadImage(
        filePath: image.path,
        folder: folder,
        publicId: publicId,
      );
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// Delete image from Cloudinary (requires API key and secret)
  static Future<bool> deleteImage({required String publicId}) async {
    if (_apiKey == null || _apiSecret == null) {
      print('API key and secret required for deletion');
      return false;
    }

    try {
      final formData = FormData.fromMap({
        'public_id': publicId,
        'api_key': _apiKey,
      });

      final response = await _dio.post(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/destroy',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Basic ${_encodeBasicAuth(_apiKey!, _apiSecret!)}',
          },
        ),
      );

      return response.statusCode == 200 && 
             response.data['result'] == 'ok';
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  /// Get optimized image URL with transformations
  static String getOptimizedImageUrl({
    required String publicId,
    int? width,
    int? height,
    String quality = 'auto',
    String fit = 'fill',
  }) {
    String url = 'https://res.cloudinary.com/$_cloudName/image/upload/';
    
    // Add transformations
    List<String> transformations = [];
    
    if (width != null || height != null) {
      if (width != null && height != null) {
        transformations.add('c_$fit'); // crop/fill
        transformations.add('w_$width');
        transformations.add('h_$height');
      } else if (width != null) {
        transformations.add('w_$width');
        transformations.add('c_scale');
      } else if (height != null) {
        transformations.add('h_$height');
        transformations.add('c_scale');
      }
    }
    
    transformations.add('q_$quality');
    transformations.add('f_auto'); // auto format conversion

    if (transformations.isNotEmpty) {
      url += '${transformations.join(',')}/';
    }

    url += publicId;
    return url;
  }

  /// Get image URL by public ID
  static String getImageUrl({required String publicId}) {
    return 'https://res.cloudinary.com/$_cloudName/image/upload/$publicId';
  }

  /// Helper function to encode basic auth
  static String _encodeBasicAuth(String username, String password) {
    return base64.encode(utf8.encode('$username:$password'));
  }
}
