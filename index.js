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


// 통합 장소 검색 API
app.get('/api/map/search/place', async (req, res) => {
    const { query } = req.query;

    if (!query) {
        return res.status(400).json({ error: '검색어를 입력해주세요.' });
    }

    try {

        console.log(`[geocode] 검색 시도: ${query}`);

        const mapResponse = await axios.get('https://maps.apigw.ntruss.com/map-geocode/v2/geocode', {
            params: { query: query },
            headers: {
                'X-NCP-APIGW-API-KEY-ID': '7wk3yroi5c',
                'X-NCP-APIGW-API-KEY': 'sMbqk6hKGgcu4yuhdHkGrZ0xN8y8sxf26b5aA2Gv'
            }
        });

        const addresses = mapResponse.data.addresses;

        if (addresses && addresses.length > 0) {
            const geoResult = addresses[0];
            const processedData = {
                placeName: query,
                address: geoResult.roadAddress || query,
                lat: geoResult.y, 
                lng: geoResult.x  
            };

            console.log(`[geocode] 주소 매핑 완료 -> lat: ${processedData.lat}`);
            return res.json(processedData);
        }


        console.log(`[developers] 검색 시도: ${query}`);

        const searchResponse = await axios.get('https://openapi.naver.com/v1/search/local.json', {
            params: { query: query, display: 1 }, 
            headers: {
                'X-Naver-Client-Id': 'nmatxOMlsM9Y4bzebIuG', 
                'X-Naver-Client-Secret': 'yThjq9bf9T'
            }
        });

        const items = searchResponse.data.items;

        if (!items || items.length === 0) {
            return res.status(404).json({ message: '검색 결과가 없습니다.' });
        }

        const targetPlace = items[0];
        const realAddress = targetPlace.roadAddress || targetPlace.address;
        const cleanTitle = targetPlace.title.replace(/<[^>]*>?/g, '');

        const finalMapResponse = await axios.get('https://maps.apigw.ntruss.com/map-geocode/v2/geocode', {
            params: { query: realAddress },
            headers: {
                'X-NCP-APIGW-API-KEY-ID': '7wk3yroi5c',
                'X-NCP-APIGW-API-KEY': 'sMbqk6hKGgcu4yuhdHkGrZ0xN8y8sxf26b5aA2Gv'
            }
        });

        const finalAddresses = finalMapResponse.data.addresses;

        if (finalAddresses && finalAddresses.length > 0) {
            const finalGeoResult = finalAddresses[0];

            const processedData = {
                placeName: cleanTitle,
                address: finalGeoResult.roadAddress || realAddress,
                lat: finalGeoResult.y, 
                lng: finalGeoResult.x  
            };

            console.log(`[developers] 건물명 변환 완료 -> lat: ${processedData.lat}`);
            return res.json(processedData);
        } else {
            return res.status(404).json({ message: '장소의 좌표 정보가 존재하지 않습니다.' });
        }

    } catch (err) {
        console.error('통합 검색 에러:', err.message);
        return res.status(500).json({ 
            error: '지도 정보를 가져오지 못했습니다.',
            details: err.response?.data || err.message
        });
    }
});


// 위도/경도 -> 주소 변환 API
app.get('/api/map/reverse-geocode', async (req, res) => {
    const { lat, lng } = req.query;

    if (!lat || !lng) {
        return res.status(400).json({ error: '위도(lat)와 경도(lng) 파라미터가 필요합니다.' });
    }

    try {
        console.log(`[reverse-geocode] 주소 변환 시도: lat=${lat}, lng=${lng}`);

        const mapResponse = await axios.get('https://naveropenapi.apigw.ntruss.com/map-reversegeocode/v2/gc', {
            params: {
                coords: `${lng},${lat}`,
                orders: 'roadaddr,addr',
                output: 'json'
            },
            headers: {
                'X-NCP-APIGW-API-KEY-ID': '7wk3yroi5c',
                'X-NCP-APIGW-API-KEY': 'sMbqk6hKGgcu4yuhdHkGrZ0xN8y8sxf26b5aA2Gv'
            }
        });

        const results = mapResponse.data.results;

        if (!results || results.length === 0) {
            return res.status(404).json({ message: '해당 좌표에 대한 주소 정보를 찾을 수 없습니다.' });
        }

        const region = results[0].region;
        const land = results[0].land;
        
        let fullAddress = `${region.area1.name} ${region.area2.name} ${region.area3.name}`;
        
        if (land && land.name) {
            fullAddress += ` ${land.name} ${land.number1}`;
            if (land.number2) fullAddress += `-${land.number2}`;
        }
        else if (land && land.number1) {
            fullAddress += ` ${land.number1}`;
            if (land.number2) fullAddress += `-${land.number2}`;
        }

        const processedData = {
            address: fullAddress.trim(),
            lat: parseFloat(lat),
            lng: parseFloat(lng)
        };

        console.log(`[reverse-geocode] 변환 완료 -> ${processedData.address}`);
        return res.json(processedData);

    } catch (err) {
        console.error('리버스 지오코딩 에러:', err.message);
        return res.status(500).json({ 
            error: '좌표를 주소로 변환하지 못했습니다.',
            details: err.response?.data || err.message
        });
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


// 게시글 삭제 API
app.delete('/api/posts/:id', async (req, res) => {
    const postId = req.params.id;         
    const userUid = req.headers['uid'];   

    if (!postId) {
        return res.status(400).json({ error: '삭제할 게시글 ID가 필요합니다.' });
    }
    if (!userUid) {
        return res.status(401).json({ error: '인증되지 않은 사용자입니다. (uid 누락)' });
    }

    try {
        const response = await axios.delete(`${DB_SERVER_URL}/api/posts/${postId}`, {
            headers: { 'uid': userUid }
        });

        console.log(`[삭제 연동 성공] 글 ID: ${postId} | 요청자 uid: ${userUid}`);
        return res.status(200).json(response.data);

    } catch (err) {
        console.error('게시글 삭제 브릿지 연동 에러:', err.message);
        
        const statusCode = err.response?.status || 500;
        const errMsg = err.response?.data?.error || err.response?.data?.message || 'DB 서버 통신 중 오류가 발생했습니다.';
        
        return res.status(statusCode).json({ 
            error: '게시글을 삭제하지 못했습니다.',
            details: errMsg 
        });
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
        const response = await axios.get(`${DB_SERVER_URL}/api/appointments/active`, {
            headers: { 'uid': uid }
        });
        
        console.log(`[배너 조회 연동 성공] UID: ${uid}`);
        return res.json(response.data);

    } catch (err) {
        console.error('배너 정보 조회 실패:', err.message);
        const statusCode = err.response?.status || 500;
        return res.status(statusCode).json({ 
            error: '배너 데이터를 가져오지 못했습니다.',
            details: err.response?.data || err.message 
        });
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


// 유저 평가 API
app.put('/api/user/profile/:targetUid/rating', async (req, res) => {
    const { targetUid } = req.params;
    const { rating, uid } = req.body;

    if (!targetUid || !uid) {
        return res.status(400).json({ error: '평가 대상(targetUid) 또는 평가자(uid) 정보가 누락되었습니다.' });
    }
    if (rating === undefined || rating === null) {
        return res.status(400).json({ error: '별점(rating) 점수가 없습니다.' });
    }

    try {
        const response = await axios.put(`${DB_SERVER_URL}/api/user/profile/${targetUid}/rating`, {
            rating: rating,
            uid: uid
        });

        console.log(`[평가 업데이트 성공] ${uid} -> ${targetUid} (${rating}점)`);
        
        return res.status(200).json({
            success: true,
            message: '평가가 성공적으로 반영되었습니다.',
            data: response.data
        });

    } catch (err) {
        console.error('평가 연동 에러:', err.message);
        
        const statusCode = err.response?.status || 500;
        const errMsg = err.response?.data?.error || err.response?.data?.message || 'DB 서버 통신 중 오류가 발생했습니다.';
        
        return res.status(statusCode).json({ 
            error: '평가 업데이트에 실패했습니다.',
            details: errMsg 
        });
    }
});


// 프로필 태그 API
app.put('/api/user/profile/tags', async (req, res) => {
    const uid = req.headers['uid'];
    const { tags } = req.body;

    if (!uid) {
        return res.status(401).json({ error: '인증되지 않은 사용자입니다. (uid 누락)' });
    }
    if (!tags || !Array.isArray(tags)) {
        return res.status(400).json({ error: 'tags 데이터가 올바른 배열 형식이 아닙니다.' });
    }

    try {
        const response = await axios.put(`${DB_SERVER_URL}/api/user/profile/tags`, 
            { tags: tags },
            { headers: { 'uid': uid } }
        );

        console.log(`[태그 업데이트 연동 성공] UID: ${uid} | 새 태그: ${tags.join(', ')}`);
        
        return res.status(200).json({
            success: true,
            message: '태그가 성공적으로 업데이트되었습니다.',
            data: response.data
        });

    } catch (err) {
        console.error('태그 업데이트 연동 에러:', err.message);
        
        const statusCode = err.response?.status || 500;
        const errMsg = err.response?.data?.error || err.response?.data?.message || 'DB 서버 통신 중 오류가 발생했습니다.';
        
        return res.status(statusCode).json({ 
            error: '태그 업데이트에 실패했습니다.',
            details: errMsg 
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