const express = require('express');
const app = express();
const port = 3000;
const cors = require('cors');
const axios = require('axios');


app.use(cors()); // app 정의 바로 다음에 추가
app.use(express.json()) // 프론트에서 주는 데이터 읽기 위해

// DB ngrok 주소
const YERIN_SERVER_URL = 'https://len-untoppable-mavis.ngrok-free.dev';


// 서버가 켜졌을 때 보여줄 첫 화면 (기본 주소)
app.get('/', (req, res) => {
    res.send('갈래말래 백엔드 서버가 시작되었습니다!');
});



// 예린이 서버에서 받아오기
app.get('/api/titles', async (req, res) => {
    // 1. 채연이(프론트)가 보낸 카테고리 값을 가져옵니다 (예: '식사' 또는 '취미')
    const category = req.query.category; 

    try {
        // 2. 예린이 서버 주소 뒤에 쿼리스트링(?category=...)을 붙여서 요청합니다.
        const response = await axios.get(`${YERIN_SERVER_URL}/api/titles`, {
            params: { category: category } // 이렇게 넣으면 자동으로 ?category=식사 가 붙어요!
        });

        // 3. 예린이 서버가 준 타이틀 리스트를 그대로 전달!
        console.log(`[${category}] 타이틀 목록 불러오기 성공`);
        res.json(response.data);
        
    } catch (err) {
        console.error('타이틀 불러오기 실패:', err.message);
        res.status(500).json({ error: '타이틀 목록을 가져올 수 없습니다.' });
    }
});


// 게시글 생성 (민서님 데이터 구조 그대로 DB에 저장)
app.post('/api/posts', async (req, res) => {
    try {
        // 4. 내가 받은 데이터를 그대로 예린이 서버로 토스합니다.
        const response = await axios.post(`${YERIN_SERVER_URL}/api/posts`, req.body);
        res.status(201).json(response.data);
    } catch (err) {
        console.error('게시글 저장 실패:', err.message);
        res.status(500).json({ error: '데이터 저장에 실패했습니다.' });
    }
});


// 게시글 전체 조회 API (예린이 서버에서 목록 가져오기)
app.get('/api/posts', async (req, res) => {
    try {
        // 예린이 서버에 "게시글 목록 줘!"라고 요청
        const response = await axios.get(`${YERIN_SERVER_URL}/api/posts`);
        
        // 받은 데이터를 그대로 민서 서버를 거쳐 채연이에게 전달
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