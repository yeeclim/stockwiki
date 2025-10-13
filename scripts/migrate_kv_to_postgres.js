// Vercel KV → PostgreSQL 마이그레이션 스크립트
import { kv } from '@vercel/kv';
import pkg from 'pg';
const { Pool } = pkg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://localhost:5432/stockwiki'
});

async function migrateToPostgreSQL() {
  console.log('🚀 KV → PostgreSQL 마이그레이션 시작...\n');

  const client = await pool.connect();

  try {
    // 1. 테이블 생성
    console.log('📋 테이블 생성 중...');
    
    await client.query(`
      CREATE TABLE IF NOT EXISTS recommendations (
        id TEXT PRIMARY KEY,
        stock_name TEXT NOT NULL,
        stock_code TEXT NOT NULL,
        posted_at TIMESTAMP NOT NULL,
        tracking_status TEXT,
        data JSONB NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_stock_code ON recommendations(stock_code);
      CREATE INDEX IF NOT EXISTS idx_posted_at ON recommendations(posted_at DESC);
      CREATE INDEX IF NOT EXISTS idx_tracking_status ON recommendations(tracking_status);
      CREATE INDEX IF NOT EXISTS idx_performance ON recommendations USING GIN ((data->'performance'));
    `);

    console.log('✅ 테이블 생성 완료\n');

    // 2. KV에서 모든 추천 ID 가져오기
    const allIds = await kv.zrange('recommendations:timeline', 0, -1);
    console.log(`📊 총 ${allIds.length}개 추천 발견\n`);

    let successCount = 0;
    let errorCount = 0;

    // 3. 트랜잭션으로 대량 삽입
    await client.query('BEGIN');

    for (let i = 0; i < allIds.length; i++) {
      const id = allIds[i];
      
      try {
        // KV에서 데이터 가져오기
        const data = await kv.get(`recommendation:${id}`);
        
        if (!data) {
          errorCount++;
          continue;
        }

        // PostgreSQL에 삽입
        await client.query(
          `INSERT INTO recommendations (id, stock_name, stock_code, posted_at, tracking_status, data)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (id) DO UPDATE SET data = $6`,
          [
            data.id,
            data.stockName,
            data.stockCode,
            new Date(data.postedAt),
            data.trackingStatus || 'active',
            JSON.stringify(data)
          ]
        );

        successCount++;

        if ((i + 1) % 100 === 0) {
          console.log(`📝 진행 중... ${i + 1}/${allIds.length} (${Math.round((i + 1) / allIds.length * 100)}%)`);
        }

      } catch (error) {
        console.error(`❌ ${id}: ${error.message}`);
        errorCount++;
      }
    }

    await client.query('COMMIT');

    console.log('\n' + '='.repeat(60));
    console.log(`✅ 마이그레이션 완료!`);
    console.log(`   성공: ${successCount}개`);
    console.log(`   실패: ${errorCount}개`);
    console.log('='.repeat(60) + '\n');

    // 4. 검증
    const result = await client.query('SELECT COUNT(*) FROM recommendations');
    console.log(`🔍 검증: PostgreSQL에 ${result.rows[0].count}개 레코드 저장됨`);

    // 5. JSONB 쿼리 예시
    console.log('\n📌 JSONB 쿼리 예시:');
    console.log(`
-- 성공률이 높은 추천 조회
SELECT 
  stock_name,
  data->>'stockCode' as stock_code,
  (data->'performance'->>'successRate')::float as success_rate
FROM recommendations
WHERE data->'performance' IS NOT NULL
ORDER BY (data->'performance'->>'successRate')::float DESC
LIMIT 10;

-- 특정 종목의 모든 추천
SELECT data 
FROM recommendations 
WHERE stock_code = '005930'
ORDER BY posted_at DESC;
    `);

  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
    await pool.end();
    console.log('\n✅ PostgreSQL 연결 종료');
  }
}

// 실행
migrateToPostgreSQL()
  .then(() => {
    console.log('\n🎉 모든 작업 완료!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 마이그레이션 실패:', error);
    process.exit(1);
  });

// 사용법:
// npm install pg
// DATABASE_URL=postgresql://localhost:5432/stockwiki node scripts/migrate_kv_to_postgres.js

