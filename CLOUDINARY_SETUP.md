# Cloudinary Integration Setup Guide

## What You Need To Do:

### 1. **Get Cloudinary Credentials** 
   - Go to [https://cloudinary.com/](https://cloudinary.com/)
   - Sign up for a free account (or log in)
   - Go to Dashboard → Settings → API Keys
   - Copy your:
     - **Cloud Name** (most important) ✅ 
     - **API Key** (optional for uploads via unsigned uploads)
     - **API Secret** (keep this private, never share!)

### 2. **Create Upload Preset (IMPORTANT)**
   - Go to Dashboard → Upload Presets
   - Click "Create upload preset" button
   - Set the following:
     - **Mode**: Unsigned (for client-side uploads without backend)
     - **Name**: `showroom_app` (or your preferred name)
     - **Folder**: `showroom_app` (organizing uploads)
   - Save and copy the preset name

### 3. **Update main.dart**
   - Replace `'YOUR_CLOUD_NAME'` with your actual Cloudinary cloud name
   - Replace `'YOUR_UPLOAD_PRESET'` with the upload preset name you created
   - API Key and Secret are optional (only needed for image deletion)
   - File: `lib/main.dart` (already updated)

### 4. **Run Pub Get**
   ```
   flutter pub get
   ```

### 5. **Update Android Permissions** (for image_picker)
   - Open `android/app/src/main/AndroidManifest.xml`
   - Add these permissions if not present:
     ```xml
     <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
     <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
     <uses-permission android:name="android.permission.CAMERA" />
     ```

### 6. **Update iOS Permissions** (for image_picker)
   - Open `ios/Runner/Info.plist`
   - Add these keys:
     ```xml
     <key>NSPhotoLibraryUsageDescription</key>
     <string>We need access to your photos to upload vehicle images</string>
     <key>NSCameraUsageDescription</key>
     <string>We need camera access to capture vehicle photos</string>
     <key>NSPhotoLibraryAddOnlyUsageDescription</key>
     <string>We need to save photos to your library</string>
     ```

---

## How to Use Cloudinary Service in Your App:

### **Option 1: Pick and Upload Image (Recommended for UI)**
```dart
import 'package:showroom_app/services/cloudinary_service.dart';
import 'package:image_picker/image_picker.dart';

// In your button/widget:
final imageUrl = await CloudinaryService.pickAndUploadImage(
  folder: 'inquiry_images', // Optional: organize by folder
  source: ImageSource.gallery, // or ImageSource.camera
);

if (imageUrl != null) {
  print('Image uploaded: $imageUrl');
  // Save this URL to Firestore
} else {
  print('Upload cancelled or failed');
}
```

### **Option 2: Direct Upload from File Path**
```dart
final imageUrl = await CloudinaryService.uploadImage(
  filePath: '/path/to/image.jpg',
  folder: 'inquiry_images',
  publicId: 'unique_id_here', // Optional
);
```

### **Option 3: Display Image with Optimization**
```dart
// Simple display:
Image.network(
  CloudinaryService.getImageUrl(publicId: 'your_image_id'),
)

// With optimizations (resize for performance):
Image.network(
  CloudinaryService.getOptimizedImageUrl(
    publicId: 'your_image_id',
    width: 300,
    height: 300,
    quality: 'auto',
    fit: 'fill',
  ),
)

// With caching (recommended):
CachedNetworkImage(
  imageUrl: CloudinaryService.getOptimizedImageUrl(
    publicId: 'your_image_id',
    width: 300,
    height: 300,
  ),
  placeholder: (context, url) => const CircularProgressIndicator(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
)
```

### **Option 4: Delete Image (requires API key & secret)**
```dart
final deleted = await CloudinaryService.deleteImage(
  publicId: 'your_image_id',
);
```

---

## Example: Using Cloudinary in add_inquiry_screen.dart

Add this to your state class:
```dart
String? vehicleImageUrl; // Store the image URL
bool uploadingImage = false;

// Add a button to upload image:
ElevatedButton.icon(
  onPressed: () async {
    setState(() => uploadingImage = true);
    
    final url = await CloudinaryService.pickAndUploadImage(
      folder: 'inquiry_vehicles',
      source: ImageSource.gallery,
    );
    
    setState(() => uploadingImage = false);
    
    if (url != null) {
      setState(() {
        vehicleImageUrl = url;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('✓ Image uploaded!')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('❌ Upload failed')));
    }
  },
  icon: uploadingImage 
    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
    : const Icon(Icons.upload_file),
  label: const Text('Upload Vehicle Photo'),
)

// Display the image:
if (vehicleImageUrl != null)
  CachedNetworkImage(
    imageUrl: vehicleImageUrl!,
    height: 200,
    fit: BoxFit.cover,
    placeholder: (context, url) => const CircularProgressIndicator(),
  )
else
  Container(
    height: 200,
    color: Colors.grey[300],
    child: const Center(child: Text('No image selected')),
  )
```

---

## Storing Images in Firestore

When saving inquiry data to Firestore, include the image URL:
```dart
await FirebaseFirestore.instance.collection('inquiries').add({
  'name': nameController.text,
  'phone': phoneController.text,
  'vehicleImageUrl': vehicleImageUrl, // Cloudinary URL
  'brand': selectedBrand,
  'model': selectedModel,
  'uploadedAt': FieldValue.serverTimestamp(),
  // ... other fields
});
```

---

## Important Notes:

✅ **Security Best Practices:**
- Use **Unsigned uploads** (upload preset) for client-side uploads (no backend needed)
- Never expose API secret in client code
- Upload presets can be restricted to specific folders/transformations
- Free tier gives you 25 GB storage + 25 GB bandwidth/month

✅ **Performance Tips:**
- Always use `CachedNetworkImage` for better performance
- Use optimized URLs with width/height to reduce bandwidth
- Cloudinary auto-formats images (WebP for modern browsers)
- CDN caches all images globally

✅ **Free Tier Limits:**
- 25 GB storage, 25 GB bandwidth/month
- Perfect for your showroom app with a few thousand images

---

## Troubleshooting:

| Issue | Solution |
|-------|----------|
| "Cloud name not set" | Make sure you updated main.dart with real credentials |
| Upload preset not found | Create upload preset in Cloudinary Dashboard → Upload Presets |
| Image upload fails | Check internet & ensure upload preset exists |
| Storage permissions denied | Update AndroidManifest.xml & Info.plist |
| Images load slowly | Use optimized URLs or enable caching |
| Compilation errors | Run `flutter clean && flutter pub get` |

---

## Next Steps:

1. ✅ Dependencies added (pubspec.yaml)
2. ✅ Service created (cloudinary_service.dart)
3. ✅ Main.dart initialized
4. → **NOW: Create Cloudinary account & upload preset**
5. → Get your Cloud Name and Upload Preset
6. → Update main.dart with credentials
7. → Run `flutter pub get`
8. → Update Android/iOS permissions
9. → Use the service in your screens!

---

## Quick Reference Commands:

```bash
# Clean and reinstall
flutter clean
flutter pub get

# Run app
flutter run

# Build APK
flutter build apk --release

# Build iOS
flutter build ios --release
```
