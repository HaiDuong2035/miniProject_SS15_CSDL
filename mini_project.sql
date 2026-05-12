CREATE DATABASE mini_project;
USE mini_project;

-- 1. TABLE USERS

CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);


-- 2. TABLE POSTS

CREATE TABLE posts (
    post_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    content TEXT NOT NULL,

    like_count INT DEFAULT 0,
    comment_count INT DEFAULT 0,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_posts_users
    FOREIGN KEY (user_id)
    REFERENCES users(user_id)
);

-- FULLTEXT SEARCH

ALTER TABLE posts
ADD FULLTEXT(content);

-- 3. TABLE COMMENTS

CREATE TABLE comments (
    comment_id INT PRIMARY KEY AUTO_INCREMENT,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_comments_posts
    FOREIGN KEY (post_id)
    REFERENCES posts(post_id),

    CONSTRAINT fk_comments_users
    FOREIGN KEY (user_id)
    REFERENCES users(user_id)
);


-- 4. TABLE LIKES

CREATE TABLE likes (
    like_id INT PRIMARY KEY AUTO_INCREMENT,

    user_id INT NOT NULL,
    post_id INT NOT NULL,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_user_post
    UNIQUE(user_id, post_id),

    CONSTRAINT fk_likes_users
    FOREIGN KEY (user_id)
    REFERENCES users(user_id),

    CONSTRAINT fk_likes_posts
    FOREIGN KEY (post_id)
    REFERENCES posts(post_id)
);


-- 5. TABLE FRIENDS

CREATE TABLE friends (
    friendship_id INT PRIMARY KEY AUTO_INCREMENT,

    user_id INT NOT NULL,
    friend_id INT NOT NULL,

    status VARCHAR(20)
    CHECK(status IN ('pending', 'accepted')),

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_not_self_friend
    CHECK(user_id <> friend_id),

    CONSTRAINT fk_friends_user
    FOREIGN KEY (user_id)
    REFERENCES users(user_id),

    CONSTRAINT fk_friends_friend
    FOREIGN KEY (friend_id)
    REFERENCES users(user_id)
);


-- 6. TABLE POST LOGS

CREATE TABLE post_logs (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    post_id INT,
    post_content TEXT,
    deleted_at DATETIME DEFAULT CURRENT_TIMESTAMP
);


INSERT INTO users(username, password, email)
VALUES
('alice', '123456', 'alice@gmail.com'),
('bob', '123456', 'bob@gmail.com'),
('charlie', '123456', 'charlie@gmail.com');


INSERT INTO posts(user_id, content)
VALUES
(1, 'Hello everyone'),
(2, 'Learning MySQL'),
(3, 'Social network project');


INSERT INTO comments(post_id, user_id, content)
VALUES
(1, 2, 'Nice post'),
(1, 3, 'Very good');


INSERT INTO likes(user_id, post_id)
VALUES
(1, 2),
(2, 1),
(3, 1);

INSERT INTO friends(user_id, friend_id, status)
VALUES
(1, 2, 'accepted'),
(1, 3, 'pending');

-- Chức năng 1: Khung nhìn Hồ sơ
create view view_user_info as
select user_id, username, email, created_at
from users;

select * from view_user_info;

-- Chức năng 2: Đăng ký tài khoản
delimiter //

create procedure sp_add_user (
	in p_username varchar(50),
    in p_password varchar(255),
    in p_email varchar(100)
)

begin
	
    declare count_username int;
    declare count_email int;
    
    select count(*) into count_email
    from users
    where email = p_email;
    
    select count(*) into count_username
    from users
    where username = p_username;
    
    if count_email <> 0 then
		signal sqlstate '45000'
        set message_text = 'Email đã tồn tại';
	elseif count_username <> 0 then
		signal sqlstate '45000'
        set message_text = 'Tên đã tồn tại';
	end if;
    
end //

delimiter ;

-- Chức năng 3: Tự động đếm tương tác
delimiter //

create trigger tg_after_like_insert

after insert on likes

for each row

begin
	
    update posts
    set like_count = like_count + 1
    where post_id = new.post_id;
    
end //

delimiter ;

delimiter //

create trigger tg_after_like_delete

after delete on likes

for each row

begin
	
    declare total_like int;
	
    select like_count into total_like
    from posts
    where post_id = old.post_id;
	
    if total_like > 0 then
		update posts
		set like_count = like_count - 1
		where post_id = old.post_id;
	end if;
    
end //

delimiter ;

delimiter //

create trigger tg_after_comment_insert

after insert on comments

for each row

begin
	
    update posts
    set comment_count = comment_count + 1
    where post_id = new.post_id;
    
end //

delimiter ;

delimiter //

create trigger tg_after_comment_delete

after delete on comments

for each row

begin
	
    declare total_comment int;
	
    select comment_count into total_comment
    from posts
    where post_id = old.post_id;
	
    if total_comment > 0 then
		update posts
		set comment_count = comment_count - 1
		where post_id = old.post_id;
	end if;
    
end //

delimiter ;

-- Chức năng 4: Thống kê hoạt động
delimiter //

create procedure sp_user_activity_report ()

begin
	
    select count(p.post_id) as total_post, count(l.like_id) as total_like, count(c.comment_id) as total_comment
    from users u
    left join posts p on p.user_id = u.user_id
    left join likes l on l.user_id = u.user_id
    left join comments c on c.user_id = u.user_id
	group by u.user_id;
    
end //

delimiter ;

-- Chức năng 5: Xóa tài khoản toàn vẹn
delimiter //

create procedure sp_delete_user (
	in p_user_id int
)

begin
	
    start transaction;
    
    delete u, p, l, c
    from users u
    left join posts p on u.user_id = p.user_id
    left join likes l on l.post_id = p.post_id
    left join comments c on c.post_id = p.post_id
    where u.user_id = p_user_id;
    
    commit;
    
end //

delimiter ;

-- Chức năng 6: Kiểm soát kết bạn 
delimiter //

create trigger tg_before_friend_insert

before insert on friends

for each row

begin

	declare count_accepted int;
    declare count_pending int;
    
    select count(*) into count_accepted
    from friends
	where ((user_id = new.user_id and friend_id = new.friend_id) or (user_id = new.friend_id and friend_id = new.user_id)) and status = 'accepted';
    
    select count(*) into count_pending
    from friends
	where ((user_id = new.user_id and friend_id = new.friend_id) or (user_id = new.friend_id and friend_id = new.user_id)) and status = 'pending';
	
    if new.user_id = new.friend_id then
		signal sqlstate '45000'
        set message_text = 'Không thể tự kết bạn';
	elseif count_accepted <> 0 then
			signal sqlstate '45000'
			set message_text = 'Cặp bạn bè đã tồn tại';
	elseif count_pending <> 0 then
			signal sqlstate '45000'
			set message_text = 'Cặp bạn bè đang chờ xác nhận';
    end if;
    
end //

delimiter ;
