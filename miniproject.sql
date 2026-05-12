create database social_network;
use social_network;
-- tạo bảng
create table users (
    user_id int primary key auto_increment,
    username varchar(100) unique,
    password varchar(100),
    email varchar(100) unique,
    created_at datetime default current_timestamp
);

create table posts (
    post_id int primary key auto_increment,
    user_id int,
    content text,
    like_count int default 0,
    comment_count int default 0,
    created_at datetime default current_timestamp,
    foreign key (user_id) references users(user_id)
);

create table comments (
    comment_id int primary key auto_increment,
    user_id int,
    post_id int,
    content text,
    created_at datetime default current_timestamp,
    foreign key (user_id) references users(user_id),
    foreign key (post_id) references posts(post_id)
);

create table likes (
    like_id int primary key auto_increment,
    user_id int,
    post_id int,
    created_at datetime default current_timestamp,
    unique(user_id, post_id),
    foreign key (user_id) references users(user_id),
    foreign key (post_id) references posts(post_id)
);

create table friends (
    id int primary key auto_increment,
    user_id int,
    friend_id int,
    created_at datetime default current_timestamp,
    foreign key (user_id) references users(user_id),
    foreign key (friend_id) references users(user_id)
);

create table post_logs (
    log_id int primary key auto_increment,
    post_id int,
    post_content text,
    deleted_at datetime default current_timestamp
);

alter table posts add fulltext(content);
-- thêm dữ liệu 
insert into users(username, password, email)
values
('dieu', '123', 'dieu@gmail.com'),
('hung', '123', 'hung@gmail.com'),
('linh', '123', 'linh@gmail.com');

insert into posts(user_id, content)
values
(1, 'hello'),
(2, 'mysql'),
(3, 'social network');

insert into likes(user_id, post_id)
values
(1,2),
(2,1);

insert into comments(user_id, post_id, content)
values
(1,2,'good'),
(2,1,'nice');

insert into friends(user_id, friend_id)
values
(1,2);

-- tạo view
create view view_user_info as
select user_id, username, email, created_at
from users;

-- tạo procedure
delimiter //
create procedure sp_add_user(
    in p_username varchar(100),
    in p_password varchar(100),
    in p_email varchar(100)
)
begin
    if exists(select * from users where username = p_username) then
        select 'username existed';
    elseif exists(select * from users where email = p_email) then
        select 'email existed';

    else
        insert into users(username, password, email)
        values(p_username, p_password, p_email);
        select 'success';
    end if;
end //
delimiter ;

-- trigger 
-- thêm 
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
-- xóa 
delimiter //
create trigger tg_after_like_delete
after delete on likes
for each row
begin
    update posts
    set like_count =
    case
        when like_count > 0 then like_count - 1
        else 0
    end
    where post_id = old.post_id;
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
    update posts
    set comment_count =
    case
        when comment_count > 0 then comment_count - 1
        else 0
    end
    where post_id = old.post_id;
end //
delimiter ;

delimiter //
create procedure sp_user_activity_report()
begin
    select
        u.user_id,
        u.username,
        count(distinct p.post_id) as total_posts,
        count(distinct l.like_id) as total_likes,
        count(distinct c.comment_id) as total_comments
    from users u
    left join posts p on u.user_id = p.user_id
    left join likes l on p.post_id = l.post_id
    left join comments c on p.post_id = c.post_id
    group by u.user_id, u.username;
end //

delimiter ;

delimiter //
create procedure sp_delete_user(
    in p_user_id int
)
begin
    begin
        rollback;
    end;
    start transaction;
    delete from likes
    where user_id = p_user_id
    or post_id in (
        select post_id from posts
        where user_id = p_user_id
    );
    
    delete from comments
    where user_id = p_user_id
    or post_id in (
        select post_id from posts
        where user_id = p_user_id
    );
    delete from friends
    where user_id = p_user_id
    or friend_id = p_user_id;
    delete from posts
    where user_id = p_user_id;
    delete from users
    where user_id = p_user_id;
    commit;
end //
delimiter ;

delimiter //

create trigger tg_before_friend_insert
before insert on friends
for each row
begin
    if new.user_id = new.friend_id then
        set message_text = 'cannot friend yourself';
    end if;
    if exists(
        select *
        from friends
        where user_id = new.user_id
        and friend_id = new.friend_id
    ) then
        set message_text = 'duplicate friend';
    end if;
    if exists(
        select *
        from friends
        where user_id = new.friend_id
        and friend_id = new.user_id
    ) then
        set message_text = 'reverse request';
    end if;
end //
delimiter ;

delimiter //
create trigger trigger_post_delete
after delete on posts
for each row
begin
    insert into post_logs(post_id, post_content)
    values(old.post_id, old.content);
end //
delimiter ;

-- kiểm tra 
select * from view_user_info;
call sp_add_user('an', '123', 'an@gmail.com');
call sp_user_activity_report();
call sp_delete_user(1);
select * from post_logs;
