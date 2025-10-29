import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void main() => runApp(const YourClosetApp());

class YourClosetApp extends StatelessWidget {
  const YourClosetApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your Closet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8A7CFF),
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF121212),
          border: OutlineInputBorder(),
          labelStyle: TextStyle(color: Colors.white70),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const SplashHome(),
    );
  }
}

const _g1 = Color(0xFF8A7CFF);
const _g2 = Color(0xFF4ED6FF);

/// ---------- Gradient UI helpers ----------
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const GradientText(this.text, {required this.style, super.key});
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [_g1, _g2],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
  });
  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_g1, _g2]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: padding,
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class AppBarBackButton extends StatelessWidget {
  const AppBarBackButton({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Material(
        color: Colors.white12,
        shape: const CircleBorder(),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: '戻る',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SplashHome()),
                (r) => false,
              );
            }
          },
        ),
      ),
    );
  }
}

Color hex(String h) {
  var s = h.replaceAll('#', '');
  if (s.length == 6) s = 'FF$s';
  return Color(int.parse(s, radix: 16));
}

String newId() =>
    '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 32)}';

/// ---------- Safe LocalStorage wrapper (prevents SecurityError) ----------
class SafeStore {
  static bool? _okCache;
  static bool get ok {
    if (!kIsWeb) return false;
    if (_okCache != null) return _okCache!;
    try {
      final ls = html.window.localStorage; // may throw SecurityError
      ls['__yc_test__'] = '1';
      ls.remove('__yc_test__');
      _okCache = true;
    } catch (_) {
      _okCache = false;
    }
    return _okCache!;
  }

  static String? getItem(String key) {
    if (!kIsWeb) return null;
    try {
      if (!ok) return null;
      return html.window.localStorage[key];
    } catch (_) {
      return null;
    }
  }

  static void setItem(String key, String value) {
    if (!kIsWeb) return;
    try {
      if (!ok) return;
      html.window.localStorage[key] = value;
    } catch (_) {
      // ignore
    }
  }

  static void remove(String key) {
    if (!kIsWeb) return;
    try {
      if (!ok) return;
      html.window.localStorage.remove(key);
    } catch (_) {
      // ignore
    }
  }
}

final app = AppState();

class AppState {
  Profile profile = Profile();
  Diagnosis diagnosis = Diagnosis();
  Uint8List? photoBytes;
  String? photoUrl;
  List<Product> products = [];

  Map<String, dynamic> toJson() => {
        'profile': profile.toJson(),
        'diagnosis': diagnosis.toJson(),
        'photoBytesB64': photoBytes == null ? null : base64Encode(photoBytes!),
        'photoUrl': photoUrl,
      };
  void fromJson(Map<String, dynamic> j) {
    profile = Profile.fromJson(j['profile'] ?? {});
    diagnosis = Diagnosis.fromJson(j['diagnosis'] ?? {});
    final b64 = j['photoBytesB64'];
    photoBytes = (b64 is String && b64.isNotEmpty) ? base64Decode(b64) : null;
    photoUrl = j['photoUrl'];
  }

  // ---- Safe persistence (no crash when blocked)
  void saveToLocalStorage() {
    final s = jsonEncode(toJson());
    SafeStore.setItem('your_closet_app', s);
  }

  void loadFromLocalStorage() {
    final s = SafeStore.getItem('your_closet_app');
    if (s != null && s.isNotEmpty) {
      try {
        fromJson(jsonDecode(s));
      } catch (_) {}
    }
  }

  void saveProducts() {
    final list = products.map((e) => e.toJson()).toList();
    SafeStore.setItem('your_closet_products', jsonEncode(list));
  }

  void loadProducts() {
    final s = SafeStore.getItem('your_closet_products');
    if (s == null || s.isEmpty) {
      products = [];
      return;
    }
    try {
      final raw = (jsonDecode(s) as List);
      products = raw
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      products = [];
    }
  }
}

/// ---------- Data models ----------
class Profile {
  String lastName = '',
      firstName = '',
      age = '',
      height = '',
      weight = '',
      phone = '',
      zip = '',
      address = '',
      email = '',
      password = '';
  Map<String, dynamic> toJson() => {
        'lastName': lastName,
        'firstName': firstName,
        'age': age,
        'height': height,
        'weight': weight,
        'phone': phone,
        'zip': zip,
        'address': address,
        'email': email,
        'password': password,
      };
  static Profile fromJson(Map<String, dynamic> j) {
    final p = Profile();
    p.lastName = j['lastName'] ?? '';
    p.firstName = j['firstName'] ?? '';
    p.age = j['age'] ?? '';
    p.height = j['height'] ?? '';
    p.weight = j['weight'] ?? '';
    p.phone = j['phone'] ?? '';
    p.zip = j['zip'] ?? '';
    p.address = j['address'] ?? '';
    p.email = j['email'] ?? '';
    p.password = j['password'] ?? '';
    return p;
  }
}

class Diagnosis {
  String bodyType = '', undertone = '', brightness = '', season = '';
  Map<String, dynamic> toJson() => {
        'bodyType': bodyType,
        'undertone': undertone,
        'brightness': brightness,
        'season': season,
      };
  static Diagnosis fromJson(Map<String, dynamic> j) {
    final d = Diagnosis();
    d.bodyType = j['bodyType'] ?? '';
    d.undertone = j['undertone'] ?? '';
    d.brightness = j['brightness'] ?? '';
    d.season = j['season'] ?? '';
    return d;
  }
}

class Product {
  final String id;
  String name;
  String brand;
  String category;
  int price;
  int stock;
  String seasonTag;
  String colorHex;
  String? imageUrl;
  String? imageB64;
  String description;
  List<String> sizes;
  List<String> tags;
  String colorFamily;
  int shippingFee;

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.price,
    required this.stock,
    required this.seasonTag,
    required this.colorHex,
    this.imageUrl,
    this.imageB64,
    required this.description,
    required this.sizes,
    required this.tags,
    required this.colorFamily,
    required this.shippingFee,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'category': category,
        'price': price,
        'stock': stock,
        'seasonTag': seasonTag,
        'colorHex': colorHex,
        'imageUrl': imageUrl,
        'imageB64': imageB64,
        'description': description,
        'sizes': sizes,
        'tags': tags,
        'colorFamily': colorFamily,
        'shippingFee': shippingFee,
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] ?? newId(),
        name: j['name'] ?? '',
        brand: j['brand'] ?? '',
        category: j['category'] ?? 'tops',
        price: (j['price'] ?? 0) is int
            ? j['price']
            : int.tryParse('${j['price']}') ?? 0,
        stock: (j['stock'] ?? 0) is int
            ? j['stock']
            : int.tryParse('${j['stock']}') ?? 0,
        seasonTag: j['seasonTag'] ?? 'All',
        colorHex: j['colorHex'] ?? '#FFFFFF',
        imageUrl: j['imageUrl'],
        imageB64: j['imageB64'],
        description: j['description'] ?? '',
        sizes:
            (j['sizes'] is List) ? List<String>.from(j['sizes']) : <String>[],
        tags: (j['tags'] is List) ? List<String>.from(j['tags']) : <String>[],
        colorFamily: j['colorFamily'] ?? 'その他',
        shippingFee: (j['shippingFee'] ?? 0) is int
            ? j['shippingFee']
            : int.tryParse('${j['shippingFee']}') ?? 0,
      );

  ImageProvider? imageProvider() {
    if (imageB64 != null && imageB64!.isNotEmpty) {
      return MemoryImage(base64Decode(imageB64!));
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return NetworkImage(imageUrl!);
    }
    return null;
  }
}

/// ---------- Palettes ----------
final paletteBySeason = <String, Map<String, List<Color>>>{
  'Spring': {
    'accents': [
      hex('#FF7F50'),
      hex('#FA8072'),
      hex('#FBCEB1'),
      hex('#40E0D0'),
      hex('#64D8CB'),
      hex('#C7EA46')
    ],
    'neutrals': [hex('#FFFFF0'), hex('#F5E6CC'), hex('#D2B48C')]
  },
  'Autumn': {
    'accents': [
      hex('#E2725B'),
      hex('#B22222'),
      hex('#D4A017'),
      hex('#708238'),
      hex('#228B22'),
      hex('#800020')
    ],
    'neutrals': [hex('#C19A6B'), hex('#8B7865'), hex('#5D3A1A')]
  },
  'Summer': {
    'accents': [
      hex('#C08081'),
      hex('#B784A7'),
      hex('#B57EDC'),
      hex('#C3CDE6'),
      hex('#B0E0E6'),
      hex('#98FF98'),
      hex('#708090')
    ],
    'neutrals': [hex('#E6C7C2'), hex('#1B3475'), hex('#A9B0B3')]
  },
  'Winter': {
    'accents': [
      hex('#C1002E'),
      hex('#FF00FF'),
      hex('#0047AB'),
      hex('#008E6F'),
      hex('#E0F7FA')
    ],
    'neutrals': [hex('#FFFFFF'), hex('#000000'), hex('#36454F'), hex('#0B1F44')]
  },
};

/// ---------- Small banner to warn when storage is blocked ----------
class StorageStatusBanner extends StatelessWidget {
  const StorageStatusBanner({super.key});
  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || SafeStore.ok) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent),
      ),
      child: const Text(
        '注意: ブラウザの制限で保存機能が無効です（DartPad/プライベートモード等）。'
        'データはページを閉じると消えます。',
        style: TextStyle(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }
}

/// ---------- Pages ----------
class SplashHome extends StatelessWidget {
  const SplashHome({super.key});
  @override
  Widget build(BuildContext context) {
    const double size = 170;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const StorageStatusBanner(),
            const SizedBox(height: 8),
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [_g1, _g2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.white24, blurRadius: 24, spreadRadius: 2)
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: Stack(alignment: Alignment.center, children: const [
                  Positioned(
                      top: 38,
                      child: GradientText('YC',
                          style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2))),
                  Positioned(
                      bottom: 34,
                      child: Icon(Icons.checkroom,
                          color: Colors.white70, size: 40)),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            const GradientText('Your Closet',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 6),
            const Text('Dress Smart with AI',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 36),
            Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 12,
                children: [
                  GradientButton(
                    label: '新規登録する',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterPage())),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginPage())),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('ログイン'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CatalogPage())),
                    icon: const Icon(Icons.storefront),
                    label: const Text('商品カタログを見る'),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SellerLoginPage())),
                    child: const Text('販売者モード'),
                  ),
                ]),
          ]),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _lastName = TextEditingController(),
      _firstName = TextEditingController(),
      _age = TextEditingController(),
      _height = TextEditingController(),
      _weight = TextEditingController(),
      _phone = TextEditingController(),
      _zip = TextEditingController(),
      _address = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController();
  bool _showPass = false;

  String? _req(String? v, String l) =>
      (v == null || v.trim().isEmpty) ? '$lを入力してください' : null;
  String? _num(String? v, String l) {
    if (v == null || v.trim().isEmpty) return '$lを入力してください';
    return num.tryParse(v) == null ? '$lは数字で入力してください' : null;
    }

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _phone.dispose();
    _zip.dispose();
    _address.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _saveProfile() {
    app.profile
      ..lastName = _lastName.text
      ..firstName = _firstName.text
      ..age = _age.text
      ..height = _height.text
      ..weight = _weight.text
      ..phone = _phone.text
      ..zip = _zip.text
      ..address = _address.text
      ..email = _email.text
      ..password = _password.text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: const AppBarBackButton(),
          title: const GradientText('新規登録',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
              key: _formKey,
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: _lastName,
                          decoration:
                              const InputDecoration(labelText: '姓'),
                          validator: (v) => _req(v, '姓'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextFormField(
                          controller: _firstName,
                          decoration:
                              const InputDecoration(labelText: '名'),
                          validator: (v) => _req(v, '名'))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: _age,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: '年齢（歳）'),
                          validator: (v) => _num(v, '年齢'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextFormField(
                          controller: _height,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: '身長（cm）'),
                          validator: (v) => _num(v, '身長'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextFormField(
                          controller: _weight,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: '体重（kg）'),
                          validator: (v) => _num(v, '体重'))),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: '電話番号'),
                    validator: (v) => _req(v, '電話番号')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _zip,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: '郵便番号'),
                    validator: (v) => _req(v, '郵便番号')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _address,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: '住所'),
                    validator: (v) => _req(v, '住所')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(labelText: 'メールアドレス'),
                    validator: (v) => _req(v, 'メールアドレス')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _password,
                    obscureText: !_showPass,
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _showPass = !_showPass),
                        icon: Icon(_showPass
                            ? Icons.visibility_off
                            : Icons.visibility),
                      ),
                    ),
                    validator: (v) => _req(v, 'パスワード')),
                const SizedBox(height: 22),
                SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      label: '登録して診断へ',
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _saveProfile();
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MethodSelectPage()));
                        }
                      },
                    )),
              ])),
        ),
      ),
    );
  }
}

class MethodSelectPage extends StatelessWidget {
  const MethodSelectPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: const AppBarBackButton(),
          title: const GradientText('診断方式の選択',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(children: [
            _card(
              icon: Icons.face_retouching_natural,
              title: '顔写真から診断（β）',
              desc: '画像プレビュー＋血管の見え方＋肌トーンで自動推定',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PhotoDiagnosisPage())),
            ),
            const SizedBox(height: 16),
            _card(
              icon: Icons.quiz,
              title: '質問に答えて診断',
              desc: '体型・アンダートーン・明度を選択して推定',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DiagnosisPage())),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _card(
      {required IconData icon,
      required String title,
      required String desc,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF101010),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_g1, _g2]),
              ),
              child: const Icon(Icons.face_retouching_natural,
                  color: Colors.black, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(color: Colors.white70)),
              ],
            )),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

class OptionItem {
  final String value;
  final String label;
  const OptionItem(this.value, this.label);
}

class DiagnosisPage extends StatefulWidget {
  const DiagnosisPage({super.key});
  @override
  State<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends State<DiagnosisPage> {
  String bodyType = app.diagnosis.bodyType,
      undertone = app.diagnosis.undertone,
      brightness = app.diagnosis.brightness,
      season = app.diagnosis.season;

  void _calcSeason() {
    if (undertone == 'warm') {
      season = (brightness == 'light') ? 'Spring' : 'Autumn';
    } else if (undertone == 'cool') {
      season = (brightness == 'light') ? 'Summer' : 'Winter';
    } else {
      season = (brightness == 'deep')
          ? 'Autumn'
          : (brightness == 'light')
              ? 'Summer'
              : 'Spring';
    }
  }

  Widget _chips(
      {required List<OptionItem> opts,
      required String group,
      required ValueChanged<String> onChanged}) {
    return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: opts.map((o) {
          final sel = group == o.value;
          return ChoiceChip(
            label: Text(o.label),
            selected: sel,
            onSelected: (_) => setState(() => onChanged(o.value)),
            selectedColor: const Color(0xFF1E1E1E),
            labelStyle: TextStyle(
                color: sel ? Colors.white : Colors.white70,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal),
            shape: StadiumBorder(
                side: BorderSide(
                    color: sel ? _g2 : Colors.white24, width: sel ? 2 : 1)),
            backgroundColor: const Color(0xFF101010),
          );
        }).toList());
  }

  void _next() {
    _calcSeason();
    app.diagnosis
      ..bodyType = bodyType
      ..undertone = undertone
      ..brightness = brightness
      ..season = season;
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const PhotoPage()));
  }

  @override
  Widget build(BuildContext context) {
    final canNext =
        bodyType.isNotEmpty && undertone.isNotEmpty && brightness.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
          leading: const AppBarBackButton(),
          title: const GradientText('診断',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title('体型タイプ'),
                _chips(opts: const [
                  OptionItem('A', 'A型（下半身が目立つ）'),
                  OptionItem('V', 'V型（上半身ががっしり）'),
                  OptionItem('X', 'X型（くびれ）'),
                  OptionItem('I', 'I型（均等）'),
                ], group: bodyType, onChanged: (v) => bodyType = v),
                const SizedBox(height: 20),
                _title('肌のアンダートーン'),
                _chips(opts: const [
                  OptionItem('warm', 'イエベ（黄み）'),
                  OptionItem('cool', 'ブルベ（青み）'),
                  OptionItem('neutral', 'ニュートラル'),
                ], group: undertone, onChanged: (v) => undertone = v),
                const SizedBox(height: 20),
                _title('全体の明度・コントラスト'),
                _chips(opts: const [
                  OptionItem('light', 'ライト（明るめ）'),
                  OptionItem('soft', 'ソフト（中間）'),
                  OptionItem('deep', 'ディープ（濃いめ）'),
                ], group: brightness, onChanged: (v) => brightness = v),
                const SizedBox(height: 28),
                if (canNext) _resultCard(() {
                  _calcSeason();
                  return season;
                }()),
                const SizedBox(height: 18),
                SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      label: '次へ（顔写真を登録）',
                      onPressed: canNext ? _next : null,
                    )),
              ]),
        ),
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GradientText(t,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );

  Widget _resultCard(String s) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_g1, _g2]),
            borderRadius: BorderRadius.circular(16)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('診断結果',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('推定シーズン: $s',
              style:
                  const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}

class PhotoPage extends StatefulWidget {
  const PhotoPage({super.key});
  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> {
  final _urlCtrl = TextEditingController(text: app.photoUrl ?? '');
  Uint8List? bytes = app.photoBytes;
  Future<void> _pickWeb() async {
    if (!kIsWeb) return;
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return;
    final file = input.files!.first;
    final r = html.FileReader();
    r.readAsArrayBuffer(file);
    await r.onLoadEnd.first;
    setState(() => bytes = Uint8List.fromList(r.result as List<int>));
  }

  void _next() {
    app.photoUrl =
        _urlCtrl.text.trim().isNotEmpty ? _urlCtrl.text.trim() : null;
    app.photoBytes = bytes;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SaveAllPage()));
  }

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (bytes != null) {
      preview =
          Image.memory(bytes!, width: 220, height: 220, fit: BoxFit.cover);
    } else if (_urlCtrl.text.trim().isNotEmpty) {
      preview = Image.network(_urlCtrl.text.trim(),
          width: 220,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Text('画像URLが無効です',
              style: TextStyle(color: Colors.redAccent)));
    } else {
      preview = Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24)),
          child: const Center(
              child: Text('プレビュー',
                  style: TextStyle(color: Colors.white54))));
    }
    return Scaffold(
      appBar: AppBar(
          leading: const AppBarBackButton(),
          title: const GradientText('顔写真の登録',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          centerTitle: true),
      body: SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const StorageStatusBanner(),
                const SizedBox(height: 12),
                const Text('・画像URLを貼る  または  ・画像ファイルを選ぶ（Web）',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: _urlCtrl,
                          decoration: const InputDecoration(
                              labelText: '画像URL（任意）',
                              hintText: 'https://example.com/me.jpg'),
                          onChanged: (_) => setState(() {}))),
                  const SizedBox(width: 10),
                  ElevatedButton(
                      onPressed: kIsWeb ? _pickWeb : null,
                      child: const Text('画像を選ぶ（Web）')),
                ]),
                const SizedBox(height: 16),
                Center(
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: preview)),
                const SizedBox(height: 24),
                SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                        label: '次へ（保存）', onPressed: _next)),
              ]))),
    );
  }
}

class ToneOpt {
  final String id;
  final List<Color> colors;
  final String label;
  const ToneOpt(this.id, this.colors, this.label);
}

class PhotoDiagnosisPage extends StatefulWidget {
  const PhotoDiagnosisPage({super.key});
  @override
  State<PhotoDiagnosisPage> createState() => _PhotoDiagnosisPageState();
}

class _PhotoDiagnosisPageState extends State<PhotoDiagnosisPage> {
  final _urlCtrl = TextEditingController(text: app.photoUrl ?? '');
  Uint8List? bytes = app.photoBytes;
  String vein = ''; // green/blue/mixed
  String tone = ''; // light/soft/deep
  String season = '';
  String undertone = '';

  Future<void> _pickWeb() async {
    if (!kIsWeb) return;
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return;
    final file = input.files!.first;
    final r = html.FileReader();
    r.readAsArrayBuffer(file);
    await r.onLoadEnd.first;
    setState(() => bytes = Uint8List.fromList(r.result as List<int>));
  }

  void _calc() {
    undertone = (vein == 'green')
        ? 'warm'
        : (vein == 'blue')
            ? 'cool'
            : 'neutral';
    final brightness = tone;
    if (undertone == 'warm') {
      season = (brightness == 'light') ? 'Spring' : 'Autumn';
    } else if (undertone == 'cool') {
      season = (brightness == 'light') ? 'Summer' : 'Winter';
    } else {
      season = (brightness == 'deep')
          ? 'Autumn'
          : (brightness == 'light')
              ? 'Summer'
              : 'Spring';
    }
    app.diagnosis
      ..undertone = undertone
      ..brightness = brightness
      ..season = season;
  }

  void _saveAndNext() {
    _calc();
    app.photoUrl =
        _urlCtrl.text.trim().isNotEmpty ? _urlCtrl.text.trim() : null;
    app.photoBytes = bytes;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SaveAllPage()));
  }

  @override
  Widget build(BuildContext context) {
    final canNext = vein.isNotEmpty && tone.isNotEmpty;
    Widget preview;
    if (bytes != null) {
      preview =
          Image.memory(bytes!, width: 220, height: 220, fit: BoxFit.cover);
    } else if (_urlCtrl.text.trim().isNotEmpty) {
      preview = Image.network(_urlCtrl.text.trim(),
          width: 220,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Text('画像URLが無効です',
              style: TextStyle(color: Colors.redAccent)));
    } else {
      preview = Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24)),
          child: const Center(
              child: Text('顔写真プレビュー',
                  style: TextStyle(color: Colors.white54))));
    }

    return Scaffold(
      appBar: AppBar(
          leading: const AppBarBackButton(),
          title: const GradientText('顔写真から診断（β）',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          centerTitle: true),
      body: SafeArea(
          child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const StorageStatusBanner(),
          const SizedBox(height: 12),
          const Text('写真を用意して、血管の見え方＆肌トーンを選ぶと自動推定します。',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                        labelText: '画像URL（任意）',
                        hintText: 'https://example.com/me.jpg'),
                    onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            ElevatedButton(
                onPressed: kIsWeb ? _pickWeb : null,
                child: const Text('画像を選ぶ（Web）')),
          ]),
          const SizedBox(height: 16),
          Center(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(12), child: preview)),
          const SizedBox(height: 24),
          _subtitle('血管の見え方'),
          _choiceRow<String>(
            values: const ['green', 'blue', 'mixed'],
            labels: const ['緑っぽい（黄み）', '青/紫っぽい（青み）', 'どちらとも言えない'],
            groupValue: vein,
            onChanged: (v) => setState(() => vein = v),
          ),
          const SizedBox(height: 16),
          _subtitle('肌トーン（明度の目安）'),
          _toneSwatches(selected: tone, onSelect: (v) => setState(() => tone = v)),
          const SizedBox(height: 20),
          if (canNext) _resultCardPreview(),
          const SizedBox(height: 18),
          SizedBox(
              width: double.infinity,
              child: GradientButton(
                  label: '次へ（保存）',
                  onPressed: canNext ? _saveAndNext : null)),
        ]),
      )),
    );
  }

  Widget _subtitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GradientText(t,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );

  Widget _choiceRow<T>(
      {required List<T> values,
      required List<String> labels,
      required T? groupValue,
      required ValueChanged<T> onChanged}) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (int i = 0; i < values.length; i++)
        ChoiceChip(
          label: Text(labels[i]),
          selected: groupValue == values[i],
          onSelected: (_) => onChanged(values[i]),
          selectedColor: const Color(0xFF1E1E1E),
          labelStyle: TextStyle(
              color:
                  groupValue == values[i] ? Colors.white : Colors.white70,
              fontWeight: groupValue == values[i]
                  ? FontWeight.bold
                  : FontWeight.normal),
          shape: StadiumBorder(
              side: BorderSide(
                  color: groupValue == values[i] ? _g2 : Colors.white24,
                  width:
                      groupValue == values[i] ? 2 : 1)),
          backgroundColor: const Color(0xFF101010),
        )
    ]);
  }

  Widget _toneSwatches(
      {required String selected, required ValueChanged<String> onSelect}) {
    const tones = <ToneOpt>[
      ToneOpt('light', <Color>[Color(0xFFFFE6CC), Color(0xFFF6D1B8)], 'ライト'),
      ToneOpt('soft', <Color>[Color(0xFFF0C39D), Color(0xFFE3A77E)], 'ソフト'),
      ToneOpt('deep', <Color>[Color(0xFFCF9163), Color(0xFFB5734A)], 'ディープ'),
    ];
    return Row(
        children: tones.map((t) {
      final isSel = selected == t.id;
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelect(t.id),
          child: Container(
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: t.colors),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSel ? _g2 : Colors.white24, width: isSel ? 2 : 1),
            ),
            alignment: Alignment.center,
            child: Text(t.label,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isSel ? Colors.white : Colors.black87)),
          ),
        ),
      );
    }).toList());
  }

  Widget _resultCardPreview() {
    String u = (vein == 'green')
        ? 'warm'
        : (vein == 'blue')
            ? 'cool'
            : 'neutral';
    String b = tone;
    String s;
    if (u == 'warm') {
      s = (b == 'light') ? 'Spring' : 'Autumn';
    } else if (u == 'cool') {
      s = (b == 'light') ? 'Summer' : 'Winter';
    } else {
      s = (b == 'deep')
          ? 'Autumn'
          : (b == 'light')
              ? 'Summer'
              : 'Spring';
    }
    season = s;
    undertone = u;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_g1, _g2]),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('現在の推定',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('アンダートーン: $undertone / 明度: $b'),
        Text('シーズン: $season',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class SaveAllPage extends StatefulWidget {
  const SaveAllPage({super.key});
  @override
  State<SaveAllPage> createState() => _SaveAllPageState();
}

class _SaveAllPageState extends State<SaveAllPage> {
  bool saved = false;
  void _saveAll() {
    app.saveToLocalStorage();
    setState(() => saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SafeStore.ok
            ? 'ユアクロのデータを保存しました（ブラウザ内）'
            : '保存機能が無効のため、保存はスキップされました')));
  }

  @override
  Widget build(BuildContext context) {
    final p = app.profile, d = app.diagnosis;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: const GradientText('保存',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          IconButton(
              tooltip: '保存を読み込む',
              onPressed: () {
                app.loadFromLocalStorage();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(SafeStore.ok
                        ? '保存済みデータを読み込みました'
                        : '保存機能が無効のため、読み込みはスキップされました')));
              },
              icon: const Icon(Icons.sync)),
        ],
      ),
      body: SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StorageStatusBanner(),
                    const SizedBox(height: 12),
                    _tile(
                        'プロフィール',
                        Text(
                          '氏名: ${p.lastName} ${p.firstName}\n'
                          '年齢: ${p.age} / 身長: ${p.height}cm / 体重: ${p.weight}kg\n'
                          '電話: ${p.phone}\n郵便: ${p.zip}\n住所: ${p.address}\nメール: ${p.email}',
                        )),
                    const SizedBox(height: 12),
                    _tile(
                        '診断結果',
                        Text(
                          '体型: ${d.bodyType.isEmpty ? '(未設定)' : d.bodyType}\n'
                          'アンダートーン: ${d.undertone}\n'
                          '明度: ${d.brightness}\n'
                          '推定シーズン: ${d.season}',
                        )),
                    const SizedBox(height: 12),
                    _tile(
                        '顔写真',
                        Center(
                            child: SizedBox(
                                width: 180,
                                height: 180,
                                child: () {
                                  if (app.photoBytes != null) {
                                    return ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.memory(app.photoBytes!,
                                            fit: BoxFit.cover));
                                  }
                                  if (app.photoUrl != null) {
                                    return ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(app.photoUrl!,
                                            fit: BoxFit.cover));
                                  }
                                  return const Center(
                                      child: Text('未登録',
                                          style: TextStyle(
                                              color: Colors.white54)));
                                }()))),
                    const SizedBox(height: 24),
                    SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                            label:
                                saved ? '保存済み ✔（もう一度保存）' : 'すべて保存',
                            onPressed: _saveAll)),
                    const SizedBox(height: 12),
                    SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                            label: 'おすすめコーデを見る',
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const OutfitRecommendPage()));
                            })),
                    const SizedBox(height: 12),
                    SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.storefront),
                          label: const Text('商品カタログを見る'),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CatalogPage())),
                        )),
                    const SizedBox(height: 12),
                    Center(
                        child: TextButton(
                      onPressed: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SplashHome()),
                          (r) => false),
                      child: const Text('トップへ戻る'),
                    )),
                  ]))),
    );
  }

  Widget _tile(String title, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFF101010),
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GradientText(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          child,
        ]),
      );
}

class Outfit {
  final Color top, bottom, outer, accent;
  final String name;
  final List<String> tips;
  Outfit(
      {required this.top,
      required this.bottom,
      required this.outer,
      required this.accent,
      required this.name,
      required this.tips});
}

class OutfitRecommendPage extends StatefulWidget {
  const OutfitRecommendPage({super.key});
  @override
  State<OutfitRecommendPage> createState() => _OutfitRecommendPageState();
}

class _OutfitRecommendPageState extends State<OutfitRecommendPage> {
  late List<Outfit> outfits;
  int index = 0;
  final GlobalKey repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    app.loadProducts();
    outfits = _buildOutfits(app.diagnosis);
  }

  List<Outfit> _buildOutfits(Diagnosis d) {
    final season = d.season.isEmpty ? 'Spring' : d.season;
    final body = d.bodyType.isEmpty ? 'I' : d.bodyType;
    final acc = paletteBySeason[season]!['accents']!;
    final neu = paletteBySeason[season]!['neutrals']!;
    Color pick(List<Color> list, int i) => list[i % list.length];

    Map<String, List<String>> rules = {
      'A': ['上に明るさ/視線', '下は濃色ストレート', 'ジャケットで肩に構築感'],
      'V': ['上は控えめ', '下にボリューム（ワイド/プリーツ）', 'ドロップショルダー'],
      'X': ['ウエスト定義（ベルト/短丈）', '程よいフィット＆フレア', 'Vネックで縦ライン'],
      'I': ['直線シルエット', 'モノトーン～低コントラスト', '細身＆ミニマル'],
    };

    return [
      Outfit(
        top: pick(acc, 0),
        bottom: pick(neu, 2),
        outer: pick(neu, 1),
        accent: pick(acc, 1),
        name: '$season コーデ #1',
        tips: [
          'トップス: アクセントカラーで顔映え',
          if (body == 'A')
            ...rules['A']!
          else if (body == 'V')
            ...rules['V']!
          else if (body == 'X')
            ...rules['X']!
          else
            ...rules['I']!,
        ],
      ),
      Outfit(
        top: pick(neu, 0),
        bottom: pick(acc, 2),
        outer: pick(neu, 2),
        accent: pick(acc, 3),
        name: '$season コーデ #2',
        tips: ['ボトムに色、上を落ち着かせてバランス', '小物はアクセント色で統一'],
      ),
      Outfit(
        top: pick(acc, 4),
        bottom: pick(neu, 0),
        outer: pick(acc, 5),
        accent: pick(neu, 2),
        name: '$season コーデ #3',
        tips: ['アウターを主役に', 'インナー/ボトムはニュートラル'],
      ),
    ];
  }

  Future<void> _savePng() async {
    try {
      final boundary =
          repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final png = byteData!.buffer.asUint8List();
      final blob = html.Blob([png], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..download = 'yourcloset_tryon.png'
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final o = outfits[index];
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: const GradientText('おすすめコーデ',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          IconButton(
              onPressed: _savePng,
              icon: const Icon(Icons.download),
              tooltip: 'PNG保存'),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: RepaintBoundary(
                key: repaintKey,
                child: OutfitCanvas(
                  width: 360,
                  height: 540,
                  face: app.photoBytes,
                  top: o.top,
                  bottom: o.bottom,
                  outer: o.outer,
                  accent: o.accent,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF101010),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GradientText(o.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _legendRow('トップス', o.top),
                _legendRow('アウター', o.outer),
                _legendRow('ボトムス', o.bottom),
                _legendRow('アクセ', o.accent),
                const SizedBox(height: 8),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                ...o.tips.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $t'),
                    )),
                const SizedBox(height: 8),
                const Text('※ この画像はデモ合成（擬似）です。実AI試着は後でAPI接続に差し替え可能。',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ),
          ]),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () => setState(
                        () => index = (index - 1 + outfits.length) % outfits.length),
                    child: const Text('前の提案')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                    onPressed: () =>
                        setState(() => index = (index + 1) % outfits.length),
                    child: const Text('次の提案')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendRow(String name, Color c) {
    return Row(
      children: [
        Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24))),
        const SizedBox(width: 8),
        Text(name),
      ],
    );
  }
}

class OutfitCanvas extends StatelessWidget {
  final double width, height;
  final Uint8List? face;
  final Color top, bottom, outer, accent;
  const OutfitCanvas({
    super.key,
    required this.width,
    required this.height,
    required this.face,
    required this.top,
    required this.bottom,
    required this.outer,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.withOpacity(0.15), Colors.black],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          Positioned.fill(
            top: 16,
            child: Align(
              alignment: Alignment.topCenter,
              child: ClipOval(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: face != null
                      ? Image.memory(face!, fit: BoxFit.cover)
                      : Container(
                          color: Colors.white12,
                          child: const Icon(Icons.account_circle,
                              size: 100, color: Colors.white30)),
                ),
              ),
            ),
          ),
          Positioned.fill(
            top: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: CustomPaint(
                size: Size(width, height - 40),
                painter: _OutfitPainter(
                    top: top, bottom: bottom, outer: outer, accent: accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutfitPainter extends CustomPainter {
  final Color top, bottom, outer, accent;
  _OutfitPainter(
      {required this.top,
      required this.bottom,
      required this.outer,
      required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final torsoTop = 160.0;
    final paint = Paint()..isAntiAlias = true;

    // base torso
    paint..color = const Color(0xFF1A1A1A);
    final torsoRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 80, torsoTop, 160, 190),
        const Radius.circular(22));
    canvas.drawRRect(torsoRect, paint);

    // bottom
    paint..color = bottom;
    final pantsPath = Path()
      ..moveTo(centerX - 70, torsoTop + 190)
      ..lineTo(centerX - 20, size.height - 20)
      ..lineTo(centerX - 2, size.height - 20)
      ..lineTo(centerX - 10, torsoTop + 190)
      ..close();
    final pantsPath2 = Path()
      ..moveTo(centerX + 70, torsoTop + 190)
      ..lineTo(centerX + 20, size.height - 20)
      ..lineTo(centerX + 2, size.height - 20)
      ..lineTo(centerX + 10, torsoTop + 190)
      ..close();
    canvas.drawPath(pantsPath, paint);
    canvas.drawPath(pantsPath2, paint);

    // top
    paint..color = top;
    final topRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 75, torsoTop + 8, 150, 130),
        const Radius.circular(20));
    canvas.drawRRect(topRect, paint);

    // outer
    paint..color = outer.withOpacity(0.85);
    final outerPath = Path()
      ..moveTo(centerX - 100, torsoTop + 10)
      ..quadraticBezierTo(
          centerX - 130, torsoTop + 120, centerX - 80, torsoTop + 210)
      ..lineTo(centerX - 20, torsoTop + 210)
      ..lineTo(centerX - 20, torsoTop + 20)
      ..close();
    final outerPath2 = Path()
      ..moveTo(centerX + 100, torsoTop + 10)
      ..quadraticBezierTo(
          centerX + 130, torsoTop + 120, centerX + 80, torsoTop + 210)
      ..lineTo(centerX + 20, torsoTop + 210)
      ..lineTo(centerX + 20, torsoTop + 20)
      ..close();
    canvas.drawPath(outerPath, paint);
    canvas.drawPath(outerPath2, paint);

    // accent belt
    paint..color = accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(centerX - 75, torsoTop + 145, 150, 10),
          const Radius.circular(4)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _OutfitPainter old) {
    return top != old.top ||
        bottom != old.bottom ||
        outer != old.outer ||
        accent != old.accent;
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPass = false;
  String? _req(String? v, String l) =>
      (v == null || v.trim().isEmpty) ? '$lを入力してください' : null;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: const AppBarBackButton(),
          title: const GradientText('ログイン',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          centerTitle: true),
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(children: [
                const Icon(Icons.checkroom, color: Colors.white70, size: 48),
                const SizedBox(height: 8),
                const GradientText('Your Closet',
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 24),
                TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(labelText: 'メールアドレス'),
                    validator: (v) => _req(v, 'メールアドレス')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _password,
                    obscureText: !_showPass,
                    decoration: InputDecoration(
                        labelText: 'パスワード',
                        suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _showPass = !_showPass),
                            icon: Icon(_showPass
                                ? Icons.visibility_off
                                : Icons.visibility))),
                    validator: (v) => _req(v, 'パスワード')),
                const SizedBox(height: 22),
                SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      label: 'ログイン',
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ログイン試行（ダミー）')));
                        }
                      },
                    )),
              ]),
            )),
      ))),
    );
  }
}

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  String query = '';
  String sizeFilter = 'すべて';
  String colorFamilyFilter = 'すべて';

  @override
  void initState() {
    super.initState();
    app.loadProducts(); // safe even if storage blocked
  }

  List<Product> _filtered() {
    final q = query.trim().toLowerCase();
    return app.products.where((p) {
      if (p.stock <= 0) return false;
      final qHit = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.tags.any((t) => t.toLowerCase().contains(q));
      final sizeHit = (sizeFilter == 'すべて') || p.sizes.contains(sizeFilter);
      final colorHit =
          (colorFamilyFilter == 'すべて') || p.colorFamily == colorFamilyFilter;
      return qHit && sizeHit && colorHit;
    }).toList();
  }

  static const colorFamilies = <String>[
    'すべて',
    'ホワイト',
    'ブラック',
    'グレー',
    'レッド',
    'オレンジ',
    'イエロー',
    'グリーン',
    'ブルー',
    'パープル',
    'ブラウン',
    'ピンク',
    'ベージュ',
    'ネイビー',
    'その他'
  ];

  @override
  Widget build(BuildContext context) {
    final items = _filtered();
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: const GradientText('商品カタログ',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() => app.loadProducts());
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('商品を再読み込みしました')));
            },
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SellerLoginPage())),
        label: const Text('販売者モード'),
        icon: const Icon(Icons.manage_accounts),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            const StorageStatusBanner(),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    labelText: '検索（商品名・ブランド・タグ・説明）',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: sizeFilter,
                  decoration: const InputDecoration(labelText: 'サイズ'),
                  items: ['すべて', 'XS', 'S', 'M', 'L', 'XL', 'XXL']
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => sizeFilter = v ?? 'すべて'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: colorFamilyFilter,
                  decoration: const InputDecoration(labelText: '色系統'),
                  items: colorFamilies
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(
                      () => colorFamilyFilter = v ?? 'すべて'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child:
                          Text('該当する商品がありません。検索条件を調整してください。'))
                  : GridView.builder(
                      itemCount: items.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: .72),
                      itemBuilder: (_, i) =>
                          _catalogCard(context, items[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catalogCard(BuildContext context, Product p) {
    final img = p.imageProvider();
    return InkWell(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProductDetailPage(product: p))),
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF101010),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: img != null
                    ? Image(image: img, fit: BoxFit.cover)
                    : Container(
                        color: Colors.white12,
                        child: const Center(
                            child: Icon(Icons.image,
                                color: Colors.white30))),
              )),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.brand,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('¥${p.price} ・ ${p.colorFamily}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: -8,
                    children: p.tags
                        .take(3)
                        .map((t) => Chip(
                              label: Text(t),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ]),
          ),
        ]),
      ),
    );
  }
}

class ProductDetailPage extends StatelessWidget {
  final Product product;
  const ProductDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final img = product.imageProvider();
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: GradientText(product.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: img != null
                    ? Image(image: img, fit: BoxFit.cover)
                    : Container(
                        color: Colors.white12,
                        child: const Center(
                            child: Icon(Icons.image,
                                color: Colors.white30))),
              ),
            ),
            const SizedBox(height: 12),
            Text(product.brand, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            GradientText(product.name,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('価格：¥${product.price}（税込）',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
                '送料：¥${product.shippingFee} / 色系統：${product.colorFamily} / 在庫：${product.stock}',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: product.sizes.isEmpty
                  ? [const Chip(label: Text('サイズ情報なし'))]
                  : product.sizes.map((s) => Chip(label: Text(s))).toList(),
            ),
            const SizedBox(height: 12),
            if (product.tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: -8,
                children:
                    product.tags.map((t) => InputChip(label: Text('#$t'))).toList(),
              ),
            const SizedBox(height: 12),
            Text(product.description.isEmpty ? '説明はありません。' : product.description),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: 'カートに入れる（ダミー）',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('「${product.name}」をカートに追加（ダミー）')));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SellerLoginPage extends StatefulWidget {
  const SellerLoginPage({super.key});
  @override
  State<SellerLoginPage> createState() => _SellerLoginPageState();
}

class _SellerLoginPageState extends State<SellerLoginPage> {
  final _pin = TextEditingController();
  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: const AppBarBackButton(),
          title: const GradientText('販売者ログイン',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(children: [
          const StorageStatusBanner(),
          const SizedBox(height: 10),
          const Text('デモPIN：9999', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 10),
          TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PINコード')),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: 'ログイン',
                onPressed: () {
                  if (_pin.text.trim() == '9999') {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SellerConsolePage()));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PINが違います')));
                  }
                },
              )),
        ]),
      ),
    );
  }
}

class SellerConsolePage extends StatefulWidget {
  const SellerConsolePage({super.key});
  @override
  State<SellerConsolePage> createState() => _SellerConsolePageState();
}

class _SellerConsolePageState extends State<SellerConsolePage> {
  @override
  void initState() {
    super.initState();
    app.loadProducts(); // safe even if storage blocked
  }

  @override
  Widget build(BuildContext context) {
    final items = app.products;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: const GradientText('販売者コンソール',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() => app.loadProducts());
            },
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ProductEditPage()));
          setState(() {});
        },
        icon: const Icon(Icons.add),
        label: const Text('新規商品'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: items.isEmpty
            ? const Center(
                child: Text('商品がありません。「新規商品」から登録してください。'))
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = items[i];
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101010),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: hex(p.colorHex),
                        backgroundImage: p.imageProvider(),
                      ),
                      title: Text('${p.brand} / ${p.name}'),
                      subtitle: Text(
                          '¥${p.price}  在庫:${p.stock}  ${p.category}  送料:¥${p.shippingFee}'),
                      trailing: Wrap(spacing: 8, children: [
                        IconButton(
                          tooltip: '編集',
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ProductEditPage(product: p)));
                            setState(() {});
                          },
                        ),
                        IconButton(
                          tooltip: '削除',
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            setState(() => app.products.removeAt(i));
                            app.saveProducts();
                          },
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class ProductEditPage extends StatefulWidget {
  final Product? product;
  const ProductEditPage({super.key, this.product});
  @override
  State<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  late TextEditingController _name,
      _brand,
      _price,
      _stock,
      _color,
      _desc,
      _imgUrl,
      _ship;
  late TextEditingController _sizeInput, _tagInput;
  String category = 'tops';
  String seasonTag = 'All';
  String colorFamily = 'その他';
  Uint8List? imageBytes;
  List<String> sizes = [];
  List<String> tags = [];

  static const List<String> colorFamilies = [
    'ホワイト',
    'ブラック',
    'グレー',
    'レッド',
    'オレンジ',
    'イエロー',
    'グリーン',
    'ブルー',
    'パープル',
    'ブラウン',
    'ピンク',
    'ベージュ',
    'ネイビー',
    'その他'
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _brand = TextEditingController(text: p?.brand ?? '');
    _price = TextEditingController(text: (p?.price ?? 0).toString());
    _stock = TextEditingController(text: (p?.stock ?? 0).toString());
    _color = TextEditingController(text: p?.colorHex ?? '#FFFFFF');
    _desc = TextEditingController(text: p?.description ?? '');
    _imgUrl = TextEditingController(text: p?.imageUrl ?? '');
    _ship = TextEditingController(text: (p?.shippingFee ?? 0).toString());
    _sizeInput = TextEditingController();
    _tagInput = TextEditingController();
    category = p?.category ?? 'tops';
    seasonTag = p?.seasonTag ?? 'All';
    colorFamily = p?.colorFamily ?? 'その他';
    sizes = List<String>.from(p?.sizes ?? const []);
    tags = List<String>.from(p?.tags ?? const []);
    if (p?.imageB64 != null && p!.imageB64!.isNotEmpty) {
      imageBytes = base64Decode(p.imageB64!);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _price.dispose();
    _stock.dispose();
    _color.dispose();
    _desc.dispose();
    _imgUrl.dispose();
    _ship.dispose();
    _sizeInput.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  Future<void> _pickImageWeb() async {
    if (!kIsWeb) return;
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return;
    final file = input.files!.first;
    final r = html.FileReader();
    r.readAsArrayBuffer(file);
    await r.onLoadEnd.first;
    setState(() => imageBytes = Uint8List.fromList(r.result as List<int>));
  }

  void _addSize() {
    final s = _sizeInput.text.trim();
    if (s.isNotEmpty && !sizes.contains(s)) {
      setState(() => sizes.add(s));
    }
    _sizeInput.clear();
  }

  void _addTag() {
    final t = _tagInput.text.trim();
    if (t.isNotEmpty && !tags.contains(t)) {
      setState(() => tags.add(t));
    }
    _tagInput.clear();
  }

  void _save() {
    final isNew = widget.product == null;
    final p = isNew
        ? Product(
            id: newId(),
            name: _name.text.trim(),
            brand: _brand.text.trim(),
            category: category,
            price: int.tryParse(_price.text.trim()) ?? 0,
            stock: int.tryParse(_stock.text.trim()) ?? 0,
            seasonTag: seasonTag,
            colorHex:
                _color.text.trim().isEmpty ? '#FFFFFF' : _color.text.trim(),
            imageUrl:
                _imgUrl.text.trim().isNotEmpty ? _imgUrl.text.trim() : null,
            imageB64: imageBytes != null ? base64Encode(imageBytes!) : null,
            description: _desc.text.trim(),
            sizes: sizes,
            tags: tags,
            colorFamily: colorFamily,
            shippingFee: int.tryParse(_ship.text.trim()) ?? 0,
          )
        : widget.product!
          ..name = _name.text.trim()
          ..brand = _brand.text.trim()
          ..category = category
          ..price = int.tryParse(_price.text.trim()) ?? 0
          ..stock = int.tryParse(_stock.text.trim()) ?? 0
          ..seasonTag = seasonTag
          ..colorHex =
              _color.text.trim().isEmpty ? '#FFFFFF' : _color.text.trim()
          ..imageUrl =
              _imgUrl.text.trim().isNotEmpty ? _imgUrl.text.trim() : null
          ..imageB64 =
              imageBytes != null ? base64Encode(imageBytes!) : widget.product!.imageB64
          ..description = _desc.text.trim()
          ..sizes = sizes
          ..tags = tags
          ..colorFamily = colorFamily
          ..shippingFee = int.tryParse(_ship.text.trim()) ?? 0;

    if (isNew) {
      app.products.insert(0, p);
    }
    app.saveProducts(); // safe even if blocked
    Navigator.pop(context);
  }

  Widget _chipEditor({
    required String label,
    required TextEditingController controller,
    required VoidCallback onAdd,
    required List<String> values,
    List<String> quickAdds = const [],
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(hintText: '入力して追加'))),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: onAdd, child: const Text('追加')),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: -8,
          children: [
            for (final v in values)
              InputChip(
                label: Text(v),
                onDeleted: () {
                  values.remove(v);
                  setState(() {});
                },
              ),
            if (quickAdds.isNotEmpty) const SizedBox(width: 12),
            for (final q in quickAdds)
              ActionChip(
                  label: Text(q),
                  onPressed: () {
                    if (!values.contains(q)) {
                      values.add(q);
                      setState(() {});
                    }
                  }),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final imgProvider = imageBytes != null
        ? MemoryImage(imageBytes!)
        : (_imgUrl.text.trim().isNotEmpty
            ? NetworkImage(_imgUrl.text.trim()) as ImageProvider
            : null);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: GradientText(
            widget.product == null ? '新規商品' : '商品を編集',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(children: [
          const StorageStatusBanner(),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: '商品名'))),
            const SizedBox(width: 12),
            Expanded(
                child: TextField(
                    controller: _brand,
                    decoration: const InputDecoration(labelText: 'ブランド'))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'カテゴリ'),
              items: const [
                DropdownMenuItem(value: 'tops', child: Text('トップス')),
                DropdownMenuItem(value: 'outer', child: Text('アウター')),
                DropdownMenuItem(value: 'bottom', child: Text('ボトムス')),
                DropdownMenuItem(value: 'accessory', child: Text('アクセサリ')),
              ],
              onChanged: (v) => setState(() => category = v ?? 'tops'),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: DropdownButtonFormField<String>(
              value: seasonTag,
              decoration: const InputDecoration(labelText: '推奨シーズン'),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All')),
                DropdownMenuItem(value: 'Spring', child: Text('Spring')),
                DropdownMenuItem(value: 'Summer', child: Text('Summer')),
                DropdownMenuItem(value: 'Autumn', child: Text('Autumn')),
                DropdownMenuItem(value: 'Winter', child: Text('Winter')),
              ],
              onChanged: (v) => setState(() => seasonTag = v ?? 'All'),
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '価格(円)'))),
            const SizedBox(width: 12),
            Expanded(
                child: TextField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '在庫数'))),
            const SizedBox(width: 12),
            Expanded(
                child: TextField(
                    controller: _ship,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '送料(円)'))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: DropdownButtonFormField<String>(
              value: colorFamily,
              decoration: const InputDecoration(labelText: '色系統'),
              items: colorFamilies
                  .map((cf) =>
                      DropdownMenuItem(value: cf, child: Text(cf)))
                  .toList(),
              onChanged: (v) => setState(() => colorFamily = v ?? 'その他'),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: TextField(
                    controller: _color,
                    decoration:
                        const InputDecoration(labelText: '代表カラー(例: #FF0000)'))),
          ]),
          const SizedBox(height: 12),
          TextField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '商品説明')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _imgUrl,
                    decoration:
                        const InputDecoration(labelText: '画像URL（任意）'),
                    onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            ElevatedButton(
                onPressed: kIsWeb ? _pickImageWeb : null,
                child: const Text('画像を選ぶ（Web）')),
          ]),
          const SizedBox(height: 12),
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF101010),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: imgProvider != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image(image: imgProvider, fit: BoxFit.cover))
                : const Center(child: Text('画像プレビュー')),
          ),
          const SizedBox(height: 16),
          _chipEditor(
            label: 'サイズ（複数可）',
            controller: _sizeInput,
            onAdd: _addSize,
            values: sizes,
            quickAdds: const ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
          ),
          const SizedBox(height: 16),
          _chipEditor(
            label: 'タグ（検索用キーワード）',
            controller: _tagInput,
            onAdd: _addTag,
            values: tags,
            quickAdds: const [
              '春夏',
              '秋冬',
              'オフィス',
              'カジュアル',
              'モノトーン',
              'デニム',
              'シャツ',
              'ジャケット'
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child:
                  GradientButton(label: '保存する', onPressed: _save)),
        ]),
      ),
    );
  }
}
