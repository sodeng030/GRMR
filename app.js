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

const app = express();
const server = http.createServer(app);
const io = new Server(server);

app.use(express.json());
app.use(cors());
app.use(session({
    secret: process.env.SESSION_SECRET || 'galrae-default-secret',
    resave: false,
    saveUninitialized: false
}));
app.use(passport.initialize());
app.use(passport.session());

io.on('connection', (socket) => {
    console.log('소켓 연결 성공 (ID):', socket.id);
});

app.get('/', (req, res) => {
    res.send('✅ 갈래말래 백엔드 서버가 정상 작동 중입니다!');
});

// 카카오 로그인
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

// [1. 카테고리/취미 목록 API]
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
            state: post.state,
            c_uid: post.c_uid,
                c_name: post.c_name || '미정',
                c_email: post.c_email || '정보 없음',
                c_gender: post.c_gender || '미정',
                c_birth: post.c_birth || '정보 없음',
                c_color: post.c_color || 'gray',
            participants: {
                a1_uid: post.a1_uid,
                a1_name: post.a1_name,
                a2_uid: post.a2_uid,
                a2_name: post.a2_name,
                a3_uid: post.a3_uid,
                a3_name: post.a3_name
            }
        }));
        res.json(formattedPosts);
    } catch (error) {
        console.error("게시글 조회 에러:", error);
        res.status(500).json({ success: false, message: '데이터 로드 실패' });
    }
});

// [3. 참여신청 API]
app.post('/api/posts/:post_id/join', async (req, res) => {
    const { post_id } = req.params;
    const { uid } = req.body;

    try {
        const [posts] = await db.query(
            "SELECT a1_uid, a2_uid, a3_uid, now_count, max_count FROM posts WHERE id = ?",
            [post_id]
        );
        if (posts.length === 0) return res.status(404).json({ message: "게시글을 찾을 수 없습니다." });

        const post = posts[0];
        if (post.now_count >= post.max_count) {
            return res.status(400).json({ message: "이미 정원이 가득 찼습니다." });
        }

        let updateColumn = "";
        if (!post.a1_uid) updateColumn = "a1_uid";
        else if (!post.a2_uid) updateColumn = "a2_uid";
        else if (!post.a3_uid) updateColumn = "a3_uid";
        else return res.status(400).json({ message: "더 이상 참여할 수 없습니다." });

        await db.query(
            `UPDATE posts SET ${updateColumn} = ?, now_count = now_count + 1 WHERE id = ?`,
            [uid, post_id]
        );

        // appointmentId 배열에 post_id 추가
        const [users] = await db.query("SELECT appointmentId FROM users WHERE uid = ?", [uid]);
        let appointmentIds = [];
        if (users[0].appointmentId) {
            try { appointmentIds = JSON.parse(users[0].appointmentId); } catch (e) { appointmentIds = []; }
        }
        if (!appointmentIds.includes(Number(post_id))) {
            appointmentIds.push(Number(post_id));
        }
        await db.query("UPDATE users SET appointmentId = ? WHERE uid = ?", [JSON.stringify(appointmentIds), uid]);

        res.json({ success: true, message: `${updateColumn} 자리에 등록 완료!` });
    } catch (error) {
        console.error(error);
        res.status(500).json({ success: false, message: "참여 처리 중 오류 발생" });
    }
});

// [4. 프로필 태그 수정]
app.put('/api/user/profile/tags', async (req, res) => {
    const uid = req.headers['uid'];
    const { tags } = req.body;
    try {
        await db.query("UPDATE users SET tags = ? WHERE uid = ?", [JSON.stringify(tags), uid]);
        res.json({ success: true, message: '태그 업데이트 완료', tags });
    } catch (error) {
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

// [5. 회원 탈퇴]
app.delete('/api/user/profile', async (req, res) => {
    const uid = req.headers['uid'];
    try {
        await db.query("DELETE FROM users WHERE uid = ?", [uid]);
        res.json({ success: true, message: '탈퇴 완료' });
    } catch (error) {
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

// [5 밑 추, 게시글 삭제 API]
app.delete('/api/posts/:id', async (req, res) => {
    const { id } = req.params;
    const uid = req.headers['uid'];

    try {
        const [posts] = await db.query("SELECT c_uid FROM posts WHERE id = ?", [id]);
        if (posts.length === 0) return res.status(404).json({ success: false, message: '게시글을 찾을 수 없습니다.' });

        if (posts[0].c_uid !== uid) {
            return res.status(403).json({ success: false, message: '본인 게시글만 삭제할 수 있습니다.' });
        }

        await db.query("DELETE FROM posts WHERE id = ?", [id]);
        res.json({ success: true, message: '게시글이 삭제되었습니다.' });
    } catch (error) {
        console.error("게시글 삭제 에러:", error);
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

// [6. 유저 정보 조회 API]
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
            let tagsArray = [];
            if (typeof user.tags === 'string') {
                try { tagsArray = JSON.parse(user.tags); } catch (e) { tagsArray = user.tags.split(',').map(t => t.trim()); }
            } else if (Array.isArray(user.tags)) {
                tagsArray = user.tags;
            }
            if (Array.isArray(tagsArray)) {
                tagsArray.sort((a, b) => a.localeCompare(b, 'ko'));
                user.tags = tagsArray;
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
        await db.query(
            `INSERT INTO posts (category, title, now_count, max_count, target_date, target_time, location, destination, c_uid) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [category, title, now_count || 1, max_count, date, time, location, destination, c_uid]
        );
        res.status(201).json({ success: true, message: '게시글이 저장되었습니다.' });
    } catch (error) {
        console.error("DB 저장 에러:", error);
        res.status(500).json({ success: false, message: '게시글 저장 실패' });
    }
});

// [8. 현재 진행 중인 약속 조회]
app.get('/api/appointments/active', async (req, res) => {
    const uid = req.headers['uid'];
    if (!uid) return res.status(400).json({ success: false, message: 'uid가 없습니다.' });

    try {
        await db.query(`
            UPDATE posts 
            SET state = 'completed'
            WHERE state = 'active'
            AND TIMESTAMP(target_date, target_time) < DATE_SUB(NOW(), INTERVAL 3 HOUR)
        `);

        const [posts] = await db.query(`
            SELECT p.*,
                DATE_FORMAT(p.target_date, '%Y-%m-%d') AS target_date,
                TIMESTAMPDIFF(MINUTE, NOW(), TIMESTAMP(p.target_date, p.target_time)) AS minutesLeft
            FROM posts p
            WHERE p.state = 'active'
            AND (p.c_uid = ? OR p.a1_uid = ? OR p.a2_uid = ? OR p.a3_uid = ?)
            ORDER BY p.target_date ASC, p.target_time ASC
            LIMIT 1
        `, [uid, uid, uid, uid]);

        if (posts.length === 0) {
            return res.json({ hasActiveMeeting: false });
        }

        const post = posts[0];
        const participantUids = [post.c_uid, post.a1_uid, post.a2_uid, post.a3_uid].filter(u => u);
        const [participants] = await db.query(
            `SELECT state FROM users WHERE uid IN (?)`,
            [participantUids]
        );

        const readyCount = participants.filter(p => p.state === '준비').length;
        const departureCount = participants.filter(p => p.state === '출발').length;
        const arrivalCount = participants.filter(p => p.state === '도착').length;

        res.json({
            hasActiveMeeting: true,
            appointmentId: post.id,
            title: post.title,
            minutesLeft: post.minutesLeft,
            distanceMeter: null,
            readyCount,
            departureCount,
            arrivalCount
        });
    } catch (error) {
        console.error("활성 약속 조회 에러:", error);
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

// [9. 내 상태 변경 API - 준비/출발/도착]
app.post('/api/appointments/status', async (req, res) => {
    const { uid, appointmentId, newStatus } = req.body;

    if (!['준비', '출발', '도착'].includes(newStatus)) {
        return res.status(400).json({ success: false, message: '유효하지 않은 상태값입니다.' });
    }

    try {
        await db.query("UPDATE users SET state = ? WHERE uid = ?", [newStatus, uid]);
        res.json({ success: true, message: `상태가 ${newStatus}로 변경되었습니다.` });
    } catch (error) {
        console.error("상태 변경 에러:", error);
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

// [10. 역지오코딩 API - 위도/경도 → 한국어 주소]
app.get('/api/map/reverse-geocode', async (req, res) => {
    const { lat, lng } = req.query;
    try {
        const response = await fetch(
            `https://naveropenapi.apigw.ntruss.com/map-reversegeocode/v2/gc?coords=${lng},${lat}&output=json&orders=roadaddr,addr`,
            {
                headers: {
                    'X-NCP-APIGW-API-KEY-ID': process.env.NAVER_MAP_CLIENT_ID,
                    'X-NCP-APIGW-API-KEY': process.env.NAVER_MAP_CLIENT_SECRET,
                }
            }
        );
        const data = await response.json();
        const region = data.results?.[0];
        if (!region) return res.status(404).json({ success: false, message: '주소를 찾을 수 없습니다.' });

        const area1 = region.region?.area1?.name || '';
        const area2 = region.region?.area2?.name || '';
        const area3 = region.region?.area3?.name || '';
        const roadName = region.land?.name || '';
        const buildingNumber = region.land?.number1 || '';
        const address = `${area1} ${area2} ${area3} ${roadName} ${buildingNumber}`.trim();

        res.json({ success: true, address });
    } catch (error) {
        console.error("역지오코딩 에러:", error);
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

// [게시글 여러 개 한 번에 조회]
app.get('/api/posts/list', async (req, res) => {
    const { ids } = req.query;
    if (!ids) return res.status(400).json({ success: false, message: 'ids가 없습니다.' });

    try {
        const idArray = ids.split(',').map(id => parseInt(id.trim())).filter(id => !isNaN(id));
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
            WHERE m.id IN (?)
        `;
        const [rows] = await db.query(sql, [idArray]);
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
            state: post.state,
            c_uid: post.c_uid,
            c_name: post.c_name || '미정',
            c_email: post.c_email || '정보 없음',
            c_gender: post.c_gender || '미정',
            c_birth: post.c_birth || '정보 없음',
            c_color: post.c_color || 'gray',
            participants: {
                a1_uid: post.a1_uid,
                a1_name: post.a1_name,
                a2_uid: post.a2_uid,
                a2_name: post.a2_name,
                a3_uid: post.a3_uid,
                a3_name: post.a3_name
            }
        }));
        res.json(formattedPosts);
    } catch (error) {
        console.error("게시글 다중 조회 에러:", error);
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

// [참여자 여러 명 상태 한 번에 조회]
app.post('/api/users/states', async (req, res) => {
    const { uids } = req.body;
    if (!uids || !Array.isArray(uids)) {
        return res.status(400).json({ success: false, message: 'uids 배열이 없습니다.' });
    }

    try {
        const [users] = await db.query(
            'SELECT uid, state FROM users WHERE uid IN (?)',
            [uids]
        );

        const result = {};
        uids.forEach(uid => { result[uid] = 'ready'; }); // 기본값 ready
        users.forEach(user => { result[user.uid] = user.state || 'ready'; });

        res.json(result);
    } catch (error) {
        console.error("상태 다중 조회 에러:", error);
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

// [유저 평점 업가데이트 API]
app.put('/api/user/profile/:targetUid/rating', async (req, res) => {
    const { targetUid } = req.params;
    const { uid, rating } = req.body;

    if (rating < 0 || rating > 5) {
        return res.status(400).json({ success: false, message: '평점은 0~5 사이여야 합니다.' });
    }

    try {
        // 평가받는 유저 존재 확인
        const [target] = await db.query("SELECT rating FROM users WHERE uid = ?", [targetUid]);
        if (target.length === 0) return res.status(404).json({ success: false, message: '유저를 찾을 수 없습니다.' });

        // 평점 업데이트 (기존 평점과 새 평점 평균)
        const currentRating = target[0].rating || 0;
        const newRating = currentRating === 0 
            ? rating.toFixed(1) 
            : ((currentRating + rating) / 2).toFixed(1);

        await db.query("UPDATE users SET rating = ? WHERE uid = ?", [newRating, targetUid]);

        res.json({ success: true, message: '평점 업데이트 완료', rating: newRating });
    } catch (error) {
        console.error("평점 업데이트 에러:", error);
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

const PORT = 3000;
server.listen(PORT, () => {
    console.log(`${PORT}번 포트에서 서버가 정상 가동 중입니다.`);
});