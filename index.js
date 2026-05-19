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
                'X-NCP-APIGW-API-KEY-ID': '7wk3yroi5c',
                'X-NCP-APIGW-API-KEY': 'sMbqk6hKGgcu4yuhdHkGrZ0xN8y8sxf26b5aA2Gv'
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
        console.error('지도 검색 실패:', err.response ? err.response.data : err.message);
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


// 현재 진행 중인 약속 조회 (상단 배너용)
app.get('/api/appointments/active', async (req, res) => {
    const uid = req.headers['uid'];

    if (!uid) {
        return res.status(401).json({ error: '인증 정보(uid)가 필요합니다.' });
    }

    try {
        const userRes = await axios.get(`${DB_SERVER_URL}/api/user/me`, {
            headers: { 'uid': uid }
        });
        
        const userAppointments = userRes.data.appointmentId || [];

        // NULL 체크
        if (userAppointments.length === 0) {
            return res.json({ hasActiveMeeting: false });
        }

        const postsRes = await axios.get(`${DB_SERVER_URL}/api/posts/list`, {
            params: { ids: userAppointments.join(',') }
        });
        
        const allPosts = postsRes.data;

        // 현재 시간보다 나중이면서 가장 빠른 약속 찾기 (target_date + target_time 조합)
        const now = new Date();
        const futureAppointments = allPosts
            .map(post => ({
                ...post,
                fullDateTime: new Date(`${post.target_date}T${post.target_time}`)
            }))
            .filter(post => post.fullDateTime > now) // 현재보다 미래인 약속만
            .sort((a, b) => a.fullDateTime - b.fullDateTime); // 가장 빠른 순 정렬

        if (futureAppointments.length === 0) {
            return res.json({ hasActiveMeeting: false });
        }

        const targetPost = futureAppointments[0];
        const participants = [targetPost.c_uid, targetPost.a1_uid, targetPost.a2_uid, targetPost.a3_uid].filter(id => id);

        
        const statesRes = await axios.post(`${DB_SERVER_URL}/api/users/states`, {
            uids: participants
        });
        
        const userStates = statesRes.data;

        // 상태별 카운트
        const counts = { ready: 0, departure: 0, arrival: 0 };
        participants.forEach(pUid => {
            const state = userStates[pUid] || 'ready'; // 기본값은 ready
            if (counts[state] !== undefined) counts[state]++;
        });

        res.json({
            hasActiveMeeting: true,
            appointmentId: targetPost.id,
            title: targetPost.title,
            readyCount: counts.ready,
            departureCount: counts.departure,
            arrivalCount: counts.arrival
        });

    } catch (err) {
        console.error('배너 정보 조회 실패:', err.message);
        res.status(500).json({ error: '데이터 처리 중 오류가 발생했습니다.' });
    }
});


// 내 상태 변경 API (배너의 준비/출발/도착 버튼 클릭 시)
app.post('/api/appointments/status', async (req, res) => {
    const { uid, appointmentId, newStatus } = req.body;

    if (!uid || !appointmentId || !newStatus) {
        return res.status(400).json({ 
            error: '필수 데이터가 누락되었습니다.', 
            details: '{ uid, appointmentId, newStatus }가 모두 필요합니다.' 
        });
    }

    const validStatuses = ['ready', 'departure', 'arrival']; // 준비, 출발, 도착
    if (!validStatuses.includes(newStatus)) {
        return res.status(400).json({ 
            error: '잘못된 상태값입니다.', 
            details: 'ready, departure, arrival 중 하나여야 합니다.' 
        });
    }

    try {
        const response = await axios.post(`${DB_SERVER_URL}/api/appointments/status`, {
            uid,
            appointmentId,
            newStatus
        });

        console.log(`[상태 변경 성공] UID: ${uid} | AppID: ${appointmentId} | Status: ${newStatus}`);
        
        res.json({
            success: true,
            message: `상태가 '${newStatus}'(으)로 변경되었습니다.`,
            data: response.data
        });

    } catch (err) {
        console.error('상태 변경 중 연동 에러:', err.message);
        res.status(500).json({ 
            error: '상태 업데이트 실패', 
            details: err.response?.data?.message || 'DB 서버 연결에 문제가 발생했습니다.' 
        });
    }
});


// 회원 탈퇴 API
app.delete('/api/user/profile', async (req, res) => {
    const uid = req.headers['uid'];

    if (!uid) {
        return res.status(400).json({ error: '사용자 ID(uid)가 누락되었습니다.' });
    }

    try {
        // DB에 삭제 요청
        const response = await axios.delete(`${DB_SERVER_URL}/api/user/profile`, {
        headers: { 'uid': uid }
        });

        console.log(`[회원 탈퇴 성공] UID: ${uid} | 관련 데이터 영구 삭제됨`);

        res.json({
            success: true,
            message: '회원 탈퇴가 완료되었습니다. 모든 개인 데이터가 삭제되었습니다.',
            data: response.data
        });

    } catch (err) {
        console.error('회원 탈퇴 처리 중 에러 발생:', err.message);
        const errMsg = err.response?.data?.message || 'DB 서버 연동 중 오류가 발생했습니다.';
        
        res.status(500).json({ 
            error: '탈퇴 처리 실패', 
            details: errMsg 
        });
    }
});


// 서버 실행 함수
app.listen(port, () => {
    console.log(`서버 주소: http://localhost:${port}`);
});