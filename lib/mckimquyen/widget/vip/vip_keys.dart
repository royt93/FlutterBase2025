// VIP key configuration (T18 — offline signed keys).
//
// Keys are Ed25519-signed and verified OFFLINE against the public key below.
// Only the PUBLIC key ships in the app, so decompiling the binary does NOT let
// anyone forge new valid keys. Mint keys with the matching PRIVATE key via
// `packages/ad_sdk/tool/vip_mint.dart` (keep the private key secret — never
// commit it). See packages/ad_sdk/README.md → "Signed VIP keys".
//
// ⚠️ The keypair below is a DEMO pair generated for local testing. Before
// release, run `dart run tool/vip_keygen.dart`, replace this public key with
// your own, and store the private key in a secret manager.

/// Ed25519 public key (base64url) used to verify redeemed VIP keys.
const String kVipPublicKeyBase64 =
    'nqmoUYYjAH_dVDcO5fZk8EagjLIq688hPbAzIYD0DWY=';

/// Demo signed keys (safe to show — they cannot be forged; each is per-device
/// one-time-use). Handy for QA and the redeem UI's "example" chips.
const Map<String, String> kVipDemoKeys = {
  '1 ngày':
      'AVP1.ODY0MDB8ZGVtbzFk.NFrAVXDD8FUNpZzBQG_MDq_dgKVyE6HmRTn7TTxmbWT0_hIZX2_9PO1tX2SBMMWh-Mp5nt3d3hnNSbYuDI-tCA==',
  '7 ngày':
      'AVP1.NjA0ODAwfGRlbW83ZA==.7lj_TWdPk3h8LWcBAQzU5dfwmfMeu0--inrlLckEgqtlx3LpNpPNOX4TNZ7ypHmfKRamSWErp6uyRDP54jAaAg==',
  '30 ngày':
      'AVP1.MjU5MjAwMHxkZW1vMzBk.nCPvlNoexldaulVWw5IycTDM1Cr_pUmQQMuf0myVogbnTcrccs69LB40t1MtvPLNhakK0OPIM3e_GaXOsXKrDg==',
};
