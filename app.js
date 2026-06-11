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

    // 약속방 입장
    socket.on('join_appointment', ({ uid, appointmentId }) => {
        socket.join(String(appointmentId));
        console.log(`[소켓] ${uid}가 약속방 ${appointmentId} 입장`);
    });

    // 상태 업데이트
    socket.on('update_status', async ({ uid, appointmentId, lat, lng, action }) => {
        try {
            // 기존 FSM 로직 그대로 실행
            const statusMap = { 'ready': 'ready', 'moving': 'moving', 'arrival': 'arrival', 'away': 'away' };
            
            let newStatus = action || 'moving';

            await db.query("UPDATE users SET state = ? ...", [newStatus, base_distance || null, uid]);


            // 카운트 집계
            const [posts] = await db.query(
                "SELECT c_uid, a1_uid, a2_uid, a3_uid FROM posts WHERE id = ?",
                [appointmentId]
            );

            if (posts.length > 0) {
                const post = posts[0];
                const participantUids = [post.c_uid, post.a1_uid, post.a2_uid, post.a3_uid].filter(u => u);
                
                const [counts] = await db.query(`
                    SELECT 
                        COUNT(CASE WHEN state = 'arrival' THEN 1 END) as arrivalCount,
                        COUNT(CASE WHEN state = 'moving' THEN 1 END) as movingCount,
                        COUNT(CASE WHEN state = 'ready' THEN 1 END) as readyCount,
                        COUNT(CASE WHEN state = 'away' THEN 1 END) as awayCount
                    FROM users WHERE uid IN (?)
                `, [participantUids]);

                // 같은 방 전체에 브로드캐스트
                io.to(String(appointmentId)).emit('status_updated', {
                    uid,
                    newStatus,
                    currentDistance: null,
                    arrivalCount: counts[0].arrivalCount,
                    movingCount: counts[0].movingCount,
                    readyCount: counts[0].readyCount,
                    awayCount: counts[0].awayCount
                });
            }
        } catch (error) {
            console.error("소켓 상태 업데이트 에러:", error);
        }
    });

    socket.on('disconnect', () => {
        console.log('소켓 연결 해제 (ID):', socket.id);
    });
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

// [로그인/회원가입 API]
app.post('/api/user/login', async (req, res) => {
    const { uid, nickname, gender, birth, email } = req.body;
    try {
        const [rows] = await db.query('SELECT * FROM users WHERE uid = ?', [uid]);
        
        if (rows.length === 0) {
            await db.query(
                'INSERT INTO users (uid, name, gender, birth, email, current_color) VALUES (?, ?, ?, ?, ?, ?)', 
                [uid, nickname, gender || null, birth || null, email || null, 'orange']
            );
            const [newUser] = await db.query('SELECT * FROM users WHERE uid = ?', [uid]);
            console.log(`[회원가입 완료] 신규 유저: ${nickname}`);
            return res.status(200).json({ success: true, user: newUser[0] });
        } else {
            console.log(`[로그인 완료] 기존 유저: ${nickname}`);
            return res.status(200).json({ success: true, user: rows[0] });
        }
    } catch (err) {
        console.error("로그인 처리 에러:", err);
        return res.status(500).json({ success: false, error: 'DB 로그인 처리 실패' });
    }
});

// [1. 카테고리/취미 목록 API]
app.get('/api/titles', async (req, res) => {
    try {
        const { category } = req.query;
        let sql = 'SELECT * FROM titles ORDER BY category ASC, title ASC';
        let params = [];

        if (category) {
            sql = 'SELECT title FROM titles WHERE category = ? ORDER BY title ASC';
            params = [decodeURIComponent(category)];
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
        const { sortBy, genderFirst } = req.query;
        const uid = req.headers['uid'];

        let genderCondition = '';
        let genderParam = [];

        if (genderFirst === 'true' && uid) {
            const [users] = await db.query('SELECT gender FROM users WHERE uid = ?', [uid]);
            if (users.length > 0 && users[0].gender) {
                genderCondition = 'WHERE (m.gender_filter = ? OR m.gender_filter = "all")';
                genderParam = [users[0].gender];
            }
        }

        const orderBy = sortBy === 'distance'
            ? 'ORDER BY m.target_date ASC'
            : 'ORDER BY m.target_date ASC, m.target_time ASC';

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
            ${genderCondition}
            ${orderBy}
        `;

        const [rows] = await db.query(sql, genderParam);
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
                c_color: post.c_color || 'orange',
            participants: {
                a1_uid: post.a1_uid,
                a1_name: post.a1_name,
                a2_uid: post.a2_uid,
                a2_name: post.a2_name,
                a3_uid: post.a3_uid,
                a3_name: post.a3_name
            },
            lat: post.lat,
            lng: post.lng,
            gender_filter: post.gender_filter,
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
            "SELECT a1_uid, a2_uid, a3_uid, now_count, max_count, gender_filter FROM posts WHERE id = ?",
            [post_id]
        );
        if (posts.length === 0) return res.status(404).json({ message: "게시글을 찾을 수 없습니다." });

        const post = posts[0];

        // 동성 전용 체크 추가
        if (post.gender_filter && post.gender_filter !== 'all') {
            const [users] = await db.query("SELECT gender FROM users WHERE uid = ?", [uid]);
            if (users.length === 0) return res.status(404).json({ message: "유저를 찾을 수 없습니다." });
            if (users[0].gender !== post.gender_filter) {
                return res.status(403).json({ message: "동성 전용 게시글입니다." });
            }
        }

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

// [참여 취소 API]
app.post('/api/posts/:post_id/cancel', async (req, res) => {
    const { post_id } = req.params;
    const { uid } = req.body;

    try {
        const [posts] = await db.query(
            "SELECT a1_uid, a2_uid, a3_uid FROM posts WHERE id = ?",
            [post_id]
        );
        if (posts.length === 0) return res.status(404).json({ message: "게시글을 찾을 수 없습니다." });

        const post = posts[0];
        let updateColumn = "";
        if (post.a1_uid === uid) updateColumn = "a1_uid";
        else if (post.a2_uid === uid) updateColumn = "a2_uid";
        else if (post.a3_uid === uid) updateColumn = "a3_uid";
        else return res.status(400).json({ message: "참여 중인 게시글이 아닙니다." });

        await db.query(
            `UPDATE posts SET ${updateColumn} = NULL, now_count = now_count - 1 WHERE id = ?`,
            [post_id]
        );

        // appointmentId 배열에서 post_id 제거
        const [users] = await db.query("SELECT appointmentId FROM users WHERE uid = ?", [uid]);
        let appointmentIds = [];
        if (users[0].appointmentId) {
            try { appointmentIds = JSON.parse(users[0].appointmentId); } catch (e) { appointmentIds = []; }
        }
        appointmentIds = appointmentIds.filter(id => id !== Number(post_id));
        await db.query("UPDATE users SET appointmentId = ? WHERE uid = ?", [JSON.stringify(appointmentIds), uid]);

        res.json({ success: true, message: '참여 취소 완료!' });
    } catch (error) {
        console.error("참여 취소 에러:", error);
        res.status(500).json({ success: false, message: "취소 처리 중 오류 발생" });
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

// [보관함 - 내 약속 모아보기]
app.get('/api/user/bookmarks', async (req, res) => {
    const uid = req.headers['uid'];
    const { state } = req.query; // 'active', 'completed', 없으면 전체

    if (!uid) return res.status(400).json({ success: false, message: 'uid가 없습니다.' });

    try {
        const [users] = await db.query('SELECT appointmentId FROM users WHERE uid = ?', [uid]);
        let appointmentIds = [];
        if (users[0]?.appointmentId) {
            try { appointmentIds = JSON.parse(users[0].appointmentId); } catch (e) { appointmentIds = []; }
        }

        // state 필터 조건
        const stateCondition = state ? 'AND m.state = ?' : '';
        const stateParam = state ? [state] : [];

        const [posts] = await db.query(`
            SELECT 
                m.*, 
                DATE_FORMAT(m.target_date, '%Y-%m-%d') AS target_date,
                c.name AS c_name, c.gender AS c_gender, c.current_color AS c_color, c.birth AS c_birth,
                a1.name AS a1_name, a2.name AS a2_name, a3.name AS a3_name
            FROM posts m
            LEFT JOIN users c ON m.c_uid = c.uid
            LEFT JOIN users a1 ON m.a1_uid = a1.uid
            LEFT JOIN users a2 ON m.a2_uid = a2.uid
            LEFT JOIN users a3 ON m.a3_uid = a3.uid
            WHERE (m.c_uid = ? OR m.id IN (?))
            ${stateCondition}
            ORDER BY 
                CASE WHEN m.state = 'completed' THEN 1 ELSE 0 END ASC,
                m.target_date ASC
        `, [uid, appointmentIds.length ? appointmentIds : [0], ...stateParam]);

        const formattedPosts = posts.map(post => ({
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
            gender_filter: post.gender_filter,
            c_uid: post.c_uid,
            c_name: post.c_name || '미정',
            c_color: post.c_color || 'orange',
            participants: {
                a1_uid: post.a1_uid, a1_name: post.a1_name,
                a2_uid: post.a2_uid, a2_name: post.a2_name,
                a3_uid: post.a3_uid, a3_name: post.a3_name
            },
            lat: post.lat,
            lng: post.lng,
        }));

        res.json({ success: true, posts: formattedPosts });
    } catch (error) {
        console.error("보관함 조회 에러:", error);
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

// [7. 게시글 작성 API]
app.post('/api/posts', async (req, res) => {
    const { category, title, now_count, max_count, date, time, location, destination, c_uid, gender_filter, lat, lng } = req.body;
    try {
        await db.query(
            `INSERT INTO posts (category, title, now_count, max_count, target_date, target_time, location, destination, c_uid, gender_filter, lat, lng) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [category, title, now_count || 1, max_count, date, time, location, destination, c_uid, gender_filter || 'all', lat || null, lng || null]
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
            AND TIMESTAMP(p.target_date, p.target_time) > NOW()
            ORDER BY ABS(TIMESTAMPDIFF(MINUTE, NOW(), TIMESTAMP(p.target_date, p.target_time))) ASC
            LIMIT 1
        `, [uid, uid, uid, uid]);

        if (posts.length === 0) {
            return res.json({ hasActiveMeeting: false });
        }

        const post = posts[0];
        const participantUids = [post.c_uid, post.a1_uid, post.a2_uid, post.a3_uid].filter(u => u);
        const [participants] = await db.query(
            `SELECT uid, name, state FROM users WHERE uid IN (?)`,
            [participantUids]
        );

        const readyCount = participants.filter(p => p.state === 'ready').length;
        const movingCount = participants.filter(p => p.state === 'moving').length;
        const arrivalCount = participants.filter(p => p.state === 'arrival').length;
        const awayCount = participants.filter(p => p.state === 'away').length;

        res.json({
            hasActiveMeeting: true,
            appointmentId: post.id,
            title: post.title,
            minutesLeft: post.minutesLeft,
            distanceMeter: null,
            lat: post.lat,
            lng: post.lng,
            c_uid: post.c_uid,
            a1_uid: post.a1_uid,
            a2_uid: post.a2_uid,
            a3_uid: post.a3_uid,
            readyCount,
            movingCount,
            arrivalCount,
            awayCount,
            members: participants.map(p => ({ uid: p.uid, name: p.name, state: p.state }))
        });
    } catch (error) {
        console.error("활성 약속 조회 에러:", error);
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

// [9. 내 상태 변경 API - 준비/출발/도착]
app.post('/api/appointments/status', async (req, res) => {
    const { uid, appointmentId, newStatus, base_distance } = req.body;

    // 영어 → 한글 변환
    const statusMap = {
        'ready': 'ready',
        'moving': 'moving',
        'arrival': 'arrival',
        'away': 'away'
    };

    const koreanStatus = statusMap[newStatus];
    if (!koreanStatus) {
        return res.status(400).json({ success: false, message: '유효하지 않은 상태값입니다.' });
    }

    try {
        await db.query(
            "UPDATE users SET state = ?, base_distance = COALESCE(?, base_distance) WHERE uid = ?",
            [koreanStatus, base_distance || null, uid]
        );

        const [posts] = await db.query(
            "SELECT c_uid, a1_uid, a2_uid, a3_uid FROM posts WHERE id = ?",
            [appointmentId]
        );

        if (posts.length > 0) {
            const post = posts[0];
            const participantUids = [post.c_uid, post.a1_uid, post.a2_uid, post.a3_uid].filter(u => u);
            const [participants] = await db.query(
                "SELECT state FROM users WHERE uid IN (?)",
                [participantUids]
            );

            const readyCount = participants.filter(p => p.state === '준비').length;
            const departureCount = participants.filter(p => p.state === '출발').length;
            const arrivalCount = participants.filter(p => p.state === '도착').length;

            return res.json({ 
                success: true, 
                message: `상태가 ${koreanStatus}로 변경되었습니다.`,
                readyCount,
                departureCount,
                arrivalCount
            });
        }

        res.json({ success: true, message: `상태가 ${koreanStatus}로 변경되었습니다.` });
    } catch (error) {
        console.error("상태 변경 에러:", error);
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
            c_color: post.c_color || 'orange',
            participants: {
                a1_uid: post.a1_uid,
                a1_name: post.a1_name,
                a2_uid: post.a2_uid,
                a2_name: post.a2_name,
                a3_uid: post.a3_uid,
                a3_name: post.a3_name
            },
            lat: post.lat,
            lng: post.lng,
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

// [유저 평점 업데이트 API]
app.put('/api/user/profile/:targetUid/rating', async (req, res) => {
    const { targetUid } = req.params;
    const { uid, rating, post_id } = req.body;

    if (rating < 0 || rating > 5) {
        return res.status(400).json({ success: false, message: '평점은 0~5 사이여야 합니다.' });
    }

    try {
        // 대상 유저 존재 확인
        const [target] = await db.query("SELECT rating FROM users WHERE uid = ?", [targetUid]);
        if (target.length === 0) return res.status(404).json({ success: false, message: '유저를 찾을 수 없습니다.' });

        // 중복 평가 확인 (같은 약속에서 같은 유저 평가 방지)
        const [existing] = await db.query(
            'SELECT * FROM ratings WHERE rater_uid = ? AND rated_uid = ? AND post_id = ?',
            [uid, targetUid, post_id]
        );
        if (existing.length > 0) {
            return res.status(400).json({ success: false, error: 'already_rated', message: '이미 평가한 유저입니다.' });
        }

        // ratings 테이블에 저장
        await db.query(
            'INSERT INTO ratings (rater_uid, rated_uid, rating, post_id) VALUES (?, ?, ?, ?)',
            [uid, targetUid, rating, post_id]
        );

        // users 테이블 평점 업데이트 (누적 평균)
        const [allRatings] = await db.query(
            'SELECT AVG(rating) AS avg_rating FROM ratings WHERE rated_uid = ?',
            [targetUid]
        );
        const newAvg = parseFloat(allRatings[0].avg_rating).toFixed(1);
        await db.query("UPDATE users SET rating = ? WHERE uid = ?", [newAvg, targetUid]);

        res.json({ success: true, message: '평점 업데이트 완료', rating: newAvg });
    } catch (error) {
        console.error("평점 업데이트 에러:", error);
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

// [현재 상태 및 목적지 정보 조회]
app.get('/api/appointments/info', async (req, res) => {
    const { uid, appointmentId } = req.query;
    if (!uid || !appointmentId) return res.status(400).json({ success: false, message: 'uid 또는 appointmentId가 없습니다.' });

    try {
        const [users] = await db.query('SELECT state, base_distance FROM users WHERE uid = ?', [uid]);
        if (users.length === 0) return res.status(404).json({ success: false, message: '유저를 찾을 수 없습니다.' });

        const [posts] = await db.query('SELECT lat, lng FROM posts WHERE id = ?', [appointmentId]);
        if (posts.length === 0) return res.status(404).json({ success: false, message: '약속을 찾을 수 없습니다.' });

        res.json({
            state: users[0].state,
            base_distance: users[0].base_distance || null,
            destLat: posts[0].lat,
            destLng: posts[0].lng
        });
    } catch (error) {
        console.error("약속 정보 조회 에러:", error);
        res.status(500).json({ success: false, message: '서버 에러' });
    }
});

const PORT = 3000;
server.listen(PORT, () => {
    console.log(`${PORT}번 포트에서 서버가 정상 가동 중입니다.`);
});