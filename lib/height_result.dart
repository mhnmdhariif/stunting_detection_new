\// File: lib/height_result.dart

class HeightResult {
final String status;
final double confidence;
final String? imageUrl;       // URL Foto dari server
final List<double> probabilities; // List probabilitas (misal: [0.2, 0.8])

HeightResult({
required this.status,
required this.confidence,
this.imageUrl,
required this.probabilities,
});

factory HeightResult.fromMap(Map<String, dynamic> json) {
// Helper untuk konversi list dynamic ke list double
List<double> parseProbs(dynamic val) {
if (val is List) {
return val.map((e) => (e ?? 0.0).toDouble()).toList();
}
return [];
}

return HeightResult(
status: json['label']?.toString() ?? 'Unknown',

// Ambil confidence
confidence: (json['confidence'] ?? 0.0).toDouble(),

// Ambil URL foto (pastikan key di JSON server adalah 'photo_url')
imageUrl: json['photo_url'],

// Ambil array probabilitas (pastikan key di JSON server adalah 'prediction')
probabilities: parseProbs(json['prediction']),
);
}
}