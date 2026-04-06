const express = require('express');
const app = express();
const port = 3000;
const cors = require('cors');
const axios = require('axios');


app.use(cors()); // app 정의 바로 다음에 추가
app.use(express.json()) // 프론트에서 주는 데이터 읽기 위해

// DB ngrok 주소
const YERIN_SERVER_URL = 'https://len-untoppable-mavis.ngrok-free.dev';

/*
// 데이터 셋(임시)
const masterHobbyTitles = {
    '취미': ['탁구', '배드민턴', '클라이밍', '방탈출', '보드게임', '당구', '영화'],
    '식사': ['한식', '일식', '중식', '양식', '카페', '술자리'],
};


// 데이터 베이스(임시)
let posts = [
    {  id: 1, category: '취미', title: '탁구', now_count: 1, max_count: 4, date: '26.04.01.', time: '13:00', location: '\0', destination: '짱탁구장'},
    {  id: 2, category: '식사', title: '한식', now_count: 2, max_count: 3, date: '26.04.03.', time: '15:00', location: '\0', destination: '사랑집' },
    ];
*/

// 서버가 켜졌을 때 보여줄 첫 화면 (기본 주소)
app.get('/', (req, res) => {
    res.send('갈래말래 백엔드 서버가 시작되었습니다!');
});

/*
  
// 필터링 조회 API - 아직은 필요없는 기능이나 지장이 없어 남겨둠.

app.get('/api/posts', (req, res) => {
    const category = req.query.category; // 사용자가 보낸 카테고리 (예: ?category=취미)
    
    if (category) {
      const filtered = posts.filter(p => p.category === category);
      return res.json(filtered);
    }
    
    res.json(posts); // 카테고리 없으면 전체 전달
});



// 게시글 생성 (저장하기)
app.post('/api/posts', (req, res) => {
    const newPost = {
        id: posts.length > 0 ? posts[posts.length - 1].id + 1 : 1, // ID 자동 부여
        category: req.body.category, // 프론트가 보낼 카테고리
        title: req.body.title,       // 프론트가 보낼 타이틀 (리스트에서 선택한 값)
        count: req.body.count,       // 나머지 텍스트 정보들
        date: req.body.date,
        location: req.body.location
    };
    
    posts.push(newPost); // 메모리에 저장
    console.log('새 게시글이 생성되었습니다:', newPost);
    res.status(201).json(newPost);
});
*/




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



/*
// 추가 버튼 눌렀을 때 보여줄 "타이틀 리스트" 내려주기
// 사용 예시: /api/titles?category=취미
app.get('/api/titles', (req, res) => {
    const category = req.query.category;
    const titles = masterHobbyTitles[category] || []; 
    res.json(titles);
});
*/


// 서버 실행 함수
app.listen(port, () => {
    console.log(`서버 주소: http://localhost:${port}`);
});