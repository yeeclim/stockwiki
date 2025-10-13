// Vercel KV → MongoDB 마이그레이션 스크립트
import { kv } from '@vercel/kv';
import { MongoClient } from 'mongodb';

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017';
const DB_NAME = 'stockwiki';

async function migrateToMongoDB() {
  console.log('🚀 KV → MongoDB 마이그레이션 시작...\n');

  // MongoDB 연결
  const mongoClient = new MongoClient(MONGODB_URI);
  await mongoClient.connect();
  const db = mongoClient.db(DB_NAME);
  const collection = db.collection('recommendations');

  console.log('✅ MongoDB 연결 완료\n');

  try {
    // 1. KV에서 모든 추천 ID 가져오기
    const allIds = await kv.zrange('recommendations:timeline', 0, -1);
    console.log(`📊 총 ${allIds.length}개 추천 발견\n`);

    let successCount = 0;
    let errorCount = 0;

    // 2. 각 추천 데이터 가져오기 및 MongoDB에 삽입
    for (let i = 0; i < allIds.length; i++) {
      const id = allIds[i];
      
      try {
        // KV에서 데이터 가져오기
        const data = await kv.get(`recommendation:${id}`);
        
        if (!data) {
          console.log(`⚠️  [${i + 1}/${allIds.length}] ${id}: 데이터 없음`);
          errorCount++;
          continue;
        }

        // MongoDB에 삽입 (upsert)
        await collection.updateOne(
          { id: data.id },
          { $set: data },
          { upsert: true }
        );

        successCount++;
        
        if ((i + 1) % 100 === 0) {
          console.log(`📝 진행 중... ${i + 1}/${allIds.length} (${Math.round((i + 1) / allIds.length * 100)}%)`);
        }

      } catch (error) {
        console.error(`❌ [${i + 1}/${allIds.length}] ${id}: ${error.message}`);
        errorCount++;
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log(`✅ 마이그레이션 완료!`);
    console.log(`   성공: ${successCount}개`);
    console.log(`   실패: ${errorCount}개`);
    console.log('='.repeat(60) + '\n');

    // 3. 인덱스 생성
    console.log('📑 인덱스 생성 중...');
    
    await collection.createIndex({ postedAt: -1 }); // 최신순 정렬용
    await collection.createIndex({ stockCode: 1 }); // 종목별 조회용
    await collection.createIndex({ trackingStatus: 1 }); // 상태별 필터링
    await collection.createIndex({ 'performance.successRate': -1 }); // 성공률 정렬
    
    console.log('✅ 인덱스 생성 완료\n');

    // 4. 검증
    const mongoCount = await collection.countDocuments();
    console.log(`🔍 검증: MongoDB에 ${mongoCount}개 문서 저장됨`);

  } finally {
    await mongoClient.close();
    console.log('\n✅ MongoDB 연결 종료');
  }
}

// 실행
migrateToMongoDB()
  .then(() => {
    console.log('\n🎉 모든 작업 완료!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 마이그레이션 실패:', error);
    process.exit(1);
  });

// 사용법:
// npm install mongodb
// MONGODB_URI=mongodb://localhost:27017 node scripts/migrate_kv_to_mongodb.js

