// Vercel KV 백업 스크립트 (JSON 파일로 내보내기)
import { kv } from '@vercel/kv';
import { writeFileSync } from 'fs';

async function exportKVBackup() {
  console.log('💾 Vercel KV 백업 시작...\n');

  try {
    // 1. 모든 추천 ID 가져오기
    const allIds = await kv.zrange('recommendations:timeline', 0, -1);
    console.log(`📊 총 ${allIds.length}개 추천 발견\n`);

    const allRecommendations = [];
    const allStats = {};

    // 2. 추천 데이터 가져오기
    console.log('📥 추천 데이터 추출 중...');
    
    for (let i = 0; i < allIds.length; i++) {
      const id = allIds[i];
      const data = await kv.get(`recommendation:${id}`);
      
      if (data) {
        allRecommendations.push(data);
        
        if ((i + 1) % 100 === 0) {
          console.log(`   ${i + 1}/${allIds.length} (${Math.round((i + 1) / allIds.length * 100)}%)`);
        }
      }
    }

    // 3. 통계 데이터 가져오기
    console.log('\n📥 통계 데이터 추출 중...');
    
    const stockCodes = [...new Set(allRecommendations.map(r => r.stockCode))];
    const periods = ['dayTrading', 'swingTrading', 'longTerm'];

    for (const stockCode of stockCodes) {
      allStats[stockCode] = {};
      
      for (const period of periods) {
        const stats = await kv.get(`stats:${stockCode}:${period}`);
        if (stats) {
          allStats[stockCode][period] = stats;
        }
      }
    }

    // 4. JSON 파일로 저장
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = `kv_backup_${timestamp}.json`;

    const backup = {
      exportedAt: new Date().toISOString(),
      version: '1.0',
      totalRecommendations: allRecommendations.length,
      recommendations: allRecommendations,
      stats: allStats,
    };

    writeFileSync(filename, JSON.stringify(backup, null, 2), 'utf-8');

    console.log('\n' + '='.repeat(60));
    console.log(`✅ 백업 완료!`);
    console.log(`   파일: ${filename}`);
    console.log(`   추천: ${allRecommendations.length}개`);
    console.log(`   종목: ${Object.keys(allStats).length}개`);
    console.log(`   크기: ${(JSON.stringify(backup).length / 1024).toFixed(2)} KB`);
    console.log('='.repeat(60));

    // 5. 백업 파일로 복원하는 방법 안내
    console.log('\n📌 복원 방법:');
    console.log(`node scripts/restore_kv_backup.js ${filename}`);

  } catch (error) {
    console.error('❌ 백업 실패:', error);
    process.exit(1);
  }
}

// 실행
exportKVBackup()
  .then(() => {
    console.log('\n🎉 백업 완료!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 오류:', error);
    process.exit(1);
  });

// 사용법:
// node scripts/export_kv_backup.js
// → kv_backup_2025-01-13T10-30-00-000Z.json 생성됨

