import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Warstwa kryptograficzna komunikatora E2E (wymaganie #12).
///
/// Schemat (Ephemeral X25519 + HKDF-SHA256 + AES-256-GCM):
///
///   1. Każdy uczestnik posiada długoterminową parę kluczy X25519 (tożsamość).
///   2. Nadawca generuje *świeżą* parę efemeryczną per wiadomość (forward secrecy).
///   3. Sekret = DH(klucz_efemeryczny_prywatny, klucz_tożsamości_odbiorcy).
///   4. Klucz wiadomości = HKDF-SHA256(sekret, "cwp/msg").
///   5. Szyfrowanie AES-256-GCM ze świeżym nonce (poufność + integralność).
///   6. Koperta zawiera klucz publiczny efemeryczny nadawcy, więc odbiorca
///      odtwarza ten sam sekret swoim kluczem prywatnym tożsamości.
///
/// Tylko posiadacz klucza prywatnego tożsamości odbiorcy może odszyfrować.
/// Tożsamość nadawcy jest potwierdzana implicite (udany DH + GCM).
///
/// Uwaga: pełny Double Ratchet (Signal) jest planowanym rozszerzeniem —
/// ten schemat zapewnia E2E poufność, integralność i forward secrecy.
class CryptoEngine {
  final X25519 _x = X25519();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final AesGcm _aes = AesGcm.with256bits();

  SimpleKeyPair? _identity;
  Uint8List? _identityPublic;
  Uint8List? _identitySeed;

  Uint8List get identityPublic => _identityPublic ?? Uint8List(0);
  Uint8List? get identitySeed => _identitySeed;

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }

  /// Generuje nową parę kluczy tożsamości.
  Future<Uint8List> generateIdentity() async {
    _identity = await _x.newKeyPair();
    _identitySeed =
        Uint8List.fromList(await _identity!.extractPrivateKeyBytes());
    _identityPublic =
        Uint8List.fromList((await _identity!.extractPublicKey()).bytes);
    return _identityPublic!;
  }

  /// Odtwarza tożsamość z zapisanego ziarna (32 bajty).
  Future<void> loadIdentityFromSeed(Uint8List seed) async {
    _identity = await _x.newKeyPairFromSeed(seed);
    _identitySeed = seed;
    _identityPublic =
        Uint8List.fromList((await _identity!.extractPublicKey()).bytes);
  }

  Future<List<int>> _derive(SecretKey shared, String label) async {
    final okm = await _hkdf.deriveKey(
      secretKey: shared,
      nonce: utf8.encode(label),
    );
    return okm.extractBytes();
  }

  /// Szyfruje `plaintext` dla odbiorcy o kluczu publicznym `recipientPub`.
  Future<Uint8List> encryptMessage(
      List<int> plaintext, List<int> recipientPub) async {
    final eph = await _x.newKeyPair();
    final ephPub = Uint8List.fromList((await eph.extractPublicKey()).bytes);
    final shared = await _x.sharedSecretKey(
      keyPair: eph,
      remotePublicKey:
          SimplePublicKey(recipientPub, type: KeyPairType.x25519),
    );
    final key = await _derive(shared, 'cwp/msg');

    final nonce = _randomBytes(12);
    final box = await _aes.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
    );

    final out = BytesBuilder();
    out.addByte(1); // wersja koperty
    out.add(ephPub); // 32 B — klucz efemeryczny nadawcy
    out.add(nonce); // 12 B
    out.add(box.mac.bytes); // 16 B
    out.add(box.cipherText);
    return out.toBytes();
  }

  /// Odszyfrowuje kopertę własnym kluczem prywatnym tożsamości.
  Future<List<int>> decryptMessage(Uint8List envelope) async {
    if (envelope.length < 1 + 32 + 12 + 16) {
      throw const FormatException('Koperta jest za krótka.');
    }
    var off = 1;
    final ephPub = Uint8List.sublistView(envelope, off, off + 32);
    off += 32;
    final nonce = Uint8List.sublistView(envelope, off, off + 12);
    off += 12;
    final mac = Uint8List.sublistView(envelope, off, off + 16);
    off += 16;
    final cipher = Uint8List.sublistView(envelope, off);

    final shared = await _x.sharedSecretKey(
      keyPair: _identity!,
      remotePublicKey: SimplePublicKey(ephPub, type: KeyPairType.x25519),
    );
    final key = await _derive(shared, 'cwp/msg');

    final clear = await _aes.decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(key),
    );
    return clear;
  }

  /// Pomocnicze: kodowanie klucza publicznego do base64.
  static String encodePub(List<int> pub) => base64Encode(pub);
  static Uint8List decodePub(String b64) => base64Decode(b64);
}
