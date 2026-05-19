import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleModelLookupData {
  const VehicleModelLookupData({
    required this.price,
    required this.photoUrls,
    required this.description,
    this.primaryPhotoUrl,
    this.vehicleId,
  });

  final String price;
  final List<String> photoUrls;
  final String description;
  final String? primaryPhotoUrl;
  final String? vehicleId;

  static const empty = VehicleModelLookupData(
    price: '',
    photoUrls: [],
    description: '',
  );
}

String _firstNonEmptyValue(List<dynamic> candidates) {
  for (final candidate in candidates) {
    final text = candidate?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
  }

  return '';
}

List<String> _stringListFrom(dynamic value) {
  if (value is! Iterable) {
    return const [];
  }

  final seen = <String>{};
  final items = <String>[];

  for (final item in value) {
    final text = item?.toString().trim() ?? '';
    if (text.isEmpty || !seen.add(text)) {
      continue;
    }

    items.add(text);
  }

  return items;
}

VehicleModelLookupData _lookupDataFromMap(
  Map<String, dynamic> data, {
  String? vehicleId,
}) {
  final price = _firstNonEmptyValue([
    data['price'],
    data['Price'],
    data['onRoadPrice'],
  ]);

  final description = _firstNonEmptyValue([
    data['description'],
    data['Description'],
  ]);

  final photoUrls = <String>[
    ..._stringListFrom(data['photoUrls']),
    ..._stringListFrom(data['photos']),
  ];

  final singlePhotoCandidates = [data['photoUrl'], data['imageUrl']];

  for (final candidate in singlePhotoCandidates) {
    final url = candidate?.toString().trim() ?? '';
    if (url.isNotEmpty && !photoUrls.contains(url)) {
      photoUrls.add(url);
    }
  }

  return VehicleModelLookupData(
    price: price,
    photoUrls: photoUrls,
    description: description,
    primaryPhotoUrl: photoUrls.isNotEmpty ? photoUrls.first : null,
    vehicleId: vehicleId,
  );
}

int _lookupScore(VehicleModelLookupData data) {
  return (data.photoUrls.length * 10) +
      (data.price.isNotEmpty ? 5 : 0) +
      (data.description.isNotEmpty ? 1 : 0);
}

Future<VehicleModelLookupData> fetchVehicleModelLookupData({
  required FirebaseFirestore firestore,
  required String brand,
  required String model,
}) async {
  final normalizedBrand = brand.trim();
  final normalizedModel = model.trim();

  if (normalizedBrand.isEmpty || normalizedModel.isEmpty) {
    return VehicleModelLookupData.empty;
  }

  VehicleModelLookupData? bestVehicleData;

  final vehicleSnapshot = await firestore
      .collection('Vehicle')
      .where('Brand', isEqualTo: normalizedBrand)
      .where('Model', isEqualTo: normalizedModel)
      .get();

  for (final doc in vehicleSnapshot.docs) {
    final candidate = _lookupDataFromMap(doc.data(), vehicleId: doc.id);

    if (bestVehicleData == null ||
        _lookupScore(candidate) > _lookupScore(bestVehicleData)) {
      bestVehicleData = candidate;
    }
  }

  if (bestVehicleData != null &&
      (bestVehicleData.price.isNotEmpty ||
          bestVehicleData.photoUrls.isNotEmpty ||
          bestVehicleData.description.isNotEmpty)) {
    return bestVehicleData;
  }

  final modelSnapshot = await firestore
      .collection('Model')
      .where('ParentBrand', isEqualTo: normalizedBrand)
      .where('Name', isEqualTo: normalizedModel)
      .limit(1)
      .get();

  if (modelSnapshot.docs.isNotEmpty) {
    return _lookupDataFromMap(
      modelSnapshot.docs.first.data(),
      vehicleId: modelSnapshot.docs.first.id,
    );
  }

  return bestVehicleData ?? VehicleModelLookupData.empty;
}
