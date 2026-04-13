require('dotenv').config(); // 1. 최상단으로 이동
const express = require('express');
const passport = require('passport');
const session = require('express-session');
const jwt = require('jsonwebtoken');
const cors = require('cors'); 
const db = require('./db'); // 2. 환경 변수 로드 후 DB 모듈 로드

const app = express();

// 1. 미들웨어 설정
app.use(express.json()); 
app.use(cors()); 
app.use(session({ 
    secret: process.env.SESSION_SECRET || 'galrae-default-secret', 
    resave: false, 
    saveUninitialized: true 
}));

// 2. 고정 데이터셋
const masterHobbyTitles = {
    '취미': [
        '탁구', '배드민턴', '클라이밍', '방탈출', '보드게임', 
        '당구', '영화', '코인노래방', '볼링', '원데이클래스', 
        '전시회', '독서모임', '산책', '등산', '러닝', 
        '봉사활동', '베이킹', '드로잉', '사진출사', '테니스'
    ],
    '식사': [
        '한식', '일식', '중식', '양식', '카페', 
        '술자리', '디저트', '분식', '고기구이', '오마카세', 
        '브런치', '패스트푸드', '동남아음식', '인도/남미음식', '비건식단', 
        '포장마차', '와인바', '이자카야', '맥주집', '뷔페'
    ],
};

// [기본 경로] 서버 작동 확인
app.get('/', (req, res) => {
    res.send('✅ 갈래말래 백엔드 서버가 정상 작동 중입니다!');
});

// [라우트 1] 카카오 로그인 및 JWT 발급
app.get('/auth/kakao', passport.authenticate('kakao'));

app.get('/auth/kakao/callback', 
    passport.authenticate('kakao', { failureRedirect: '/' }),
    (req, res) => {
        const token = jwt.sign(
            { id: req.user.id, nickname: req.user.nickname },
            process.env.JWT_SECRET || 'galrae-secret-key',
            { expiresIn: '1h' }
        );

        res.json({
            success: true,
            message: `${req.user.nickname}님 로그인 성공!`,
            token: token
        });
    }
);

// [라우트 2] 타이틀 리스트 내려주기
app.get('/api/titles', async (req, res) => {
    const category = req.query.category;
    try {
        const [rows] = await db.query('SELECT title FROM CategoryTitles WHERE category = ?', [category]);
        const titles = rows.map(row => row.title); 
        res.json(titles);
    } catch (error) {
        console.error("❌ 타이틀 조회 에러:", error);
        res.status(500).json({ success: false, message: '리스트 로드 실패' });
    }
});

// [라우트 3] 게시글 목록 조회 API (creator 내부에 birth 추가)
app.get('/api/posts', async (req, res) => {
    try {
        const sql = `
            SELECT 
                m.*, 
                c.email AS c_email, c.name AS c_name, c.gender AS c_gender, 
                c.current_color AS c_color, c.birth AS c_birth, -- birth 추가
                a1.name AS a1_name,
                a2.name AS a2_name,
                a3.name AS a3_name
            FROM meetings m
            LEFT JOIN tempusers c ON m.CUID = c.uid
            LEFT JOIN tempusers a1 ON m.A1UID = a1.uid
            LEFT JOIN tempusers a2 ON m.A2UID = a2.uid
            LEFT JOIN tempusers a3 ON m.A3UID = a3.uid
            ORDER BY m.target_date ASC
        `;
        
        const [rows] = await db.query(sql);
        
        const formattedPosts = rows.map(post => ({
            id: post.id,
            category: post.category,
            title: post.title,
            now_count: post.now_count,
            max_count: post.max_count,
            date: post.target_date,
            time: post.target_time,
            location: post.location,
            destination: post.destination,
            
            creator: {
                uid: post.CUID,
                name: post.c_name || '미정',
                email: post.c_email || '정보 없음',
                gender: post.c_gender || '미정',
                birth: post.c_birth || '정보 없음', // 여기에 생일 추가!
                current_color: post.c_color || 'gray'
            },
            
            participants: {
                a1_name: post.a1_name,
                a2_name: post.a2_name,
                a3_name: post.a3_name
            }
        }));

        res.json(formattedPosts);
    } catch (error) {
        console.error("❌ 게시글 조회 중 DB 에러:", error);
        res.status(500).json({ success: false, message: '데이터 로드 실패' });
    }
});

// [라우트 4] 유저 정보 가져오기 (birth 포함)
app.get('/api/user/me', async (req, res) => {
    try {
        const headerUid = req.headers['uid']; 
        if (!headerUid) {
            return res.status(400).json({ success: false, message: '헤더에 uid가 없습니다.' });
        }

        const [rows] = await db.query('SELECT * FROM tempusers WHERE uid = ?', [headerUid]);

        if (rows.length === 0) {
            return res.status(404).json({ success: false, message: '유저를 찾을 수 없습니다.' });
        }

        // rows[0]을 그대로 던져주면 DB에 birth가 있을 때 같이 나갑니다.
        res.json(rows[0]); 
    } catch (error) {
        console.error("❌ 유저 조회 에러:", error);
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

// [라우트 5] 게시글 생성
app.post('/api/posts', async (req, res) => {
    const { category, title, now_count, max_count, date, time, location, destination } = req.body;
    try {
        const sql = `
            INSERT INTO Meetings 
            (category, title, now_count, max_count, target_date, target_time, location, destination) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `;
        await db.query(sql, [category, title, now_count || 1, max_count, date, time, location, destination]);
        res.status(201).json({ success: true, message: '게시글이 저장되었습니다.' });
    } catch (error) {
        console.error("❌ DB 저장 에러:", error);
        res.status(500).json({ success: false, message: '게시글 저장 실패' });
    }
});

// [서버 시작]
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`✅ 갈래말래 서버 시작! 포트: ${PORT}`);
    console.log(`👉 전체 게시글 확인: http://localhost:${PORT}/api/posts`);
    console.log(`👉 유저 정보 확인(헤더필요): http://localhost:${PORT}/api/user/me`);
});