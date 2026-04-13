const passport = require('passport');
const KakaoStrategy = require('passport-kakao').Strategy;
const db = require('./db'); // 아까 만든 DB 연결 파일

passport.use(new KakaoStrategy({
    clientID: process.env.KAKAO_ID,
    callbackURL: process.env.KAKAO_CALLBACK_URL,
}, async (accessToken, refreshToken, profile, done) => {
    try {
        // 2주차 설계: kakao_id로 기존 유저인지 확인 
        const [rows] = await db.query('SELECT * FROM Users WHERE kakao_id = ?', [profile.id]);
        
        if (rows.length > 0) {
            return done(null, rows[0]);
        } else {
            // 신규 유저라면 DB에 저장 (신뢰 지수 기본값 0.0 반영) 
            const [result] = await db.query(
                'INSERT INTO Users (kakao_id, nickname, trust_score) VALUES (?, ?, ?)',
                [profile.id, profile.username, 0.0]
            );
            const [newUser] = await db.query('SELECT * FROM Users WHERE id = ?', [result.insertId]);
            return done(null, newUser[0]);
        }
    } catch (error) {
        return done(error);
    }
}));

passport.serializeUser((user, done) => done(null, user));
passport.deserializeUser((user, done) => done(null, user));