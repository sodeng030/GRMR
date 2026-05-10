const express = require('express');
const app = express();
const port = 3001;
const cors = require('cors');
const axios = require('axios');


app.use(cors());
app.use(express.json())

// DB 주소소
const DB_SERVER_URL = 'http://localhost:3000';

// 프로필 색상코드
const colorPalette = {
    'red': '#F6796E',
    'orange': '#FFAA46',
    'yellow': '#FFD66D',
    'green': '#C7DA80'
};



// 서버 시작
app.get('/', (req, res) => {
    res.send('갈래말래 백엔드 서버가 시작되었습니다!');
});


// uid/프로필 불러오는 API
app.get('/api/user/profile/:uid', async (req, res) => {
    const { uid } = req.params;
    
    try {
        const response = await axios.get(`${DB_SERVER_URL}/api/user/me`, {
            headers: {
                'uid': uid,
            }
        });
        
        const dbData = response.data; 
        
        const colorKey = dbData.color || dbData.current_color;

        const processedData = {
            ...dbData,
            colorCode: colorPalette[colorKey] || '#C7DA80'
        };

        console.log(`[헤더인증 연동] UID ${uid} 데이터 수신 성공`);
        res.json(processedData);

    } catch (err) {
        console.error('연결 에러:', err.message);
        res.status(500).json({ 
            error: 'DB 서버 연동 실패', 
            details: 'DB 서버에서 해당 UID의 헤더를 읽지 못했을 수 있습니다.' 
        });
    }
});

// 장소 검색 API (네이버 지도 좌표 추출용)
app.get('/api/map/search', async (req, res) => {
    const { query } = req.query; 

    if (!query) {
        return res.status(400).json({ error: '검색어를 입력해주세요.' });
    }

    try {
        const response = await axios.get('https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode', {
            params: { query },
            headers: {
                'cxm3n7ljxs',
                'ts3Iw20w12gG5Ym8tBJelqqMUgJj46Swi28UCLMa'
            }
        });

        // 네이버가 준 데이터가 있는지 확인
        if (response.data.addresses && response.data.addresses.length > 0) {
            const firstResult = response.data.addresses[0]; 
            
            // 위도 경도 골라내기기
            const processedData = {
                address: firstResult.roadAddress || firstResult.jibunAddress, // 주소
                lat: firstResult.y, // 위도
                lng: firstResult.x  // 경도
            };

            console.log(`[지도 검색 성공] ${query} -> lat: ${processedData.lat}, lng: ${processedData.lng}`);
            res.json(processedData);
        } else {
            res.status(404).json({ message: '검색 결과가 없습니다.' });
        }

    } catch (err) {
        console.error('지도 검색 실패:', err.message);
        res.status(500).json({ error: '지도 정보를 가져오지 못했습니다.' });
    }
});


// 게시글 참가 API
app.post('/api/posts/:post_id/join', async (req, res) => {
    const { post_id } = req.params;
    const { uid } = req.body; 

    if (!uid || !post_id) {
        return res.status(400).json({ error: '사용자 ID(uid) 또는 게시글 ID(post_id)가 누락되었습니다.' });
    }

    try {
        const response = await axios.post(`${DB_SERVER_URL}/api/posts/${post_id}/join`, {
            uid: uid
        });

        console.log(`[신청 성공] URL: /api/posts/${post_id}/join | User: ${uid}`);
        res.json({
            success: true,
            message: '참여 신청이 완료되었습니다.',
            data: response.data
        });

    } catch (err) {
        console.error('신청 처리 중 에러 발생:', err.message);
        const errMsg = err.response?.data?.message || 'DB 서버 연동 중 오류가 발생했습니다.';
        res.status(500).json({ error: '신청 실패', details: errMsg });
    }
});


// title 받아오는 API
app.get('/api/titles', async (req, res) => {
    const category = req.query.category; 

    try {
        const response = await axios.get(`${DB_SERVER_URL}/api/titles`, {
            params: { category: category }
        });

        console.log(`[${category}] 타이틀 목록 불러오기 성공`);
        res.json(response.data);
        
    } catch (err) {
        console.error('타이틀 불러오기 실패:', err.message);
        res.status(500).json({ error: '타이틀 목록을 가져올 수 없습니다.' });
    }
});


// 게시글 생성 API
app.post('/api/posts', async (req, res) => {
    try {
        const response = await axios.post(`${DB_SERVER_URL}/api/posts`, req.body);
        res.status(201).json(response.data);
    } catch (err) {
        console.error('게시글 저장 실패:', err.message);
        res.status(500).json({ error: '데이터 저장에 실패했습니다.' });
    }
});


// 게시글 전체 조회 API
app.get('/api/posts', async (req, res) => {
    try {
        const response = await axios.get(`${DB_SERVER_URL}/api/posts`);
        
        console.log("게시글 목록 불러오기 성공");
        res.json(response.data);
    } catch (err) {
        console.error('게시글 목록 불러오기 실패:', err.message);
        res.status(500).json({ error: '목록을 가져올 수 없습니다.' });
    }
});


// 서버 실행 함수
app.listen(port, () => {
    console.log(`서버 주소: http://localhost:${port}`);
});