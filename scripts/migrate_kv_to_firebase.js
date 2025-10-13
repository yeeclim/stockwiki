// Vercel KV → Firebase Firestore 마이그레이션 스크립트
import { kv } from '@vercel/kv';
import admin from 'firebase-admin';
import { readFileSync } from 'fs';

// Firebase 설정
const serviceAccount = JSON.parse(
  readFileSync('./firebase-service-account.json', 'utf8')
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const firestore = admin.firestore();

async function migrateToFirebase() {
  console.log('🚀 KV → Firebase 마이그레이션 시작...\n');

  try {
    // 1. KV에서 모든 추천 ID 가져오기
    const allIds = await kv.zrange('recommendations:timeline', 0, -1);
    console.log(`📊 총 ${allIds.length}개 추천 발견\n`);

    let successCount = 0;
    let errorCount = 0;

    // 2. Firestore 배치 쓰기 (500개씩)
    const batchSize = 500;
    
    for (let i = 0; i < allIds.length; i += batchSize) {
      const batch = firestore.batch();
      const batchIds = allIds.slice(i, i + batchSize);

      for (const id of batchIds) {
        try {
          // KV에서 데이터 가져오기
          const data = await kv.get(`recommendation:${id}`);
          
          if (!data) {
            errorCount++;
            continue;
          }

          // Firestore 문서 참조
          const docRef = firestore.collection('recommendations').doc(data.id);
          
          // 배치에 추가
          batch.set(docRef, data, { merge: true });
          
          successCount++;

        } catch (error) {
          console.error(`❌ ${id}: ${error.message}`);
          errorCount++;
        }
      }

      // 배치 커밋
      await batch.commit();
      
      console.log(`📝 진행 중... ${Math.min(i + batchSize, allIds.length)}/${allIds.length} (${Math.round(Math.min(i + batchSize, allIds.length) / allIds.length * 100)}%)`);
    }

    console.log('\n' + '='.repeat(60));
    console.log(`✅ 마이그레이션 완료!`);
    console.log(`   성공: ${successCount}개`);
    console.log(`   실패: ${errorCount}개`);
    console.log('='.repeat(60) + '\n');

    // 3. 인덱스 안내 (Firestore는 Firebase Console에서 수동 생성)
    console.log('📑 권장 인덱스 (Firebase Console에서 생성):');
    console.log('   - stockCode (ASC) + postedAt (DESC)');
    console.log('   - trackingStatus (ASC) + postedAt (DESC)');
    console.log('   - performance.successRate (DESC)');

  } finally {
    await admin.app().delete();
    console.log('\n✅ Firebase 연결 종료');
  }
}

// 실행
migrateToFirebase()
  .then(() => {
    console.log('\n🎉 모든 작업 완료!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 마이그레이션 실패:', error);
    process.exit(1);
  });

// 사용법:
// npm install firebase-admin
// node scripts/migrate_kv_to_firebase.js

