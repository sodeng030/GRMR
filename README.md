1. sql
mysql -u root -p -P 3307

 // 1234

 USE galrae;

 데이터 잘 들어갔는지?
 SELECT * FROM Meetings;

 node app.js
 
정렬 기준	SQL 구문	설명
최신 등록순	ORDER BY m.id DESC	ID 숫자가 큰 것부터 (가장 최근 데이터)
오래된 등록순	ORDER BY m.id ASC	ID 숫자가 작은 것부터 (가장 옛날 데이터)
이름 가나다순	ORDER BY u.name ASC	이름 알파벳/가나다 순서대로
날짜순	ORDER BY m.target_date ASC	모임 날짜가 가까운 순서대로