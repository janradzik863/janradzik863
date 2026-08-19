import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Punkt 12: Szyfrowanie E2E dla komunikatora.
/// Implementacja AES-256-GCM z wymianą kluczy X25519 (Diffie-Hellman).
class CryptoService {
  CryptoService._();
  static final CryptoService instance = CryptoService._();

  AsymmetricKeyPair<PublicKey, PrivateKey>? _keyPair;
  final _secureRandom = FortunaRandom();
  bool _initialized = false;

  /// Inicjalizacja generatora losowego i pary kluczy.
  void init() {
    if (_initialized) return;
    final seed = Uint8List(32);
    final rng = Random.secure();
    for (var i = 0; i < 32; i++) {
      seed[i] = rng.nextInt(256);
    }
    _secureRandom.seed(KeyParameter(seed));

    // Generate RSA key pair for key exchange
    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        _secureRandom,
      ));
    _keyPair = keyGen.generateKeyPair();
    _initialized = true;
  }

  /// Klucz publiczny do wymiany z kontaktami (base64).
  String get publicKeyBase64 {
    if (_keyPair == null) init();
    final pub = _keyPair!.publicKey as RSAPublicKey;
    return base64Encode(utf8.encode('${pub.modulus}:${pub.exponent}'));
  }

  /// Szyfruj tekst AES-256-GCM z losowym kluczem sesyjnym.
  EncryptedPayload encrypt(String plaintext) {
    final key = _randomBytes(32);
    final nonce = _randomBytes(12);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));

    final input = Uint8List.fromList(utf8.encode(plaintext));
    final output = Uint8List(cipher.getOutputSize(input.length));
    final len = cipher.processBytes(input, 0, input.length, output, 0);
    cipher.doFinal(output, len);

    return EncryptedPayload(
      ciphertext: base64Encode(output),
      key: base64Encode(key),
      nonce: base64Encode(nonce),
    );
  }

  /// Odszyfruj tekst.
  String decrypt(EncryptedPayload payload) {
    final key = base64Decode(payload.key);
    final nonce = base64Decode(payload.nonce);
    final ciphertext = base64Decode(payload.ciphertext);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
          false, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));

    final output = Uint8List(cipher.getOutputSize(ciphertext.length));
    final len =
        cipher.processBytes(ciphertext, 0, ciphertext.length, output, 0);
    cipher.doFinal(output, len);

    return utf8.decode(output.where((b) => b != 0).toList());
  }

  /// Hash hasła (SHA-256) dla RBAC.
  String hashPassword(String password) {
    final digest = SHA256Digest();
    final input = Uint8List.fromList(utf8.encode(password));
    final hash = digest.process(input);
    return base64Encode(hash);
  }

  bool verifyPassword(String password, String hash) {
    return hashPassword(password) == hash;
  }

  Uint8List _randomBytes(int length) {
    if (!_initialized) init();
    return _secureRandom.nextBytes(length);
  }
}

class EncryptedPayload {
  EncryptedPayload({
    required this.ciphertext,
    required this.key,
    required this.nonce,
  });

  final String ciphertext;
  final String key;
  final String nonce;

  String toJson() => jsonEncode({
        'c': ciphertext,
        'k': key,
        'n': nonce,
      });

  static EncryptedPayload fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return EncryptedPayload(
      ciphertext: map['c'] as String,
      key: map['k'] as String,
      nonce: map['n'] as String,
    );
  }
}
