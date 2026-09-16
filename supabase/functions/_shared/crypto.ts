/**
 * trading_configs 민감 필드 암호화 (AES-256-GCM).
 *
 * 왜 필요한가
 * -----------
 * KIS App Key/Secret, 계좌번호, 카카오 refresh token 이 DB에 평문으로 있었다.
 * RLS 로 본인 행만 보이게는 했지만, RLS 는 DB 유출·백업 유출·service_role 키
 * 유출 앞에서는 아무 역할도 못 한다. 이 프로젝트에서 제일 민감한 데이터가
 * 증권사 API 자격증명이므로 애플리케이션 레벨에서 암호화한다.
 *
 * 키 관리
 * -------
 * TRADING_ENC_KEY : base64 로 인코딩한 32바이트. 두 곳에 같은 값을 넣는다.
 *   - Supabase Function Secrets (쓰기 = 이 파일)
 *   - GitHub Actions Secrets    (읽기 = trading/config_crypto.py)
 * DB 밖에 있으므로, DB 만 털려서는 복호화되지 않는다.
 *
 * 저장 형식
 * ---------
 *   enc:v1:<base64(iv 12B)>:<base64(ciphertext||tag)>
 * 접두사를 두는 이유는 두 가지다. 암호화 전 평문 행과 섞여 있어도 구분되고
 * (마이그레이션 중 무중단), 나중에 키 교체나 알고리즘 변경 시 v2 로 올릴 수 있다.
 */
import * as base64 from "jsr:@std/encoding/base64";

const PREFIX = "enc:v1:";

function keyBytes(): Uint8Array {
  const raw = Deno.env.get("TRADING_ENC_KEY") ?? "";
  if (!raw) {
    throw new Error(
      "TRADING_ENC_KEY 미설정 — supabase secrets set TRADING_ENC_KEY=<base64 32바이트>",
    );
  }
  const bytes = base64.decodeBase64(raw);
  if (bytes.length !== 32) {
    throw new Error(`TRADING_ENC_KEY 길이 오류: ${bytes.length}바이트 (32 필요)`);
  }
  return bytes;
}

export function isEncrypted(value: string): boolean {
  return typeof value === "string" && value.startsWith(PREFIX);
}

/** 평문 → "enc:v1:...". 빈 값은 그대로 둔다 (NULL/빈칸을 암호문으로 만들지 않는다). */
export async function encryptField(plain: string | null | undefined): Promise<string | null> {
  if (plain === null || plain === undefined || plain === "") return null;
  if (isEncrypted(plain)) return plain;   // 이미 암호문이면 이중 암호화 방지

  const key = await crypto.subtle.importKey(
    "raw", keyBytes(), { name: "AES-GCM" }, false, ["encrypt"],
  );
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(
    await crypto.subtle.encrypt(
      { name: "AES-GCM", iv }, key, new TextEncoder().encode(plain),
    ),
  );
  return `${PREFIX}${base64.encodeBase64(iv)}:${base64.encodeBase64(ct)}`;
}

/** "enc:v1:..." → 평문. 접두사가 없으면 아직 암호화 전 평문으로 보고 그대로 반환한다. */
export async function decryptField(value: string | null | undefined): Promise<string | null> {
  if (value === null || value === undefined || value === "") return null;
  if (!isEncrypted(value)) return value;

  const parts = value.split(":");
  if (parts.length !== 4) throw new Error("암호문 형식 오류");
  const iv = base64.decodeBase64(parts[2]);
  const ct = base64.decodeBase64(parts[3]);

  const key = await crypto.subtle.importKey(
    "raw", keyBytes(), { name: "AES-GCM" }, false, ["decrypt"],
  );
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, ct);
  return new TextDecoder().decode(plain);
}
