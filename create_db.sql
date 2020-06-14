CREATE DATABASE avito_social_network;

CREATE SCHEMA net;

CREATE TABLE net.UserAccount (
    user_id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_name VARCHAR(255) UNIQUE NOT NULL,
	user_login VARCHAR(30) UNIQUE NOT NULL,
	password_hash VARCHAR(256) NOT NULL,
    created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE net.Chat (
    chat_id INT PRIMARY KEY,
    chat_name VARCHAR(255) UNIQUE NOT NULL,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE net.ChatUser (
    user_id INT REFERENCES net.UserAccount(user_id) NOT NULL,
    chat_id INT REFERENCES net.Chat(chat_id) NOT NULL,
    CONSTRAINT PK_ChatUser PRIMARY KEY (user_id, chat_id)
);

CREATE TABLE net.Message (
    message_id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    message_text VARCHAR(1000) NOT NULL,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP,
    chat_id INT REFERENCES net.Chat(chat_id) NOT NULL,
    user_id INT REFERENCES net.UserAccount(user_id) NOT NULL
);

-- Добавить пользователя
CREATE FUNCTION net.add_user(_user_login VARCHAR(30), _password_hash VARCHAR(256), _user_name VARCHAR(255)) RETURNS INT AS
    $$
    BEGIN
        INSERT INTO net.UserAccount(user_name, user_login, password_hash) VALUES (_user_name, _user_login, _password_hash);
        RETURN currval('net.useraccount_user_id_seq');
    END;
    $$ LANGUAGE plpgsql;

-- Создать чат между пользователями
CREATE FUNCTION net.add_chat(_chat_name VARCHAR(255), users json) RETURNS INT AS
    $$
    DECLARE inserted_id INT;
    BEGIN
        INSERT INTO net.Chat(chat_name) VALUES (_chat_name);
        inserted_id := currval('net.chat_chat_id_seq');
        INSERT INTO net.ChatUser(chat_id, user_id) SELECT inserted_id, json_array_elements(users);
        RETURN inserted_id;
    END;
    $$ LANGUAGE plpgsql;

-- Добавить пользователя в чат
CREATE PROCEDURE net.add_chat_member(_user_id INT, _chat_id INT) AS
    $$
    BEGIN
        INSERT INTO net.ChatUser(user_id, chat_id) VALUES (_user_id, _chat_id);
    END;
    $$ LANGUAGE plpgsql;

-- Отправить сообщение в чат
CREATE FUNCTION net.send_message(_user_id INT, _chat_id INT, _message VARCHAR(1000)) RETURNS INT AS
    $$
    BEGIN
        INSERT INTO net.Message(message_text, chat_id, user_id) VALUES (_message, _chat_id, _user_id);
        RETURN currval('net.message_message_id_seq');
    END;
    $$ LANGUAGE plpgsql;

SELECT net.add_user('ivan', 'Иван', 'pass');
SELECT net.add_user('s11', 'Сергей', 'pass');
SELECT net.add_user('dima', 'Дмитрий', 'pass');
SELECT net.add_user('ann', 'Анна', 'pass');
SELECT net.add_user('m11', 'Мария', 'pass');

SELECT net.add_chat('Переговорная1', '[1, 3]');
SELECT net.add_chat('О моде', '[4, 5]');
CALL net.add_chat_member(2, 1);

SELECT net.send_message(1, 1, 'Всем Привет!');
SELECT net.send_message(2, 1, 'Сегодня мы обсудим..');

SELECT net.send_message(4, 2, 'Такс');
SELECT net.send_message(4, 2, 'Приветики');
SELECT net.send_message(5, 2, 'Все завтра!');
SELECT net.send_message(4, 2, 'Но почему..');