const passport = require('passport');
const KakaoStrategy = require('passport-kakao').Strategy;
const db = require('./db');

passport.use(new KakaoStrategy({
    clientID: process.env.KAKAO_ID,
    callbackURL: process.env.KAKAO_CALLBACK_URL,
}, async (accessToken, refreshToken, profile, done) => {
    try {
        const kakaoUid = String(profile.id);
        const [rows] = await db.query('SELECT * FROM users WHERE uid = ?', [kakaoUid]);
        
        if (rows.length > 0) {
            return done(null, rows[0]);
        } else {
            const email = profile._json?.kakao_account?.email || null;
            const name = profile.username || profile.displayName || '이름없음';

            await db.query(
                'INSERT INTO users (uid, name, email) VALUES (?, ?, ?)',
                [kakaoUid, name, email]
            );
            const [newUser] = await db.query('SELECT * FROM users WHERE uid = ?', [kakaoUid]);
            return done(null, newUser[0]);
        }
    } catch (error) {
        return done(error);
    }
}));

passport.serializeUser((user, done) => done(null, user));
passport.deserializeUser((user, done) => done(null, user));
