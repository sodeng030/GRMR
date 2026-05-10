require('dotenv').config();
const express = require('express');
const passport = require('passport');
const session = require('express-session');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const db = require('./db');
require('./passport');

const http = require('http');
const { Server } = require("socket.io");
const admin = require('firebase-admin');

const app = express();
const server = http.createServer(app);
const io = new Server(server);

app.use(express.json());
app.use(cors());

// 9주차: WebSocket 연결 테스트
io.on('connection', (socket) => {
    console.log('9주차 실시간 매칭 소켓 연결 성공 (ID):', socket.id);
});

// 10주차: FCM Admin SDK 연동
try {
    admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: "galrae-malrae"
    });
    console.log("10주차 FCM SDK 초기화 완료");
} catch (e) {
    console.log("FCM 초기화 대기 중 (인증 파일 확인 필요)");
}

app.use(session({
    secret: process.env.SESSION_SECRET || 'galrae-default-secret',
    resave: false,
    saveUninitialized: true
}));

app.get('/', (req, res) => {
    res.send('✅ 갈래말래 백엔드 서버가 정상 작동 중입니다!');
});

app.get('/auth/kakao', passport.authenticate('kakao'));

app.get('/auth/kakao/callback',
    passport.authenticate('kakao', { failureRedirect: '/' }),
    (req, res) => {
        const token = jwt.sign(
            { id: req.user.id, nickname: req.user.name },
            process.env.JWT_SECRET || 'galrae-secret-key',
            { expiresIn: '1h' }
        );
        res.json({
            success: true,
            message: `${req.user.name}님 로그인 성공!`,
            token: token
        });
    }
);

// [1. 카테고리/취미 목록 가나다순 정렬 API]
app.get('/api/titles', async (req, res) => {
    try {
        const { category } = req.query;
        let sql = 'SELECT * FROM titles ORDER BY category ASC, title ASC';
        let params = [];

        if (category) {
            sql = 'SELECT title FROM titles WHERE category = ? ORDER BY title ASC';
            params = [category];
        }

        const [rows] = await db.query(sql, params);
        console.log(`조회 성공: ${rows.length}건`);
        res.json(rows);
    } catch (error) {
        console.error("데이터 조회 에러:", error);
        res.status(500).json({ success: false });
    }
});

// [2. 전체 게시글 조회 API]
app.get('/api/posts', async (req, res) => {
    try {
        const sql = `
            SELECT 
                m.*, 
                DATE_FORMAT(m.target_date, '%Y-%m-%d') AS target_date,
                c.email AS c_email, c.name AS c_name, c.gender AS c_gender,
                c.current_color AS c_color, c.birth AS c_birth,
                a1.name AS a1_name,
                a2.name AS a2_name,
                a3.name AS a3_name
            FROM posts m
            LEFT JOIN users c ON m.c_uid = c.uid
            LEFT JOIN users a1 ON m.a1_uid = a1.uid
            LEFT JOIN users a2 ON m.a2_uid = a2.uid
            LEFT JOIN users a3 ON m.a3_uid = a3.uid
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
                uid: post.c_uid,
                name: post.c_name || '미정',
                email: post.c_email || '정보 없음',
                gender: post.c_gender || '미정',
                birth: post.c_birth || '정보 없음',
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

// [3. 참여신청 API: a_uid 칸 채우기 & now_count +1]
app.post('/api/posts/:post_id/join', async (req, res) => {
    const { post_id } = req.params;
    const { uid } = req.body;

    try {
        const [posts] = await db.query("SELECT a1_uid, a2_uid, a3_uid, now_count, max_count FROM posts WHERE id = ?", [post_id]);
        if (posts.length === 0) return res.status(404).json({ message: "게시글을 찾을 수 없습니다." });

        const post = posts[0];
        if (post.now_count >= post.max_count) {
            return res.status(400).json({ message: "이미 정원이 가득 찼습니다." });
        }

        let updateColumn = "";
        if (!post.a1_uid) updateColumn = "a1_uid";
        else if (!post.a2_uid) updateColumn = "a2_uid";
        else if (!post.a3_uid) updateColumn = "a3_uid";
        else return res.status(400).json({ message: "더 이상 참여할 수 있는 칸이 없습니다." });

        const sql = `UPDATE posts SET ${updateColumn} = ?, now_count = now_count + 1 WHERE id = ?`;
        await db.query(sql, [uid, post_id]);

        res.json({ success: true, message: `${updateColumn} 자리에 등록 완료!` });
    } catch (error) {
        console.error(error);
        res.status(500).json({ success: false, message: "참여 처리 중 오류 발생" });
    }
});

// [4. 프로필 태그 수정]
app.put('/api/user/profile/:uid/tags', async (req, res) => {
    const { uid } = req.params;
    const { tags } = req.body;
    try {
        const tagsString = JSON.stringify(tags);
        await db.query("UPDATE users SET tags = ? WHERE uid = ?", [tagsString, uid]);
        res.json({ success: true, message: '태그 업데이트 완료', tags });
    } catch (error) {
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

// [5. 회원 탈퇴]
app.delete('/api/user/profile/:uid', async (req, res) => {
    const { uid } = req.params;
    try {
        await db.query("DELETE FROM users WHERE uid = ?", [uid]);
        res.json({ success: true, message: '탈퇴 완료' });
    } catch (error) {
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

// [6. 내 정보 조회 API: 취미 가나다순 정렬 포함]
app.get('/api/user/me', async (req, res) => {
    try {
        const headerUid = req.headers['uid'];
        if (!headerUid) {
            return res.status(400).json({ success: false, message: '헤더에 uid가 없습니다.' });
        }

        const [rows] = await db.query('SELECT * FROM users WHERE uid = ?', [headerUid]);
        if (rows.length === 0) {
            return res.status(404).json({ success: false, message: '유저를 찾을 수 없습니다.' });
        }

        let user = rows[0];

        if (user.tags) {
            try {
                let tagsArray = typeof user.tags === 'string' ? JSON.parse(user.tags) : user.tags;
                if (Array.isArray(tagsArray)) {
                    tagsArray.sort((a, b) => a.localeCompare(b, 'ko'));
                    user.tags = tagsArray;
                }
            } catch (e) {
                console.log("태그 정렬 에러:", e);
            }
        }
        res.json(user);
    } catch (error) {
        console.error("유저 조회 에러:", error);
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

// [7. 게시글 작성 API]
app.post('/api/posts', async (req, res) => {
    const { category, title, now_count, max_count, date, time, location, destination, c_uid } = req.body;
    try {
        const sql = `
            INSERT INTO posts 
            (category, title, now_count, max_count, target_date, target_time, location, destination, c_uid) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `;
        await db.query(sql, [category, title, now_count || 1, max_count, date, time, location, destination, c_uid]);
        res.status(201).json({ success: true, message: '게시글이 저장되었습니다.' });
    } catch (error) {
        console.error("❌ DB 저장 에러:", error);
        res.status(500).json({ success: false, message: '게시글 저장 실패' });
    }
});

const PORT = 3000;
server.listen(PORT, () => {
    console.log(`${PORT}번 포트에서 서버가 정상 가동 중입니다.`);
});
