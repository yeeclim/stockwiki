// scripts/fetch-krx.js
import fs from 'fs';
import axios from 'axios';
import path from 'path';
import { fileURLToPath } from 'url';

// __dirname 대체 (ESM 환경용)
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 저장 경로
const DATA_DIR = path.join(__dirname, '..', 'data');
const OUTPUT_PATH = path.join(DATA_DIR, 'krx_filtered_data.json');

async function fetchKRXData() {
  try {
    console.log('📡 한국거래소 데이터 요청 중...');

    const res = await axios.post(
      'http://data.krx.co.kr/comm/bldAttendant/getJsonData.cmd',
      new URLSearchParams({
        bld: 'dbms/MDC/STAT/standard/MDCSTAT01901',
        mktId: 'STK', // KOSPI: STK, KOSDAQ: KSQ
        share: '1',
        money: '1',
        csvxls_isNo: 'false',
      }),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      }
    );

    const fullData = res.data?.OutBlock_1 || [];

    if (!Array.isArray(fullData) || fullData.length === 0) {
      console.warn('⚠️ 응답 데이터가 비어있습니다.');
      process.exit(1);
    }

    // 📊 필터링: 시가총액 기준 상위 30종목
    const topList = fullData
      .filter(item => item.MKTCAP && !isNaN(Number(item.MKTCAP.replace(/,/g, ''))))
      .sort((a, b) => Number(b.MKTCAP.replace(/,/g, '')) - Number(a.MKTCAP.replace(/,/g, '')))
      .slice(0, 30);

    if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
    fs.writeFileSync(OUTPUT_PATH, JSON.stringify(topList, null, 2));

    console.log(`✅ KRX 데이터 저장 완료: ${OUTPUT_PATH} (${topList.length}개 종목)`);
  } catch (err) {
    console.error('❌ KRX 데이터 요청 실패:', err.response?.data || err.message);
    process.exit(1);
  }
}

fetchKRXData();
