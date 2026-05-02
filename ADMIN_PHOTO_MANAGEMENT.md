# Admin Vehicle Catalog - Photo Management Guide

## What's New ✨

The showroom app now has full photo management:

### **For Admin:**
- ✅ Upload vehicle photos for each variant
- ✅ View photo thumbnails in the catalog list
- ✅ Update/change photos along with other vehicle details (name, price)
- ✅ Photos stored in Cloudinary, linked to Firestore

### **For Staff/Customers:**
- ✅ See vehicle photos when creating inquiries
- ✅ Photo displayed automatically when variant is selected
- ✅ Photo saved with inquiry for reference
- ✅ Beautiful photo preview (220px height)

---

## Admin Workflow

### **Step 1: Upload Photos to Vehicle Variants**

1. Admin Dashboard → Vehicle Catalog
2. Select Brand → Select Model
3. Click Edit (✏️) button on any variant
4. Click **"Upload Photo"** button
5. Select photo from gallery
6. Photo uploads automatically
7. Click **"Save"** to update variant
8. Photo thumbnail appears in list

### **Step 2: View Variant Catalog with Photos**

- Variant list now shows:
  - Photo thumbnail (60x60) on the left
  - Variant name and price
  - Edit and Delete buttons

---

## Staff/Customer Inquiry Workflow

### **Step 1: Create Inquiry with Vehicle Photo**

1. Staff opens "New Inquiry" screen
2. Fills in customer details (name, phone)
3. Selects Brand → Model → Variant
4. **Vehicle photo automatically displays!** 📸
5. Photo shows:
   - Full variant photo (220px height)
   - Auto-loads from Cloudinary
   - Shows placeholder if no photo
6. Staff confirms details and sends WhatsApp

### **Step 2: Inquiry Saved with Photo**

- Inquiry record includes `vehiclePhotoUrl`
- Admin can see photo when reviewing inquiries
- Photo reference available for future follow-ups

---

## Technical Details

### **Admin Variant (Database)**

```json
{
  "Name": "SE 1.6 Manual",
  "Price": "450000",
  "ParentModel": "City",
  "ParentBrand": "Honda",
  "photoUrl": "https://res.cloudinary.com/.../variant_image.jpg"
}
```

### **Staff Inquiry (Database)**

```json
{
  "name": "John Doe",
  "phone": "9876543210",
  "brand": "Honda",
  "model": "City",
  "variant": "SE 1.6 Manual",
  "vehiclePhotoUrl": "https://res.cloudinary.com/.../variant_image.jpg",
  "price": "450000",
  "status": "New Inquiry",
  "createdAt": "2024-04-27T..."
}
```

---

## Files Modified

| File | Changes |
|------|---------|
| `lib/services/screens/admin/variant_screen.dart` | Added photo upload, display, and edit functionality |
| `lib/services/screens/staff/add_inquiry_screen.dart` | Added photo preview when variant selected |
| `lib/services/cloudinary_service.dart` | Created (photo upload service) |
| `lib/main.dart` | Initialized Cloudinary |
| `pubspec.yaml` | Added dependencies |

---

## UI Features

### ✨ **Admin Variant Photo Management**

**Edit Dialog:**
- 200x200 photo preview area
- "Upload Photo" button
- Progress indicator during upload
- Success/error messages
- Fields for name and price
- Save button

**List View:**
- 60x60 photo thumbnail
- Variant name and price
- Edit and Delete buttons
- Smooth loading and error handling

### ✨ **Staff Inquiry Photo Preview**

**New Inquiry Screen:**
- 220px height photo preview
- Shows when variant is selected
- Cached for performance
- Placeholder for missing photos
- Beautiful border styling
- Responsive design

---

## Photo Management Best Practices

### 📸 **Recommended Guidelines:**

| Item | Recommendation |
|------|-----------------|
| **Dimensions** | 1000x800px (landscape) |
| **Format** | JPG or PNG |
| **Size** | 500KB - 2MB |
| **Content** | Vehicle side/3/4 view |
| **Quality** | High resolution |

### 🎯 **Tips:**

1. **Best to add**: When creating new variants
2. **Can update**: Anytime via edit dialog
3. **Storage**: Free 25GB on Cloudinary
4. **Performance**: Auto-cached, auto-optimized

---

## Cloudinary Configuration

### ✅ **Upload Settings:**

- Cloud: showroom_app
- Preset: Unsigned (client-side)
- Folder: `vehicle_variants/{brand}`
- Auto-format: WebP
- Auto-optimize: Yes

### 📊 **Image URLs:**

**Full Size:**
```
https://res.cloudinary.com/{cloud}/image/upload/vehicle_variants/Honda/photo.jpg
```

**Admin Thumbnail (60x60):**
```
https://res.cloudinary.com/{cloud}/image/upload/c_fill,w_60,h_60,q_auto/vehicle_variants/Honda/photo.jpg
```

---

## Step-by-Step Examples

### **Example 1: Admin Adding Photo to Variant**

1. Admin Dashboard → Vehicle Catalog
2. Honda → City
3. See list: [SE] [SV] [EX] [RS]
4. Click Edit (✏️) on "SE"
5. Dialog: Empty photo area + "Upload Photo" button
6. Click Upload → Select photo
7. Photo appears in preview
8. Click Save
9. ✅ Variant updated, thumbnail shows in list

### **Example 2: Staff Creating Inquiry with Photo**

1. Staff: New Inquiry
2. Name: "Rajesh Kumar"
3. Phone: "9876543210"
4. Brand: Honda
5. Model: City
6. **Variant: SE** → Photo auto-displays!
7. See beautiful Honda City SE photo (220px)
8. Continue with inquiry details
9. Send WhatsApp + Save
10. ✅ Inquiry saved with `vehiclePhotoUrl`

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Photo not uploading | Check internet & Cloudinary dashboard |
| Photo not showing in list | Refresh the screen |
| Slow photo loading | Network delay - Cloudinary optimizing |
| Wrong photo uploaded | Edit again and select correct image |
| Photo shows broken icon | Cloudinary URL may have expired |
| Upload button disabled | Wait for previous upload to finish |

---

## Future Enhancements

- [ ] Multiple photos per variant (gallery view)
- [ ] Photo drag-and-drop
- [ ] Photo cropping before upload
- [ ] Auto-generated compressed versions
- [ ] Photo moderation approval
- [ ] Customer photo uploads for comparison

---

## Support

For issues:
1. Check internet connection
2. Verify Cloudinary dashboard
3. Check Firestore console
4. Refresh app and retry
5. Contact development team if persistent

---

## Summary

✅ **What's Working:**

1. Admin can upload photos to vehicle variants
2. Staff sees photos when creating inquiries
3. Customers see vehicle photos in inquiries
4. Photos stored in Cloudinary
5. Photos linked in Firestore
6. Beautiful UI with loading states
7. Performance optimized with caching

🎉 **App is now fully featured with photo management!**
