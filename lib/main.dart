// File: lib/main.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// Pastikan file height_result.dart ada di folder lib dan sudah diupdate!
import 'height_result.dart';

// ---------------------------------------------------------
// CONFIG & MAIN
// ---------------------------------------------------------

void main() => runApp(const StuntingApp());

// 1. URL HUGGING FACE (Untuk Otak/AI)
// NOTE: Jangan ditambah /measure lagi nanti di bawah, pakai link bersih ini
const hfBaseUrl = 'https://syahhh01-stunting-detector-app.hf.space/predict-image';

// 2. URL GOOGLE CLOUD (Untuk Database & Storage)
const cloudBaseUrl = 'https://stunting-server-376046612572.us-central1.run.app';

class StuntingApp extends StatelessWidget {
  const StuntingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stunting Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB30017)),
        useMaterial3: true,
      ),
      home: const SplashPage(),
    );
  }
}

/* ---------------- Splash Screen ---------------- */
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}
class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2000),
            () => Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const InputPage())));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB30017),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.health_and_safety, color: Colors.white, size: 96),
          const SizedBox(height: 12),
          Text('Stunting Detection',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          Text('Demi Indonesia Emas 2045',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white70,
              )),
        ]),
      ),
    );
  }
}

/* --------------- Halaman Input Data --------------- */
class InputPage extends StatefulWidget {
  const InputPage({super.key});
  @override
  State<InputPage> createState() => _InputPageState();
}
class _InputPageState extends State<InputPage> {
  final name = TextEditingController();
  final age = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    super.dispose();
  }

  void _goCamera() {
    if (name.text.trim().isEmpty || age.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nama & umur wajib diisi')));
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CameraAndUploadPage(
        childName: name.text.trim(),
        childAge: age.text.trim(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Anak')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Masukkan Identitas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Nama Anak',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: age,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Umur Anak (tahun)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.cake),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _goCamera,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Lanjut ke Pemindaian'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
        ],
      ),
    );
  }
}

/* ------- Kamera & Proses Upload (LOGIKA UTAMA DISINI) ------- */
class CameraAndUploadPage extends StatefulWidget {
  final String childName;
  final String childAge;
  const CameraAndUploadPage(
      {super.key, required this.childName, required this.childAge});
  @override
  State<CameraAndUploadPage> createState() => _CameraAndUploadPageState();
}

class _CameraAndUploadPageState extends State<CameraAndUploadPage> {
  final _picker = ImagePicker();
  XFile? _captured;
  bool _busy = false;
  String _statusText = "";
  String? _error;

  Future<void> _takeAndSend() async {
    setState(() {
      _busy = true;
      _error = null;
      _statusText = "Mengambil Foto...";
    });

    try {
      // ---------------------------------------------------
      // 0. AMBIL FOTO
      // ---------------------------------------------------
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60,
        maxWidth: 800,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (shot == null) {
        setState(() => _busy = false);
        return;
      }
      _captured = shot;
      setState(() => _statusText = "Menganalisis di AI Hugging Face...");

      // ---------------------------------------------------
      // 1. KIRIM KE HUGGING FACE (Untuk Prediksi)
      // ---------------------------------------------------
      // [FIX] Langsung parse URL tanpa nambah '/measure'
      final hfUri = Uri.parse(hfBaseUrl);

      final hfReq = http.MultipartRequest('POST', hfUri)
      // [FIX] Menggunakan key 'file' bukan 'image' agar sesuai dengan kode yang jalan
        ..files.add(await http.MultipartFile.fromPath('file', shot.path, filename: 'hf_check.jpg'));

      final hfStreamed = await hfReq.send().timeout(const Duration(seconds: 90));
      final hfResp = await http.Response.fromStream(hfStreamed);

      if (hfResp.statusCode != 200) {
        throw Exception('HF Space Error ${hfResp.statusCode}: ${hfResp.body}');
      }

      // Parsing hasil AI
      final Map<String, dynamic> aiResult = jsonDecode(hfResp.body) as Map<String, dynamic>;
      // aiResult isinya: { "label": "Stunting", "confidence": 0.95, "prediction": [...] }

      setState(() => _statusText = "Menyimpan ke Database Cloud...");

      // ---------------------------------------------------
      // 2. KIRIM KE GOOGLE CLOUD (Untuk Simpan Data)
      // ---------------------------------------------------
      // Cloud Run Python kamu sepertinya pakai endpoint /measure dan key 'image'
      // Jadi bagian ini tidak perlu diubah ke 'file' (kecuali backend python kamu juga diubah)
      final cloudUri = Uri.parse('$cloudBaseUrl/measure');

      final cloudReq = http.MultipartRequest('POST', cloudUri)
        ..fields['name'] = widget.childName
        ..fields['age'] = widget.childAge
      // Kirim hasil AI ke Cloud supaya disimpan
        ..fields['ai_label'] = aiResult['label'].toString()
        ..fields['ai_confidence'] = aiResult['confidence'].toString()
      // Ke Cloud Run Python tetap pakai 'image' (sesuai backend flask)
        ..files.add(await http.MultipartFile.fromPath('image', shot.path, filename: 'capture.jpg'));

      final cloudStreamed = await cloudReq.send().timeout(const Duration(seconds: 60));
      final cloudResp = await http.Response.fromStream(cloudStreamed);

      if (cloudResp.statusCode != 200) {
        throw Exception('Cloud Save Error ${cloudResp.statusCode}: ${cloudResp.body}');
      }

      // ---------------------------------------------------
      // 3. GABUNGKAN DATA UNTUK TAMPILAN
      // ---------------------------------------------------
      final Map<String, dynamic> cloudData = jsonDecode(cloudResp.body) as Map<String, dynamic>;

      // Kita bikin Map gabungan untuk HeightResult
      final Map<String, dynamic> finalData = {
        'label': aiResult['label'],           // Dari HF
        'confidence': aiResult['confidence'], // Dari HF
        'prediction': aiResult['prediction'], // Dari HF (List Probs)
        'photo_url': cloudData['photo_url'] ?? cloudData['foto_url'], // Dari Cloud
      };

      final HeightResult heightResult = HeightResult.fromMap(finalData);

      if (!mounted) return;

      // 4. Pindah Halaman
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(
            name: widget.childName,
            age: widget.childAge,
            previewPath: shot.path,
            result: heightResult,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeAndSend());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Ambil Foto')),
      body: Stack(
        children: [
          if (_captured != null)
            Center(child: Image.file(File(_captured!.path), fit: BoxFit.contain)),

          if (_busy)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_statusText, style: const TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text("(Mohon tunggu sebentar)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),

          if (_error != null)
            Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _takeAndSend, child: const Text('Coba Lagi')),
                  ]),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: (!_busy)
          ? FloatingActionButton(
        onPressed: _takeAndSend,
        child: const Icon(Icons.camera_alt),
      )
          : null,
    );
  }
}

/* ---------------- Halaman Hasil ---------------- */
class ResultPage extends StatelessWidget {
  final String name, age, previewPath;
  final HeightResult result;

  const ResultPage({
    super.key,
    required this.name,
    required this.age,
    required this.result,
    required this.previewPath,
  });

  @override
  Widget build(BuildContext context) {
    final double normalProb = result.probabilities[1];
    final double stuntingProb = result.probabilities[0];

    final bool isStuntingFinal = stuntingProb > normalProb;
    final String finalStatus = isStuntingFinal ? 'STUNTING' : 'NORMAL';

    final Color statusColor = isStuntingFinal ? Colors.red : Colors.green;

    ImageProvider imageProvider;
    if (result.imageUrl != null && result.imageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(result.imageUrl!);
    } else {
      imageProvider = FileImage(File(previewPath));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Analisis AI')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image(
              image: imageProvider,
              height: 300,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 300,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Image.file(File(previewPath), height: 300, fit: BoxFit.cover);
              },
            ),
          ),
          const SizedBox(height: 20),

          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text("Status Gizi", style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    finalStatus.toUpperCase(),
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: statusColor
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Divider(height: 30),

                  Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      _row('Nama Anak', name),
                      _row('Umur', '$age Tahun'),
                      _row('Akurasi AI', '${(result.confidence * 100).toStringAsFixed(1)} %'),

                      const TableRow(children: [
                        SizedBox(height: 15),
                        SizedBox(height: 15)
                      ]),

                      _row(
                          'Peluang Stunting',
                          '${(result.probabilities[0] * 100).toStringAsFixed(1)} %'
                      ),
                      _row(
                          'Peluang Normal',
                          '${(result.probabilities[1] * 100).toStringAsFixed(1)} %'
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const InputPage()),
                    (_) => false
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Periksa Anak Lain'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: const Color(0xFFB30017),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  TableRow _row(String label, String value) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.right),
      ),
    ]);
  }
}